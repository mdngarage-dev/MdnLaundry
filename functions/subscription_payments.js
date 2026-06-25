const functions = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
const axios = require("axios");
require("dotenv").config();

admin.initializeApp();
const db = admin.firestore();

const XENDIT_API_KEY = process.env.XENDIT_API_KEY;
const XENDIT_BASE_URL = "https://api.xendit.co";

// ──────────────────────────────────────────────────────────────────────────
// FUNCTION 1: Generate QRIS Invoice untuk payment
// ──────────────────────────────────────────────────────────────────────────
exports.generateQrisInvoice = functions.https.onCall(async (request) => {
  if (!request.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "User harus login"
    );
  }

  const { storeId, outletId, packageId, amount } = request.data;

  if (!storeId || !outletId || !packageId || !amount) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Missing required fields"
    );
  }

  try {
    // 1. Get outlet info
    const outletSnap = await db
      .collection("stores")
      .doc(storeId)
      .collection("outlets")
      .doc(outletId)
      .get();

    if (!outletSnap.exists) {
      throw new Error("Outlet tidak ditemukan");
    }

    const outletData = outletSnap.data();
    const outletName = outletData.nama_outlet || "Outlet";

    // 2. Create invoice di Xendit
    const invoiceData = {
      external_id: `${storeId}_${outletId}_${Date.now()}`,
      amount: parseInt(amount),
      description: `Subscription ${packageId} - ${outletName}`,
      invoice_duration: 259200, // 3 hari dalam detik
      customer: {
        given_names: outletName,
        email: request.auth.token.email || "",
      },
      items: [
        {
          name: `Paket ${packageId.toUpperCase()}`,
          quantity: 1,
          price: parseInt(amount),
        },
      ],
      fees: [
        {
          type: "ADMIN",
          value: 0, // atau set fee jika ingin
        },
      ],
    };

    const response = await axios.post(
      `${XENDIT_BASE_URL}/v2/invoices`,
      invoiceData,
      {
        auth: {
          username: XENDIT_API_KEY,
          password: "",
        },
      }
    );

    const invoiceId = response.data.id;
    const qrisUrl = response.data.invoice_url;

    // 3. Simpan payment record ke Firestore
    await db
      .collection("stores")
      .doc(storeId)
      .collection("outlets")
      .doc(outletId)
      .collection("payment_history")
      .add({
        invoice_id: invoiceId,
        package_id: packageId,
        amount: amount,
        status: "pending", // pending, completed, failed
        qris_url: qrisUrl,
        external_id: invoiceData.external_id,
        created_at: admin.firestore.FieldValue.serverTimestamp(),
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
        verified_at: null,
      });

    console.log(`✅ QRIS invoice created: ${invoiceId}`);

    return {
      success: true,
      invoice_id: invoiceId,
      qris_url: qrisUrl,
      external_id: invoiceData.external_id,
    };
  } catch (error) {
    console.error("❌ Error generating QRIS:", error);
    throw new functions.https.HttpsError("internal", error.message);
  }
});

// ──────────────────────────────────────────────────────────────────────────
// FUNCTION 2: Daily cron - Verify pending invoices & update subscription
// ──────────────────────────────────────────────────────────────────────────
exports.verifyPendingPayments = onSchedule(
  {
    schedule: "0 */6 * * *", // setiap 6 jam
    timeZone: "Asia/Jakarta",
    region: "asia-southeast1",
  },
  async (event) => {
    console.log("🔄 Verifying pending payments...");

    try {
      // 1. Cari semua payment record yang masih pending
      const pendingSnap = await db
        .collectionGroup("payment_history")
        .where("status", "==", "pending")
        .get();

      console.log(`Found ${pendingSnap.size} pending payments`);

      for (const paymentDoc of pendingSnap.docs) {
        const paymentData = paymentDoc.data();
        const invoiceId = paymentData.invoice_id;

        try {
          // 2. Check status invoice ke Xendit
          const invoiceResponse = await axios.get(
            `${XENDIT_BASE_URL}/v2/invoices/${invoiceId}`,
            {
              auth: {
                username: XENDIT_API_KEY,
                password: "",
              },
            }
          );

          const invoiceStatus = invoiceResponse.data.status; // PAID, PENDING, EXPIRED

          if (invoiceStatus === "PAID") {
            // 3. Invoice sudah lunas → update subscription
            const pathParts = paymentDoc.ref.parent.parent;
            const outletId = pathParts.id;
            const storeId = pathParts.parent.parent.id;

            console.log(
              `💰 Invoice ${invoiceId} paid! Updating subscription...`
            );

            // Upgrade subscription
            const now = new Date();
            const nextPaymentDue = new Date(
              now.getFullYear(),
              now.getMonth() + 1,
              now.getDate()
            );

            await db
              .collection("stores")
              .doc(storeId)
              .collection("outlets")
              .doc(outletId)
              .collection("subscription")
              .doc("active")
              .update({
                status: "active",
                plan: paymentData.package_id,
                subscription_start_date: admin.firestore.FieldValue
                  .serverTimestamp(),
                subscription_end_date: admin.firestore.Timestamp.fromDate(
                  nextPaymentDue
                ),
                last_payment_date: admin.firestore.FieldValue.serverTimestamp(),
                next_payment_due: admin.firestore.Timestamp.fromDate(
                  nextPaymentDue
                ),
                qris_reference: invoiceId,
                notified_h3: false,
                updated_at: admin.firestore.FieldValue.serverTimestamp(),
              });

            // Update payment record
            await paymentDoc.ref.update({
              status: "completed",
              verified_at: admin.firestore.FieldValue.serverTimestamp(),
              updated_at: admin.firestore.FieldValue.serverTimestamp(),
            });

            console.log(`✅ Subscription updated for outlet ${outletId}`);
          } else if (invoiceStatus === "EXPIRED") {
            // Invoice expired → update payment record
            await paymentDoc.ref.update({
              status: "expired",
              updated_at: admin.firestore.FieldValue.serverTimestamp(),
            });

            console.log(`⏰ Invoice ${invoiceId} expired`);
          }
          // PENDING → tunggu verification berikutnya
        } catch (invoiceError) {
          console.error(
            `❌ Error checking invoice ${invoiceId}:`,
            invoiceError
          );
        }
      }

      console.log("✅ Payment verification completed");
    } catch (error) {
      console.error("❌ Error in verifyPendingPayments:", error);
    }
  }
);

// ──────────────────────────────────────────────────────────────────────────
// FUNCTION 3: Get payment history (untuk admin dashboard)
// ──────────────────────────────────────────────────────────────────────────
exports.getPaymentHistory = functions.https.onCall(async (request) => {
  if (!request.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "User harus login"
    );
  }

  const { storeId, outletId } = request.data;

  try {
    const paymentSnap = await db
      .collection("stores")
      .doc(storeId)
      .collection("outlets")
      .doc(outletId)
      .collection("payment_history")
      .orderBy("created_at", "desc")
      .limit(50)
      .get();

    const history = paymentSnap.docs.map((doc) => ({
      id: doc.id,
      ...doc.data(),
      created_at: doc.data().created_at?.toDate().toISOString(),
      verified_at: doc.data().verified_at?.toDate().toISOString(),
      updated_at: doc.data().updated_at?.toDate().toISOString(),
    }));

    return { success: true, history };
  } catch (error) {
    throw new functions.https.HttpsError("internal", error.message);
  }
});
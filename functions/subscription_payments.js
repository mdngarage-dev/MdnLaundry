const { onCall, HttpsError, onRequest } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin"); // ← require SAJA, JANGAN initializeApp()
const axios = require("axios");
require("dotenv").config();

// ── Pakai db dari admin yang sudah di-init di index.js ───────────────────────
const db = admin.firestore();

// ── Midtrans Config ──────────────────────────────────────────────────────────
const MIDTRANS_SERVER_KEY = process.env.MIDTRANS_SERVER_KEY;
// const MIDTRANS_BASE_URL = "https://api.midtrans.com"; // Production (aktifkan nanti)
const MIDTRANS_BASE_URL = "https://api.sandbox.midtrans.com"; // Sandbox

const midtransAuth = () =>
  Buffer.from(`${MIDTRANS_SERVER_KEY}:`).toString("base64");

// ────────────────────────────────────────────────────────────────────────────
// FUNCTION 1: Create Midtrans Transaction (QRIS)
// ────────────────────────────────────────────────────────────────────────────
exports.createMidtransTransaction = onCall(
  { region: "asia-southeast1" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "User harus login");
    }

    const { storeId, outletId, packageId, amount } = request.data;

    if (!storeId || !outletId || !packageId || !amount) {
      throw new HttpsError(
        "invalid-argument",
        "Missing required fields: storeId, outletId, packageId, amount"
      );
    }

    try {
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
      const noHp = outletData.no_hp || "";

      const orderId = `SUB-${storeId.slice(0, 6)}-${outletId.slice(0, 6)}-${Date.now()}`;

      const chargePayload = {
        payment_type: "qris",
        transaction_details: {
          order_id: orderId,
          gross_amount: parseInt(amount),
        },
        item_details: [
          {
            id: packageId,
            price: parseInt(amount),
            quantity: 1,
            name: `Subscription ${packageId.toUpperCase()} - ${outletName}`,
          },
        ],
        customer_details: {
          first_name: outletName,
          email: request.auth.token.email || "",
          phone: noHp,
        },
        qris: {
          acquirer: "gopay",
        },
      };

      console.log(`🔄 Creating Midtrans transaction: ${orderId}, amount: ${amount}`);

      const response = await axios.post(
        `${MIDTRANS_BASE_URL}/v2/charge`,
        chargePayload,
        {
          headers: {
            "Content-Type": "application/json",
            Accept: "application/json",
            Authorization: `Basic ${midtransAuth()}`,
          },
        }
      );

      const transactionData = response.data;
      console.log(`📨 Midtrans response: ${transactionData.status_code} - ${transactionData.status_message}`);

      if (transactionData.status_code !== "201" && transactionData.status_code !== 201) {
        throw new Error(`Midtrans error: ${transactionData.status_message}`);
      }

      const qrCodeUrl =
        transactionData.actions?.find((a) => a.name === "generate-qr-code")?.url || "";
      const qrRawString = transactionData.qr_string || "";

      const paymentRef = await db
        .collection("stores")
        .doc(storeId)
        .collection("outlets")
        .doc(outletId)
        .collection("payment_history")
        .add({
          order_id: orderId,
          transaction_id: transactionData.transaction_id || "",
          package_id: packageId,
          amount: parseInt(amount),
          status: "pending",
          qr_code_url: qrCodeUrl,
          qr_string: qrRawString,
          payment_type: "qris",
          store_id: storeId,
          outlet_id: outletId,
          created_at: admin.firestore.FieldValue.serverTimestamp(),
          updated_at: admin.firestore.FieldValue.serverTimestamp(),
          verified_at: null,
        });

      console.log(`✅ Transaction created: ${orderId}`);

      return {
        success: true,
        order_id: orderId,
        transaction_id: transactionData.transaction_id,
        qr_code_url: qrCodeUrl,
        qr_string: qrRawString,
        amount: parseInt(amount),
        payment_record_id: paymentRef.id,
      };
    } catch (error) {
      console.error("❌ Error:", error.message);
      if (error.response?.data) {
        console.error("Midtrans response:", JSON.stringify(error.response.data));
      }
      throw new HttpsError(
        "internal",
        error.response?.data?.status_message || error.message
      );
    }
  }
);

// ────────────────────────────────────────────────────────────────────────────
// FUNCTION 2: Midtrans Webhook Handler
// ────────────────────────────────────────────────────────────────────────────
exports.midtransWebhook = onRequest(
  { region: "asia-southeast1" },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).send("Method Not Allowed");
      return;
    }

    try {
      const notif = req.body;

      console.log("📨 Webhook received:", notif.order_id, notif.transaction_status);

      const orderId = notif.order_id;
      const transactionStatus = notif.transaction_status;
      const fraudStatus = notif.fraud_status;
      const transactionId = notif.transaction_id;

      // Verify signature
      const crypto = require("crypto");
      const signatureKey = crypto
        .createHash("sha512")
        .update(`${orderId}${notif.status_code}${notif.gross_amount}${MIDTRANS_SERVER_KEY}`)
        .digest("hex");

      if (signatureKey !== notif.signature_key) {
        console.error("❌ Invalid signature!");
        res.status(403).json({ error: "Invalid signature" });
        return;
      }

      const paymentQuery = await db
        .collectionGroup("payment_history")
        .where("order_id", "==", orderId)
        .limit(1)
        .get();

      if (paymentQuery.empty) {
        console.error(`❌ Payment record tidak ditemukan: ${orderId}`);
        res.status(200).json({ message: "Order not found, skipped" });
        return;
      }

      const paymentDoc = paymentQuery.docs[0];
      const paymentData = paymentDoc.data();
      const storeId = paymentData.store_id;
      const outletId = paymentData.outlet_id;

      let finalStatus = "pending";
      let isPaid = false;

      if (transactionStatus === "settlement") {
        finalStatus = "settlement";
        isPaid = true;
      } else if (transactionStatus === "capture" && fraudStatus === "accept") {
        finalStatus = "settlement";
        isPaid = true;
      } else if (["cancel", "deny", "expire"].includes(transactionStatus)) {
        finalStatus = transactionStatus;
      }

      if (isPaid) {
        const now = new Date();
        const nextPaymentDue = new Date(now.getFullYear(), now.getMonth() + 1, now.getDate());

        await db
          .collection("stores").doc(storeId)
          .collection("outlets").doc(outletId)
          .collection("subscription").doc("active")
          .update({
            status: "active",
            plan: paymentData.package_id,
            subscription_start_date: admin.firestore.FieldValue.serverTimestamp(),
            subscription_end_date: admin.firestore.Timestamp.fromDate(nextPaymentDue),
            last_payment_date: admin.firestore.FieldValue.serverTimestamp(),
            next_payment_due: admin.firestore.Timestamp.fromDate(nextPaymentDue),
            midtrans_order_id: orderId,
            notified_h3: false,
            updated_at: admin.firestore.FieldValue.serverTimestamp(),
          });

        await paymentDoc.ref.update({
          status: "settlement",
          transaction_id: transactionId,
          verified_at: admin.firestore.FieldValue.serverTimestamp(),
          updated_at: admin.firestore.FieldValue.serverTimestamp(),
        });

        console.log(`✅ Subscription AKTIF: outlet ${outletId}`);
      } else {
        await paymentDoc.ref.update({
          status: finalStatus,
          updated_at: admin.firestore.FieldValue.serverTimestamp(),
        });
        console.log(`ℹ️ Payment ${finalStatus}: ${orderId}`);
      }

      res.status(200).json({ message: "OK", status: finalStatus });
    } catch (error) {
      console.error("❌ Webhook error:", error);
      res.status(200).json({ error: error.message });
    }
  }
);

// ────────────────────────────────────────────────────────────────────────────
// FUNCTION 3: Cron backup - cek pending setiap 1 jam
// ────────────────────────────────────────────────────────────────────────────
exports.checkPendingTransactions = onSchedule(
  { schedule: "0 * * * *", timeZone: "Asia/Jakarta", region: "asia-southeast1" },
  async (event) => {
    console.log("🔄 Checking pending transactions...");

    try {
      const tenMinutesAgo = new Date(Date.now() - 10 * 60 * 1000);

      const pendingSnap = await db
        .collectionGroup("payment_history")
        .where("status", "==", "pending")
        .where("created_at", "<=", admin.firestore.Timestamp.fromDate(tenMinutesAgo))
        .get();

      console.log(`Found ${pendingSnap.size} pending transactions`);

      for (const paymentDoc of pendingSnap.docs) {
        const paymentData = paymentDoc.data();
        const orderId = paymentData.order_id;
        if (!orderId) continue;

        try {
          const statusResponse = await axios.get(
            `${MIDTRANS_BASE_URL}/v2/${orderId}/status`,
            { headers: { Authorization: `Basic ${midtransAuth()}` } }
          );

          const txStatus = statusResponse.data.transaction_status;
          const fraudStatus = statusResponse.data.fraud_status;

          console.log(`  Order ${orderId}: ${txStatus}`);

          if (txStatus === "settlement" || (txStatus === "capture" && fraudStatus === "accept")) {
            const storeId = paymentData.store_id;
            const outletId = paymentData.outlet_id;
            const now = new Date();
            const nextPaymentDue = new Date(now.getFullYear(), now.getMonth() + 1, now.getDate());

            await db
              .collection("stores").doc(storeId)
              .collection("outlets").doc(outletId)
              .collection("subscription").doc("active")
              .update({
                status: "active",
                plan: paymentData.package_id,
                subscription_start_date: admin.firestore.FieldValue.serverTimestamp(),
                subscription_end_date: admin.firestore.Timestamp.fromDate(nextPaymentDue),
                last_payment_date: admin.firestore.FieldValue.serverTimestamp(),
                next_payment_due: admin.firestore.Timestamp.fromDate(nextPaymentDue),
                midtrans_order_id: orderId,
                notified_h3: false,
                updated_at: admin.firestore.FieldValue.serverTimestamp(),
              });

            await paymentDoc.ref.update({
              status: "settlement",
              verified_at: admin.firestore.FieldValue.serverTimestamp(),
              updated_at: admin.firestore.FieldValue.serverTimestamp(),
            });

            console.log(`  ✅ Updated via cron: ${orderId}`);
          } else if (["expire", "cancel", "deny"].includes(txStatus)) {
            await paymentDoc.ref.update({
              status: txStatus,
              updated_at: admin.firestore.FieldValue.serverTimestamp(),
            });
          }
        } catch (e) {
          console.error(`  ❌ Error checking ${orderId}:`, e.message);
        }
      }

      console.log("✅ Done");
    } catch (error) {
      console.error("❌ Error:", error);
    }
  }
);

// ────────────────────────────────────────────────────────────────────────────
// FUNCTION 4: Get payment history
// ────────────────────────────────────────────────────────────────────────────
exports.getPaymentHistory = onCall(
  { region: "asia-southeast1" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "User harus login");
    }

    const { storeId, outletId } = request.data;

    try {
      const paymentSnap = await db
        .collection("stores").doc(storeId)
        .collection("outlets").doc(outletId)
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
        midtrans_response: undefined,
      }));

      return { success: true, history };
    } catch (error) {
      throw new HttpsError("internal", error.message);
    }
  }
);
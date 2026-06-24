// ─────────────────────────────────────────────────────────────────────────────
// PENTING: File ini menggunakan OneSignal REST API untuk kirim notifikasi
// Tidak perlu Firebase Blaze Plan!
//
// Cara deploy:
// 1. Pastikan Firebase project masih Spark Plan (gratis)
// 2. Jalankan: firebase deploy --only functions
//
// CATATAN: Cloud Functions tetap butuh Blaze Plan untuk DEPLOY.
// Solusi alternatif tanpa server ada di file workmanager_service.dart
// ─────────────────────────────────────────────────────────────────────────────

const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onDocumentUpdated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");
const https = require("https");

admin.initializeApp();

// ─── Konfigurasi OneSignal ────────────────────────────────────────────────────
const ONESIGNAL_APP_ID = "54e65963-bfc8-40ad-aef9-cb1d7303590e";
const ONESIGNAL_REST_API_KEY =
  "os_v2_app_kttfsy57zbak3lxzzmoxga2zbyyafdfldcnuc4ed3jmmetfcpa3uxm3m3of4hv4xkmharny7ohegu73dqv5wil7xzhs3cfv7x6rn2rq";

// ─────────────────────────────────────────────────────────────────────────────
// HELPER: Kirim notif via OneSignal REST API
// Target: semua device dengan tag role = "admin"
// ─────────────────────────────────────────────────────────────────────────────
function _kirimOneSignal(judul, isi, tipe) {
  return new Promise((resolve, reject) => {
    const payload = JSON.stringify({
      app_id: ONESIGNAL_APP_ID,
      // Kirim hanya ke device yang punya tag role = admin
      filters: [{ field: "tag", key: "role", relation: "=", value: "admin" }],
      headings: { en: judul, id: judul },
      contents: { en: isi, id: isi },
      // Data tambahan untuk Flutter handler
      data: {
        type: tipe,
        route: "/notifikasi",
        waktu: new Date().toISOString(),
      },
      // Android config
      android_channel_id: "laundry_reminder",
      priority: 10,
      android_accent_color: "FF0D9488",
    });

    const options = {
      hostname: "onesignal.com",
      port: 443,
      path: "/api/v1/notifications",
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Key ${ONESIGNAL_REST_API_KEY}`,
      },
    };

    const req = https.request(options, (res) => {
      let data = "";
      res.on("data", (chunk) => (data += chunk));
      res.on("end", () => {
        const parsed = JSON.parse(data);
        if (parsed.errors) {
          reject(new Error(JSON.stringify(parsed.errors)));
        } else {
          resolve(parsed);
        }
      });
    });

    req.on("error", reject);
    req.write(payload);
    req.end();
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPER: Format waktu WIB
// ─────────────────────────────────────────────────────────────────────────────
function _fmtWib(date) {
  const wib = new Date(date.getTime() + 7 * 60 * 60 * 1000);
  const pad = (n) => n.toString().padStart(2, "0");
  return `${pad(wib.getUTCDate())}-${pad(wib.getUTCMonth() + 1)}-${wib.getUTCFullYear()} ${pad(wib.getUTCHours())}:${pad(wib.getUTCMinutes())}`;
}

function _fmtJam(date) {
  const wib = new Date(date.getTime() + 7 * 60 * 60 * 1000);
  const pad = (n) => n.toString().padStart(2, "0");
  return `${pad(wib.getUTCHours())}:${pad(wib.getUTCMinutes())} WIB`;
}

// ─────────────────────────────────────────────────────────────────────────────
// FUNCTION 1: Notif estimasi selesai ~4 jam lagi (cek setiap 30 menit)
// ─────────────────────────────────────────────────────────────────────────────
exports.notifLaundryEstimasi = onSchedule(
  {
    schedule: "*/30 * * * *",
    timeZone: "Asia/Jakarta",
    region: "asia-southeast1",
  },
  async (event) => {
    const db = admin.firestore();
    const now = new Date();
    const windowMin = new Date(now.getTime() + 3.5 * 60 * 60 * 1000);
    const windowMax = new Date(now.getTime() + 4.5 * 60 * 60 * 1000);

    console.log(
      `[${_fmtWib(now)}] Cek estimasi: ${_fmtWib(windowMin)} - ${_fmtWib(windowMax)}`
    );

    try {
      const snap = await db
        .collection("order")
        .where("status", "==", "proses")
        .get();

      if (snap.empty) { console.log("Tidak ada order proses."); return; }

      const perluNotif = [];
      snap.forEach((doc) => {
        const data = doc.data();
        if (!data.waktu_order || data.durasi_jam == null) return;

        const waktuOrderDate = data.waktu_order.toDate
          ? data.waktu_order.toDate()
          : new Date(data.waktu_order._seconds * 1000);

        const estimasiSelesai = new Date(
          waktuOrderDate.getTime() + data.durasi_jam * 60 * 60 * 1000
        );

        if (
          estimasiSelesai >= windowMin &&
          estimasiSelesai <= windowMax &&
          data.notif_estimasi_terkirim !== true
        ) {
          perluNotif.push({
            docId: doc.id,
            nama: data.nama_pelanggan || "Pelanggan",
            layanan: data.layanan_nama || "Laundry",
            estimasiSelesai,
          });
        }
      });

      if (perluNotif.length === 0) {
        console.log("Semua sudah dapat notif estimasi.");
        return;
      }

      let judul, isi;
      if (perluNotif.length === 1) {
        const o = perluNotif[0];
        judul = "🧺 Laundry Segera Selesai";
        isi = `${o.layanan} milik ${o.nama} estimasi selesai jam ${_fmtJam(o.estimasiSelesai)} — mohon siapkan pesanan.`;
      } else {
        const namaList = perluNotif.slice(0, 3).map((o) => o.nama).join(", ");
        const sisanya = perluNotif.length > 3 ? ` +${perluNotif.length - 3} lainnya` : "";
        judul = `🧺 ${perluNotif.length} Laundry Segera Selesai`;
        isi = `${namaList}${sisanya} — estimasi selesai ~4 jam lagi.`;
      }

      console.log(`Kirim OneSignal estimasi: "${judul}"`);
      const result = await _kirimOneSignal(judul, isi, "laundry_estimasi");
      console.log(`✅ OneSignal terkirim. ID: ${result.id}, Recipients: ${result.recipients}`);

      const batch = db.batch();
      perluNotif.forEach((o) => {
        batch.update(db.collection("order").doc(o.docId), {
          notif_estimasi_terkirim: true,
        });
      });
      await batch.commit();
      console.log(`✅ ${perluNotif.length} order ditandai notif_estimasi_terkirim`);
    } catch (err) {
      console.error("❌ Error notifLaundryEstimasi:", err);
    }
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// FUNCTION 2: Notif deadline (30 menit lagi) & terlambat (sudah lewat)
// ─────────────────────────────────────────────────────────────────────────────
exports.notifDeadlineTerlambat = onSchedule(
  {
    schedule: "*/10 * * * *",
    timeZone: "Asia/Jakarta",
    region: "asia-southeast1",
  },
  async (event) => {
    const db = admin.firestore();
    const now = new Date();

    console.log(`[${_fmtWib(now)}] Cek deadline & terlambat...`);

    try {
      const snap = await db
        .collection("order")
        .where("status", "in", ["antrian", "proses"])
        .get();

      if (snap.empty) { console.log("Tidak ada order aktif."); return; }

      const orderDeadline = [];
      const orderTerlambat = [];

      snap.forEach((doc) => {
        const data = doc.data();
        if (!data.waktu_order || data.durasi_jam == null) return;

        const waktuOrderDate = data.waktu_order.toDate
          ? data.waktu_order.toDate()
          : new Date(data.waktu_order._seconds * 1000);

        const estimasiSelesai = new Date(
          waktuOrderDate.getTime() + data.durasi_jam * 60 * 60 * 1000
        );

        const selisihMenit = (estimasiSelesai - now) / 1000 / 60;

        if (selisihMenit > 0 && selisihMenit <= 30 && data.notif_deadline_terkirim !== true) {
          orderDeadline.push({
            docId: doc.id,
            nama: data.nama_pelanggan || "Pelanggan",
            layanan: data.layanan_nama || "Laundry",
            menitLagi: Math.round(selisihMenit),
          });
        }

        if (selisihMenit < 0 && data.notif_terlambat_terkirim !== true) {
          orderTerlambat.push({
            docId: doc.id,
            nama: data.nama_pelanggan || "Pelanggan",
            layanan: data.layanan_nama || "Laundry",
            terlambatMenit: Math.round(Math.abs(selisihMenit)),
          });
        }
      });

      // ── Kirim DEADLINE ────────────────────────────────────────────────────
      if (orderDeadline.length > 0) {
        const judul = orderDeadline.length === 1
          ? `⏰ Deadline Hampir Tiba`
          : `⏰ ${orderDeadline.length} Order Hampir Deadline`;
        const isi = orderDeadline.length === 1
          ? `${orderDeadline[0].layanan} milik ${orderDeadline[0].nama} selesai ${orderDeadline[0].menitLagi} menit lagi!`
          : `${orderDeadline.slice(0, 2).map((o) => o.nama).join(", ")} dan lainnya hampir deadline!`;

        console.log(`Kirim OneSignal deadline: "${judul}"`);
        const result = await _kirimOneSignal(judul, isi, "deadline");
        console.log(`✅ Deadline terkirim. ID: ${result.id}`);

        const batch = db.batch();
        orderDeadline.forEach((o) => {
          batch.update(db.collection("order").doc(o.docId), { notif_deadline_terkirim: true });
        });
        await batch.commit();
      } else {
        console.log("Tidak ada order hampir deadline.");
      }

      // ── Kirim TERLAMBAT ───────────────────────────────────────────────────
      if (orderTerlambat.length > 0) {
        const judul = orderTerlambat.length === 1
          ? `🔴 Order Terlambat!`
          : `🔴 ${orderTerlambat.length} Order Terlambat!`;
        const isi = orderTerlambat.length === 1
          ? `${orderTerlambat[0].layanan} milik ${orderTerlambat[0].nama} sudah terlambat ${orderTerlambat[0].terlambatMenit} menit!`
          : `${orderTerlambat.slice(0, 2).map((o) => o.nama).join(", ")} dan lainnya sudah melewati deadline!`;

        console.log(`Kirim OneSignal terlambat: "${judul}"`);
        const result = await _kirimOneSignal(judul, isi, "terlambat");
        console.log(`✅ Terlambat terkirim. ID: ${result.id}`);

        const batch = db.batch();
        orderTerlambat.forEach((o) => {
          batch.update(db.collection("order").doc(o.docId), { notif_terlambat_terkirim: true });
        });
        await batch.commit();
      } else {
        console.log("Tidak ada order terlambat.");
      }
    } catch (err) {
      console.error("❌ Error notifDeadlineTerlambat:", err);
    }
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// FUNCTION 3: Reset flag notif jika durasi/waktu order berubah
// ─────────────────────────────────────────────────────────────────────────────
exports.resetNotifFlagOnOrderUpdate = onDocumentUpdated(
  { document: "order/{orderId}", region: "asia-southeast1" },
  (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();

    const durasiChanged = before.durasi_jam !== after.durasi_jam;
    const waktuChanged =
      JSON.stringify(before.waktu_order) !== JSON.stringify(after.waktu_order);

    if (!durasiChanged && !waktuChanged) return null;

    const updates = {};
    if (after.notif_estimasi_terkirim === true) updates.notif_estimasi_terkirim = false;
    if (after.notif_deadline_terkirim === true) updates.notif_deadline_terkirim = false;
    if (after.notif_terlambat_terkirim === true) updates.notif_terlambat_terkirim = false;

    if (Object.keys(updates).length === 0) return null;

    console.log(`[resetNotifFlag] Order ${event.params.orderId} reset: ${Object.keys(updates).join(", ")}`);
    return event.data.after.ref.update(updates);
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// FUNCTION 4: Hapus Akun Admin
// ─────────────────────────────────────────────────────────────────────────────
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");

const GITHUB_PAT = defineSecret("GITHUB_PAT");

exports.deleteAdmin = onCall(
  {
    region: "asia-southeast1",
    secrets: [GITHUB_PAT],
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Harus login dulu");
    }

    const callerUid = request.auth.uid;
    const targetUid = request.data.targetUid;

    if (!targetUid) {
      throw new HttpsError("invalid-argument", "targetUid wajib diisi");
    }

    const callerDoc = await admin
      .firestore()
      .collection("users")
      .doc(callerUid)
      .get();

    if (!callerDoc.exists || callerDoc.data()?.can_access_admin !== true) {
      throw new HttpsError("permission-denied", "Tidak punya izin hapus admin");
    }

    // Trigger GitHub Actions pakai https bawaan Node.js
    await new Promise((resolve, reject) => {
      const body = JSON.stringify({
        ref: "main",
        inputs: {
          caller_uid: callerUid,
          target_uid: targetUid,
        },
      });

      const options = {
        hostname: "api.github.com",
        port: 443,
        path: "/repos/mdngarage-dev/MdnLaundry/actions/workflows/delete-admin.yml/dispatches",
        method: "POST",
        headers: {
          Authorization: `Bearer ${GITHUB_PAT.value()}`,
          Accept: "application/vnd.github+json",
          "X-GitHub-Api-Version": "2022-11-28",
          "Content-Type": "application/json",
          "Content-Length": Buffer.byteLength(body),
          "User-Agent": "MdnLaundry-App",
        },
      };

      const req = https.request(options, (res) => {
        let data = "";
        res.on("data", (chunk) => (data += chunk));
        res.on("end", () => {
          if (res.statusCode === 204) {
            resolve();
          } else {
            reject(new Error(`GitHub error ${res.statusCode}: ${data}`));
          }
        });
      });

      req.on("error", reject);
      req.write(body);
      req.end();
    });

    await admin.firestore().collection("users").doc(targetUid).delete();

    console.log(`✅ Admin ${targetUid} dihapus oleh ${callerUid}`);
    return { success: true };
  }
);
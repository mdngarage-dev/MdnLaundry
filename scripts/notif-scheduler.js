// ─────────────────────────────────────────────────────────────────────────────
// Script ini dijalankan oleh GitHub Actions sebagai pengganti Cloud Functions
// Tidak perlu Firebase Blaze Plan!
//
// Cara pakai lokal (testing):
//   node scripts/notif-scheduler.js
// ─────────────────────────────────────────────────────────────────────────────

const admin = require("firebase-admin");
const https = require("https");

// ─── Inisialisasi Firebase Admin pakai Service Account dari ENV ──────────────
// Service account JSON disimpan sebagai GitHub Secret (lihat panduan)
const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

// ─── Konfigurasi OneSignal dari ENV (GitHub Secrets) ──────────────────────────
const ONESIGNAL_APP_ID = process.env.ONESIGNAL_APP_ID;
const ONESIGNAL_REST_API_KEY = process.env.ONESIGNAL_REST_API_KEY;

// ─────────────────────────────────────────────────────────────────────────────
// HELPER: Kirim notif via OneSignal REST API
// ─────────────────────────────────────────────────────────────────────────────
function kirimOneSignal(judul, isi, tipe) {
  return new Promise((resolve, reject) => {
    const payload = JSON.stringify({
      app_id: ONESIGNAL_APP_ID,
      filters: [{ field: "tag", key: "role", relation: "=", value: "admin" }],
      headings: { en: judul, id: judul },
      contents: { en: isi, id: isi },
      data: {
        type: tipe,
        route: "/notifikasi",
        waktu: new Date().toISOString(),
      },
      priority: 10,
      android_accent_color: "FF0D9488",
    });

    const options = {
      hostname: "api.onesignal.com",
      port: 443,
      path: "/notifications",
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
        if (parsed.errors) reject(new Error(JSON.stringify(parsed.errors)));
        else resolve(parsed);
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
function fmtWib(date) {
  const wib = new Date(date.getTime() + 7 * 60 * 60 * 1000);
  const pad = (n) => n.toString().padStart(2, "0");
  return `${pad(wib.getUTCDate())}-${pad(wib.getUTCMonth() + 1)}-${wib.getUTCFullYear()} ${pad(wib.getUTCHours())}:${pad(wib.getUTCMinutes())}`;
}

function fmtJam(date) {
  const wib = new Date(date.getTime() + 7 * 60 * 60 * 1000);
  const pad = (n) => n.toString().padStart(2, "0");
  return `${pad(wib.getUTCHours())}:${pad(wib.getUTCMinutes())} WIB`;
}

// ─────────────────────────────────────────────────────────────────────────────
// TASK 1: Notif estimasi selesai ~4 jam lagi
// ─────────────────────────────────────────────────────────────────────────────
async function cekEstimasi(db) {
  const now = new Date();
  const windowMin = new Date(now.getTime() + 3.5 * 60 * 60 * 1000);
  const windowMax = new Date(now.getTime() + 4.5 * 60 * 60 * 1000);

  console.log(`[${fmtWib(now)}] Cek estimasi: ${fmtWib(windowMin)} - ${fmtWib(windowMax)}`);

  const snap = await db.collection("order").where("status", "==", "proses").get();
  if (snap.empty) { console.log("Tidak ada order proses."); return; }

  const perluNotif = [];
  snap.forEach((doc) => {
    const data = doc.data();
    if (!data.waktu_order || data.durasi_jam == null) return;

    const waktuOrderDate = data.waktu_order.toDate
      ? data.waktu_order.toDate()
      : new Date(data.waktu_order._seconds * 1000);

    const estimasiSelesai = new Date(waktuOrderDate.getTime() + data.durasi_jam * 60 * 60 * 1000);

    if (estimasiSelesai >= windowMin && estimasiSelesai <= windowMax && data.notif_estimasi_terkirim !== true) {
      perluNotif.push({
        docId: doc.id,
        nama: data.nama_pelanggan || "Pelanggan",
        layanan: data.layanan_nama || "Laundry",
        estimasiSelesai,
      });
    }
  });

  if (perluNotif.length === 0) { console.log("Semua sudah dapat notif estimasi."); return; }

  let judul, isi;
  if (perluNotif.length === 1) {
    const o = perluNotif[0];
    judul = "🧺 Laundry Segera Selesai";
    isi = `${o.layanan} milik ${o.nama} estimasi selesai jam ${fmtJam(o.estimasiSelesai)} — mohon siapkan pesanan.`;
  } else {
    const namaList = perluNotif.slice(0, 3).map((o) => o.nama).join(", ");
    const sisanya = perluNotif.length > 3 ? ` +${perluNotif.length - 3} lainnya` : "";
    judul = `🧺 ${perluNotif.length} Laundry Segera Selesai`;
    isi = `${namaList}${sisanya} — estimasi selesai ~4 jam lagi.`;
  }

  console.log(`Kirim OneSignal estimasi: "${judul}"`);
  const result = await kirimOneSignal(judul, isi, "laundry_estimasi");
  console.log(`✅ Terkirim. ID: ${result.id}, Recipients: ${result.recipients}`);

  const batch = db.batch();
  perluNotif.forEach((o) => {
    batch.update(db.collection("order").doc(o.docId), { notif_estimasi_terkirim: true });
  });
  await batch.commit();
  console.log(`✅ ${perluNotif.length} order ditandai terkirim`);
}

// ─────────────────────────────────────────────────────────────────────────────
// TASK 2: Notif deadline (30 menit lagi) & terlambat
// ─────────────────────────────────────────────────────────────────────────────
async function cekDeadlineTerlambat(db) {
  const now = new Date();
  console.log(`[${fmtWib(now)}] Cek deadline & terlambat...`);

  const snap = await db.collection("order").where("status", "in", ["antrian", "proses"]).get();
  if (snap.empty) { console.log("Tidak ada order aktif."); return; }

  const orderDeadline = [];
  const orderTerlambat = [];

  snap.forEach((doc) => {
    const data = doc.data();
    if (!data.waktu_order || data.durasi_jam == null) return;

    const waktuOrderDate = data.waktu_order.toDate
      ? data.waktu_order.toDate()
      : new Date(data.waktu_order._seconds * 1000);

    const estimasiSelesai = new Date(waktuOrderDate.getTime() + data.durasi_jam * 60 * 60 * 1000);
    const selisihMenit = (estimasiSelesai - now) / 1000 / 60;

    if (selisihMenit > 0 && selisihMenit <= 30 && data.notif_deadline_terkirim !== true) {
      orderDeadline.push({
        docId: doc.id,
        nama: data.nama_pelanggan || "Pelanggan",
        layanan: data.layanan_nama || "Laundry",
        menitLagi: Math.round(selisihMenit),
      });
    }

    // ── TERLAMBAT: diulang tiap 1 jam selama order belum diselesaikan ──────
    // Pakai timestamp terakhir kirim, bukan flag boolean sekali pakai
    if (selisihMenit < 0) {
      const terakhirKirim = data.notif_terlambat_terkirim_at
        ? (data.notif_terlambat_terkirim_at.toDate
            ? data.notif_terlambat_terkirim_at.toDate()
            : new Date(data.notif_terlambat_terkirim_at._seconds * 1000))
        : null;

      const menitSejakTerakhirKirim = terakhirKirim
        ? (now - terakhirKirim) / 1000 / 60
        : null;

      // Kirim kalau belum pernah dikirim ATAU sudah lewat 60 menit dari terakhir kirim
      if (terakhirKirim === null || menitSejakTerakhirKirim >= 60) {
        orderTerlambat.push({
          docId: doc.id,
          nama: data.nama_pelanggan || "Pelanggan",
          layanan: data.layanan_nama || "Laundry",
          terlambatMenit: Math.round(Math.abs(selisihMenit)),
        });
      }
    }
  });

  if (orderDeadline.length > 0) {
    const judul = orderDeadline.length === 1
      ? `⏰ Deadline Hampir Tiba`
      : `⏰ ${orderDeadline.length} Order Hampir Deadline`;
    const isi = orderDeadline.length === 1
      ? `${orderDeadline[0].layanan} milik ${orderDeadline[0].nama} selesai ${orderDeadline[0].menitLagi} menit lagi!`
      : `${orderDeadline.slice(0, 2).map((o) => o.nama).join(", ")} dan lainnya hampir deadline!`;

    console.log(`Kirim OneSignal deadline: "${judul}"`);
    const result = await kirimOneSignal(judul, isi, "deadline");
    console.log(`✅ Deadline terkirim. ID: ${result.id}`);

    const batch = db.batch();
    orderDeadline.forEach((o) => {
      batch.update(db.collection("order").doc(o.docId), { notif_deadline_terkirim: true });
    });
    await batch.commit();
  } else {
    console.log("Tidak ada order hampir deadline.");
  }

  if (orderTerlambat.length > 0) {
    const judul = orderTerlambat.length === 1
      ? `🔴 Order Terlambat!`
      : `🔴 ${orderTerlambat.length} Order Terlambat!`;
    const isi = orderTerlambat.length === 1
      ? `${orderTerlambat[0].layanan} milik ${orderTerlambat[0].nama} sudah terlambat ${orderTerlambat[0].terlambatMenit} menit!`
      : `${orderTerlambat.slice(0, 2).map((o) => o.nama).join(", ")} dan lainnya sudah melewati deadline!`;

    console.log(`Kirim OneSignal terlambat: "${judul}"`);
    const result = await kirimOneSignal(judul, isi, "terlambat");
    console.log(`✅ Terlambat terkirim. ID: ${result.id}`);

    const batch = db.batch();
    orderTerlambat.forEach((o) => {
      batch.update(db.collection("order").doc(o.docId), {
        notif_terlambat_terkirim_at: admin.firestore.Timestamp.now(),
      });
    });
    await batch.commit();
  } else {
    console.log("Tidak ada order terlambat.");
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TASK 3 (opsional): Reset flag notif kalau order baru diubah signifikan
// NOTE: Reset otomatis saat update field (seperti onDocumentUpdated Cloud Functions)
// TIDAK bisa dilakukan via cron biasa karena perlu trigger real-time.
// Solusi: reset dilakukan langsung dari sisi Flutter app saat user edit order
// (lihat catatan di PANDUAN_GITHUB_ACTIONS.md)
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// MAIN — jalankan semua task lalu exit
// ─────────────────────────────────────────────────────────────────────────────
async function main() {
  const db = admin.firestore();
  try {
    await cekEstimasi(db);
    await cekDeadlineTerlambat(db);
    console.log("✅ Selesai semua pengecekan.");
    process.exit(0);
  } catch (err) {
    console.error("❌ Error:", err);
    process.exit(1);
  }
}

main();
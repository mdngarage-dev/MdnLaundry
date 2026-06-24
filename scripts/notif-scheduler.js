// ─────────────────────────────────────────────────────────────────────────────
// Script ini dijalankan oleh GitHub Actions sebagai pengganti Cloud Functions
// Tidak perlu Firebase Blaze Plan!
//
// Cara pakai lokal (testing):
//   node scripts/notif-scheduler.js
// ─────────────────────────────────────────────────────────────────────────────

const admin = require("firebase-admin");
const https = require("https");

// Paling atas, setelah baris require
console.log("=== ENV CHECK ===");
console.log("APP_ID:", process.env.ONESIGNAL_APP_ID);
console.log("API_KEY:", process.env.ONESIGNAL_REST_API_KEY?.slice(0, 10));
console.log("=================");
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
// HELPER: Kirim notif via OneSignal REST API ke target tertentu
//
// targetFilters: array filter OneSignal (lihat dokumentasi "filters").
// Kalau null/kosong, fallback ke broadcast "Total Subscriptions" (dipakai
// hanya untuk kondisi darurat / testing — sebisa mungkin selalu kirim
// targetFilters yang spesifik per store_id/outlet_id/role).
// ─────────────────────────────────────────────────────────────────────────────
function kirimOneSignal(judul, isi, tipe, targetFilters) {
  return new Promise((resolve, reject) => {
    const basePayload = {
      app_id: ONESIGNAL_APP_ID,
      target_channel: "push",
      headings: { en: judul, id: judul },
      contents: { en: isi, id: isi },
      data: {
        type: tipe,
        route: "/notifikasi",
        waktu: new Date().toISOString(),
      },
      priority: 10,
      android_accent_color: "FF0D9488",
    };

    // ── Targeting: filters (spesifik) ATAU included_segments (broadcast) ────
    const payloadObj =
      targetFilters && targetFilters.length > 0
        ? { ...basePayload, filters: targetFilters }
        : { ...basePayload, included_segments: ["Total Subscriptions"] };

    const payload = JSON.stringify(payloadObj);

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
        console.log("STATUS:", res.statusCode);
        console.log("RESPONSE RAW:", data);
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
// HELPER: Bangun filter OneSignal untuk Owner toko tertentu
// Owner harus dapat notif dari SEMUA outlet di toko miliknya.
// ─────────────────────────────────────────────────────────────────────────────
function filterOwnerToko(storeId) {
  return [
    { field: "tag", key: "store_id", relation: "=", value: storeId },
    { operator: "AND" },
    { field: "tag", key: "role", relation: "=", value: "Owner" },
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPER: Bangun filter OneSignal untuk Admin yang current_outlet_id-nya
// sama dengan outlet tempat order itu berada.
// ─────────────────────────────────────────────────────────────────────────────
function filterAdminOutlet(storeId, outletId) {
  return [
    { field: "tag", key: "store_id", relation: "=", value: storeId },
    { operator: "AND" },
    { field: "tag", key: "role", relation: "=", value: "Admin" },
    { operator: "AND" },
    { field: "tag", key: "current_outlet_id", relation: "=", value: outletId },
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPER: Kirim notif ke Owner toko DAN Admin outlet itu sekaligus (2 request)
// Dipisah supaya masing-masing punya log/recipient count sendiri.
// ─────────────────────────────────────────────────────────────────────────────
async function kirimKeOwnerDanAdminOutlet(storeId, outletId, judul, isi, tipe) {
  const hasil = { owner: null, admin: null };

  try {
    hasil.owner = await kirimOneSignal(
      judul,
      isi,
      tipe,
      filterOwnerToko(storeId)
    );
    console.log(
      `  ✅ Owner toko ${storeId} → recipients: ${hasil.owner.recipients}`
    );
  } catch (e) {
    console.error(`  ⚠ Gagal kirim ke Owner toko ${storeId}:`, e.message);
  }

  try {
    hasil.admin = await kirimOneSignal(
      judul,
      isi,
      tipe,
      filterAdminOutlet(storeId, outletId)
    );
    console.log(
      `  ✅ Admin outlet ${outletId} → recipients: ${hasil.admin.recipients}`
    );
  } catch (e) {
    console.error(`  ⚠ Gagal kirim ke Admin outlet ${outletId}:`, e.message);
  }

  return hasil;
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
// HELPER: Group list order berdasarkan (store_id, outlet_id)
// Mengembalikan Map dengan key "storeId|outletId" → array order
// ─────────────────────────────────────────────────────────────────────────────
function groupByStoreOutlet(orders) {
  const map = new Map();
  for (const o of orders) {
    const key = `${o.storeId}|${o.outletId}`;
    if (!map.has(key)) map.set(key, []);
    map.get(key).push(o);
  }
  return map;
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
    if (!data.store_id || !data.outlet_id) return; // wajib ada untuk targeting

    const waktuOrderDate = data.waktu_order.toDate
      ? data.waktu_order.toDate()
      : new Date(data.waktu_order._seconds * 1000);

    const estimasiSelesai = new Date(waktuOrderDate.getTime() + data.durasi_jam * 60 * 60 * 1000);

    if (estimasiSelesai >= windowMin && estimasiSelesai <= windowMax && data.notif_estimasi_terkirim !== true) {
      perluNotif.push({
        docId: doc.id,
        storeId: data.store_id,
        outletId: data.outlet_id,
        nama: data.nama_pelanggan || "Pelanggan",
        layanan: data.layanan_nama || "Laundry",
        estimasiSelesai,
      });
    }
  });

  if (perluNotif.length === 0) { console.log("Semua sudah dapat notif estimasi."); return; }

  // ── Group per outlet, supaya tiap outlet dapat 1 notif gabungan (kalau
  //    lebih dari 1 order), bukan numpuk jadi 1 notif lintas semua outlet ────
  const grouped = groupByStoreOutlet(perluNotif);
  const semuaTerkirim = [];

  for (const [key, orders] of grouped) {
    const [storeId, outletId] = key.split("|");

    let judul, isi;
    if (orders.length === 1) {
      const o = orders[0];
      judul = "🧺 Laundry Segera Selesai";
      isi = `${o.layanan} milik ${o.nama} estimasi selesai jam ${fmtJam(o.estimasiSelesai)} — mohon siapkan pesanan.`;
    } else {
      const namaList = orders.slice(0, 3).map((o) => o.nama).join(", ");
      const sisanya = orders.length > 3 ? ` +${orders.length - 3} lainnya` : "";
      judul = `🧺 ${orders.length} Laundry Segera Selesai`;
      isi = `${namaList}${sisanya} — estimasi selesai ~4 jam lagi.`;
    }

    console.log(`Kirim OneSignal estimasi untuk outlet ${outletId} (toko ${storeId}): "${judul}"`);
    await kirimKeOwnerDanAdminOutlet(storeId, outletId, judul, isi, "laundry_estimasi");

    semuaTerkirim.push(...orders);
  }

  const batch = db.batch();
  semuaTerkirim.forEach((o) => {
    batch.update(db.collection("order").doc(o.docId), { notif_estimasi_terkirim: true });
  });
  await batch.commit();
  console.log(`✅ ${semuaTerkirim.length} order ditandai terkirim`);
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
    if (!data.store_id || !data.outlet_id) return; // wajib ada untuk targeting

    const waktuOrderDate = data.waktu_order.toDate
      ? data.waktu_order.toDate()
      : new Date(data.waktu_order._seconds * 1000);

    const estimasiSelesai = new Date(waktuOrderDate.getTime() + data.durasi_jam * 60 * 60 * 1000);
    const selisihMenit = (estimasiSelesai - now) / 1000 / 60;

    if (selisihMenit > 0 && selisihMenit <= 30 && data.notif_deadline_terkirim !== true) {
      orderDeadline.push({
        docId: doc.id,
        storeId: data.store_id,
        outletId: data.outlet_id,
        nama: data.nama_pelanggan || "Pelanggan",
        layanan: data.layanan_nama || "Laundry",
        menitLagi: Math.round(selisihMenit),
      });
    }

    // ── TERLAMBAT: diulang tiap 1 jam selama order belum diselesaikan ──────
    if (selisihMenit < 0) {
      const terakhirKirim = data.notif_terlambat_terkirim_at
        ? (data.notif_terlambat_terkirim_at.toDate
            ? data.notif_terlambat_terkirim_at.toDate()
            : new Date(data.notif_terlambat_terkirim_at._seconds * 1000))
        : null;

      const menitSejakTerakhirKirim = terakhirKirim
        ? (now - terakhirKirim) / 1000 / 60
        : null;

      if (terakhirKirim === null || menitSejakTerakhirKirim >= 60) {
        orderTerlambat.push({
          docId: doc.id,
          storeId: data.store_id,
          outletId: data.outlet_id,
          nama: data.nama_pelanggan || "Pelanggan",
          layanan: data.layanan_nama || "Laundry",
          terlambatMenit: Math.round(Math.abs(selisihMenit)),
        });
      }
    }
  });

  // ── DEADLINE: group per outlet ─────────────────────────────────────────
  if (orderDeadline.length > 0) {
    const grouped = groupByStoreOutlet(orderDeadline);
    const semuaTerkirim = [];

    for (const [key, orders] of grouped) {
      const [storeId, outletId] = key.split("|");

      const judul = orders.length === 1
        ? `⏰ Deadline Hampir Tiba`
        : `⏰ ${orders.length} Order Hampir Deadline`;
      const isi = orders.length === 1
        ? `${orders[0].layanan} milik ${orders[0].nama} selesai ${orders[0].menitLagi} menit lagi!`
        : `${orders.slice(0, 2).map((o) => o.nama).join(", ")} dan lainnya hampir deadline!`;

      console.log(`Kirim OneSignal deadline untuk outlet ${outletId} (toko ${storeId}): "${judul}"`);
      await kirimKeOwnerDanAdminOutlet(storeId, outletId, judul, isi, "deadline");

      semuaTerkirim.push(...orders);
    }

    const batch = db.batch();
    semuaTerkirim.forEach((o) => {
      batch.update(db.collection("order").doc(o.docId), { notif_deadline_terkirim: true });
    });
    await batch.commit();
  } else {
    console.log("Tidak ada order hampir deadline.");
  }

  // ── TERLAMBAT: group per outlet ────────────────────────────────────────
  if (orderTerlambat.length > 0) {
    const grouped = groupByStoreOutlet(orderTerlambat);
    const semuaTerkirim = [];

    for (const [key, orders] of grouped) {
      const [storeId, outletId] = key.split("|");

      const judul = orders.length === 1
        ? `🔴 Order Terlambat!`
        : `🔴 ${orders.length} Order Terlambat!`;
      const isi = orders.length === 1
        ? `${orders[0].layanan} milik ${orders[0].nama} sudah terlambat ${orders[0].terlambatMenit} menit!`
        : `${orders.slice(0, 2).map((o) => o.nama).join(", ")} dan lainnya sudah melewati deadline!`;

      console.log(`Kirim OneSignal terlambat untuk outlet ${outletId} (toko ${storeId}): "${judul}"`);
      await kirimKeOwnerDanAdminOutlet(storeId, outletId, judul, isi, "terlambat");

      semuaTerkirim.push(...orders);
    }

    const batch = db.batch();
    semuaTerkirim.forEach((o) => {
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
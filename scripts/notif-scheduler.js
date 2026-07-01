// ─────────────────────────────────────────────────────────────────────────────
// Script ini dijalankan oleh GitHub Actions sebagai pengganti Cloud Functions
// Tidak perlu Firebase Blaze Plan!
//
// Cara pakai lokal (testing):
//   node scripts/notif-scheduler.js
// ─────────────────────────────────────────────────────────────────────────────

const admin = require("firebase-admin");
const https = require("https");

console.log("=== ENV CHECK ===");
console.log("APP_ID:", process.env.ONESIGNAL_APP_ID);
console.log("API_KEY:", process.env.ONESIGNAL_REST_API_KEY?.slice(0, 10));
console.log("=================");

const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const ONESIGNAL_APP_ID = process.env.ONESIGNAL_APP_ID;
const ONESIGNAL_REST_API_KEY = process.env.ONESIGNAL_REST_API_KEY;

// ─────────────────────────────────────────────────────────────────────────────
// HELPER: Kirim notif via OneSignal REST API ke target tertentu
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

function filterOwnerToko(storeId) {
  return [
    { field: "tag", key: "store_id", relation: "=", value: storeId },
    { operator: "AND" },
    { field: "tag", key: "role", relation: "=", value: "Owner" },
  ];
}

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
// BARU: Cari uid user (Owner toko + Admin outlet itu) dari Firestore,
// supaya kita bisa tulis history notif langsung tanpa bergantung
// pada client (foreground listener / tap notif).
// ─────────────────────────────────────────────────────────────────────────────
async function cariUidPenerima(db, storeId, outletId) {
  const uidSet = new Set();

  try {
    const ownerSnap = await db
      .collection("users")
      .where("store_id", "==", storeId)
      .where("role", "==", "Owner")
      .get();
    ownerSnap.forEach((doc) => uidSet.add(doc.id));
  } catch (e) {
    console.error(`  ⚠ Gagal query Owner toko ${storeId}:`, e.message);
  }

  try {
    const adminSnap = await db
      .collection("users")
      .where("store_id", "==", storeId)
      .where("role", "==", "Admin")
      .where("current_outlet_id", "==", outletId)
      .get();
    adminSnap.forEach((doc) => uidSet.add(doc.id));
  } catch (e) {
    console.error(`  ⚠ Gagal query Admin outlet ${outletId}:`, e.message);
  }

  return [...uidSet];
}

// ─────────────────────────────────────────────────────────────────────────────
// BARU: Tulis history notif ke users/{uid}/notif_history/{docId}
// Format doc harus sama persis dengan NotifItem.toFirestore() di Flutter:
//   { id, judul, isi, waktu: Timestamp, sudahDibaca: false }
// ─────────────────────────────────────────────────────────────────────────────
async function simpanHistoryUntukUsers(db, uids, judul, isi) {
  if (uids.length === 0) {
    console.log("  ⚠ Tidak ada uid penerima ditemukan, history tidak ditulis.");
    return;
  }

  const now = admin.firestore.Timestamp.now();
  const batch = db.batch();

  for (const uid of uids) {
    // docId unik per kiriman per user, biar tidak overwrite history lain
    const docRef = db
      .collection("users")
      .doc(uid)
      .collection("notif_history")
      .doc();

    batch.set(docRef, {
      id: docRef.id,
      judul,
      isi,
      waktu: now,
      sudahDibaca: false,
    });
  }

  try {
    await batch.commit();
    console.log(`  ✅ History ditulis untuk ${uids.length} user`);
  } catch (e) {
    console.error("  ⚠ Gagal tulis history notif:", e.message);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Kirim push OneSignal ke Owner + Admin outlet, DAN tulis history Firestore
// untuk user yang sama, dalam satu pemanggilan.
// ─────────────────────────────────────────────────────────────────────────────
async function kirimKeOwnerDanAdminOutlet(db, storeId, outletId, judul, isi, tipe) {
  const hasil = { owner: null, admin: null };

  try {
    hasil.owner = await kirimOneSignal(judul, isi, tipe, filterOwnerToko(storeId));
    console.log(`  ✅ Push Owner toko ${storeId} → recipients: ${hasil.owner.recipients}`);
  } catch (e) {
    console.error(`  ⚠ Gagal kirim push ke Owner toko ${storeId}:`, e.message);
  }

  try {
    hasil.admin = await kirimOneSignal(judul, isi, tipe, filterAdminOutlet(storeId, outletId));
    console.log(`  ✅ Push Admin outlet ${outletId} → recipients: ${hasil.admin.recipients}`);
  } catch (e) {
    console.error(`  ⚠ Gagal kirim push ke Admin outlet ${outletId}:`, e.message);
  }

  // ── Tulis history Firestore terlepas dari status push, supaya badge/riwayat
  //    tetap muncul walau push gagal (device offline, permission dicabut, dll) ──
  const uids = await cariUidPenerima(db, storeId, outletId);
  await simpanHistoryUntukUsers(db, uids, judul, isi);

  return hasil;
}

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
// BARU: Parse "estimasi_selesai" — field yang SAMA dipakai app Flutter.
// Bisa berupa Firestore Timestamp atau string "DD-MM-YYYY" / "YYYY-MM-DD".
// Deadline dianggap jatuh di akhir hari itu (23:59:59 WIB).
// ─────────────────────────────────────────────────────────────────────────────
function parseEstimasiSelesai(raw) {
  if (raw == null) return null;

  // Firestore Timestamp
  if (raw.toDate) return endOfDayWib(raw.toDate());
  if (raw._seconds) return endOfDayWib(new Date(raw._seconds * 1000));

  if (typeof raw === "string" && raw.trim() !== "") {
    const parts = raw.split("-");
    if (parts.length !== 3) return null;
    let y, m, d;
    if (parts[0].length === 4) {
      [y, m, d] = parts.map(Number);
    } else {
      [d, m, y] = parts.map(Number);
    }
    if (!y || !m || !d) return null;
    // 23:59:59 WIB = 16:59:59 UTC
    return new Date(Date.UTC(y, m - 1, d, 16, 59, 59));
  }

  return null;
}

function endOfDayWib(date) {
  const wib = new Date(date.getTime() + 7 * 60 * 60 * 1000);
  return new Date(
    Date.UTC(wib.getUTCFullYear(), wib.getUTCMonth(), wib.getUTCDate(), 16, 59, 59)
  );
}

// Selisih hari (WIB) antara sekarang dan deadline (yang sudah end-of-day UTC)
function diffHariWib(now, deadlineUtc) {
  const nowWib = new Date(now.getTime() + 7 * 60 * 60 * 1000);
  const todayWib = Date.UTC(nowWib.getUTCFullYear(), nowWib.getUTCMonth(), nowWib.getUTCDate());
  const dlWib = new Date(deadlineUtc.getTime() + 7 * 60 * 60 * 1000);
  const dlDayWib = Date.UTC(dlWib.getUTCFullYear(), dlWib.getUTCMonth(), dlWib.getUTCDate());
  return Math.round((dlDayWib - todayWib) / (1000 * 60 * 60 * 24));
}

// ─────────────────────────────────────────────────────────────────────────────
// TASK 1: Notif estimasi selesai ~4 jam lagi
// (masih pakai waktu_order + durasi_jam karena butuh presisi jam;
//  estimasi_selesai tidak punya info jam)
// ─────────────────────────────────────────────────────────────────────────────
async function cekEstimasi(db) {
  const now = new Date();
  const windowMin = new Date(now.getTime() + 3.5 * 60 * 60 * 1000);
  const windowMax = new Date(now.getTime() + 4.5 * 60 * 60 * 1000);

  console.log(`[${fmtWib(now)}] Cek estimasi: ${fmtWib(windowMin)} - ${fmtWib(windowMax)}`);

  const snap = await db.collection("order").where("status", "==", "proses").get();
  if (snap.empty) {
    console.log("Tidak ada order proses.");
    return;
  }

  const perluNotif = [];
  snap.forEach((doc) => {
    const data = doc.data();
    if (!data.waktu_order || data.durasi_jam == null) return;
    if (!data.store_id || !data.outlet_id) return;

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
        storeId: data.store_id,
        outletId: data.outlet_id,
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
    await kirimKeOwnerDanAdminOutlet(db, storeId, outletId, judul, isi, "laundry_estimasi");

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
// TASK 2: Notif deadline & terlambat — SEKARANG PAKAI estimasi_selesai,
// field yang sama persis dipakai app Flutter, supaya tidak drift lagi.
// ─────────────────────────────────────────────────────────────────────────────
async function cekDeadlineTerlambat(db) {
  const now = new Date();
  console.log(`[${fmtWib(now)}] Cek deadline & terlambat (via estimasi_selesai)...`);

  const snap = await db
    .collection("order")
    .where("status", "in", ["antrian", "proses"])
    .get();
  if (snap.empty) {
    console.log("Tidak ada order aktif.");
    return;
  }

  const orderDeadline = [];
  const orderTerlambat = [];

  snap.forEach((doc) => {
    const data = doc.data();
    if (!data.store_id || !data.outlet_id) return;

    const deadline = parseEstimasiSelesai(data.estimasi_selesai);
    if (!deadline) return; // tidak ada estimasi → skip

    const lewatDeadline = now.getTime() > deadline.getTime();
    const diffHari = diffHariWib(now, deadline);

    if (lewatDeadline) {
      const terakhirKirim = data.notif_terlambat_terkirim_at
        ? data.notif_terlambat_terkirim_at.toDate
          ? data.notif_terlambat_terkirim_at.toDate()
          : new Date(data.notif_terlambat_terkirim_at._seconds * 1000)
        : null;

      const jamSejakTerakhir = terakhirKirim ? (now - terakhirKirim) / 1000 / 3600 : null;

      // Kirim ulang tiap 6 jam selama masih terlambat & belum selesai
      if (terakhirKirim === null || jamSejakTerakhir >= 6) {
        orderTerlambat.push({
          docId: doc.id,
          storeId: data.store_id,
          outletId: data.outlet_id,
          nama: data.nama_pelanggan || "Pelanggan",
          layanan: data.layanan_nama || "Laundry",
          terlambatHari: Math.abs(diffHari),
        });
      }
    } else if (diffHari <= 1) {
      // Hari ini (0) atau besok (1) — samakan dengan filter "Deadline" di app
      // Kirim sekali per tanggal estimasi (biar tidak spam tiap 10 menit)
      const sudahKirimUntuk = data.notif_deadline_terkirim_tanggal;
      const tandaTanggal =
        typeof data.estimasi_selesai === "string"
          ? data.estimasi_selesai
          : deadline.toISOString().slice(0, 10);

      if (sudahKirimUntuk !== tandaTanggal) {
        orderDeadline.push({
          docId: doc.id,
          storeId: data.store_id,
          outletId: data.outlet_id,
          nama: data.nama_pelanggan || "Pelanggan",
          layanan: data.layanan_nama || "Laundry",
          besok: diffHari === 1,
          tandaTanggal,
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

      const judul = orders.length === 1 ? `⏰ Deadline Hampir Tiba` : `⏰ ${orders.length} Order Hampir Deadline`;
      const isi =
        orders.length === 1
          ? `${orders[0].layanan} milik ${orders[0].nama} estimasi selesai ${orders[0].besok ? "besok" : "hari ini"}.`
          : `${orders.slice(0, 2).map((o) => o.nama).join(", ")} dan lainnya deadline ${orders[0].besok ? "besok" : "hari ini"}!`;

      console.log(`Kirim OneSignal deadline untuk outlet ${outletId} (toko ${storeId}): "${judul}"`);
      await kirimKeOwnerDanAdminOutlet(db, storeId, outletId, judul, isi, "deadline");

      semuaTerkirim.push(...orders);
    }

    const batch = db.batch();
    semuaTerkirim.forEach((o) => {
      batch.update(db.collection("order").doc(o.docId), {
        notif_deadline_terkirim_tanggal: o.tandaTanggal,
      });
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

      const judul = orders.length === 1 ? `🔴 Order Terlambat!` : `🔴 ${orders.length} Order Terlambat!`;
      const isi =
        orders.length === 1
          ? `${orders[0].layanan} milik ${orders[0].nama} sudah terlambat ${orders[0].terlambatHari} hari!`
          : `${orders.slice(0, 2).map((o) => o.nama).join(", ")} dan lainnya sudah melewati deadline!`;

      console.log(`Kirim OneSignal terlambat untuk outlet ${outletId} (toko ${storeId}): "${judul}"`);
      await kirimKeOwnerDanAdminOutlet(db, storeId, outletId, judul, isi, "terlambat");

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
// MAIN
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

main();S
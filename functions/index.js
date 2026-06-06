// ─── functions/index.js ──────────────────────────────────────────────────────
// firebase-functions v5+ (Gen 2 syntax)
// Notifikasi laundry: kirim FCM 4 jam sebelum estimasi selesai
// ─────────────────────────────────────────────────────────────────────────────

const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onDocumentUpdated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

admin.initializeApp();

// ─── Scheduled: cek setiap 30 menit ─────────────────────────────────────────
exports.notifLaundryEstimasi = onSchedule(
  {
    schedule: "*/30 * * * *",
    timeZone: "Asia/Jakarta",
    region: "asia-southeast1",
  },
  async (event) => {
    const db = admin.firestore();
    const messaging = admin.messaging();

    const now = new Date();

    // Window notif: 3.5 ~ 4.5 jam dari sekarang
    const windowMin = new Date(now.getTime() + 3.5 * 60 * 60 * 1000);
    const windowMax = new Date(now.getTime() + 4.5 * 60 * 60 * 1000);

    console.log(
      `[${_fmtWib(now)}] Cek order estimasi selesai antara ${_fmtWib(windowMin)} - ${_fmtWib(windowMax)} WIB`
    );

    try {
      const snap = await db
        .collection("order")
        .where("status", "==", "proses")
        .get();

      if (snap.empty) {
        console.log("Tidak ada order dengan status proses.");
        return;
      }

      console.log(`Total order proses: ${snap.size}`);

      const orderJatuhTempo = [];

      snap.forEach((doc) => {
        const data = doc.data();
        const docId = doc.id;

        const waktuOrder = data.waktu_order;
        const durasiJam = data.durasi_jam;

        if (!waktuOrder || durasiJam === undefined || durasiJam === null) {
          console.log(`Skip ${docId}: waktu_order atau durasi_jam kosong`);
          return;
        }

        const waktuOrderDate = waktuOrder.toDate
          ? waktuOrder.toDate()
          : new Date(waktuOrder._seconds * 1000);

        const estimasiSelesai = new Date(
          waktuOrderDate.getTime() + durasiJam * 60 * 60 * 1000
        );

        if (estimasiSelesai >= windowMin && estimasiSelesai <= windowMax) {
          orderJatuhTempo.push({
            docId,
            nama: data.nama_pelanggan || "Pelanggan",
            noHp: data.no_hp || "",
            layanan: data.layanan_nama || "Laundry",
            estimasiSelesai,
            notifSudahDikirim: data.notif_estimasi_terkirim === true,
          });
        }
      });

      if (orderJatuhTempo.length === 0) {
        console.log("Tidak ada order dalam window notifikasi.");
        return;
      }

      const perluNotif = orderJatuhTempo.filter((o) => !o.notifSudahDikirim);

      if (perluNotif.length === 0) {
        console.log("Semua order dalam window sudah dapat notifikasi.");
        return;
      }

      console.log(`Order perlu notifikasi: ${perluNotif.length}`);

      // ── Susun pesan ───────────────────────────────────────────────────────
      let judulNotif;
      let bodyNotif;

      if (perluNotif.length === 1) {
        const o = perluNotif[0];
        judulNotif = "🧺 Laundry Segera Selesai";
        bodyNotif = `${o.layanan} milik ${o.nama} estimasi selesai jam ${_fmtJam(o.estimasiSelesai)} — mohon siapkan pesanan.`;
      } else {
        const namaList = perluNotif
          .slice(0, 3)
          .map((o) => o.nama)
          .join(", ");
        const sisanya =
          perluNotif.length > 3 ? ` +${perluNotif.length - 3} lainnya` : "";
        judulNotif = `🧺 ${perluNotif.length} Laundry Segera Selesai`;
        bodyNotif = `${namaList}${sisanya} — estimasi selesai ~4 jam lagi.`;
      }

      console.log(`Kirim FCM: "${judulNotif}" | "${bodyNotif}"`);

      // ── Kirim FCM ─────────────────────────────────────────────────────────
      const message = {
        topic: "admin_Madeena_Laundry",
        notification: {
          title: judulNotif,
          body: bodyNotif,
        },
        android: {
          priority: "high",
          notification: {
            channelId: "laundry_reminder",
            sound: "default",
            clickAction: "FLUTTER_NOTIFICATION_CLICK",
          },
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
              badge: perluNotif.length,
            },
          },
        },
        data: {
          type: "laundry_estimasi",
          jumlah: perluNotif.length.toString(),
          route: "/notifikasi",
        },
      };

      const response = await messaging.send(message);
      console.log(`✅ FCM terkirim. Message ID: ${response}`);

      // ── Tandai sudah dapat notif ──────────────────────────────────────────
      const batch = db.batch();
      perluNotif.forEach((o) => {
        const ref = db.collection("order").doc(o.docId);
        batch.update(ref, { notif_estimasi_terkirim: true });
      });
      await batch.commit();
      console.log(`✅ ${perluNotif.length} order ditandai notif_estimasi_terkirim = true`);

    } catch (err) {
      console.error("❌ Error notifLaundryEstimasi:", err);
    }
  }
);

// ─── Realtime trigger: reset flag jika durasi/waktu order diubah ─────────────
exports.resetNotifFlagOnOrderUpdate = onDocumentUpdated(
  {
    document: "order/{orderId}",
    region: "asia-southeast1",
  },
  (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();

    const durasiChanged = before.durasi_jam !== after.durasi_jam;
    const waktuChanged =
      JSON.stringify(before.waktu_order) !== JSON.stringify(after.waktu_order);

    if ((durasiChanged || waktuChanged) && after.notif_estimasi_terkirim === true) {
      console.log(`Reset notif flag untuk order ${event.params.orderId}`);
      return event.data.after.ref.update({ notif_estimasi_terkirim: false });
    }

    return null;
  }
);

// ─── Helper ──────────────────────────────────────────────────────────────────
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
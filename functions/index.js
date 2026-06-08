const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onDocumentUpdated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

admin.initializeApp();

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

    const windowMin = new Date(now.getTime() + 3.5 * 60 * 60 * 1000);
    const windowMax = new Date(now.getTime() + 4.5 * 60 * 60 * 1000);

    console.log(`[${_fmtWib(now)}] Cek order estimasi ${_fmtWib(windowMin)} - ${_fmtWib(windowMax)} WIB`);

    try {
      const snap = await db.collection("order").where("status", "==", "proses").get();
      if (snap.empty) { console.log("Tidak ada order proses."); return; }

      const orderJatuhTempo = [];
      snap.forEach((doc) => {
        const data = doc.data();
        const waktuOrder = data.waktu_order;
        const durasiJam = data.durasi_jam;
        if (!waktuOrder || durasiJam == null) return;

        const waktuOrderDate = waktuOrder.toDate ? waktuOrder.toDate() : new Date(waktuOrder._seconds * 1000);
        const estimasiSelesai = new Date(waktuOrderDate.getTime() + durasiJam * 60 * 60 * 1000);

        if (estimasiSelesai >= windowMin && estimasiSelesai <= windowMax) {
          orderJatuhTempo.push({
            docId: doc.id,
            nama: data.nama_pelanggan || "Pelanggan",
            layanan: data.layanan_nama || "Laundry",
            estimasiSelesai,
            notifSudahDikirim: data.notif_estimasi_terkirim === true,
          });
        }
      });

      const perluNotif = orderJatuhTempo.filter((o) => !o.notifSudahDikirim);
      if (perluNotif.length === 0) { console.log("Semua sudah dapat notif."); return; }

      let judulNotif, bodyNotif;
      if (perluNotif.length === 1) {
        const o = perluNotif[0];
        judulNotif = "🧺 Laundry Segera Selesai";
        bodyNotif = `${o.layanan} milik ${o.nama} estimasi selesai jam ${_fmtJam(o.estimasiSelesai)} — mohon siapkan pesanan.`;
      } else {
        const namaList = perluNotif.slice(0, 3).map((o) => o.nama).join(", ");
        const sisanya = perluNotif.length > 3 ? ` +${perluNotif.length - 3} lainnya` : "";
        judulNotif = `🧺 ${perluNotif.length} Laundry Segera Selesai`;
        bodyNotif = `${namaList}${sisanya} — estimasi selesai ~4 jam lagi.`;
      }

      console.log(`Kirim FCM: "${judulNotif}" | "${bodyNotif}"`);

      // ── DATA-ONLY message — tidak ada 'notification' key ─────────────────
      // Ini mencegah Android auto-display notif (yang bikin dobel)
      // Flutter handler yang akan tampilkan notif lewat local notifications
      const message = {
        topic: "admin_Madeena_Laundry",
        // TIDAK ada field 'notification' di sini
        android: {
          priority: "high",
        },
        apns: {
          headers: {
            "apns-priority": "10",
          },
        },
        // Semua payload di 'data' — termasuk judul & isi notif
        data: {
          type: "laundry_estimasi",
          judul: judulNotif,
          isi: bodyNotif,
          jumlah: perluNotif.length.toString(),
          route: "/notifikasi",
          waktu: new Date().toISOString(),
        },
      };

      const response = await messaging.send(message);
      console.log(`✅ FCM terkirim. Message ID: ${response}`);

      const batch = db.batch();
      perluNotif.forEach((o) => {
        batch.update(db.collection("order").doc(o.docId), { notif_estimasi_terkirim: true });
      });
      await batch.commit();
      console.log(`✅ ${perluNotif.length} order ditandai terkirim`);

    } catch (err) {
      console.error("❌ Error:", err);
    }
  }
);

exports.resetNotifFlagOnOrderUpdate = onDocumentUpdated(
  { document: "order/{orderId}", region: "asia-southeast1" },
  (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();
    const durasiChanged = before.durasi_jam !== after.durasi_jam;
    const waktuChanged = JSON.stringify(before.waktu_order) !== JSON.stringify(after.waktu_order);
    if ((durasiChanged || waktuChanged) && after.notif_estimasi_terkirim === true) {
      return event.data.after.ref.update({ notif_estimasi_terkirim: false });
    }
    return null;
  }
);

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
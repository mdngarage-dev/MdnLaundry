// ─── functions/index.js (Gen 1 - Spark Plan Compatible) ─────────────────────
// Menggunakan firebase-functions v1 (pubsub.schedule) bukan v2
// Kompatibel dengan Firebase Spark plan (gratis)
// Cron: setiap hari jam 08:00 WIB
// ─────────────────────────────────────────────────────────────────────────────

const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

exports.notifHarianKB = functions
  .region("asia-southeast1") // Singapore — paling dekat, support scheduled functions
  .pubsub.schedule("0 8 * * *") // 01:00 UTC = 08:00 WIB
  .timeZone("Asia/Jakarta")
  .onRun(async (context) => {
    const db = admin.firestore();
    const messaging = admin.messaging();

    // ── Hitung rentang tanggal ──────────────────────────────────────────────
    const now = new Date();
    const hariIni = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const batasAkhir = new Date(hariIni);
    batasAkhir.setDate(batasAkhir.getDate() + 3);

    console.log(`Cek KB jatuh tempo: ${_fmt(hariIni)} s/d ${_fmt(batasAkhir)}`);

    try {
      // ── Ambil semua rekam_medis yang punya tgl_kembali tidak kosong ───────
      const snap = await db
        .collection("rekam_medis")
        .where("tgl_kembali", "!=", "")
        .get();

      if (snap.empty) {
        console.log("Tidak ada dokumen dengan tgl_kembali.");
        return null;
      }

      // ── Dedup per NIP: ambil rekam medis terbaru ─────────────────────────
      const latestPerNip = {};
      snap.forEach((doc) => {
        const data = doc.data();
        const nip = data.nomer_induk_pasien || "";
        if (!nip) return;

        const tglStr = (data.tgl_kembali || "").trim();
        if (!tglStr) return;

        const tglKembali = _parseTgl(tglStr);
        if (!tglKembali) return;

        // Filter: hanya yang jatuh tempo hari ini s/d 3 hari ke depan
        if (tglKembali < hariIni || tglKembali > batasAkhir) return;

        // Simpan yang paling baru per NIP
        if (!latestPerNip[nip]) {
          latestPerNip[nip] = { data, tglKembali };
        } else {
          const existing = latestPerNip[nip].data.waktu_kunjungan || "";
          const current = data.waktu_kunjungan || "";
          if (current > existing) {
            latestPerNip[nip] = { data, tglKembali };
          }
        }
      });

      const listPasien = Object.entries(latestPerNip);

      if (listPasien.length === 0) {
        console.log("Tidak ada pasien KB yang jatuh tempo hari ini.");
        return null;
      }

      console.log(`Ditemukan ${listPasien.length} pasien KB jatuh tempo.`);

      // ── Ambil nama pasien dari collection 'pasien' ───────────────────────
      const nipList = listPasien.map(([nip]) => nip);
      const namaPasien = {};
      const chunkSize = 30;

      for (let i = 0; i < nipList.length; i += chunkSize) {
        const chunk = nipList.slice(i, i + chunkSize);
        const pasienSnap = await db
          .collection("pasien")
          .where("nomer_induk_pasien", "in", chunk)
          .get();
        pasienSnap.forEach((doc) => {
          const d = doc.data();
          namaPasien[d.nomer_induk_pasien] =
            d.nama_lengkap || d.nomer_induk_pasien;
        });
      }

      // ── Susun isi notifikasi ─────────────────────────────────────────────
      let judulNotif;
      let bodyNotif;

      if (listPasien.length === 1) {
        const [nip, { tglKembali }] = listPasien[0];
        const nama = namaPasien[nip] || nip;
        const selisih = _selisihHari(hariIni, tglKembali);
        const waktuStr = _labelWaktu(selisih);

        judulNotif = "⏰ Pengingat Jadwal KB";
        bodyNotif = `Pasien ${nama} jadwal kontrol KB ${waktuStr} (${_fmtTampil(tglKembali)})`;
      } else {
        const namaList = listPasien
          .slice(0, 3)
          .map(([nip]) => namaPasien[nip] || nip)
          .join(", ");
        const sisanya =
          listPasien.length > 3 ? ` +${listPasien.length - 3} lainnya` : "";

        judulNotif = `⏰ ${listPasien.length} Pasien KB Jatuh Tempo`;
        bodyNotif = `${namaList}${sisanya} — Buka app untuk detail`;
      }

      console.log(`Kirim FCM: "${judulNotif}" | "${bodyNotif}"`);

      // ── Kirim FCM ke topic admin_klinik ──────────────────────────────────
      const message = {
        topic: "admin_klinik",
        notification: {
          title: judulNotif,
          body: bodyNotif,
        },
        android: {
          priority: "high",
          notification: {
            channelId: "kb_reminder",
            sound: "default",
            clickAction: "FLUTTER_NOTIFICATION_CLICK",
          },
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
              badge: listPasien.length,
            },
          },
        },
        data: {
          type: "kb_reminder",
          jumlah: listPasien.length.toString(),
          route: "/notifikasi",
        },
      };

      const response = await messaging.send(message);
      console.log(`✅ FCM terkirim. Message ID: ${response}`);
      return null;

    } catch (err) {
      console.error("❌ Error notifHarianKB:", err);
      return null;
    }
  });

// ─── Helper functions ────────────────────────────────────────────────────────

function _parseTgl(str) {
  try {
    const [d, m, y] = str.split("-");
    if (d && m && y && y.length === 4) {
      const dt = new Date(parseInt(y), parseInt(m) - 1, parseInt(d));
      if (!isNaN(dt.getTime())) return dt;
    }
  } catch (_) {}
  return null;
}

function _selisihHari(dari, ke) {
  const ms = ke.getTime() - dari.getTime();
  return Math.round(ms / (1000 * 60 * 60 * 24));
}

function _labelWaktu(selisih) {
  if (selisih === 0) return "hari ini";
  if (selisih === 1) return "besok";
  if (selisih > 1) return `${selisih} hari lagi`;
  return `terlambat ${Math.abs(selisih)} hari`;
}

function _fmt(date) {
  return `${date.getDate().toString().padStart(2, "0")}/${(date.getMonth() + 1)
    .toString()
    .padStart(2, "0")}/${date.getFullYear()}`;
}

function _fmtTampil(date) {
  const bulan = [
    "Jan","Feb","Mar","Apr","Mei","Jun",
    "Jul","Agt","Sep","Okt","Nov","Des",
  ];
  return `${date.getDate().toString().padStart(2, "0")} ${
    bulan[date.getMonth()]
  } ${date.getFullYear()}`;
}
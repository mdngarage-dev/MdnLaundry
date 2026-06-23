const admin = require("firebase-admin");

const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });

const db = admin.firestore();

async function deleteAdmin() {
  const callerUid = process.env.CALLER_UID;
  const targetUid = process.env.TARGET_UID;

  if (!callerUid || !targetUid) {
    console.error("❌ CALLER_UID dan TARGET_UID wajib diisi.");
    process.exit(1);
  }

  try {
    // 1. Verifikasi caller adalah Owner
    const callerDoc = await db.collection("users").doc(callerUid).get();
    if (!callerDoc.exists || callerDoc.data().role !== "Owner") {
      console.error("❌ Permission denied: caller bukan Owner.");
      process.exit(1);
    }

    const ownerStoreId = callerDoc.data().store_id;

    // 2. Verifikasi target adalah Admin dari toko yang sama
    const targetDoc = await db.collection("users").doc(targetUid).get();
    if (!targetDoc.exists) {
      console.error("❌ Akun admin tidak ditemukan.");
      process.exit(1);
    }

    const targetData = targetDoc.data();
    if (targetData.role !== "Admin" || targetData.store_id !== ownerStoreId) {
      console.error("❌ Target bukan admin dari toko yang sama.");
      process.exit(1);
    }

    // 3. Hapus dokumen Firestore
    await db.collection("users").doc(targetUid).delete();
    console.log(`✅ Dokumen Firestore users/${targetUid} dihapus.`);

    // 4. Hapus akun Firebase Auth
    await admin.auth().deleteUser(targetUid);
    console.log(`✅ Firebase Auth akun ${targetUid} dihapus permanen.`);

    console.log(`✅ Selesai. Admin ${targetUid} dari toko ${ownerStoreId} berhasil dihapus.`);
    process.exit(0);
  } catch (err) {
    console.error("❌ Error:", err.message);
    process.exit(1);
  }
}

deleteAdmin();
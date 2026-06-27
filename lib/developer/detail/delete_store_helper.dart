import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Helper static untuk hapus seluruh data store dari Firestore.
/// Dipanggil dari store_owner_page.dart dan store_outlets_page.dart.
class DeleteStoreHelper {
  static Future<void> hapusSeluruhStore(String storeId) async {
    final db = FirebaseFirestore.instance;

    WriteBatch batch = db.batch();
    int opCount = 0;

    Future<void> safeDelete(DocumentReference ref) async {
      batch.delete(ref);
      opCount++;
      if (opCount >= 450) {
        await batch.commit();
        batch = db.batch();
        opCount = 0;
      }
    }

    // 1. Root collections
    for (final col in ['keuangan', 'order', 'pengeluaran', 'rak']) {
      final docs = await db
          .collection(col)
          .where('store_id', isEqualTo: storeId)
          .get();
      for (final doc in docs.docs) await safeDelete(doc.reference);
    }

    // 2. Subcollection outlet
    final outlets = await db
        .collection('stores')
        .doc(storeId)
        .collection('outlets')
        .get();
    for (final outlet in outlets.docs) {
      for (final sub in [
        'pelanggan',
        'settings',
        'counters',
        'layanan',
        'subscription',
        'payment_history',
      ]) {
        final subDocs = await outlet.reference.collection(sub).get();
        for (final doc in subDocs.docs) await safeDelete(doc.reference);
      }
      await safeDelete(outlet.reference);
    }

    // 3. store_permissions
    final permissions = await db
        .collection('store_permissions')
        .where('store_id', isEqualTo: storeId)
        .get();
    for (final doc in permissions.docs) await safeDelete(doc.reference);

    // 4. Semua user terkait (admin + owner)
    final users = await db
        .collection('users')
        .where('store_id', isEqualTo: storeId)
        .get();
    for (final doc in users.docs) await safeDelete(doc.reference);

    // 5. Store doc
    await safeDelete(db.collection('stores').doc(storeId));

    // Commit sisa
    if (opCount > 0) await batch.commit();

    debugPrint('✅ Store $storeId berhasil dihapus seluruhnya');
  }
}

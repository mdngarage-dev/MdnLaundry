import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mdnlaundry_project/core/config/app_config.dart';

// ════════════════════════════════════════════════════════════════════════════
//  OutletSettingsService — baca & tulis ke Firestore
//  Dokumen: settings/outlet
// ════════════════════════════════════════════════════════════════════════════
class OutletSettingsService {
  static DocumentReference<Map<String, dynamic>> _docRef(
    String storeId,
    String outletId,
  ) => FirebaseFirestore.instance
      .collection('stores')
      .doc(storeId)
      .collection('outlets')
      .doc(outletId)
      .collection('settings')
      .doc('outlet');

  /// Muat data dari Firestore lalu update OutletSettings in-memory.
  static Future<void> load(String storeId, String outletId) async {
    // 🌟 TAMBAH parameter
    try {
      final snap = await _docRef(storeId, outletId).get(); // 🌟 UBAH
      if (!snap.exists) return;
      final d = snap.data()!;
      OutletSettings.namaLaundry =
          d['nama']?.toString() ?? OutletSettings.namaLaundry;
      OutletSettings.noHpLaundry =
          d['no_hp']?.toString() ?? OutletSettings.noHpLaundry;
      OutletSettings.alamat = d['alamat']?.toString() ?? OutletSettings.alamat;
      if (!kIsWeb) {
        OutletSettings.logoPath =
            d['logo_path']?.toString() ?? OutletSettings.logoPath;
      }
    } catch (_) {
      // Gagal muat = tetap pakai nilai default
    }
  }

  /// Simpan data ke Firestore.
  static Future<void> save({
    required String storeId,
    required String outletId,
    required String nama,
    required String noHp,
    required String alamat,
    String logoPath = '',
  }) async {
    await _docRef(storeId, outletId).set({
      // 🌟 UBAH
      'nama': nama,
      'no_hp': noHp,
      'alamat': alamat,
      if (!kIsWeb && logoPath.isNotEmpty) 'logo_path': logoPath,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Stream untuk realtime sync (opsional — dipakai jika ingin live update).
  static Stream<DocumentSnapshot<Map<String, dynamic>>> streamFor(
    String storeId,
    String outletId,
  ) => // 🌟 UBAH jadi method, bukan getter statis
      _docRef(storeId, outletId).snapshots();
}

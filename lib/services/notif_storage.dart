import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mdnlaundry_project/models/notif_item.dart';

// ─── Firestore NotifStorage ──────────────────────────────────────────────────
class NotifStorage {
  static const _collectionName = 'notif_history';
  static const _maxItem = 50;

  static CollectionReference get _notifCollection =>
      FirebaseFirestore.instance.collection(_collectionName);

  static String? get _currentUserId => FirebaseAuth.instance.currentUser?.uid;

  /// Simpan notif baru ke Firestore
  static Future<void> simpan(NotifItem item) async {
    try {
      final userId = _currentUserId;
      if (userId == null) {
        debugPrint('⚠ User belum login, notif tidak disimpan');
        return;
      }

      // Simpan ke sub-collection user-specific untuk isolasi data
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection(_collectionName)
          .doc(item.id)
          .set(item.toFirestore());

      debugPrint('✅ Notif tersimpan di Firestore: ${item.judul}');
    } catch (e) {
      debugPrint('⚠ Error simpan notif: $e');
    }
  }

  /// Ambil semua notif dari Firestore (sync antar device)
  static Future<List<NotifItem>> ambilSemua() async {
    try {
      final userId = _currentUserId;
      if (userId == null) {
        debugPrint('⚠ User belum login, notif kosong');
        return [];
      }

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection(_collectionName)
          .orderBy('waktu', descending: true)
          .limit(_maxItem)
          .get();

      return snapshot.docs.map((doc) => NotifItem.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('⚠ Error ambil notif: $e');
      return [];
    }
  }

  /// Stream notif untuk real-time update
  static Stream<List<NotifItem>> streamNotif() {
    final userId = _currentUserId;
    if (userId == null) return Stream.value([]);

    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection(_collectionName)
        .orderBy('waktu', descending: true)
        .limit(_maxItem)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => NotifItem.fromFirestore(doc)).toList(),
        );
  }

  /// Hapus satu notif berdasarkan id
  static Future<void> hapus(String id) async {
    try {
      final userId = _currentUserId;
      if (userId == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection(_collectionName)
          .doc(id)
          .delete();

      debugPrint('✅ Notif dihapus: $id');
    } catch (e) {
      debugPrint('⚠ Error hapus notif: $e');
    }
  }

  /// Hapus semua notif
  static Future<void> hapusSemua() async {
    try {
      final userId = _currentUserId;
      if (userId == null) return;

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection(_collectionName)
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      debugPrint('✅ Semua notif dihapus');
    } catch (e) {
      debugPrint('⚠ Error hapus semua notif: $e');
    }
  }

  /// Tandai semua sudah dibaca
  static Future<void> tandaiSemuaDibaca() async {
    try {
      final userId = _currentUserId;
      if (userId == null) return;

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection(_collectionName)
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {'sudahDibaca': true});
      }
      await batch.commit();

      debugPrint('✅ Semua notif ditandai dibaca');
    } catch (e) {
      debugPrint('⚠ Error tandai dibaca: $e');
    }
  }

  /// Hitung jumlah notif belum dibaca
  static Future<int> jumlahBelumDibaca() async {
    try {
      final userId = _currentUserId;
      if (userId == null) return 0;

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection(_collectionName)
          .where('sudahDibaca', isEqualTo: false)
          .get();

      return snapshot.size;
    } catch (e) {
      debugPrint('⚠ Error hitung belum dibaca: $e');
      return 0;
    }
  }

  /// Stream jumlah notif belum dibaca (real-time)
  static Stream<int> streamJumlahBelumDibaca() {
    final userId = _currentUserId;
    if (userId == null) return Stream.value(0);

    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection(_collectionName)
        .where('sudahDibaca', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.size);
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

class OutletService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Get Order per Outlet ──────────────────────────────────────────────────
  static Stream<QuerySnapshot> getOrdersStream({
    required String storeId,
    required String outletId,
    String? statusFilter,
  }) {
    Query query = _db
        .collection('order')
        .where('store_id', isEqualTo: storeId)
        .where('outlet_id', isEqualTo: outletId);

    if (statusFilter != null && statusFilter.isNotEmpty) {
      query = query.where('status', isEqualTo: statusFilter);
    }

    // Tidak pakai orderBy agar tidak butuh composite index tambahan.
    // Sorting dilakukan client-side di masing-masing screen.
    return query.snapshots();
  }

  // ── Get Layanan per Outlet ───────────────────────────────────────────────
  static Stream<QuerySnapshot> getLayananStream({
    required String storeId,
    required String outletId,
  }) {
    return _db
        .collection('stores')
        .doc(storeId)
        .collection('outlets')
        .doc(outletId)
        .collection('layanan')
        .snapshots();
  }

  // ── Get Rak per Outlet ────────────────────────────────────────────────────
  static Stream<QuerySnapshot> getRakStream({
    required String storeId,
    required String outletId,
  }) {
    return _db
        .collection('rak')
        .where('store_id', isEqualTo: storeId)
        .where('outlet_id', isEqualTo: outletId)
        .snapshots();
  }

  // ── Get Pengeluaran per Outlet ────────────────────────────────────────────
  static Stream<QuerySnapshot> getPengeluaranStream({
    required String storeId,
    required String outletId,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    Query query = _db
        .collection('pengeluaran')
        .where('store_id', isEqualTo: storeId)
        .where('outlet_id', isEqualTo: outletId);

    if (startDate != null) {
      query = query.where('tanggal', isGreaterThanOrEqualTo: startDate);
    }
    if (endDate != null) {
      query = query.where('tanggal', isLessThanOrEqualTo: endDate);
    }

    // Tidak pakai orderBy agar tidak butuh composite index tambahan.
    return query.snapshots();
  }

  // ── Get Keuangan per Outlet ───────────────────────────────────────────────
  static Stream<QuerySnapshot> getKeuanganStream({
    required String storeId,
    required String outletId,
  }) {
    return _db
        .collection('keuangan')
        .where('store_id', isEqualTo: storeId)
        .where('outlet_id', isEqualTo: outletId)
        .snapshots();
  }

  // ── Get Counter Nota per Outlet ───────────────────────────────────────────
  static Future<int> getNextNotaNumber({
    required String storeId,
    required String outletId,
  }) async {
    final counterRef = _db
        .collection('stores')
        .doc(storeId)
        .collection('outlets')
        .doc(outletId)
        .collection('counters')
        .doc('pelanggan');

    final snap = await counterRef.get();
    return (snap.data()?['last'] ?? 0) + 1;
  }

  // ── Increment Counter Nota ────────────────────────────────────────────────
  static Future<void> incrementNotaCounter({
    required String storeId,
    required String outletId,
  }) async {
    final counterRef = _db
        .collection('stores')
        .doc(storeId)
        .collection('outlets')
        .doc(outletId)
        .collection('counters')
        .doc('pelanggan');

    await counterRef.update({'last': FieldValue.increment(1)});
  }

  // ── Get Outlet Settings ───────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getOutletSettings({
    required String storeId,
    required String outletId,
  }) async {
    final snap = await _db
        .collection('stores')
        .doc(storeId)
        .collection('outlets')
        .doc(outletId)
        .collection('settings')
        .doc('default')
        .get();

    return snap.data() ?? {};
  }

  // ── Update Outlet Settings ────────────────────────────────────────────────
  static Future<void> updateOutletSettings({
    required String storeId,
    required String outletId,
    required Map<String, dynamic> data,
  }) async {
    await _db
        .collection('stores')
        .doc(storeId)
        .collection('outlets')
        .doc(outletId)
        .collection('settings')
        .doc('default')
        .set(data, SetOptions(merge: true));
  }
}

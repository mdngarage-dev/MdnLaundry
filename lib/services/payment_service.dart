import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_functions/firebase_functions.dart';

class PaymentService {
  static final _functions = FirebaseFunctions.instanceFor(
    region: 'asia-southeast1',
  );
  static final _db = FirebaseFirestore.instance;

  // ── Generate QRIS Invoice ────────────────────────────────────────────────
  static Future<Map<String, dynamic>> generateQrisInvoice({
    required String storeId,
    required String outletId,
    required String packageId,
    required int amount,
  }) async {
    try {
      final callable = _functions.httpsCallable('generateQrisInvoice');
      final result = await callable.call({
        'storeId': storeId,
        'outletId': outletId,
        'packageId': packageId,
        'amount': amount,
      });

      return result.data as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Gagal generate QRIS: $e');
    }
  }

  // ── Get Package Price ────────────────────────────────────────────────────
  static Future<int> getPackagePrice(String packageId) async {
    try {
      final doc = await _db
          .collection('subscription_packages')
          .doc(packageId)
          .get();

      return doc.data()?['price'] as int? ?? 0;
    } catch (e) {
      return 0;
    }
  }

  // ── Get Payment History ──────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getPaymentHistory({
    required String storeId,
    required String outletId,
  }) async {
    try {
      final callable = _functions.httpsCallable('getPaymentHistory');
      final result = await callable.call({
        'storeId': storeId,
        'outletId': outletId,
      });

      final history = result.data as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(history['history'] ?? []);
    } catch (e) {
      return [];
    }
  }

  // ── Get latest payment record ────────────────────────────────────────────
  static Future<Map<String, dynamic>?> getLatestPendingPayment({
    required String storeId,
    required String outletId,
  }) async {
    try {
      final snap = await _db
          .collection('stores')
          .doc(storeId)
          .collection('outlets')
          .doc(outletId)
          .collection('payment_history')
          .where('status', isEqualTo: 'pending')
          .orderBy('created_at', descending: true)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) return null;
      return snap.docs.first.data();
    } catch (e) {
      return null;
    }
  }
}

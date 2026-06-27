import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class PaymentService {
  static final _functions = FirebaseFunctions.instanceFor(
    region: 'asia-southeast1',
  );
  static final _db = FirebaseFirestore.instance;

  // ── Create Midtrans Transaction (QRIS) ───────────────────────────────────
  // Menggantikan generateQrisInvoice (Xendit)
  static Future<Map<String, dynamic>> createMidtransTransaction({
    required String storeId,
    required String outletId,
    required String packageId,
    required int amount,
  }) async {
    try {
      final callable = _functions.httpsCallable('createMidtransTransaction');
      final result = await callable.call({
        'storeId': storeId,
        'outletId': outletId,
        'packageId': packageId,
        'amount': amount,
      });

      return Map<String, dynamic>.from(result.data as Map);
    } on FirebaseFunctionsException catch (e) {
      throw Exception('Gagal create transaksi: ${e.message}');
    } catch (e) {
      throw Exception('Gagal create transaksi: $e');
    }
  }

  // ── Get Package Price dari Firestore ────────────────────────────────────
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

  // ── Get Package Details dari Firestore ──────────────────────────────────
  static Future<Map<String, dynamic>> getPackageDetails(
    String packageId,
  ) async {
    try {
      final doc = await _db
          .collection('subscription_packages')
          .doc(packageId)
          .get();
      return doc.data() ?? {};
    } catch (e) {
      return {};
    }
  }

  // ── Get Payment History via Cloud Function ──────────────────────────────
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

      final data = result.data as Map;
      return List<Map<String, dynamic>>.from(
        (data['history'] as List? ?? []).map(
          (e) => Map<String, dynamic>.from(e as Map),
        ),
      );
    } catch (e) {
      return [];
    }
  }

  // ── Get latest pending payment dari Firestore ───────────────────────────
  // Cek apakah ada pending payment sebelumnya supaya tidak double charge
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

  // ── Stream payment status real-time ─────────────────────────────────────
  // Listen perubahan status payment → auto unlock saat settlement
  static Stream<QuerySnapshot> paymentStatusStream({
    required String storeId,
    required String outletId,
  }) {
    return _db
        .collection('stores')
        .doc(storeId)
        .collection('outlets')
        .doc(outletId)
        .collection('payment_history')
        .where('status', isEqualTo: 'pending')
        .orderBy('created_at', descending: true)
        .limit(1)
        .snapshots();
  }

  // ── Cancel pending payment ───────────────────────────────────────────────
  static Future<void> cancelPendingPayment({
    required String storeId,
    required String outletId,
    required String paymentRecordId,
  }) async {
    try {
      await _db
          .collection('stores')
          .doc(storeId)
          .collection('outlets')
          .doc(outletId)
          .collection('payment_history')
          .doc(paymentRecordId)
          .update({
            'status': 'cancel',
            'updated_at': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      throw Exception('Gagal cancel payment: $e');
    }
  }
}

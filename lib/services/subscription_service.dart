import 'package:cloud_firestore/cloud_firestore.dart';

class SubscriptionService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Get subscription status outlet ────────────────────────────────────
  static Future<Map<String, dynamic>> getOutletSubscription({
    required String storeId,
    required String outletId,
  }) async {
    try {
      final snap = await _db
          .collection('stores')
          .doc(storeId)
          .collection('outlets')
          .doc(outletId)
          .collection('subscription')
          .doc('active')
          .get();

      if (!snap.exists) {
        return {
          'status': 'unknown',
          'plan': 'basic',
          'error': 'Subscription not found',
        };
      }

      return snap.data() ?? {};
    } catch (e) {
      return {'status': 'error', 'error': e.toString()};
    }
  }

  // ── Get subscription package details ─────────────────────────────────
  static Future<Map<String, dynamic>> getPackageDetails(
    String packageId,
  ) async {
    try {
      final snap = await _db
          .collection('subscription_packages')
          .doc(packageId)
          .get();
      return snap.data() ?? {};
    } catch (e) {
      return {};
    }
  }

  // ── Stream subscription status (real-time) ────────────────────────────
  static Stream<DocumentSnapshot> subscriptionStream({
    required String storeId,
    required String outletId,
  }) {
    return _db
        .collection('stores')
        .doc(storeId)
        .collection('outlets')
        .doc(outletId)
        .collection('subscription')
        .doc('active')
        .snapshots();
  }

  // ── Check apakah feature enabled untuk outlet ─────────────────────────
  static Future<bool> isFeatureEnabled({
    required String storeId,
    required String outletId,
    required String feature, // 'edit_nota', 'edit_wa_message'
  }) async {
    final sub = await getOutletSubscription(
      storeId: storeId,
      outletId: outletId,
    );

    // Jika expired atau unknown → false
    if (sub['status'] != 'active' && sub['status'] != 'trial') {
      return false;
    }

    final plan = sub['plan'] ?? 'basic';
    final packageDetails = await getPackageDetails(plan);
    final features = packageDetails['features'] as Map<String, dynamic>?;

    return features?[feature] ?? false;
  }

  // ── Check order limit ────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getOrderLimitInfo({
    required String storeId,
    required String outletId,
  }) async {
    final sub = await getOutletSubscription(
      storeId: storeId,
      outletId: outletId,
    );

    if (sub['status'] != 'active' && sub['status'] != 'trial') {
      return {'limit': 0, 'used': 0, 'remaining': 0};
    }

    final plan = sub['plan'] ?? 'basic';
    final packageDetails = await getPackageDetails(plan);
    final limit = packageDetails['features']['order_limit'] as int? ?? 0;

    // Hitung order bulan ini
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0);

    final orderSnap = await _db
        .collection('order')
        .where('store_id', isEqualTo: storeId)
        .where('outlet_id', isEqualTo: outletId)
        .where(
          'waktu_order',
          isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart),
        )
        .where('waktu_order', isLessThanOrEqualTo: Timestamp.fromDate(monthEnd))
        .count()
        .get();

    final used = orderSnap.count;
    final remaining = limit - used!;

    return {
      'limit': limit,
      'used': used,
      'remaining': remaining > 0 ? remaining : 0,
    };
  }

  // ── Get all outlets subscription (untuk admin dashboard) ──────────────
  static Future<List<Map<String, dynamic>>> getAllOutletsSubscription({
    required String storeId,
  }) async {
    try {
      final outletsSnap = await _db
          .collection('stores')
          .doc(storeId)
          .collection('outlets')
          .get();

      final result = <Map<String, dynamic>>[];

      for (final outletDoc in outletsSnap.docs) {
        final outletId = outletDoc.id;
        final outletData = outletDoc.data();

        final subSnap = await _db
            .collection('stores')
            .doc(storeId)
            .collection('outlets')
            .doc(outletId)
            .collection('subscription')
            .doc('active')
            .get();

        result.add({
          'outlet_id': outletId,
          'outlet_name': outletData['nama_outlet'] ?? 'Outlet',
          'subscription': subSnap.data() ?? {},
        });
      }

      return result;
    } catch (e) {
      return [];
    }
  }

  // ── Upgrade subscription ─────────────────────────────────────────────
  static Future<bool> upgradeSubscription({
    required String storeId,
    required String outletId,
    required String newPlan, // 'basic' atau 'pro'
    required String qrisReference,
  }) async {
    try {
      final now = DateTime.now();
      final nextPaymentDue = DateTime(
        now.year,
        now.month + 1,
        now.day,
      ); // 1 bulan kedepan

      await _db
          .collection('stores')
          .doc(storeId)
          .collection('outlets')
          .doc(outletId)
          .collection('subscription')
          .doc('active')
          .update({
            'status': 'active',
            'plan': newPlan,
            'subscription_start_date': FieldValue.serverTimestamp(),
            'subscription_end_date': Timestamp.fromDate(nextPaymentDue),
            'last_payment_date': FieldValue.serverTimestamp(),
            'next_payment_due': Timestamp.fromDate(nextPaymentDue),
            'qris_reference': qrisReference,
            'notified_h3': false,
            'updated_at': FieldValue.serverTimestamp(),
          });

      return true;
    } catch (e) {
      return false;
    }
  }

  // ── Manual extend subscription (admin) ────────────────────────────────
  static Future<bool> extendSubscription({
    required String storeId,
    required String outletId,
    required int monthsToAdd,
  }) async {
    try {
      final sub = await getOutletSubscription(
        storeId: storeId,
        outletId: outletId,
      );

      // ── Fix: handle null subscription_end_date ──────────────────────
      DateTime currentEndDate;

      final endDateRaw = sub['subscription_end_date'];
      final trialEndRaw = sub['trial_end_date'];

      if (endDateRaw != null) {
        currentEndDate = (endDateRaw as Timestamp).toDate();
      } else if (trialEndRaw != null) {
        // Jika belum pernah bayar, extend dari trial_end_date
        currentEndDate = (trialEndRaw as Timestamp).toDate();
      } else {
        // Fallback: extend dari sekarang
        currentEndDate = DateTime.now();
      }

      final newEndDate = DateTime(
        currentEndDate.year,
        currentEndDate.month + monthsToAdd,
        currentEndDate.day,
      );

      await _db
          .collection('stores')
          .doc(storeId)
          .collection('outlets')
          .doc(outletId)
          .collection('subscription')
          .doc('active')
          .update({
            'status': 'active', // ← Aktifkan juga saat extend
            'subscription_end_date': Timestamp.fromDate(newEndDate),
            'next_payment_due': Timestamp.fromDate(newEndDate),
            'notified_h3': false,
            'updated_at': FieldValue.serverTimestamp(),
          });

      return true;
    } catch (e) {
      return false;
    }
  }

  // ── Cancel subscription ──────────────────────────────────────────────
  static Future<bool> cancelSubscription({
    required String storeId,
    required String outletId,
  }) async {
    try {
      await _db
          .collection('stores')
          .doc(storeId)
          .collection('outlets')
          .doc(outletId)
          .collection('subscription')
          .doc('active')
          .update({
            'status': 'expired',
            'updated_at': FieldValue.serverTimestamp(),
          });

      return true;
    } catch (e) {
      return false;
    }
  }
}

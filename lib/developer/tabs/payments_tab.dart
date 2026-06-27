// ── payments_tab.dart ────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class PaymentsTab extends StatelessWidget {
  const PaymentsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getAllPayments(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 48,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 12),
                Text(
                  'Belum ada pembayaran',
                  style: TextStyle(color: Colors.grey.shade500),
                ),
              ],
            ),
          );
        }

        final payments = snapshot.data!;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: payments.length,
          itemBuilder: (context, idx) {
            final payment = payments[idx];
            final storeName = payment['store_name'] ?? 'Store';
            final outletName = payment['outlet_name'] ?? 'Outlet';
            final amount = payment['amount'] ?? 0;
            final status = payment['status'] ?? 'pending';
            final createdAt = payment['created_at_date'] as DateTime?;
            final packageId = payment['package_id'] ?? '';

            Color statusColor;
            IconData statusIcon;
            String statusLabel;

            // ── Fix: Midtrans pakai 'settlement' bukan 'completed' ──────────
            switch (status) {
              case 'settlement':
                statusColor = Colors.green;
                statusIcon = Icons.check_circle_rounded;
                statusLabel = 'LUNAS';
                break;
              case 'pending':
                statusColor = Colors.orange;
                statusIcon = Icons.schedule_rounded;
                statusLabel = 'PENDING';
                break;
              case 'expire':
                statusColor = Colors.grey;
                statusIcon = Icons.timer_off_rounded;
                statusLabel = 'EXPIRED';
                break;
              case 'cancel':
              case 'deny':
                statusColor = Colors.red;
                statusIcon = Icons.cancel_rounded;
                statusLabel = 'DIBATALKAN';
                break;
              default:
                statusColor = Colors.grey;
                statusIcon = Icons.help_outline_rounded;
                statusLabel = status.toUpperCase();
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(statusIcon, color: statusColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$storeName',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            outletName,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          if (packageId.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Paket ${packageId.toUpperCase()}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.blue,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          if (createdAt != null)
                            Text(
                              DateFormat('dd MMM yyyy HH:mm').format(createdAt),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          NumberFormat.currency(
                            locale: 'id_ID',
                            symbol: 'Rp ',
                            decimalDigits: 0,
                          ).format(amount),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: statusColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(
                              fontSize: 9,
                              color: statusColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ── Helper: parse Timestamp atau String ke DateTime ──────────────────────
  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String && value.isNotEmpty) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> _getAllPayments() async {
    try {
      final db = FirebaseFirestore.instance;
      final allPayments = <Map<String, dynamic>>[];
      final storesSnap = await db.collection('stores').get();

      for (final storeDoc in storesSnap.docs) {
        final storeData = storeDoc.data();
        final storeName = storeData['nama_toko'] ?? 'Store';

        final outletsSnap = await db
            .collection('stores')
            .doc(storeDoc.id)
            .collection('outlets')
            .get();

        for (final outletDoc in outletsSnap.docs) {
          final outletData = outletDoc.data();
          final outletName = outletData['nama_outlet'] ?? 'Outlet';

          final paymentsSnap = await db
              .collection('stores')
              .doc(storeDoc.id)
              .collection('outlets')
              .doc(outletDoc.id)
              .collection('payment_history')
              .orderBy('created_at', descending: true)
              .get();

          for (final paymentDoc in paymentsSnap.docs) {
            final data = paymentDoc.data();
            // ── Fix: konversi Timestamp ke DateTime ──────────────────────
            final createdAtDate = _parseDate(data['created_at']);

            allPayments.add({
              'id': paymentDoc.id,
              'store_id': storeDoc.id,
              'outlet_id': outletDoc.id,
              'store_name': storeName,
              'outlet_name': outletName,
              ...data,
              // Override created_at dengan DateTime object
              'created_at_date': createdAtDate,
              'created_at_str': createdAtDate?.toIso8601String() ?? '',
            });
          }
        }
      }

      // Sort by date descending
      allPayments.sort((a, b) {
        final dateA = a['created_at_date'] as DateTime?;
        final dateB = b['created_at_date'] as DateTime?;
        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return 1;
        if (dateB == null) return -1;
        return dateB.compareTo(dateA);
      });

      return allPayments;
    } catch (e) {
      debugPrint('Error getting payments: $e');
      return [];
    }
  }
}

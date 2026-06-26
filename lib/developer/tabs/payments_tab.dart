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
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final payments = snapshot.data!;

        if (payments.isEmpty) {
          return const Center(child: Text('Tidak ada pembayaran ditemukan.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: payments.length,
          itemBuilder: (context, idx) {
            final payment = payments[idx];
            final storeName = payment['store_name'] ?? 'Store';
            final outletName = payment['outlet_name'] ?? 'Outlet';
            final amount = payment['amount'] ?? 0;
            final status = payment['status'] ?? 'pending';
            final createdAt = payment['created_at'] != null
                ? DateTime.parse(payment['created_at'] as String)
                : null;

            Color statusColor;
            IconData statusIcon;

            switch (status) {
              case 'completed':
                statusColor = Colors.green;
                statusIcon = Icons.check_circle_rounded;
                break;
              case 'pending':
                statusColor = Colors.orange;
                statusIcon = Icons.schedule_rounded;
                break;
              default:
                statusColor = Colors.red;
                statusIcon = Icons.error_rounded;
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(statusIcon, color: statusColor, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$storeName - $outletName',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          if (createdAt != null)
                            Text(
                              DateFormat('dd MMM yyyy HH:mm').format(createdAt),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                        ],
                      ),
                    ),
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
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                        Text(
                          status.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            color: statusColor,
                            fontWeight: FontWeight.w500,
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

  Future<List<Map<String, dynamic>>> _getAllPayments() async {
    try {
      final db = FirebaseFirestore.instance;
      final allPayments = <Map<String, dynamic>>[];
      final storesSnap = await db.collection('stores').get();

      for (final storeDoc in storesSnap.docs) {
        final storeName = storeDoc['nama_toko'] ?? 'Store';
        final outletsSnap = await db
            .collection('stores')
            .doc(storeDoc.id)
            .collection('outlets')
            .get();

        for (final outletDoc in outletsSnap.docs) {
          final outletName = outletDoc['nama_outlet'] ?? 'Outlet';
          final paymentsSnap = await db
              .collection('stores')
              .doc(storeDoc.id)
              .collection('outlets')
              .doc(outletDoc.id)
              .collection('payment_history')
              .orderBy('created_at', descending: true)
              .get();

          for (final paymentDoc in paymentsSnap.docs) {
            allPayments.add({
              'store_id': storeDoc.id,
              'outlet_id': outletDoc.id,
              'store_name': storeName,
              'outlet_name': outletName,
              ...paymentDoc.data(),
            });
          }
        }
      }

      allPayments.sort((a, b) {
        final dateA = DateTime.parse(a['created_at'] as String? ?? '');
        final dateB = DateTime.parse(b['created_at'] as String? ?? '');
        return dateB.compareTo(dateA);
      });

      return allPayments;
    } catch (e) {
      debugPrint('Error getting payments: $e');
      return [];
    }
  }
}

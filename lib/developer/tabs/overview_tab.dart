import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class OverviewTab extends StatelessWidget {
  const OverviewTab({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _getGlobalStats(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final stats = snapshot.data!;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatCard(
                context: context,
                title: 'Total Revenue',
                value: NumberFormat.currency(
                  locale: 'id_ID',
                  symbol: 'Rp ',
                  decimalDigits: 0,
                ).format(stats['total_revenue'] ?? 0),
                icon: Icons.trending_up,
                color: Colors.green,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildSmallStatCard(
                      title: 'Total Stores',
                      value: (stats['total_stores'] ?? 0).toString(),
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSmallStatCard(
                      title: 'Active Subscriptions',
                      value: (stats['active_subscriptions'] ?? 0).toString(),
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSmallStatCard(
                      title: 'Expired',
                      value: (stats['expired_subscriptions'] ?? 0).toString(),
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Monthly Revenue (Last 6 Months)',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).dividerColor.withOpacity(0.5),
                  ),
                ),
                child: SizedBox(
                  height: 200,
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: _getMonthlyRevenue(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final data = snapshot.data!;
                      // TODO: Implement chart using fl_chart
                      return Center(
                        child: Text('Chart: ${data.length} months data'),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Latest Transactions',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              _buildLatestTransactions(context),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard({
    required BuildContext context,
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.5),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallStatCard({
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 18,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLatestTransactions(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getLatestTransactions(limit: 5),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final transactions = snapshot.data!;

        if (transactions.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                'Tidak ada transaksi',
                style: TextStyle(color: Colors.grey.shade500),
              ),
            ),
          );
        }

        return Column(
          children: transactions.map((tx) {
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(
                  tx['status'] == 'completed'
                      ? Icons.check_circle
                      : Icons.schedule,
                  color: tx['status'] == 'completed'
                      ? Colors.green
                      : Colors.orange,
                ),
                title: Text('${tx['store_name']} - ${tx['outlet_name']}'),
                subtitle: Text(
                  DateFormat(
                    'dd MMM yyyy HH:mm',
                  ).format(DateTime.parse(tx['created_at'] as String)),
                ),
                trailing: Text(
                  NumberFormat.currency(
                    locale: 'id_ID',
                    symbol: 'Rp ',
                    decimalDigits: 0,
                  ).format(tx['amount'] ?? 0),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Future<Map<String, dynamic>> _getGlobalStats() async {
    try {
      final db = FirebaseFirestore.instance;
      final storesSnap = await db.collection('stores').get();
      final storeCount = storesSnap.size;

      int totalRevenue = 0;
      int activeSubCount = 0;
      int expiredSubCount = 0;
      int outletCount = 0;

      for (final storeDoc in storesSnap.docs) {
        final outletsSnap = await db
            .collection('stores')
            .doc(storeDoc.id)
            .collection('outlets')
            .get();

        outletCount += outletsSnap.size;

        for (final outletDoc in outletsSnap.docs) {
          final subSnap = await db
              .collection('stores')
              .doc(storeDoc.id)
              .collection('outlets')
              .doc(outletDoc.id)
              .collection('subscription')
              .doc('active')
              .get();

          if (subSnap.exists) {
            final status = subSnap.data()!['status'] ?? 'unknown';
            if (status == 'active') activeSubCount++;
            if (status == 'expired') expiredSubCount++;
          }
        }
      }

      final paymentsSnap = await db
          .collectionGroup('payment_history')
          .where('status', isEqualTo: 'completed')
          .get();

      for (final paymentDoc in paymentsSnap.docs) {
        totalRevenue += paymentDoc['amount'] as int? ?? 0;
      }

      return {
        'total_stores': storeCount,
        'total_outlets': outletCount,
        'total_revenue': totalRevenue,
        'active_subscriptions': activeSubCount,
        'expired_subscriptions': expiredSubCount,
      };
    } catch (e) {
      debugPrint('Error getting global stats: $e');
      return {};
    }
  }

  Future<List<Map<String, dynamic>>> _getMonthlyRevenue() async {
    try {
      final db = FirebaseFirestore.instance;
      final monthlyData = <String, int>{};

      final paymentsSnap = await db
          .collectionGroup('payment_history')
          .where('status', isEqualTo: 'completed')
          .get();

      for (final paymentDoc in paymentsSnap.docs) {
        final createdAt = paymentDoc['created_at'] != null
            ? (paymentDoc['created_at'] as Timestamp).toDate()
            : null;

        if (createdAt != null) {
          final monthKey = DateFormat('yyyy-MM').format(createdAt);
          monthlyData[monthKey] =
              (monthlyData[monthKey] ?? 0) +
              (paymentDoc['amount'] as int? ?? 0);
        }
      }

      return monthlyData.entries
          .map((e) => {'month': e.key, 'revenue': e.value})
          .toList();
    } catch (e) {
      return [];
    }
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

  Future<List<Map<String, dynamic>>> _getLatestTransactions({
    int limit = 5,
  }) async {
    try {
      return (await _getAllPayments()).take(limit).toList();
    } catch (e) {
      return [];
    }
  }
}

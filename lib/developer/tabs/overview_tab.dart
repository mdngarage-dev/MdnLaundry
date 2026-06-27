// ── overview_tab.dart ────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class OverviewTab extends StatelessWidget {
  const OverviewTab({super.key});

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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _getGlobalStats(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData) {
          return const Center(child: Text('Gagal load data'));
        }

        final stats = snapshot.data!;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Total Revenue ────────────────────────────────────────────
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

              // ── Stats Row ────────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: _buildSmallStatCard(
                      title: 'Stores',
                      value: (stats['total_stores'] ?? 0).toString(),
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildSmallStatCard(
                      title: 'Outlets',
                      value: (stats['total_outlets'] ?? 0).toString(),
                      color: Colors.purple,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildSmallStatCard(
                      title: 'Active',
                      value: (stats['active_subscriptions'] ?? 0).toString(),
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 8),
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

              // ── Monthly Revenue ──────────────────────────────────────────
              Text(
                'Revenue per Bulan (6 Bulan Terakhir)',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _getMonthlyRevenue(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final data = snapshot.data!;

                  if (data.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          'Belum ada data revenue',
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      ),
                    );
                  }

                  // ── Simple Bar Chart tanpa library ──────────────────────
                  final maxRevenue = data
                      .map((e) => e['revenue'] as int)
                      .reduce((a, b) => a > b ? a : b);

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).dividerColor.withOpacity(0.5),
                      ),
                    ),
                    child: Column(
                      children: [
                        SizedBox(
                          height: 160,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: data.map((item) {
                              final revenue = item['revenue'] as int;
                              final month = item['month'] as String;
                              final heightRatio = maxRevenue > 0
                                  ? revenue / maxRevenue
                                  : 0.0;
                              final monthLabel = month
                                  .split('-')
                                  .last; // ambil bulan saja

                              return Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Text(
                                        NumberFormat.compact(
                                          locale: 'id',
                                        ).format(revenue),
                                        style: const TextStyle(fontSize: 9),
                                      ),
                                      const SizedBox(height: 4),
                                      Container(
                                        height: 120 * heightRatio,
                                        decoration: BoxDecoration(
                                          color: Theme.of(
                                            context,
                                          ).primaryColor.withOpacity(0.7),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _monthName(monthLabel),
                                        style: const TextStyle(fontSize: 9),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),

              // ── Latest Transactions ──────────────────────────────────────
              Text(
                'Transaksi Terbaru',
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

  String _monthName(String monthNum) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    final idx = int.tryParse(monthNum);
    if (idx == null || idx < 1 || idx > 12) return monthNum;
    return months[idx - 1];
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
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
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
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
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
              fontWeight: FontWeight.w700,
              fontSize: 20,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
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
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final transactions = snapshot.data ?? [];

        if (transactions.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                'Belum ada transaksi',
                style: TextStyle(color: Colors.grey.shade500),
              ),
            ),
          );
        }

        return Column(
          children: transactions.map((tx) {
            // ── Fix: pakai 'settlement' bukan 'completed' ─────────────────
            final isSettled = tx['status'] == 'settlement';
            final createdAt = tx['created_at_date'] as DateTime?;

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isSettled
                      ? Colors.green.withOpacity(0.1)
                      : Colors.orange.withOpacity(0.1),
                  child: Icon(
                    isSettled
                        ? Icons.check_circle_rounded
                        : Icons.schedule_rounded,
                    color: isSettled ? Colors.green : Colors.orange,
                    size: 20,
                  ),
                ),
                title: Text(
                  '${tx['store_name']} • ${tx['outlet_name']}',
                  style: const TextStyle(fontSize: 13),
                ),
                subtitle: createdAt != null
                    ? Text(
                        DateFormat('dd MMM yyyy HH:mm').format(createdAt),
                        style: const TextStyle(fontSize: 11),
                      )
                    : null,
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      NumberFormat.currency(
                        locale: 'id_ID',
                        symbol: 'Rp ',
                        decimalDigits: 0,
                      ).format(tx['amount'] ?? 0),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: isSettled ? Colors.green : Colors.orange,
                      ),
                    ),
                    Text(
                      isSettled ? 'LUNAS' : 'PENDING',
                      style: TextStyle(
                        fontSize: 9,
                        color: isSettled ? Colors.green : Colors.orange,
                      ),
                    ),
                  ],
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

      int totalRevenue = 0;
      int activeSubCount = 0;
      int expiredSubCount = 0;
      int trialSubCount = 0;
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
            if (status == 'trial') trialSubCount++;
          }
        }
      }

      // ── Fix: pakai 'settlement' bukan 'completed' ─────────────────────
      final paymentsSnap = await db
          .collectionGroup('payment_history')
          .where('status', isEqualTo: 'settlement')
          .get();

      for (final paymentDoc in paymentsSnap.docs) {
        totalRevenue += paymentDoc['amount'] as int? ?? 0;
      }

      return {
        'total_stores': storesSnap.size,
        'total_outlets': outletCount,
        'total_revenue': totalRevenue,
        'active_subscriptions': activeSubCount,
        'expired_subscriptions': expiredSubCount,
        'trial_subscriptions': trialSubCount,
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

      // Ambil 6 bulan terakhir
      final sixMonthsAgo = DateTime.now().subtract(const Duration(days: 180));

      // ── Fix: pakai 'settlement' bukan 'completed' ─────────────────────
      final paymentsSnap = await db
          .collectionGroup('payment_history')
          .where('status', isEqualTo: 'settlement')
          .where(
            'created_at',
            isGreaterThanOrEqualTo: Timestamp.fromDate(sixMonthsAgo),
          )
          .get();

      for (final paymentDoc in paymentsSnap.docs) {
        final createdAt = _parseDate(paymentDoc['created_at']);
        if (createdAt != null) {
          final monthKey = DateFormat('yyyy-MM').format(createdAt);
          monthlyData[monthKey] =
              (monthlyData[monthKey] ?? 0) +
              (paymentDoc['amount'] as int? ?? 0);
        }
      }

      // Sort by month ascending
      final sorted = monthlyData.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));

      return sorted.map((e) => {'month': e.key, 'revenue': e.value}).toList();
    } catch (e) {
      debugPrint('Error getting monthly revenue: $e');
      return [];
    }
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
            final createdAtDate = _parseDate(data['created_at']);

            allPayments.add({
              'id': paymentDoc.id,
              'store_id': storeDoc.id,
              'outlet_id': outletDoc.id,
              'store_name': storeName,
              'outlet_name': outletName,
              ...data,
              'created_at_date': createdAtDate,
            });
          }
        }
      }

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

  Future<List<Map<String, dynamic>>> _getLatestTransactions({
    int limit = 5,
  }) async {
    return (await _getAllPayments()).take(limit).toList();
  }
}

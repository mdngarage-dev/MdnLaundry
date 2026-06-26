import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:mdnlaundry_project/components/theme.dart';
import 'package:mdnlaundry_project/services/subscription_service.dart';
import 'package:mdnlaundry_project/services/payment_service.dart';

class SubscriptionDashboard extends StatefulWidget {
  final String storeId;

  const SubscriptionDashboard({super.key, required this.storeId});

  @override
  State<SubscriptionDashboard> createState() => _SubscriptionDashboardState();
}

class _SubscriptionDashboardState extends State<SubscriptionDashboard> {
  @override
  Widget build(BuildContext context) {
    final appBarColor =
        Theme.of(context).appBarTheme.backgroundColor ?? kPrimary;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Subscription Management',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          backgroundColor: appBarColor,
          foregroundColor: Colors.white,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(56),
            child: Container(
              decoration: const BoxDecoration(color: Colors.transparent),
              child: TabBar(
                indicator: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                indicatorPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 6,
                ),
                dividerColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white60,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                labelPadding: const EdgeInsets.symmetric(vertical: 6),
                tabs: const [
                  Tab(
                    height: 48,
                    icon: Icon(Icons.store_outlined, size: 20),
                    text: 'Outlet',
                  ),
                  Tab(
                    height: 48,
                    icon: Icon(Icons.history_rounded, size: 20),
                    text: 'Revenue',
                  ),
                ],
              ),
            ),
          ),
        ),
        body: TabBarView(
          children: [
            // Tab 1: List Outlet + Subscription Status
            _buildOutletTab(),
            // Tab 2: Revenue Chart
            _buildRevenueTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildOutletTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: SubscriptionService.getAllOutletsSubscription(
        storeId: widget.storeId,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('Tidak ada outlet'));
        }

        final outlets = snapshot.data!;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: outlets.length,
          itemBuilder: (context, idx) {
            final outlet = outlets[idx];
            final outletName = outlet['outlet_name'] ?? 'Outlet';
            final outletId = outlet['outlet_id'] ?? '';
            final sub = outlet['subscription'] as Map<String, dynamic>;
            final status = sub['status'] ?? 'unknown';
            final plan = sub['plan'] ?? 'basic';
            final endDate = sub['subscription_end_date'] != null
                ? (sub['subscription_end_date'] as Timestamp).toDate()
                : null;

            Color statusColor;
            IconData statusIcon;

            switch (status) {
              case 'trial':
                statusColor = Colors.blue;
                statusIcon = Icons.schedule_rounded;
                break;
              case 'active':
                statusColor = Colors.green;
                statusIcon = Icons.check_circle_rounded;
                break;
              case 'expired':
                statusColor = Colors.red;
                statusIcon = Icons.error_rounded;
                break;
              default:
                statusColor = Colors.grey;
                statusIcon = Icons.help_outline_rounded;
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header ────────────────────────────────────────────
                    Row(
                      children: [
                        Icon(Icons.store_outlined),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                outletName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                outletId.substring(0, 8),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(statusIcon, size: 12, color: statusColor),
                              const SizedBox(width: 4),
                              Text(
                                status.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: statusColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 16),

                    // ── Info ──────────────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Paket',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              plan.toUpperCase(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        if (endDate != null)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Berakhir',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                DateFormat('dd MMM yyyy').format(endDate),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // ── Action Buttons ────────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () =>
                                _showExtendDialog(outletId, outletName),
                            child: const Text('Extend'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () =>
                                _showPaymentHistory(outletId, outletName),
                            child: const Text('History'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                            onPressed: () =>
                                _showCancelDialog(outletId, outletName),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(color: Colors.white),
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

  Widget _buildRevenueTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: SubscriptionService.getAllOutletsSubscription(
        storeId: widget.storeId,
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final outlets = snapshot.data!;
        num totalRevenue = 0;
        int activeCount = 0;
        int trialCount = 0;
        int expiredCount = 0;

        for (final outlet in outlets) {
          final sub = outlet['subscription'] as Map<String, dynamic>;
          final status = sub['status'] ?? 'unknown';
          final lastPayment = sub['last_payment_date'];

          if (status == 'active' && lastPayment != null) {
            totalRevenue += sub['amount'] ?? 0;
          }

          if (status == 'active') activeCount++;
          if (status == 'trial') trialCount++;
          if (status == 'expired') expiredCount++;
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Summary Cards ─────────────────────────────────────────
              _buildSummaryCard(
                title: 'Total Revenue',
                value: NumberFormat.currency(
                  locale: 'id_ID',
                  symbol: 'Rp ',
                  decimalDigits: 0,
                ).format(totalRevenue),
                icon: Icons.trending_up,
                color: Colors.green,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildSmallCard(
                      title: 'Active',
                      value: activeCount.toString(),
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSmallCard(
                      title: 'Trial',
                      value: trialCount.toString(),
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSmallCard(
                      title: 'Expired',
                      value: expiredCount.toString(),
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Payment History ──────────────────────────────────────
              Text(
                'Recent Payments',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              _buildRecentPayments(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryCard({
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

  Widget _buildSmallCard({
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
              fontSize: 16,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentPayments() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getAllPaymentHistory(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final payments = snapshot.data!;

        if (payments.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                'Belum ada payment',
                style: TextStyle(color: Colors.grey.shade500),
              ),
            ),
          );
        }

        return Column(
          children: payments.take(10).map((payment) {
            final createdAt = payment['created_at'] != null
                ? DateTime.parse(payment['created_at'] as String)
                : null;
            final status = payment['status'] ?? 'pending';

            Color statusColor;
            if (status == 'completed') {
              statusColor = Colors.green;
            } else if (status == 'pending') {
              statusColor = Colors.orange;
            } else {
              statusColor = Colors.red;
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    status == 'completed' ? Icons.check_circle : Icons.schedule,
                    color: statusColor,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          payment['package_id']?.toUpperCase() ?? 'Unknown',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
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
                  Text(
                    NumberFormat.currency(
                      locale: 'id_ID',
                      symbol: 'Rp ',
                      decimalDigits: 0,
                    ).format(payment['amount'] ?? 0),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _getAllPaymentHistory() async {
    try {
      final outletsSnap = await FirebaseFirestore.instance
          .collection('stores')
          .doc(widget.storeId)
          .collection('outlets')
          .get();

      final allPayments = <Map<String, dynamic>>[];

      for (final outletDoc in outletsSnap.docs) {
        final payments = await PaymentService.getPaymentHistory(
          storeId: widget.storeId,
          outletId: outletDoc.id,
        );
        allPayments.addAll(payments);
      }

      allPayments.sort((a, b) {
        final dateA = DateTime.parse(a['created_at'] as String? ?? '');
        final dateB = DateTime.parse(b['created_at'] as String? ?? '');
        return dateB.compareTo(dateA);
      });

      return allPayments;
    } catch (e) {
      return [];
    }
  }

  void _showExtendDialog(String outletId, String outletName) {
    final monthController = TextEditingController(text: '1');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Extend Subscription'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Extend subscription untuk $outletName',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: monthController,
              decoration: InputDecoration(
                labelText: 'Bulan',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                prefixIcon: const Icon(Icons.calendar_month),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              final months = int.tryParse(monthController.text) ?? 1;

              try {
                await SubscriptionService.extendSubscription(
                  storeId: widget.storeId,
                  outletId: outletId,
                  monthsToAdd: months,
                );

                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Subscription extended'),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  setState(() {});
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            child: const Text('Extend'),
          ),
        ],
      ),
    );
  }

  void _showPaymentHistory(String outletId, String outletName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Payment History - $outletName'),
        content: SizedBox(
          width: double.maxFinite,
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: PaymentService.getPaymentHistory(
              storeId: widget.storeId,
              outletId: outletId,
            ),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final history = snapshot.data!;

              return ListView.builder(
                itemCount: history.length,
                itemBuilder: (context, idx) {
                  final payment = history[idx];
                  final createdAt = payment['created_at'] != null
                      ? DateTime.parse(payment['created_at'] as String)
                      : null;

                  return ListTile(
                    leading: Icon(
                      payment['status'] == 'completed'
                          ? Icons.check_circle
                          : Icons.schedule,
                      color: payment['status'] == 'completed'
                          ? Colors.green
                          : Colors.orange,
                    ),
                    title: Text(payment['package_id']?.toUpperCase() ?? ''),
                    subtitle: createdAt != null
                        ? Text(DateFormat('dd MMM yyyy').format(createdAt))
                        : null,
                    trailing: Text(
                      NumberFormat.currency(
                        locale: 'id_ID',
                        symbol: 'Rp ',
                        decimalDigits: 0,
                      ).format(payment['amount'] ?? 0),
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showCancelDialog(String outletId, String outletName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cancel Subscription?'),
        content: Text(
          'Outlet $outletName akan di-lock. Anda harus extend subscription untuk membukanya kembali.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              try {
                await SubscriptionService.cancelSubscription(
                  storeId: widget.storeId,
                  outletId: outletId,
                );

                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Subscription cancelled'),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  setState(() {});
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            child: const Text('Cancel', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

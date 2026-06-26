import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../detail/store_owner_page.dart';
import '../detail/store_admins_page.dart';

class StoresTab extends StatelessWidget {
  const StoresTab({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getAllStoresWithStats(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final stores = snapshot.data!;

        if (stores.isEmpty) {
          return const Center(child: Text('Tidak ada store ditemukan.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: stores.length,
          itemBuilder: (context, idx) {
            final store = stores[idx];
            final storeName = store['nama_toko'] ?? 'Store';
            final totalRevenue = store['total_revenue'] ?? 0;
            final totalAdmin = store['total_admin'] ?? 0;
            final activeAdmin = store['active_admin'] ?? 0;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.store_rounded, color: Colors.blue),
                ),
                title: Text(storeName),
                subtitle: Row(
                  children: [
                    // Admin count
                    Icon(
                      Icons.people_outline,
                      size: 13,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '$totalAdmin admin',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Active admin badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: activeAdmin > 0
                            ? Colors.green.withOpacity(0.1)
                            : Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '$activeAdmin aktif',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: activeAdmin > 0
                              ? Colors.green.shade700
                              : Colors.grey.shade500,
                        ),
                      ),
                    ),
                  ],
                ),
                trailing: Text(
                  NumberFormat.currency(
                    locale: 'id_ID',
                    symbol: 'Rp ',
                    decimalDigits: 0,
                  ).format(totalRevenue),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                onTap: () => _showStoreDetail(context, store),
              ),
            );
          },
        );
      },
    );
  }

  void _showStoreDetail(BuildContext context, Map<String, dynamic> store) {
    final storeId = store['store_id'] ?? '';
    final storeName = store['nama_toko'] ?? 'Store';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          storeName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Info statis ──────────────────────────────────────────
            _buildDetailRow('Store ID', storeId),
            _buildDetailRow(
              'Total Revenue',
              NumberFormat.currency(
                locale: 'id_ID',
                symbol: 'Rp ',
                decimalDigits: 0,
              ).format(store['total_revenue'] ?? 0),
            ),
            const Divider(height: 20),

            // ── Owner — bisa diklik ───────────────────────────────────
            _buildTappableRow(
              context: ctx,
              icon: Icons.person_rounded,
              iconColor: Colors.blue,
              label: 'Owner',
              value: store['owner_name'] ?? 'Lihat detail →',
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        StoreOwnerPage(storeId: storeId, storeName: storeName),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),

            // ── Admin — bisa diklik ───────────────────────────────────
            _buildTappableRow(
              context: ctx,
              icon: Icons.people_rounded,
              iconColor: Colors.orange,
              label: 'Admin',
              value:
                  '${store['total_admin'] ?? 0} total • ${store['active_admin'] ?? 0} aktif',
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        StoreAdminsPage(storeId: storeId, storeName: storeName),
                  ),
                );
              },
            ),
          ],
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

  Widget _buildTappableRow({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: iconColor.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: iconColor,
              ),
            ),
            const Spacer(),
            Text(
              value,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 12,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _getAllStoresWithStats() async {
    try {
      final db = FirebaseFirestore.instance;
      final storesSnap = await db.collection('stores').get();
      final result = <Map<String, dynamic>>[];

      for (final storeDoc in storesSnap.docs) {
        final storeName = storeDoc.data()['nama_toko'] ?? 'Store';

        // ── Hitung outlet ─────────────────────────────────────────────
        final outletsSnap = await db
            .collection('stores')
            .doc(storeDoc.id)
            .collection('outlets')
            .get();

        int outletCount = outletsSnap.size;
        int totalRevenue = 0;

        for (final outletDoc in outletsSnap.docs) {
          final paymentsSnap = await db
              .collection('stores')
              .doc(storeDoc.id)
              .collection('outlets')
              .doc(outletDoc.id)
              .collection('payment_history')
              .where('status', isEqualTo: 'completed')
              .get();

          for (final paymentDoc in paymentsSnap.docs) {
            totalRevenue += paymentDoc['amount'] as int? ?? 0;
          }
        }

        // ── Hitung admin ──────────────────────────────────────────────
        final adminSnap = await db
            .collection('users')
            .where('store_id', isEqualTo: storeDoc.id)
            .where('role', isEqualTo: 'Admin')
            .get();

        final totalAdmin = adminSnap.size;
        final activeAdmin = adminSnap.docs
            .where((doc) => (doc.data()['is_activated'] ?? false) == true)
            .length;

        result.add({
          'store_id': storeDoc.id,
          'nama_toko': storeName,
          'outlet_count': outletCount,
          'total_admin': totalAdmin,
          'active_admin': activeAdmin,
          'total_revenue': totalRevenue,
        });
      }

      return result;
    } catch (e) {
      debugPrint('Error getting stores stats: $e');
      return [];
    }
  }
}

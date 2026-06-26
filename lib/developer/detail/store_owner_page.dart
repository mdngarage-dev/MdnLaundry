import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:mdnlaundry_project/components/theme.dart';

class StoreOwnerPage extends StatelessWidget {
  final String storeId;
  final String storeName;

  const StoreOwnerPage({
    super.key,
    required this.storeId,
    required this.storeName,
  });

  @override
  Widget build(BuildContext context) {
    final appBarColor =
        Theme.of(context).appBarTheme.backgroundColor ?? kPrimary;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Owner - $storeName',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
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
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _getOwnerData(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.data!.isEmpty) {
            return const Center(
              child: Text('Owner tidak ditemukan untuk store ini.'),
            );
          }

          final owner = snapshot.data!;
          final totalStore = owner['total_store'] ?? 0;
          final totalAdmin = owner['total_admin'] ?? 0;
          final createdAt = owner['created_at'] != null
              ? DateFormat(
                  'dd MMM yyyy',
                ).format((owner['created_at'] as Timestamp).toDate())
              : 'N/A';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // ── Avatar + Nama ──────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(context).dividerColor.withOpacity(0.4),
                    ),
                  ),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 36,
                        backgroundColor: appBarColor.withOpacity(0.15),
                        child: Text(
                          (owner['nama'] ?? 'O')[0].toUpperCase(),
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: appBarColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        owner['nama'] ?? 'N/A',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Owner',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Info Detail ────────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(context).dividerColor.withOpacity(0.4),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Informasi Akun',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildInfoRow(
                        Icons.email_outlined,
                        'Email',
                        owner['email'] ?? 'N/A',
                      ),
                      _buildInfoRow(
                        Icons.phone_outlined,
                        'No. HP',
                        owner['phone']?.toString().isNotEmpty == true
                            ? owner['phone']
                            : 'Tidak ada',
                      ),
                      _buildInfoRow(
                        Icons.badge_outlined,
                        'NIP',
                        owner['nip'] ?? 'N/A',
                      ),
                      _buildInfoRow(
                        Icons.calendar_today_outlined,
                        'Bergabung',
                        createdAt,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Stats ──────────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: _buildStatBox(
                        context: context,
                        icon: Icons.store_rounded,
                        label: 'Total Store',
                        value: totalStore.toString(),
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatBox(
                        context: context,
                        icon: Icons.people_rounded,
                        label: 'Total Admin',
                        value: totalAdmin.toString(),
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade500),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBox({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>> _getOwnerData() async {
    try {
      final db = FirebaseFirestore.instance;

      // Cari owner berdasarkan store_id
      final ownerSnap = await db
          .collection('users')
          .where('store_id', isEqualTo: storeId)
          .where('role', isEqualTo: 'Owner')
          .limit(1)
          .get();

      if (ownerSnap.docs.isEmpty) return {};

      final ownerData = ownerSnap.docs.first.data();
      final ownerUid = ownerSnap.docs.first.id;

      // Hitung total store milik owner ini (berdasarkan uid yang sama punya store lain)
      // Asumsi: owner bisa punya 1 store per dokumen, tapi bisa dicek dari stores collection
      final storesSnap = await db
          .collection('stores')
          .where('owner_id', isEqualTo: ownerUid)
          .get();
      final totalStore = storesSnap.size > 0 ? storesSnap.size : 1;

      // Hitung total admin di store ini
      final adminSnap = await db
          .collection('users')
          .where('store_id', isEqualTo: storeId)
          .where('role', isEqualTo: 'Admin')
          .get();

      return {
        ...ownerData,
        'total_store': totalStore,
        'total_admin': adminSnap.size,
      };
    } catch (e) {
      debugPrint('Error getting owner data: $e');
      return {};
    }
  }
}

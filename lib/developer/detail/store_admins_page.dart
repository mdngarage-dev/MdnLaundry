import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mdnlaundry_project/components/theme.dart';

class StoreAdminsPage extends StatelessWidget {
  final String storeId;
  final String storeName;

  const StoreAdminsPage({
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
          'Admin - $storeName',
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
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _getAdmins(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final admins = snapshot.data!;

          if (admins.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 64,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Belum ada admin di store ini',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ],
              ),
            );
          }

          final activeCount = admins
              .where((a) => a['is_activated'] == true)
              .length;

          return Column(
            children: [
              // ── Summary bar ──────────────────────────────────────────
              Container(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: appBarColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: appBarColor.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.people_rounded, color: appBarColor, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '${admins.length} total admin',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: appBarColor,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$activeCount aktif',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.green,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${admins.length - activeCount} pending',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── List Admin ────────────────────────────────────────────
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount: admins.length,
                  itemBuilder: (context, idx) {
                    final admin = admins[idx];
                    final nama = admin['nama'] ?? 'N/A';
                    final email = admin['email'] ?? '';
                    final isActivated = admin['is_activated'] ?? false;
                    final outletId =
                        admin['current_outlet_id']?.toString() ?? '';
                    final outletName =
                        admin['outlet_name']?.toString() ?? 'Belum assign';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            // Avatar
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: isActivated
                                  ? Colors.green.withOpacity(0.15)
                                  : Colors.orange.withOpacity(0.15),
                              child: Text(
                                nama[0].toUpperCase(),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isActivated
                                      ? Colors.green.shade700
                                      : Colors.orange.shade700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    nama,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    email,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.storefront_outlined,
                                        size: 12,
                                        color: Colors.grey.shade400,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        outletId.isNotEmpty
                                            ? outletName
                                            : 'Belum assign ke outlet',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // Status badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isActivated
                                    ? Colors.green.withOpacity(0.1)
                                    : Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isActivated ? 'Aktif' : 'Pending',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isActivated
                                      ? Colors.green.shade700
                                      : Colors.orange.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _getAdmins() async {
    try {
      final db = FirebaseFirestore.instance;

      final adminSnap = await db
          .collection('users')
          .where('store_id', isEqualTo: storeId)
          .where('role', isEqualTo: 'Admin')
          .get();

      final admins = <Map<String, dynamic>>[];

      for (final doc in adminSnap.docs) {
        final data = doc.data();
        final outletId = data['current_outlet_id']?.toString() ?? '';
        String outletName = 'Belum assign';

        // Fetch nama outlet kalau ada
        if (outletId.isNotEmpty) {
          try {
            final outletDoc = await db
                .collection('stores')
                .doc(storeId)
                .collection('outlets')
                .doc(outletId)
                .get();
            if (outletDoc.exists) {
              outletName = outletDoc['nama_outlet'] ?? 'Outlet';
            }
          } catch (_) {}
        }

        admins.add({...data, 'uid': doc.id, 'outlet_name': outletName});
      }

      // Sort: aktif dulu, baru pending
      admins.sort((a, b) {
        final aActive = a['is_activated'] == true ? 0 : 1;
        final bActive = b['is_activated'] == true ? 0 : 1;
        return aActive.compareTo(bActive);
      });

      return admins;
    } catch (e) {
      debugPrint('Error getting admins: $e');
      return [];
    }
  }
}

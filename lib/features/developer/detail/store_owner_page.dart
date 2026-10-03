import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:mdnlaundry_project/core/theme/theme.dart';
import 'package:mdnlaundry_project/features/developer/detail/store_outlets_page.dart';

class StoreOwnerPage extends StatefulWidget {
  final String storeId;
  final String storeName;

  const StoreOwnerPage({
    super.key,
    required this.storeId,
    required this.storeName,
  });

  @override
  State<StoreOwnerPage> createState() => _StoreOwnerPageState();
}

class _StoreOwnerPageState extends State<StoreOwnerPage> {
  Map<String, dynamic> _ownerData = {};
  bool _isLoading = true;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _loadOwner();
  }

  Future<void> _loadOwner() async {
    setState(() => _isLoading = true);
    final data = await _getOwnerData();
    if (mounted)
      setState(() {
        _ownerData = data;
        _isLoading = false;
      });
  }

  Future<Map<String, dynamic>> _getOwnerData() async {
    try {
      final db = FirebaseFirestore.instance;
      final ownerSnap = await db
          .collection('users')
          .where('store_id', isEqualTo: widget.storeId)
          .where('role', isEqualTo: 'Owner')
          .limit(1)
          .get();

      if (ownerSnap.docs.isEmpty) return {};

      final ownerData = ownerSnap.docs.first.data();
      final ownerUid = ownerSnap.docs.first.id;

      final storesSnap = await db
          .collection('stores')
          .where('owner_uid', isEqualTo: ownerUid)
          .get();
      final totalStore = storesSnap.size > 0 ? storesSnap.size : 1;

      final adminSnap = await db
          .collection('users')
          .where('store_id', isEqualTo: widget.storeId)
          .where('role', isEqualTo: 'Admin')
          .get();

      final outletSnap = await db
          .collection('stores')
          .doc(widget.storeId)
          .collection('outlets')
          .get();

      return {
        ...ownerData,
        'uid': ownerUid,
        'total_store': totalStore,
        'total_admin': adminSnap.size,
        'total_outlet': outletSnap.size,
      };
    } catch (e) {
      debugPrint('Error getting owner data: $e');
      return {};
    }
  }

  Future<void> _hapusSeluruhStore() async {
    final konfirmasi = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.warning_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text(
              'Hapus Seluruh Store?',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.withOpacity(0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '⚠️ Tindakan ini TIDAK BISA dibatalkan!',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.red.shade700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Yang akan dihapus:',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  _buildDeleteItem('Akun Owner'),
                  _buildDeleteItem('Semua akun Admin'),
                  _buildDeleteItem('Semua Outlet beserta data'),
                  _buildDeleteItem('Dokumen Store'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Hapus Semua',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (konfirmasi != true || !mounted) return;

    setState(() => _isDeleting = true);

    try {
      final callable = FirebaseFunctions.instanceFor(
        region: 'asia-southeast1',
      ).httpsCallable('deleteStore');

      await callable.call({'storeId': widget.storeId});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Store dan seluruh data (termasuk akun) berhasil dihapus',
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(
          context,
        ).popUntil((route) => route.isFirst || route.settings.name != null);
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        setState(() => _isDeleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal hapus store: ${e.message}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _buildDeleteItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        children: [
          const Icon(Icons.remove_circle_outline, size: 13, color: Colors.red),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appBarColor =
        Theme.of(context).appBarTheme.backgroundColor ?? kPrimary;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Owner - ${widget.storeName}',
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _ownerData.isEmpty
          ? const Center(child: Text('Owner tidak ditemukan untuk store ini.'))
          : _isDeleting
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.red),
                  SizedBox(height: 16),
                  Text(
                    'Menghapus seluruh data store...',
                    style: TextStyle(color: Colors.red),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // ── Avatar + Nama ────────────────────────────
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
                            (_ownerData['nama'] ?? 'O')[0].toUpperCase(),
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: appBarColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _ownerData['nama'] ?? 'N/A',
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

                  // ── Info Detail ──────────────────────────────
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
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 12),
                        _buildInfoRow(
                          Icons.email_outlined,
                          'Email',
                          _ownerData['email'] ?? 'N/A',
                        ),
                        _buildInfoRow(
                          Icons.phone_outlined,
                          'No. HP',
                          (_ownerData['phone']?.toString().isNotEmpty == true
                                  ? _ownerData['phone']
                                  : 'Tidak ada')
                              .toString(),
                        ),
                        _buildInfoRow(
                          Icons.badge_outlined,
                          'NIP',
                          _ownerData['nip'] ?? 'N/A',
                        ),
                        _buildInfoRow(
                          Icons.calendar_today_outlined,
                          'Bergabung',
                          _ownerData['created_at'] != null
                              ? DateFormat('dd MMM yyyy').format(
                                  (_ownerData['created_at'] as Timestamp)
                                      .toDate(),
                                )
                              : 'N/A',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Stats + Outlet ───────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatBox(
                          context: context,
                          icon: Icons.store_rounded,
                          label: 'Total Store',
                          value: (_ownerData['total_store'] ?? 0).toString(),
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatBox(
                          context: context,
                          icon: Icons.people_rounded,
                          label: 'Total Admin',
                          value: (_ownerData['total_admin'] ?? 0).toString(),
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => StoreOutletsPage(
                                storeId: widget.storeId,
                                storeName: widget.storeName,
                                ownerUid: _ownerData['uid'] ?? '',
                              ),
                            ),
                          ).then((_) => _loadOwner()), // refresh setelah balik
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.purple.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.purple.withOpacity(0.2),
                              ),
                            ),
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.storefront_rounded,
                                  color: Colors.purple,
                                  size: 28,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  (_ownerData['total_outlet'] ?? 0).toString(),
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.purple,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Outlet',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Kelola',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.purple,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      size: 9,
                                      color: Colors.purple,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── Tombol Hapus Store ───────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _hapusSeluruhStore,
                      icon: const Icon(
                        Icons.delete_forever_rounded,
                        color: Colors.red,
                      ),
                      label: const Text(
                        'Hapus Seluruh Store',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
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
}

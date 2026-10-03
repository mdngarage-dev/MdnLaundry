import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mdnlaundry_project/core/theme/theme.dart';

class StoreAdminsPage extends StatefulWidget {
  final String storeId;
  final String storeName;

  const StoreAdminsPage({
    super.key,
    required this.storeId,
    required this.storeName,
  });

  @override
  State<StoreAdminsPage> createState() => _StoreAdminsPageState();
}

class _StoreAdminsPageState extends State<StoreAdminsPage> {
  List<Map<String, dynamic>> _admins = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAdmins();
  }

  Future<void> _loadAdmins() async {
    setState(() => _isLoading = true);
    final admins = await _getAdmins();
    if (mounted)
      setState(() {
        _admins = admins;
        _isLoading = false;
      });
  }

  Future<List<Map<String, dynamic>>> _getAdmins() async {
    try {
      final db = FirebaseFirestore.instance;
      final adminSnap = await db
          .collection('users')
          .where('store_id', isEqualTo: widget.storeId)
          .where('role', isEqualTo: 'Admin')
          .get();

      final admins = <Map<String, dynamic>>[];
      for (final doc in adminSnap.docs) {
        final data = doc.data();
        final outletId = data['current_outlet_id']?.toString() ?? '';
        String outletName = 'Belum assign';
        if (outletId.isNotEmpty) {
          try {
            final outletDoc = await db
                .collection('stores')
                .doc(widget.storeId)
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

  // ── Hapus satu admin ────────────────────────────────────────────────
  Future<void> _hapusAdmin(Map<String, dynamic> admin) async {
    final uid = admin['uid'] ?? '';
    final nama = admin['nama'] ?? 'Admin ini';

    final konfirmasi = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Hapus Admin?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Kamu akan menghapus akun admin:'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person_rounded, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nama,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          admin['email'] ?? '',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Akun akan dihapus permanen (Firestore + login). Data transaksi tidak ikut terhapus.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
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
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (konfirmasi != true || !mounted) return;

    try {
      final callable = FirebaseFunctions.instanceFor(
        region: 'asia-southeast1',
      ).httpsCallable('deleteAdmin');

      await callable.call({'targetUid': uid});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Admin $nama berhasil dihapus permanen'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        await _loadAdmins();
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal hapus admin: ${e.message}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appBarColor =
        Theme.of(context).appBarTheme.backgroundColor ?? kPrimary;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Admin - ${widget.storeName}',
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
          : _admins.isEmpty
          ? Center(
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
            )
          : Column(
              children: [
                // ── Summary bar ──────────────────────────────────
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
                        '${_admins.length} total admin',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: appBarColor,
                        ),
                      ),
                      const Spacer(),
                      _buildBadge(
                        '${_admins.where((a) => a['is_activated'] == true).length} aktif',
                        Colors.green,
                      ),
                      const SizedBox(width: 8),
                      _buildBadge(
                        '${_admins.where((a) => a['is_activated'] != true).length} pending',
                        Colors.orange,
                      ),
                    ],
                  ),
                ),

                // ── List Admin ────────────────────────────────────
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: _admins.length,
                    itemBuilder: (context, idx) {
                      final admin = _admins[idx];
                      final nama = admin['nama'] ?? 'N/A';
                      final email = admin['email'] ?? '';
                      final isActivated = admin['is_activated'] ?? false;
                      final outletId =
                          admin['current_outlet_id']?.toString() ?? '';
                      final outletName = admin['outlet_name'] ?? 'Belum assign';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
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
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  _buildBadge(
                                    isActivated ? 'Aktif' : 'Pending',
                                    isActivated ? Colors.green : Colors.orange,
                                  ),
                                  const SizedBox(height: 8),
                                  // ── Tombol Hapus ──────────────
                                  GestureDetector(
                                    onTap: () => _hapusAdmin(admin),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.red.withOpacity(0.3),
                                        ),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.delete_outline,
                                            size: 13,
                                            color: Colors.red,
                                          ),
                                          SizedBox(width: 3),
                                          Text(
                                            'Hapus',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.red,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
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
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color is MaterialColor ? color.shade700 : color,
        ),
      ),
    );
  }
}

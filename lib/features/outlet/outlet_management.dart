import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OutletManagementScreen extends StatefulWidget {
  final String storeId;

  const OutletManagementScreen({super.key, required this.storeId});

  @override
  State<OutletManagementScreen> createState() => _OutletManagementScreenState();
}

class _OutletManagementScreenState extends State<OutletManagementScreen> {
  late CollectionReference<Map<String, dynamic>> outletsRef;
  bool _isAddingOutlet = false;

  final _namaController = TextEditingController();
  final _alamatController = TextEditingController();
  final _noHpController = TextEditingController();

  @override
  void initState() {
    super.initState();
    outletsRef = FirebaseFirestore.instance
        .collection('stores')
        .doc(widget.storeId)
        .collection('outlets');
  }

  @override
  void dispose() {
    _namaController.dispose();
    _alamatController.dispose();
    _noHpController.dispose();
    super.dispose();
  }

  Future<void> _tambahOutlet() async {
    if (_namaController.text.trim().isEmpty) {
      _showSnackBar('Nama outlet wajib diisi!', isError: true);
      return;
    }

    setState(() => _isAddingOutlet = true);
    try {
      await outletsRef.add({
        'nama_outlet': _namaController.text.trim(),
        'alamat': _alamatController.text.trim(),
        'no_hp': _noHpController.text.trim(),
        'logo_url': '',
        'is_utama': false,
        'created_at': FieldValue.serverTimestamp(),
      });

      _namaController.clear();
      _alamatController.clear();
      _noHpController.clear();

      if (mounted) {
        _showSnackBar('Outlet berhasil ditambah!', isError: false);
        Navigator.pop(context);
      }
    } catch (e) {
      _showSnackBar('Gagal tambah outlet: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isAddingOutlet = false);
    }
  }

  Future<void> _hapusOutlet(String outletId) async {
    // Cek apakah outlet ini masih ada admin yang menggunakannya
    final usersSnap = await FirebaseFirestore.instance
        .collection('users')
        .where('store_id', isEqualTo: widget.storeId)
        .where('allowed_outlets', arrayContains: outletId)
        .get();

    if (usersSnap.docs.isNotEmpty) {
      _showSnackBar(
        'Outlet ini masih digunakan admin. Pindahkan admin dulu sebelum hapus.',
        isError: true,
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Outlet?'),
        content: const Text(
          'Outlet dan semua datanya akan dihapus permanen. Tidak bisa dikembalikan.',
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

    if (confirm != true) return;

    try {
      // Hapus sub-collection dulu (layanan, settings, counters)
      await _deleteCollectionRecursive(
        outletsRef.doc(outletId).collection('layanan'),
      );
      await _deleteCollectionRecursive(
        outletsRef.doc(outletId).collection('settings'),
      );
      await _deleteCollectionRecursive(
        outletsRef.doc(outletId).collection('counters'),
      );

      // Hapus dokumen outlet
      await outletsRef.doc(outletId).delete();

      if (mounted) _showSnackBar('Outlet berhasil dihapus!', isError: false);
    } catch (e) {
      if (mounted) _showSnackBar('Gagal hapus outlet: $e', isError: true);
    }
  }

  Future<void> _deleteCollectionRecursive(
    CollectionReference collection,
  ) async {
    final snap = await collection.get();
    for (final doc in snap.docs) {
      await doc.reference.delete();
    }
  }

  void _showSnackBar(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Outlet'),
        centerTitle: true,
        elevation: 2,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: outletsRef.orderBy('is_utama', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Tidak ada outlet'));
          }

          final outlets = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: outlets.length,
            itemBuilder: (context, idx) {
              final outlet = outlets[idx];
              final data = outlet.data() as Map<String, dynamic>;
              final isUtama = data['is_utama'] ?? false;
              final namaOutlet = data['nama_outlet'] ?? 'Outlet';
              final alamat = data['alamat'] ?? '';

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isUtama
                          ? Colors.blue.withOpacity(0.2)
                          : Colors.grey.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.store_outlined,
                      color: isUtama ? Colors.blue : Colors.grey,
                    ),
                  ),
                  title: Text(
                    namaOutlet,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isUtama ? Colors.blue : null,
                    ),
                  ),
                  subtitle: Text(alamat),
                  trailing: isUtama
                      ? Chip(
                          label: const Text(
                            'Utama',
                            style: TextStyle(fontSize: 11),
                          ),
                          backgroundColor: Colors.blue.withOpacity(0.2),
                        )
                      : PopupMenuButton(
                          itemBuilder: (ctx) => [
                            PopupMenuItem(
                              onTap: () async {
                                // Edit outlet (bisa dikembang nanti)
                              },
                              child: const Text('Edit'),
                            ),
                            PopupMenuItem(
                              onTap: () => _hapusOutlet(outlet.id),
                              child: const Text(
                                'Hapus',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showTambahOutletDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showTambahOutletDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Tambah Outlet Baru'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _namaController,
                decoration: InputDecoration(
                  hintText: 'Nama Outlet',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _alamatController,
                decoration: InputDecoration(
                  hintText: 'Alamat',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                minLines: 2,
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _noHpController,
                decoration: InputDecoration(
                  hintText: 'No HP',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: _isAddingOutlet ? null : _tambahOutlet,
            child: _isAddingOutlet
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Tambah'),
          ),
        ],
      ),
    );
  }
}

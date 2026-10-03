import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OutletSelectorDialog extends StatefulWidget {
  final String storeId;
  final String currentOutletId;
  final Function(String outletId, String outletName) onOutletSelected;

  const OutletSelectorDialog({
    super.key,
    required this.storeId,
    required this.currentOutletId,
    required this.onOutletSelected,
  });

  @override
  State<OutletSelectorDialog> createState() => _OutletSelectorDialogState();
}

class _OutletSelectorDialogState extends State<OutletSelectorDialog> {
  late CollectionReference<Map<String, dynamic>> outletsRef;

  @override
  void initState() {
    super.initState();
    outletsRef = FirebaseFirestore.instance
        .collection('stores')
        .doc(widget.storeId)
        .collection('outlets');
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ────────────────────────────────────────────────────
            Row(
              children: [
                Icon(Icons.store_outlined, size: 28, color: Colors.blue),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Pilih Outlet',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── List Outlet ───────────────────────────────────────────────
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: outletsRef
                    .orderBy('is_utama', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('Tidak ada outlet'));
                  }

                  final outlets = snapshot.data!.docs;

                  return ListView.builder(
                    itemCount: outlets.length,
                    itemBuilder: (context, idx) {
                      final outlet = outlets[idx];
                      final data = outlet.data() as Map<String, dynamic>;
                      final outletId = outlet.id;
                      final namaOutlet = data['nama_outlet'] ?? 'Outlet';
                      final alamat = data['alamat'] ?? '';
                      final isUtama = data['is_utama'] ?? false;
                      final isActive = outletId == widget.currentOutletId;

                      return GestureDetector(
                        onTap: () {
                          widget.onOutletSelected(outletId, namaOutlet);
                          Navigator.pop(context);
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isActive
                                ? Colors.blue.withOpacity(0.1)
                                : Colors.grey.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isActive
                                  ? Colors.blue
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.store_outlined,
                                  color: Colors.blue,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            namaOutlet,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 15,
                                              color: isActive
                                                  ? Colors.blue
                                                  : Colors.black,
                                            ),
                                          ),
                                        ),
                                        if (isUtama)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.green.withOpacity(
                                                0.2,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: const Text(
                                              'Utama',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.green,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    if (alamat.isNotEmpty)
                                      Text(
                                        alamat,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (isActive)
                                const Icon(
                                  Icons.check_circle,
                                  color: Colors.blue,
                                  size: 24,
                                )
                              else if (!isUtama)
                                // ── Tombol Hapus (tidak ada di outlet utama) ────
                                GestureDetector(
                                  onTap: () => _showKonfirmasiHapusOutlet(
                                    outletId,
                                    namaOutlet,
                                  ),
                                  child: Icon(
                                    Icons.delete_outline_rounded,
                                    color: Colors.red.withOpacity(0.6),
                                    size: 20,
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
            ),
            const SizedBox(height: 16),

            // ── Tombol Tambah Outlet ────────────────────────────────────
            GestureDetector(
              onTap: () => _showTambahOutletDialog(),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 14,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_rounded, color: Colors.blue, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Tambah Outlet Baru',
                      style: TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── Tombol Batal ───────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Batal'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Dialog Konfirmasi Hapus Outlet ───────────────────────────────────────
  Future<void> _showKonfirmasiHapusOutlet(
    String outletId,
    String namaOutlet,
  ) async {
    // Cek ada admin di outlet ini tidak
    final adminsSnap = await FirebaseFirestore.instance
        .collection('users')
        .where('store_id', isEqualTo: widget.storeId)
        .where('allowed_outlets', arrayContains: outletId)
        .get();

    if (!mounted) return;

    final adminList = adminsSnap.docs;
    final adaAdmin = adminList.isNotEmpty;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Outlet?'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  style: Theme.of(context).textTheme.bodyMedium,
                  children: [
                    const TextSpan(text: 'Outlet '),
                    TextSpan(
                      text: namaOutlet,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const TextSpan(
                      text:
                          ' akan dihapus permanen.\n\nSemua layanan dan data outlet ini akan dihapus.',
                    ),
                  ],
                ),
              ),
              if (adaAdmin) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 14,
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Admin yang terdampak:',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ...adminList.map((doc) {
                        final namaAdmin = doc['nama'] ?? 'Admin';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '• $namaAdmin',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.orange,
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 6),
                      const Text(
                        'Admin akan kehilangan akses ke outlet ini dan harus diassign kembali oleh Owner.',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.orange,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await _hapusOutlet(outletId, namaOutlet, adminList);
            },
            child: const Text(
              'Ya, Hapus',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // ── Proses Hapus Outlet ──────────────────────────────────────────────────
  Future<void> _hapusOutlet(
    String outletId,
    String namaOutlet,
    List<QueryDocumentSnapshot> adminList,
  ) async {
    try {
      final batch = FirebaseFirestore.instance.batch();

      // 1. Hapus sub-collection outlet (layanan, settings, counters)
      final layananSnap = await outletsRef
          .doc(outletId)
          .collection('layanan')
          .get();
      for (final doc in layananSnap.docs) {
        batch.delete(doc.reference);
      }

      final settingsSnap = await outletsRef
          .doc(outletId)
          .collection('settings')
          .get();
      for (final doc in settingsSnap.docs) {
        batch.delete(doc.reference);
      }

      final countersSnap = await outletsRef
          .doc(outletId)
          .collection('counters')
          .get();
      for (final doc in countersSnap.docs) {
        batch.delete(doc.reference);
      }

      // 2. Hapus dokumen outlet
      batch.delete(outletsRef.doc(outletId));

      // 3. Update admin — hapus outletId dari allowed_outlets & current_outlet_id
      for (final adminDoc in adminList) {
        final adminUid = adminDoc.id;
        final allowedOutlets = List<String>.from(
          adminDoc['allowed_outlets'] ?? [],
        );
        final currentOutlet = adminDoc['current_outlet_id'];

        // Hapus outletId dari list
        allowedOutlets.remove(outletId);

        // Update user doc
        if (allowedOutlets.isEmpty) {
          // Jika admin tidak punya outlet lagi → deaktifasi
          batch.update(
            FirebaseFirestore.instance.collection('users').doc(adminUid),
            {
              'allowed_outlets': [],
              'current_outlet_id': '',
              'is_activated': false,
            },
          );
        } else {
          // Ada outlet lain → set current_outlet_id ke outlet pertama di list
          batch.update(
            FirebaseFirestore.instance.collection('users').doc(adminUid),
            {
              'allowed_outlets': allowedOutlets,
              'current_outlet_id': allowedOutlets.first,
            },
          );
        }

        // Hapus permission admin di outlet ini
        final permRef = FirebaseFirestore.instance
            .collection('store_permissions')
            .doc(widget.storeId)
            .collection(outletId)
            .doc(adminUid);

        batch.delete(permRef);
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Outlet $namaOutlet berhasil dihapus'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal hapus outlet: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ── Dialog Tambah Outlet ─────────────────────────────────────────────────
  void _showTambahOutletDialog() {
    final namaController = TextEditingController();
    final alamatController = TextEditingController();
    final noHpController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text('Tambah Outlet Baru'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: namaController,
                    decoration: InputDecoration(
                      hintText: 'Nama Outlet',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      prefixIcon: const Icon(Icons.store_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: alamatController,
                    decoration: InputDecoration(
                      hintText: 'Alamat',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      prefixIcon: const Icon(Icons.location_on_outlined),
                    ),
                    minLines: 2,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noHpController,
                    decoration: InputDecoration(
                      hintText: 'No HP',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      prefixIcon: const Icon(Icons.phone_outlined),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(ctx),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        if (namaController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Nama outlet wajib diisi!'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        setStateDialog(() => isLoading = true);

                        try {
                          final docRef = await outletsRef.add({
                            'nama_outlet': namaController.text.trim(),
                            'alamat': alamatController.text.trim(),
                            'no_hp': noHpController.text.trim(),
                            'logo_url': '',
                            'is_utama': false,
                            'created_at': FieldValue.serverTimestamp(),
                          });

                          if (mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Outlet berhasil ditambah!'),
                                backgroundColor: Colors.green,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );

                            // Auto-select outlet yang baru dibuat
                            final newOutletName = namaController.text.trim();
                            Future.delayed(
                              const Duration(milliseconds: 500),
                              () {
                                widget.onOutletSelected(
                                  docRef.id,
                                  newOutletName,
                                );
                                Navigator.pop(context);
                              },
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Gagal tambah outlet: $e'),
                                backgroundColor: Colors.redAccent,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        } finally {
                          if (mounted) setStateDialog(() => isLoading = false);
                        }
                      },
                child: isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Tambah'),
              ),
            ],
          );
        },
      ),
    );
  }
}

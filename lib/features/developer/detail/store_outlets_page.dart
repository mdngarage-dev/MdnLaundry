import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mdnlaundry_project/core/theme/theme.dart';

class StoreOutletsPage extends StatefulWidget {
  final String storeId;
  final String storeName;
  final String ownerUid;

  const StoreOutletsPage({
    super.key,
    required this.storeId,
    required this.storeName,
    required this.ownerUid,
  });

  @override
  State<StoreOutletsPage> createState() => _StoreOutletsPageState();
}

class _StoreOutletsPageState extends State<StoreOutletsPage> {
  List<Map<String, dynamic>> _outlets = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOutlets();
  }

  Future<void> _loadOutlets() async {
    setState(() => _isLoading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('stores')
          .doc(widget.storeId)
          .collection('outlets')
          .get();

      final outlets = snap.docs
          .map((doc) => {...doc.data(), 'id': doc.id})
          .toList();
      outlets.sort((a, b) {
        final aUtama = a['is_utama'] == true ? 0 : 1;
        final bUtama = b['is_utama'] == true ? 0 : 1;
        return aUtama.compareTo(bUtama);
      });

      if (mounted)
        setState(() {
          _outlets = outlets;
          _isLoading = false;
        });
    } catch (e) {
      debugPrint('Error loading outlets: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _hapusOutlet(Map<String, dynamic> outlet) async {
    final outletId = outlet['id'] ?? '';
    final outletName = outlet['nama_outlet'] ?? 'Outlet ini';
    final isUtama = outlet['is_utama'] == true;
    final isLastOutlet = _outlets.length == 1;

    if (isLastOutlet) {
      await _tawarHapusStore(outletName);
      return;
    }

    if (isUtama) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Outlet utama tidak bisa dihapus selama masih ada outlet lain.',
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final konfirmasi = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Hapus Outlet?',
          style: TextStyle(fontWeight: FontWeight.bold),
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
                border: Border.all(color: Colors.red.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.storefront_outlined,
                        color: Colors.red,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        outletName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  if ((outlet['alamat'] ?? '').isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      outlet['alamat'],
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Semua data outlet akan dihapus permanen.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 6),
            Text(
              'Admin yang terhubung outlet ini akan dilepas.',
              style: TextStyle(fontSize: 12, color: Colors.orange.shade700),
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
              'Hapus Outlet',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (konfirmasi != true || !mounted) return;

    if (konfirmasi != true || !mounted) return;

    try {
      final callable = FirebaseFunctions.instanceFor(
        region: 'asia-southeast1',
      ).httpsCallable('deleteOutlet');

      await callable.call({'storeId': widget.storeId, 'outletId': outletId});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Outlet $outletName beserta seluruh datanya berhasil dihapus',
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        await _loadOutlets();
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal hapus outlet: ${e.message}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _tawarHapusStore(String outletName) async {
    final konfirmasi = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.warning_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text(
              'Outlet Terakhir!',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.red.withOpacity(0.2)),
          ),
          child: Text(
            '"$outletName" adalah satu-satunya outlet yang tersisa.\n\nMenghapusnya berarti menghapus SELURUH store beserta akun owner dan admin.',
            style: const TextStyle(fontSize: 13),
          ),
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
              'Hapus Seluruh Store',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (konfirmasi != true || !mounted) return;

    // Tampilkan loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.red),
                  SizedBox(height: 16),
                  Text('Menghapus seluruh data...'),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    try {
      final callable = FirebaseFunctions.instanceFor(
        region: 'asia-southeast1',
      ).httpsCallable('deleteStore');

      await callable.call({'storeId': widget.storeId});

      if (mounted) {
        Navigator.of(context).pop(); // tutup loading
        Navigator.of(context).pop(); // outlets page
        Navigator.of(context).pop(); // owner page
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Seluruh store berhasil dihapus'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // tutup loading
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

  @override
  Widget build(BuildContext context) {
    final appBarColor =
        Theme.of(context).appBarTheme.backgroundColor ?? kPrimary;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Outlet - ${widget.storeName}',
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
          : _outlets.isEmpty
          ? const Center(child: Text('Tidak ada outlet ditemukan.'))
          : Column(
              children: [
                if (_outlets.length == 1)
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: Colors.orange,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Hanya ada 1 outlet. Menghapusnya akan menghapus seluruh store.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _outlets.length,
                    itemBuilder: (context, idx) {
                      final outlet = _outlets[idx];
                      final nama = outlet['nama_outlet'] ?? 'Outlet';
                      final alamat = outlet['alamat'] ?? '';
                      final isUtama = outlet['is_utama'] == true;
                      final noHp = outlet['no_hp'] ?? '';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: isUtama
                                      ? Colors.blue.withOpacity(0.12)
                                      : Colors.grey.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.storefront_rounded,
                                  color: isUtama ? Colors.blue : Colors.grey,
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
                                        Text(
                                          nama,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                        if (isUtama) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.blue.withOpacity(
                                                0.1,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: const Text(
                                              'Utama',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.blue,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    if (alamat.isNotEmpty) ...[
                                      const SizedBox(height: 3),
                                      Text(
                                        alamat,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade500,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                    if (noHp.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        noHp,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade400,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              GestureDetector(
                                onTap: () => _hapusOutlet(outlet),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 6,
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
                                        size: 14,
                                        color: Colors.red,
                                      ),
                                      SizedBox(width: 3),
                                      Text(
                                        'Hapus',
                                        style: TextStyle(
                                          fontSize: 12,
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
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

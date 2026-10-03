import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mdnlaundry_project/core/app_exports.dart';

// ════════════════════════════════════════════════════════════════════════════
//  DIALOG: Pilih Rak
// ════════════════════════════════════════════════════════════════════════════
class PilihRakDialog extends StatefulWidget {
  final String storeId;
  final String outletId;

  final void Function(String rakId, String rakNama) onRakSelected;

  const PilihRakDialog({
    required this.storeId,
    required this.outletId,
    required this.onRakSelected,
  });

  @override
  State<PilihRakDialog> createState() => PilihRakDialogState();
}

class PilihRakDialogState extends State<PilihRakDialog> {
  List<Map<String, dynamic>> _rakList = [];
  bool _isLoading = true;
  final _namaRakCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadRak();
  }

  @override
  void dispose() {
    _namaRakCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRak() async {
    setState(() => _isLoading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('rak')
          .where('store_id', isEqualTo: widget.storeId)
          .where('outlet_id', isEqualTo: widget.outletId)
          .orderBy('urutan')
          .get();
      setState(() {
        _rakList = snap.docs.map((d) {
          return {'id': d.id, ...d.data()};
        }).toList();
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _tambahRak(String nama) async {
    if (nama.trim().isEmpty) return;
    // Hitung urutan hanya dari rak milik outlet ini (bukan semua toko).
    final snap = await FirebaseFirestore.instance
        .collection('rak')
        .where('store_id', isEqualTo: widget.storeId)
        .where('outlet_id', isEqualTo: widget.outletId)
        .get();
    await FirebaseFirestore.instance.collection('rak').add({
      'nama': nama.trim(),
      'urutan': snap.docs.length + 1,
      'store_id': widget.storeId,
      'outlet_id': widget.outletId,
    });
    _namaRakCtrl.clear();
    await _loadRak();
  }

  Future<void> _hapusRak(String rakId) async {
    final db = FirebaseFirestore.instance;
    // Lepaskan rak dari order yang masih memakainya (sama seperti di
    // Monitoring Rak) supaya tidak ada order yang menunjuk rak yang sudah hilang.
    final orders = await db
        .collection('order')
        .where('store_id', isEqualTo: widget.storeId)
        .where('outlet_id', isEqualTo: widget.outletId)
        .where('rak_id', isEqualTo: rakId)
        .get();
    final batch = db.batch();
    for (final o in orders.docs) {
      batch.update(o.reference, {
        'rak_id': FieldValue.delete(),
        'rak_nama': FieldValue.delete(),
        'waktu_masuk_rak': FieldValue.delete(),
      });
    }
    batch.delete(db.collection('rak').doc(rakId));
    await batch.commit();
    await _loadRak();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Dialog(
      backgroundColor: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ─────────────────────────────────────────────────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D9488).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.inventory_2_outlined,
                    color: Color(0xFF0D9488),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pilih Rak',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'Pesanan selesai, masukkan ke rak',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // ── Daftar rak ─────────────────────────────────────────────────
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_rakList.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Belum ada rak. Tambahkan dulu di bawah.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade400),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 240),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _rakList.length,
                  itemBuilder: (ctx, i) {
                    final rak = _rakList[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () =>
                                  widget.onRakSelected(rak['id'], rak['nama']),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF0D9488,
                                  ).withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(
                                      0xFF0D9488,
                                    ).withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.shelves,
                                      color: Color(0xFF0D9488),
                                      size: 18,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      rak['nama']?.toString() ?? '-',
                                      style: const TextStyle(
                                        color: Color(0xFF0D9488),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => _hapusRak(rak['id']),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                                size: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // ── Tambah rak baru ─────────────────────────────────────────────
            Text(
              'Tambah Rak Baru',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _namaRakCtrl,
                    decoration: InputDecoration(
                      hintText: 'Nama rak, contoh: Rak 3',
                      hintStyle: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 13,
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      filled: true,
                      fillColor: Theme.of(context).scaffoldBackgroundColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: primary, width: 1.5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _tambahRak(_namaRakCtrl.text),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Tambah',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Batal',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

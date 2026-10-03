import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mdnlaundry_project/core/app_exports.dart';

// ════════════════════════════════════════════════════════════════════════════
// BOTTOM SHEET: Pilih Layanan — tidak berubah, tetap sama
// ════════════════════════════════════════════════════════════════════════════
class AddLayananPickerSheet extends StatefulWidget {
  final String storeId;
  final String outletId;
  final void Function(Layanan) onSelected;

  const AddLayananPickerSheet({
    required this.storeId,
    required this.outletId,
    required this.onSelected,
  });

  @override
  State<AddLayananPickerSheet> createState() => AddLayananPickerSheetState();
}

class AddLayananPickerSheetState extends State<AddLayananPickerSheet> {
  String _filterTipe = 'semua';
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  List<Layanan> _layananList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLayanan();
  }

  Future<void> _loadLayanan() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('stores')
          .doc(widget.storeId)
          .collection('outlets')
          .doc(widget.outletId)
          .collection('layanan')
          .orderBy('nama')
          .get();
      if (mounted) {
        setState(() {
          _layananList = snap.docs
              .map((d) => Layanan.fromFirestore(d))
              .toList();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showTambahLayananPopup() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => LayananFormSheet(
        existing: null,
        onSave: (nama, tipe, harga, durasiJam) async {
          await FirebaseFirestore.instance
              .collection('stores')
              .doc(widget.storeId)
              .collection('outlets')
              .doc(widget.outletId)
              .collection('layanan')
              .add({
                'nama': nama,
                'tipe': tipe,
                'harga': harga,
                'durasi_jam': durasiJam,
              });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Layanan "$nama" berhasil ditambahkan'),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          }
        },
      ),
    );
    await _loadLayanan();
  }

  Color _tipeColor(String tipe) {
    switch (tipe) {
      case 'kiloan':
        return Colors.blue;
      case 'satuan':
        return Colors.green;
      case 'meter':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _tipeIcon(String tipe) {
    switch (tipe) {
      case 'kiloan':
        return Icons.scale_outlined;
      case 'satuan':
        return Icons.tag_outlined;
      case 'meter':
        return Icons.straighten_outlined;
      default:
        return Icons.local_laundry_service_outlined;
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final filtered = _layananList.where((l) {
      final matchTipe = _filterTipe == 'semua' || l.tipe == _filterTipe;
      final matchSearch =
          _searchQuery.isEmpty ||
          l.nama.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchTipe && matchSearch;
    }).toList();

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Pilih Layanan',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchCtrl,
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: InputDecoration(
              hintText: 'Cari layanan...',
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: Colors.grey.shade400,
                size: 20,
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? GestureDetector(
                      onTap: () => setState(() {
                        _searchCtrl.clear();
                        _searchQuery = '';
                      }),
                      child: Icon(
                        Icons.close_rounded,
                        color: Colors.grey.shade400,
                        size: 18,
                      ),
                    )
                  : null,
              filled: true,
              fillColor: Theme.of(context).cardColor,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 10,
                horizontal: 16,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: primary, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _chip(context, 'Semua', 'semua', primary),
                const SizedBox(width: 8),
                _chip(context, 'Kiloan', 'kiloan', Colors.blue),
                const SizedBox(width: 8),
                _chip(context, 'Satuan', 'satuan', Colors.green),
                const SizedBox(width: 8),
                _chip(context, 'Meter', 'meter', Colors.orange),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.search_off_rounded,
                      size: 40,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _searchQuery.isNotEmpty
                          ? 'Layanan "$_searchQuery" tidak ditemukan'
                          : 'Belum ada layanan',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FutureBuilder<bool>(
                      future: canAccess('can_access_layanan'),
                      builder: (context, snapshot) {
                        if (!(snapshot.data ?? false))
                          return const SizedBox.shrink();
                        return ElevatedButton.icon(
                          onPressed: _showTambahLayananPopup,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.add),
                          label: const Text(
                            'Tambah Layanan',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.45,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: filtered.length,
                itemBuilder: (ctx, i) {
                  final l = filtered[i];
                  final color = _tipeColor(l.tipe);
                  final satuan = l.tipe == 'kiloan'
                      ? 'kg'
                      : l.tipe == 'meter'
                      ? 'm²'
                      : 'pcs';
                  return GestureDetector(
                    onTap: () => widget.onSelected(l),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: color.withOpacity(0.25)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              _tipeIcon(l.tipe),
                              color: color,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l.nama,
                                  style: Theme.of(context).textTheme.bodyLarge
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  'Rp ${NumberFormat('#,###', 'id_ID').format(l.harga.round())} / $satuan  •  ${_durasiLabel(l.durasiJam)}',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodySmall?.copyWith(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: Colors.grey.shade400,
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

  Widget _chip(BuildContext context, String label, String value, Color color) {
    final selected = _filterTipe == value;
    return GestureDetector(
      onTap: () => setState(() => _filterTipe = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color : color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color : color.withOpacity(0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : color,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  String _durasiLabel(int jam) {
    if (jam >= 24 && jam % 24 == 0) return '${jam ~/ 24} Hari';
    return '$jam Jam';
  }
}

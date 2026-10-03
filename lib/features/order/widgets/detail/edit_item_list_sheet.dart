import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mdnlaundry_project/core/app_exports.dart';
import 'package:mdnlaundry_project/core/utils/format_utils.dart';
import 'package:mdnlaundry_project/features/order/widgets/detail/layanan_picker_sheet.dart';

// ════════════════════════════════════════════════════════════════════════════
//  BOTTOM SHEET: Edit Item Pesanan (dengan Ganti Layanan)
// ════════════════════════════════════════════════════════════════════════════
class EditItemListSheet extends StatefulWidget {
  final String storeId;
  final String outletId;
  final List<Map<String, dynamic>> items;
  final void Function(List<Map<String, dynamic>>) onSave;

  const EditItemListSheet({
    required this.storeId,
    required this.outletId,
    required this.items,
    required this.onSave,
  });

  @override
  State<EditItemListSheet> createState() => EditItemListSheetState();
}

class EditItemListSheetState extends State<EditItemListSheet> {
  late List<Map<String, dynamic>> _editedItems;
  late List<TextEditingController> _beratControllers;
  late List<TextEditingController> _hargaControllers;
  late List<TextEditingController> _catatanControllers;
  bool _loadingLayanan = false;

  @override
  void initState() {
    super.initState();
    _initFromItems(widget.items);
  }

  void _initFromItems(List<Map<String, dynamic>> items) {
    _editedItems = items.map((e) => Map<String, dynamic>.from(e)).toList();
    _beratControllers = _editedItems.map((item) {
      final berat = item['berat_kg'];
      return TextEditingController(
        text: berat != null
            ? (berat is double && berat % 1 == 0
                  ? berat.toInt().toString()
                  : berat.toString())
            : '1',
      );
    }).toList();
    _hargaControllers = _editedItems.map((item) {
      final harga = item['harga_satuan'];
      final hargaInt = harga is num
          ? harga.round()
          : int.tryParse(harga?.toString() ?? '0') ?? 0;
      return TextEditingController(text: hargaInt.toString());
    }).toList();
    _catatanControllers = _editedItems.map((item) {
      return TextEditingController(text: item['catatan']?.toString() ?? '');
    }).toList();
  }

  @override
  void dispose() {
    for (final c in _beratControllers) c.dispose();
    for (final c in _hargaControllers) c.dispose();
    for (final c in _catatanControllers) c.dispose();
    super.dispose();
  }

  String _satuanLabel(String tipe) {
    switch (tipe) {
      case 'kiloan':
        return 'kg';
      case 'meter':
        return 'm²';
      default:
        return 'pcs';
    }
  }

  int _hitungSubtotal(int idx) {
    try {
      final berat = double.parse(_beratControllers[idx].text);
      final harga = double.parse(
        _hargaControllers[idx].text,
      ); // ← double, bukan int
      return (berat * harga).toInt();
    } catch (_) {
      return 0;
    }
  }

  Future<void> _bukaGantiLayanan(int idx) async {
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DetailLayananPickerSheet(
        storeId: widget.storeId,
        outletId: widget.outletId,
        onSelected: (layanan) {
          Navigator.pop(ctx);
          _hargaControllers[idx].dispose();
          _hargaControllers[idx] = TextEditingController(
            text: layanan.harga.round().toString(),
          );
          setState(() {
            _editedItems[idx] = {
              ..._editedItems[idx],
              'layanan_nama': layanan.nama,
              'layanan_tipe': layanan.tipe,
              'layanan_id': layanan.id,
              'harga_satuan': layanan.harga.round(),
            };
          });
        },
      ),
    );
  }

  void _simpan() {
    for (int i = 0; i < _editedItems.length; i++) {
      _editedItems[i]['berat_kg'] =
          double.tryParse(_beratControllers[i].text) ??
          _editedItems[i]['berat_kg'];
      _editedItems[i]['harga_satuan'] =
          int.tryParse(
            _hargaControllers[i].text,
          ) ?? // sekarang aman, teksnya sudah bulat
          _editedItems[i]['harga_satuan'];
      _editedItems[i]['catatan'] = _catatanControllers[i].text.trim();
    }
    widget.onSave(_editedItems);
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
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
              'Edit Item Pesanan',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Ubah layanan, berat/jumlah, harga, atau catatan',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),

            // List item editor
            ...List.generate(_editedItems.length, (i) {
              final item = _editedItems[i];
              final tipe = item['layanan_tipe']?.toString() ?? '';
              final satuan = _satuanLabel(tipe);
              final namaLayanan = item['layanan_nama']?.toString() ?? '-';

              return StatefulBuilder(
                builder: (ctx, setS) {
                  final subtotal = _hitungSubtotal(i);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Header item ──────────────────────────────────
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: primary.withOpacity(0.10),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${i + 1}',
                                style: TextStyle(
                                  color: primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    namaLayanan,
                                    style: Theme.of(context).textTheme.bodyLarge
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                  ),
                                  const SizedBox(height: 2),
                                  // ── Tombol Ganti Layanan ──────────────
                                  GestureDetector(
                                    onTap: _loadingLayanan
                                        ? null
                                        : () async {
                                            await _bukaGantiLayanan(i);
                                            setS(() {});
                                          },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.withOpacity(0.10),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.orange.withOpacity(
                                            0.35,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _loadingLayanan
                                              ? const SizedBox(
                                                  width: 10,
                                                  height: 10,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 1.5,
                                                        color: Colors.orange,
                                                      ),
                                                )
                                              : Icon(
                                                  Icons.swap_horiz_rounded,
                                                  size: 11,
                                                  color: Colors.orange.shade700,
                                                ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Ganti Layanan',
                                            style: TextStyle(
                                              color: Colors.orange.shade700,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              formatRupiah(subtotal),
                              style: TextStyle(
                                color: primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Divider(
                          height: 1,
                          color: Theme.of(
                            context,
                          ).dividerColor.withOpacity(0.4),
                        ),
                        const SizedBox(height: 12),

                        // ── Berat & Harga ────────────────────────────────
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Jumlah ($satuan)',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(fontSize: 11),
                                  ),
                                  const SizedBox(height: 4),
                                  TextField(
                                    controller: _beratControllers[i],
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(
                                        RegExp(r'^\d+\.?\d{0,2}'),
                                      ),
                                    ],
                                    onChanged: (_) => setS(() {}),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    decoration: InputDecoration(
                                      suffixText: satuan,
                                      isDense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 10,
                                          ),
                                      filled: true,
                                      fillColor: Theme.of(
                                        context,
                                      ).scaffoldBackgroundColor,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide(
                                          color: Colors.grey.shade200,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide(
                                          color: Colors.grey.shade200,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide(
                                          color: primary,
                                          width: 1.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Harga / $satuan',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(fontSize: 11),
                                  ),
                                  const SizedBox(height: 4),
                                  TextField(
                                    controller: _hargaControllers[i],
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    onChanged: (_) => setS(() {}),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    decoration: InputDecoration(
                                      prefixText: 'Rp ',
                                      isDense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 10,
                                          ),
                                      filled: true,
                                      fillColor: Theme.of(
                                        context,
                                      ).scaffoldBackgroundColor,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide(
                                          color: Colors.grey.shade200,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide(
                                          color: Colors.grey.shade200,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide(
                                          color: primary,
                                          width: 1.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // ── Catatan ──────────────────────────────────────
                        Text(
                          'Catatan',
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(fontSize: 11),
                        ),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _catatanControllers[i],
                          maxLines: 2,
                          style: const TextStyle(fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Kosongkan jika tidak ada',
                            hintStyle: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 12,
                            ),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 10,
                            ),
                            filled: true,
                            fillColor: Theme.of(
                              context,
                            ).scaffoldBackgroundColor,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: Colors.grey.shade200,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: Colors.grey.shade200,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: primary,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            }),

            const SizedBox(height: 8),

            // ── Tombol Simpan ────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _simpan,
                icon: const Icon(Icons.save_outlined, size: 18),
                label: const Text(
                  'Simpan Perubahan',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      Theme.of(context).appBarTheme.backgroundColor ?? kPrimary,
                  foregroundColor:
                      Theme.of(context).appBarTheme.foregroundColor ??
                      Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

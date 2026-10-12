import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mdnlaundry_project/core/app_exports.dart';
import 'package:mdnlaundry_project/core/utils/format_utils.dart';

// ════════════════════════════════════════════════════════════════════════════
//  BOTTOM SHEET: Tambah / Edit Biaya Tambahan (halaman Detail Order)
//  Data yang dihasilkan sama dengan di halaman Tambah Order:
//  { keterangan, nominal, qty }
// ════════════════════════════════════════════════════════════════════════════
class BiayaTambahanSheet extends StatefulWidget {
  /// null = tambah baru, terisi = edit biaya yang sudah ada.
  final Map<String, dynamic>? existing;

  final Future<void> Function(String keterangan, int nominal, int qty) onSave;

  /// Hanya dipakai saat edit. Bila null, tombol hapus tidak ditampilkan.
  final Future<void> Function()? onDelete;

  const BiayaTambahanSheet({
    this.existing,
    required this.onSave,
    this.onDelete,
  });

  @override
  State<BiayaTambahanSheet> createState() => BiayaTambahanSheetState();
}

class BiayaTambahanSheetState extends State<BiayaTambahanSheet> {
  final _keteranganCtrl = TextEditingController();
  final _nominalCtrl = TextEditingController();
  int _qty = 1;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _keteranganCtrl.text = e['keterangan']?.toString() ?? '';
      final nominal = e['nominal'] is num
          ? (e['nominal'] as num).toInt()
          : int.tryParse(e['nominal']?.toString() ?? '') ?? 0;
      _nominalCtrl.text = nominal > 0
          ? NumberFormat.decimalPattern('id').format(nominal)
          : '';
      final qty = e['qty'] is num
          ? (e['qty'] as num).toInt()
          : int.tryParse(e['qty']?.toString() ?? '') ?? 1;
      _qty = qty < 1 ? 1 : qty;
    }
  }

  @override
  void dispose() {
    _keteranganCtrl.dispose();
    _nominalCtrl.dispose();
    super.dispose();
  }

  int get _nominal =>
      int.tryParse(_nominalCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _submit() async {
    final ket = _keteranganCtrl.text.trim();
    final nominal = _nominal;
    if (ket.isEmpty) {
      _snack('Keterangan tidak boleh kosong');
      return;
    }
    if (nominal <= 0) {
      _snack('Nominal harus lebih dari 0');
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.onSave(ket, nominal, _qty);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _snack('Gagal menyimpan: $e');
      }
    }
  }

  Future<void> _hapus() async {
    final onDelete = widget.onDelete;
    if (onDelete == null) return;
    final yakin = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus biaya tambahan?'),
        content: Text(
          '"${_keteranganCtrl.text.trim()}" akan dihapus dan total tagihan '
          'dihitung ulang.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (yakin != true) return;
    setState(() => _saving = true);
    try {
      await onDelete();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _snack('Gagal menghapus: $e');
      }
    }
  }

  InputDecoration _dekor(String hint, {Widget? prefix}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
      filled: true,
      fillColor: Theme.of(context).cardColor,
      prefixIcon: prefix,
      prefixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: kPrimary, width: 1.5),
      ),
    );
  }

  Widget _label(String text) => Text(
    text,
    style: Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(fontSize: 12, fontWeight: FontWeight.w500),
  );

  Widget _qtyButton(IconData icon, bool aktif, VoidCallback onTap) {
    return GestureDetector(
      onTap: aktif ? onTap : null,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: aktif ? Colors.black87 : Colors.grey.shade400,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final subtotal = _nominal * _qty;
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
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
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
            Row(
              children: [
                Icon(Icons.add_card_outlined, color: kPrimary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _isEdit ? 'Edit Biaya Tambahan' : 'Tambah Biaya Tambahan',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (_isEdit && widget.onDelete != null)
                  IconButton(
                    tooltip: 'Hapus',
                    onPressed: _saving ? null : _hapus,
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.red,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            _label('Keterangan'),
            const SizedBox(height: 6),
            TextField(
              controller: _keteranganCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: _dekor('Contoh: Biaya antar, Plastik, dll'),
            ),
            const SizedBox(height: 14),
            _label('Nominal (Rp)'),
            const SizedBox(height: 6),
            TextField(
              controller: _nominalCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                CurrencyInputFormatter(),
              ],
              onChanged: (_) => setState(() {}),
              decoration: _dekor(
                'Contoh: 5.000',
                prefix: SizedBox(
                  width: 48,
                  child: Center(
                    child: Text(
                      'Rp',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            _label('Qty'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  _qtyButton(Icons.remove, _qty > 1, () => setState(() => _qty--)),
                  Expanded(
                    child: Center(
                      child: Text(
                        '$_qty',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  _qtyButton(Icons.add, true, () => setState(() => _qty++)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: kPrimary.withOpacity(0.07),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kPrimary.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Subtotal', style: Theme.of(context).textTheme.bodySmall),
                  Text(
                    formatRupiah(subtotal),
                    style: TextStyle(
                      color: kPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _isEdit ? 'Simpan Perubahan' : 'Tambahkan',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
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

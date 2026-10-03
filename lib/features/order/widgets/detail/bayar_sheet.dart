import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mdnlaundry_project/core/app_exports.dart';
import 'package:mdnlaundry_project/core/utils/format_utils.dart';

// ════════════════════════════════════════════════════════════════════════════
//  BOTTOM SHEET: BAYAR (PENUH / SEBAGIAN)
// ════════════════════════════════════════════════════════════════════════════
class BayarSheet extends StatefulWidget {
  final String namaPelanggan;
  final int grandTotal;
  final int sudahDibayar;
  final int sisa;
  final Future<void> Function(int nominal, String metode, String catatan)
  onSubmit;

  const BayarSheet({
    required this.namaPelanggan,
    required this.grandTotal,
    required this.sudahDibayar,
    required this.sisa,
    required this.onSubmit,
  });

  @override
  State<BayarSheet> createState() => BayarSheetState();
}

class BayarSheetState extends State<BayarSheet> {
  static const _metodeList = ['Tunai', 'Transfer', 'QRIS', 'Lainnya'];

  final _nominalCtrl = TextEditingController();
  final _catatanCtrl = TextEditingController();
  String _metode = 'Tunai';
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Default: langsung isi sisa tagihan (alur "lunasi" tetap 1 ketukan).
    _setNominal(widget.sisa);
  }

  @override
  void dispose() {
    _nominalCtrl.dispose();
    _catatanCtrl.dispose();
    super.dispose();
  }

  int get _nominal =>
      int.tryParse(_nominalCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

  void _setNominal(int v) {
    final text = v <= 0 ? '' : NumberFormat.decimalPattern('id').format(v);
    _nominalCtrl.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    setState(() => _error = null);
  }

  Future<void> _submit() async {
    final nominal = _nominal;
    if (nominal <= 0) {
      setState(() => _error = 'Masukkan nominal pembayaran');
      return;
    }
    if (nominal > widget.sisa) {
      setState(
        () => _error =
            'Melebihi sisa tagihan (${formatRupiah(widget.sisa)})',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSubmit(nominal, _metode, _catatanCtrl.text.trim());
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Gagal menyimpan pembayaran: $e';
        });
      }
    }
  }

  Widget _infoRow(String label, String value, {Color? color, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: bold ? FontWeight.bold : FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).appBarTheme.backgroundColor ?? kPrimary;
    final nominal = _nominal;
    final sisaSetelah = (widget.sisa - nominal).clamp(0, widget.sisa);
    final lunasi = nominal > 0 && nominal >= widget.sisa;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
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
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(Icons.payments_rounded, color: Colors.green),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Catat Pembayaran',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 17,
                              ),
                        ),
                        Text(
                          widget.namaPelanggan,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _infoRow('Total tagihan', formatRupiah(widget.grandTotal)),
              if (widget.sudahDibayar > 0)
                _infoRow(
                  'Sudah dibayar',
                  formatRupiah(widget.sudahDibayar),
                  color: Colors.teal.shade600,
                ),
              _infoRow(
                'Sisa tagihan',
                formatRupiah(widget.sisa),
                color: Colors.red.shade600,
                bold: true,
              ),
              const Divider(height: 24),
              Text(
                'Nominal dibayar sekarang',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _nominalCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [CurrencyInputFormatter()],
                onChanged: (_) => setState(() => _error = null),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  prefixText: 'Rp ',
                  errorText: _error,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ActionChip(
                    label: const Text('Lunasi'),
                    onPressed: () => _setNominal(widget.sisa),
                  ),
                  if (widget.sisa >= 2000)
                    ActionChip(
                      label: const Text('50% sisa'),
                      onPressed: () => _setNominal((widget.sisa / 2).round()),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Metode',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                children: [
                  for (final m in _metodeList)
                    ChoiceChip(
                      label: Text(m),
                      selected: _metode == m,
                      onSelected: (_) => setState(() => _metode = m),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _catatanCtrl,
                decoration: InputDecoration(
                  labelText: 'Catatan (opsional)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: (lunasi ? Colors.green : Colors.orange).withOpacity(
                    0.08,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  lunasi
                      ? 'Dengan pembayaran ini pesanan menjadi LUNAS'
                      : 'Sisa setelah pembayaran ini: ${formatRupiah(sisaSetelah)}',
                  style: TextStyle(
                    color: lunasi
                        ? Colors.green.shade700
                        : Colors.orange.shade800,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _submit,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_circle_outline, size: 18),
                  label: Text(
                    lunasi ? 'Lunasi Pembayaran' : 'Simpan Pembayaran',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: lunasi ? Colors.green : accent,
                    foregroundColor: Colors.white,
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
      ),
    );
  }
}

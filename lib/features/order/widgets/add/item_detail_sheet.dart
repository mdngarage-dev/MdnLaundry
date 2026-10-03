import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mdnlaundry_project/core/app_exports.dart';
import 'package:mdnlaundry_project/core/utils/format_utils.dart';

// ════════════════════════════════════════════════════════════════════════════
// BOTTOM SHEET: Input Detail Item — tidak berubah
// ════════════════════════════════════════════════════════════════════════════
class AddItemDetailSheet extends StatefulWidget {
  final Layanan layanan;
  final void Function(Map<String, dynamic>) onAdd;
  final DateTime? customTanggal;
  const AddItemDetailSheet({
    required this.layanan,
    required this.onAdd,
    this.customTanggal,
  });

  @override
  State<AddItemDetailSheet> createState() => AddItemDetailSheetState();
}

class AddItemDetailSheetState extends State<AddItemDetailSheet> {
  double _jumlah = 1.0;
  final _catatanCtrl = TextEditingController();
  final _jumlahPakaianCtrl = TextEditingController(text: '0');
  final _jumlahManualCtrl = TextEditingController();
  bool _isManualMode = false;

  double get _step => widget.layanan.tipe == 'kiloan' ? 0.5 : 1.0;
  double get _min => widget.layanan.tipe == 'kiloan' ? 0.5 : 1.0;

  String get _satuanLabel {
    switch (widget.layanan.tipe) {
      case 'kiloan':
        return 'kg';
      case 'meter':
        return 'meter';
      default:
        return 'pcs';
    }
  }

  int get _subtotal => (_jumlah * widget.layanan.harga).round();

  String _hitungEstimasi() {
    final baseDate = widget.customTanggal != null
        ? DateTime(
            widget.customTanggal!.year,
            widget.customTanggal!.month,
            widget.customTanggal!.day,
            18,
            0,
          )
        : DateTime.now();
    return DateFormat(
      'dd-MM-yyyy',
    ).format(baseDate.add(Duration(hours: widget.layanan.durasiJam)));
  }

  @override
  void initState() {
    super.initState();
    _jumlahManualCtrl.text = _jumlah % 1 == 0
        ? _jumlah.toStringAsFixed(0)
        : _jumlah.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _catatanCtrl.dispose();
    _jumlahPakaianCtrl.dispose();
    _jumlahManualCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final isKarpet = widget.layanan.tipe == 'meter';
    final satuan = _satuanLabel;
    final jumlahStr =
        widget.layanan.tipe == 'kiloan' || widget.layanan.tipe == 'meter'
        ? (_jumlah % 1 == 0
              ? _jumlah.toStringAsFixed(0)
              : NumberFormat('#,##0.##', 'id_ID').format(_jumlah))
        : _jumlah.toStringAsFixed(0);
    final estimasiInfo = _hitungEstimasi();
    final baseLabel = widget.customTanggal != null
        ? 'dari tgl ${DateFormat('dd MMM', 'id_ID').format(widget.customTanggal!)}'
        : 'dari sekarang';

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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.layanan.nama,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Rp ${NumberFormat('#,###', 'id_ID').format(widget.layanan.harga.round())}/$satuan',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(fontSize: 14),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close,
                      size: 18,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Jumlah / Berat',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: _isManualMode
                  ? Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            if (_jumlah > _min) {
                              final newVal = double.parse(
                                (_jumlah - _step).toStringAsFixed(2),
                              );
                              setState(() {
                                _jumlah = newVal;
                                _jumlahManualCtrl.text = newVal % 1 == 0
                                    ? newVal.toStringAsFixed(0)
                                    : newVal.toStringAsFixed(2);
                              });
                            }
                          },
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.remove,
                              color: _jumlah > _min
                                  ? Colors.black87
                                  : Colors.grey.shade400,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: TextField(
                              controller: _jumlahManualCtrl,
                              autofocus: true,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d+\.?\d{0,3}'),
                                ),
                              ],
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                              decoration: InputDecoration(
                                suffixText: satuan,
                                suffixStyle: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 14,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                  horizontal: 4,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                    color: primary,
                                    width: 2,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                    color: primary.withOpacity(0.4),
                                  ),
                                ),
                              ),
                              onChanged: (val) {
                                final parsed = double.tryParse(val);
                                if (parsed != null && parsed >= _min)
                                  setState(() => _jumlah = parsed);
                              },
                              onSubmitted: (_) =>
                                  setState(() => _isManualMode = false),
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            final newVal = double.parse(
                              (_jumlah + _step).toStringAsFixed(2),
                            );
                            setState(() {
                              _jumlah = newVal;
                              _jumlahManualCtrl.text = newVal % 1 == 0
                                  ? newVal.toStringAsFixed(0)
                                  : newVal.toStringAsFixed(2);
                            });
                          },
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.add, color: Colors.black87),
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            if (_jumlah > _min) {
                              final newVal = double.parse(
                                (_jumlah - _step).toStringAsFixed(2),
                              );
                              setState(() {
                                _jumlah = newVal;
                                _jumlahManualCtrl.text = newVal % 1 == 0
                                    ? newVal.toStringAsFixed(0)
                                    : newVal.toStringAsFixed(2);
                              });
                            }
                          },
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.remove,
                              color: _jumlah > _min
                                  ? Colors.black87
                                  : Colors.grey.shade400,
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() {
                              _isManualMode = true;
                              _jumlahManualCtrl.text = _jumlah % 1 == 0
                                  ? _jumlah.toStringAsFixed(0)
                                  : _jumlah.toStringAsFixed(2);
                            }),
                            child: Column(
                              children: [
                                RichText(
                                  text: TextSpan(
                                    children: [
                                      TextSpan(
                                        text: jumlahStr,
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                      TextSpan(
                                        text: '  $satuan',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: Colors.grey.shade500,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.edit_outlined,
                                      size: 10,
                                      color: primary.withOpacity(0.6),
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      'Ketuk untuk edit manual',
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: primary.withOpacity(0.6),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            final newVal = double.parse(
                              (_jumlah + _step).toStringAsFixed(2),
                            );
                            setState(() {
                              _jumlah = newVal;
                              _jumlahManualCtrl.text = newVal % 1 == 0
                                  ? newVal.toStringAsFixed(0)
                                  : newVal.toStringAsFixed(2);
                            });
                          },
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.add, color: Colors.black87),
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 12),
            if (isKarpet) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final pCtrl = TextEditingController();
                    final lCtrl = TextEditingController();
                    double? hasilDouble;
                    await showDialog(
                      context: context,
                      builder: (ctx) => StatefulBuilder(
                        builder: (ctx, setS) {
                          void hitung() {
                            final p = double.tryParse(pCtrl.text) ?? 0;
                            final l = double.tryParse(lCtrl.text) ?? 0;
                            setS(() => hasilDouble = p * l);
                          }

                          final hasil = hasilDouble ?? 0.0;
                          return AlertDialog(
                            backgroundColor: Theme.of(ctx).cardColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            title: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: kPrimary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Text(
                                    '🧮',
                                    style: TextStyle(fontSize: 18),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Kalkulator P × L',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(
                                      ctx,
                                    ).textTheme.bodyLarge?.color,
                                  ),
                                ),
                              ],
                            ),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextField(
                                  controller: pCtrl,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'^\d+\.?\d{0,2}'),
                                    ),
                                  ],
                                  onChanged: (_) => hitung(),
                                  decoration: InputDecoration(
                                    labelText: 'Panjang (meter)',
                                    suffixText: 'm',
                                    filled: true,
                                    fillColor: Theme.of(
                                      ctx,
                                    ).scaffoldBackgroundColor,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: kPrimary,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: lCtrl,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'^\d+\.?\d{0,2}'),
                                    ),
                                  ],
                                  onChanged: (_) => hitung(),
                                  decoration: InputDecoration(
                                    labelText: 'Lebar (meter)',
                                    suffixText: 'm',
                                    filled: true,
                                    fillColor: Theme.of(
                                      ctx,
                                    ).scaffoldBackgroundColor,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: kPrimary,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                    horizontal: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: kPrimary.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        'Hasil',
                                        style: TextStyle(
                                          color: Theme.of(
                                            ctx,
                                          ).textTheme.bodySmall?.color,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      RichText(
                                        text: TextSpan(
                                          children: [
                                            TextSpan(
                                              text: hasil > 0
                                                  ? NumberFormat(
                                                      '#,##0.##',
                                                      'id_ID',
                                                    ).format(hasil)
                                                  : '0',
                                              style: const TextStyle(
                                                color: kPrimary,
                                                fontSize: 28,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const TextSpan(
                                              text: ' meter²',
                                              style: TextStyle(
                                                color: kPrimary,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (hasil > 0) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                          NumberFormat.currency(
                                            locale: 'id_ID',
                                            symbol: 'Rp ',
                                            decimalDigits: 0,
                                          ).format(
                                            (widget.layanan.harga * hasil)
                                                .round(),
                                          ),
                                          style: const TextStyle(
                                            color: kPrimary,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: Text(
                                  'Batal',
                                  style: TextStyle(
                                    color: Theme.of(ctx).hintColor,
                                  ),
                                ),
                              ),
                              ElevatedButton(
                                onPressed: hasil > 0
                                    ? () {
                                        final nilaiRapi = double.parse(
                                          hasilDouble!.toStringAsFixed(2),
                                        );
                                        setState(() {
                                          _jumlah = nilaiRapi;
                                          _jumlahManualCtrl.text =
                                              nilaiRapi % 1 == 0
                                              ? nilaiRapi.toStringAsFixed(0)
                                              : nilaiRapi.toStringAsFixed(2);
                                        });
                                        Navigator.pop(ctx);
                                      }
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: kPrimary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: const Text(
                                  'Gunakan',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    );
                  },
                  icon: Icon(Icons.calculate_outlined, color: primary),
                  label: Text(
                    'Kalkulator P × L',
                    style: TextStyle(
                      color: primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: primary, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Text(
              'Catatan (Opsional)',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _catatanCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Contoh: Jangan campur baju putih',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                filled: true,
                fillColor: Theme.of(context).cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200),
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
            Text(
              'Jumlah Pakaian (Opsional)',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _jumlahPakaianCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                hintText: '0',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                filled: true,
                fillColor: Theme.of(context).cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200),
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
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: kPrimary.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kPrimary.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.event_available_outlined,
                    color: kPrimary,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Estimasi Selesai',
                          style: TextStyle(
                            fontSize: 11,
                            color: kPrimary.withOpacity(0.7),
                          ),
                        ),
                        Text(
                          estimasiInfo,
                          style: TextStyle(
                            color: kPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    baseLabel,
                    style: TextStyle(
                      fontSize: 10,
                      color: kPrimary.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Subtotal',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  formatRupiah(_subtotal),
                  style: TextStyle(
                    color: primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => widget.onAdd({
                  'layanan_nama': widget.layanan.nama,
                  'layanan_tipe': widget.layanan.tipe,
                  'layanan_id': widget.layanan.id,
                  'jenis_pakaian': '',
                  'berat_kg': _jumlah,
                  'harga_satuan': widget.layanan.harga,
                  'durasi_jam': widget.layanan.durasiJam,
                  'estimasi_selesai': _hitungEstimasi(),
                  'catatan': _catatanCtrl.text.trim(),
                  'jumlah_pakaian': int.tryParse(_jumlahPakaianCtrl.text) ?? 0,
                }),
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
                child: const Text(
                  'Tambah ke Order',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

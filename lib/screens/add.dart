import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'screens.dart';

class AddOrderScreen extends StatefulWidget {
  const AddOrderScreen({super.key});

  @override
  State<AddOrderScreen> createState() => _AddOrderScreenState();
}

class _AddOrderScreenState extends State<AddOrderScreen> {
  final _formKey = GlobalKey<FormState>();

  // ── Pelanggan ─────────────────────────────────────────────────────────────
  String? _selectedNama;
  String? _selectedHp;

  // ── Items ─────────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _biayaTambahan = [];

  // ── Diskon ────────────────────────────────────────────────────────────────
  int _diskonNominal = 0;
  String _diskonCatatan = '';

  int get _totalBiayaTambahan => _biayaTambahan.fold(0, (sum, b) {
    try {
      return sum + ((b['nominal'] as num).toInt() * (b['qty'] as num).toInt());
    } catch (_) {
      return sum;
    }
  });

  // Grand total layanan saja
  int get _grandTotal => _items.fold(0, (sum, item) {
    try {
      final berat = (item['berat_kg'] as num).toDouble();
      final harga = (item['harga_satuan'] as num).toInt();
      return sum + (berat * harga).toInt();
    } catch (_) {
      return sum;
    }
  });

  // Subtotal sebelum diskon (layanan + biaya tambahan)
  int get _grandTotalSebelumDiskon => _grandTotal + _totalBiayaTambahan;

  // Grand total final setelah diskon
  int get _grandTotalFinal {
    final hasil = _grandTotalSebelumDiskon - _diskonNominal;
    return hasil < 0 ? 0 : hasil;
  }

  // ── Status pembayaran ─────────────────────────────────────────────────────
  String _statusBayar = 'belum_bayar';
  final _dpCtrl = TextEditingController();
  final _catatanOrderCtrl = TextEditingController();

  bool _isSubmitting = false;
  DateTime? _customTanggal;

  DateTime get _waktuOrderFinal {
    if (_customTanggal != null) {
      return DateTime(
        _customTanggal!.year,
        _customTanggal!.month,
        _customTanggal!.day,
        18,
        0,
      );
    }
    return DateTime.now();
  }

  @override
  void dispose() {
    _dpCtrl.dispose();
    _catatanOrderCtrl.dispose();
    super.dispose();
  }

  // ── Estimasi selesai terpanjang dari semua items ───────────────────────────
  String get _estimasiTerpanjang {
    if (_items.isEmpty) return '-';
    return _items.map((i) => i['estimasi_selesai']?.toString() ?? '-').last;
  }

  // ── Pilih pelanggan ───────────────────────────────────────────────────────
  Future<void> _pilihPelanggan() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => const DaftarPelangganPage(isSelecting: true),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _selectedNama = result['nama']?.toString();
        _selectedHp = result['no_hp']?.toString();
      });
    }
  }

  // ── Buka picker layanan ───────────────────────────────────────────────────
  Future<void> _openTambahLayanan() async {
    final snap = await FirebaseFirestore.instance
        .collection('layanan')
        .orderBy('nama')
        .get();
    final layananList = snap.docs.map((d) => Layanan.fromFirestore(d)).toList();

    if (!mounted) return;
    if (layananList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Belum ada layanan. Tambah layanan terlebih dahulu.'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _LayananPickerSheet(
        layananList: layananList,
        onSelected: (layanan) {
          Navigator.pop(ctx);
          Future.delayed(const Duration(milliseconds: 200), () {
            if (!mounted) return;
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (ctx2) => _ItemDetailSheet(
                layanan: layanan,
                onAdd: (item) {
                  Navigator.pop(ctx2);
                  setState(() => _items.add(item));
                },
              ),
            );
          });
        },
      ),
    );
  }

  // ── biaya tambahan ────────────────────────────────────────────────────────
  void _showTambahBiayaSheet() {
    final nominalCtrl = TextEditingController();
    final keteranganCtrl = TextEditingController();
    int qty = 1;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
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
                  Text(
                    'Tambah Biaya Tambahan',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Keterangan',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: keteranganCtrl,
                decoration: InputDecoration(
                  hintText: 'Contoh: Biaya antar, Plastik, dll',
                  hintStyle: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 13,
                  ),
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: kPrimary, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Nominal (Rp)',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: nominalCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  CurrencyInputFormatter(),
                ],
                onChanged: (_) => setS(() {}),
                decoration: InputDecoration(
                  hintText: 'Contoh: 5.000',
                  hintStyle: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 13,
                  ),
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                  prefixIcon: SizedBox(
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
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: kPrimary, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Qty',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (qty > 1) setS(() => qty--);
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.remove,
                          color: qty > 1
                              ? Colors.black87
                              : Colors.grey.shade400,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          '$qty',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setS(() => qty++),
                      child: Container(
                        width: 40,
                        height: 40,
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
              Builder(
                builder: (_) {
                  final nominal =
                      int.tryParse(
                        nominalCtrl.text
                            .replaceAll('.', '')
                            .replaceAll(',', ''),
                      ) ??
                      0;
                  final subtotal = nominal * qty;
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: kPrimary.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: kPrimary.withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Subtotal',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text(
                          _formatRupiah(subtotal),
                          style: TextStyle(
                            color: kPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final nominal =
                        int.tryParse(
                          nominalCtrl.text
                              .replaceAll('.', '')
                              .replaceAll(',', ''),
                        ) ??
                        0;
                    final ket = keteranganCtrl.text.trim();
                    if (ket.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Keterangan tidak boleh kosong'),
                          backgroundColor: Colors.orange,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      return;
                    }
                    if (nominal <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Nominal harus lebih dari 0'),
                          backgroundColor: Colors.orange,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      return;
                    }
                    setState(
                      () => _biayaTambahan.add({
                        'keterangan': ket,
                        'nominal': nominal,
                        'qty': qty,
                      }),
                    );
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Tambahkan',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Sheet Diskon ──────────────────────────────────────────────────────────
  void _showDiskonSheet() {
    final nominalCtrl = TextEditingController(
      text: _diskonNominal > 0 ? _diskonNominal.toString() : '',
    );
    final catatanCtrl = TextEditingController(text: _diskonCatatan);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
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
                  Icon(
                    Icons.local_offer_outlined,
                    color: Colors.red.shade400,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Tambah Diskon',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Diskon akan mengurangi total tagihan pelanggan',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).hintColor,
                ),
              ),
              const SizedBox(height: 20),

              // Nominal diskon
              Text(
                'Nominal Diskon (Rp)',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: nominalCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  CurrencyInputFormatter(),
                ],
                onChanged: (_) => setS(() {}),
                decoration: InputDecoration(
                  hintText: 'Contoh: 10.000',
                  hintStyle: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 13,
                  ),
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                  prefixIcon: SizedBox(
                    width: 48,
                    child: Center(
                      child: Text(
                        'Rp',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.red.shade400,
                        ),
                      ),
                    ),
                  ),
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.red.shade400,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Catatan diskon
              Text(
                'Catatan (Opsional)',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: catatanCtrl,
                decoration: InputDecoration(
                  hintText: 'Contoh: Pelanggan setia, Promo, dll',
                  hintStyle: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 13,
                  ),
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.red.shade400,
                      width: 1.5,
                    ),
                  ),
                ),
              ),

              // Preview pengurangan
              const SizedBox(height: 14),
              Builder(
                builder: (_) {
                  final nominal =
                      int.tryParse(
                        nominalCtrl.text
                            .replaceAll('.', '')
                            .replaceAll(',', ''),
                      ) ??
                      0;
                  final setelahDiskon = (_grandTotalSebelumDiskon - nominal)
                      .clamp(0, _grandTotalSebelumDiskon);
                  if (nominal <= 0) return const SizedBox.shrink();
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.withOpacity(0.2)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total sebelum diskon',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            Text(
                              _formatRupiah(_grandTotalSebelumDiskon),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Diskon',
                              style: TextStyle(
                                color: Colors.red.shade400,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              '- ${_formatRupiah(nominal)}',
                              style: TextStyle(
                                color: Colors.red.shade400,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        Divider(height: 12, color: Colors.red.withOpacity(0.2)),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total akhir',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              _formatRupiah(setelahDiskon),
                              style: TextStyle(
                                color: kPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 16),
              Row(
                children: [
                  if (_diskonNominal > 0) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _diskonNominal = 0;
                            _diskonCatatan = '';
                          });
                          Navigator.pop(ctx);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: BorderSide(color: Colors.red.shade300),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Hapus Diskon'),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () {
                        final nominal =
                            int.tryParse(
                              nominalCtrl.text
                                  .replaceAll('.', '')
                                  .replaceAll(',', ''),
                            ) ??
                            0;
                        if (nominal <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Nominal diskon harus lebih dari 0',
                              ),
                              backgroundColor: Colors.orange,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          return;
                        }
                        if (nominal > _grandTotalSebelumDiskon) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Diskon tidak boleh melebihi total',
                              ),
                              backgroundColor: Colors.orange,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          return;
                        }
                        setState(() {
                          _diskonNominal = nominal;
                          _diskonCatatan = catatanCtrl.text.trim();
                        });
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade400,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Terapkan',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Hapus item ────────────────────────────────────────────────────────────
  void _hapusItem(int idx) {
    setState(() => _items.removeAt(idx));
  }

  // ── Date picker sheet ─────────────────────────────────────────────────────
  void _showDatePickerSheet() {
    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, 1);
    final lastDay = DateTime(now.year, now.month + 1, 0);
    final totalDays = lastDay.day;
    final startWeekday = (firstDay.weekday - 1) % 7;
    const dayLabels = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

    DateTime? tempSelected = _customTanggal;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
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
              Row(
                children: [
                  Icon(
                    Icons.calendar_month_outlined,
                    color: kPrimary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Pilih Tanggal Order',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Jika dipilih, jam order otomatis menjadi 18:00',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).hintColor,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: kPrimary.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    DateFormat('MMMM yyyy', 'id_ID').format(now),
                    style: TextStyle(
                      color: kPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: dayLabels
                    .map(
                      (d) => Expanded(
                        child: Center(
                          child: Text(
                            d,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: d == 'Min'
                                  ? Colors.red.shade400
                                  : Colors.grey.shade500,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 8),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  childAspectRatio: 1,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 2,
                ),
                itemCount: startWeekday + totalDays,
                itemBuilder: (_, index) {
                  if (index < startWeekday) return const SizedBox();
                  final day = index - startWeekday + 1;
                  final date = DateTime(now.year, now.month, day);
                  final isToday = day == now.day;
                  final isSelected =
                      tempSelected != null &&
                      tempSelected!.day == day &&
                      tempSelected!.month == now.month &&
                      tempSelected!.year == now.year;
                  final isSunday = date.weekday == DateTime.sunday;
                  return GestureDetector(
                    onTap: () => setS(() {
                      tempSelected = isSelected ? null : date;
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? kPrimary
                            : isToday
                            ? kPrimary.withOpacity(0.12)
                            : Colors.transparent,
                        shape: BoxShape.circle,
                        border: isToday && !isSelected
                            ? Border.all(
                                color: kPrimary.withOpacity(0.5),
                                width: 1,
                              )
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          '$day',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected || isToday
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSelected
                                ? Colors.white
                                : isSunday
                                ? Colors.red.shade400
                                : Theme.of(context).brightness ==
                                      Brightness.dark
                                ? Colors.white70
                                : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              if (tempSelected != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: kPrimary.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: kPrimary.withOpacity(0.25)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        color: kPrimary,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${DateFormat('dd MMM yyyy', 'id_ID').format(tempSelected!)}  •  18:00',
                        style: TextStyle(
                          color: kPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() => _customTanggal = null);
                        Navigator.pop(ctx);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey,
                        side: BorderSide(color: Colors.grey.shade300),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Reset'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() => _customTanggal = tempSelected);
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        tempSelected != null
                            ? 'Gunakan Tanggal Ini'
                            : 'Pakai Sekarang',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Simpan order ──────────────────────────────────────────────────────────
  Future<void> _submitData() async {
    if (_isSubmitting) return;
    if (_selectedNama == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih pelanggan terlebih dahulu'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tambahkan minimal 1 layanan'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (_statusBayar == 'dp' && _dpCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Masukkan nominal DP'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final firestore = FirebaseFirestore.instance;
      final String adminFinal =
          FirebaseAuth.instance.currentUser?.displayName?.split('|')[0] ??
          'Admin';

      // Generate nomor struk
      final counterRef = firestore.collection('counters').doc('pelanggan');
      final String nomorStruk = await firestore
          .runTransaction<String>((tx) async {
            final snap = await tx.get(counterRef);
            final int next = (snap.data()?['last'] ?? 0) + 1;
            tx.set(counterRef, {'last': next});
            final tgl = DateFormat('yyMMdd').format(DateTime.now());
            return 'MDN$tgl${next.toString().padLeft(3, '0')}';
          })
          .timeout(const Duration(seconds: 10));

      final int dpInt = _statusBayar == 'dp'
          ? int.tryParse(
                  _dpCtrl.text.trim().replaceAll('.', '').replaceAll(',', ''),
                ) ??
                0
          : 0;

      final firstItem = _items.first;

      // Simpan dokumen order utama — include diskon
      final orderRef = await firestore.collection('order').add({
        'nomor_pelanggan': nomorStruk,
        'nama_pelanggan': _selectedNama,
        'no_hp': _selectedHp ?? '',
        'layanan_id': firstItem['layanan_id'] ?? '',
        'layanan_nama': firstItem['layanan_nama'] ?? '',
        'layanan_tipe': firstItem['layanan_tipe'] ?? '',
        'harga_satuan': firstItem['harga_satuan'] ?? 0,
        'jenis_pakaian': firstItem['jenis_pakaian'] ?? '',
        'berat_kg': firstItem['berat_kg'] ?? 0,
        'catatan': _catatanOrderCtrl.text.trim(),
        'admin': adminFinal,
        'waktu_order': _customTanggal != null
            ? Timestamp.fromDate(_waktuOrderFinal)
            : FieldValue.serverTimestamp(),
        'estimasi_selesai': _estimasiTerpanjang,
        'durasi_jam': firstItem['durasi_jam'] ?? 24,
        'status': 'antrian',
        'status_bayar': _statusBayar,
        'dp_amount': dpInt,
        // ── Diskon ──────────────────────────
        'diskon_nominal': _diskonNominal,
        'diskon_catatan': _diskonCatatan,
        // ── Harga final setelah diskon ───────
        'harga_total': _grandTotalFinal,
        'jumlah_item': _items.length,
      });

      // Simpan subcollection biaya_tambahan
      for (final biaya in _biayaTambahan) {
        final biayaData = Map<String, dynamic>.from(biaya);
        biayaData['created_at'] = FieldValue.serverTimestamp();
        await orderRef.collection('biaya_tambahan').add(biayaData);
      }

      // Simpan subcollection items
      for (final item in _items) {
        final itemData = Map<String, dynamic>.from(item);
        itemData.remove('_itemDocId');
        itemData['created_at'] = FieldValue.serverTimestamp();
        await orderRef.collection('items').add(itemData);
      }

      // Simpan keuangan
      await firestore.collection('keuangan').add({
        'nomor_pelanggan': nomorStruk,
        'biaya': _grandTotalFinal,
        'dp_amount': dpInt,
        'diskon_nominal': _diskonNominal,
        'status_bayar': _statusBayar,
        'waktu_transaksi': FieldValue.serverTimestamp(),
      });

      if (!context.mounted) return;
      setState(() => _isSubmitting = false);

      // Data untuk dikirim ke OrderDetailScreen
      final savedOrderData = {
        'nomor_pelanggan': nomorStruk,
        'nama_pelanggan': _selectedNama,
        'no_hp': _selectedHp ?? '',
        'layanan_id': firstItem['layanan_id'] ?? '',
        'layanan_nama': firstItem['layanan_nama'] ?? '',
        'layanan_tipe': firstItem['layanan_tipe'] ?? '',
        'harga_satuan': firstItem['harga_satuan'] ?? 0,
        'jenis_pakaian': firstItem['jenis_pakaian'] ?? '',
        'berat_kg': firstItem['berat_kg'] ?? 0,
        'catatan': _catatanOrderCtrl.text.trim(),
        'admin': adminFinal,
        'waktu_order': Timestamp.fromDate(_waktuOrderFinal),
        'estimasi_selesai': _estimasiTerpanjang,
        'durasi_jam': firstItem['durasi_jam'] ?? 24,
        'status': 'antrian',
        'status_bayar': _statusBayar,
        'dp_amount': dpInt,
        'diskon_nominal': _diskonNominal,
        'diskon_catatan': _diskonCatatan,
        'harga_total': _grandTotalFinal,
        'jumlah_item': _items.length,
      };

      // Reset form
      setState(() {
        _selectedNama = null;
        _selectedHp = null;
        _items = [];
        _statusBayar = 'belum_bayar';
        _dpCtrl.clear();
        _catatanOrderCtrl.clear();
        _customTanggal = null;
        _biayaTambahan = [];
        _diskonNominal = 0;
        _diskonCatatan = '';
      });

      // ── Navigate langsung ke OrderDetailScreen (cetak ada di sana) ──────
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                OrderDetailScreen(docId: orderRef.id, data: savedOrderData),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _isSubmitting = false);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
          child: AppBar(
            title: Text(
              'Tambah Order Baru',
              style:
                  Theme.of(context).appBarTheme.titleTextStyle?.copyWith(
                    fontWeight: FontWeight.bold,
                  ) ??
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            backgroundColor:
                Theme.of(context).appBarTheme.backgroundColor ?? kPrimary,
            elevation: 2,
            centerTitle: true,
            iconTheme:
                Theme.of(context).appBarTheme.iconTheme ??
                const IconThemeData(color: Colors.white),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── GROUP 1: PILIH PELANGGAN ──────────────────────────────
              _buildCardGroup(
                title: 'Data Pelanggan',
                icon: Icons.person_outline,
                isDark: isDark,
                children: [
                  GestureDetector(
                    onTap: _pilihPelanggan,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 15,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _selectedNama != null
                              ? kPrimary.withOpacity(0.5)
                              : Theme.of(context).dividerColor,
                          width: _selectedNama != null ? 1.5 : 1,
                        ),
                      ),
                      child: _selectedNama == null
                          ? Row(
                              children: [
                                Icon(
                                  Icons.person_search_outlined,
                                  color: kPrimary,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Pilih dari Daftar Pelanggan',
                                  style: TextStyle(
                                    color: Theme.of(context).hintColor,
                                    fontSize: 14,
                                  ),
                                ),
                                const Spacer(),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  color: Theme.of(context).hintColor,
                                ),
                              ],
                            )
                          : Row(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: kPrimary.withOpacity(0.15),
                                  child: Text(
                                    _selectedNama!.isNotEmpty
                                        ? _selectedNama![0].toUpperCase()
                                        : '?',
                                    style: TextStyle(
                                      color: kPrimary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _selectedNama!,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: isDark
                                              ? Colors.white
                                              : kTextDark,
                                        ),
                                      ),
                                      if (_selectedHp != null)
                                        Text(
                                          _selectedHp!,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Theme.of(context).hintColor,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                GestureDetector(
                                  onTap: _pilihPelanggan,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: kPrimary.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Ganti',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: kPrimary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── GROUP 2: ITEM PESANAN ─────────────────────────────────
              _buildCardGroup(
                title: 'Item Pesanan',
                icon: Icons.local_laundry_service_outlined,
                isDark: isDark,
                trailingWidget: _items.isNotEmpty
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_items.length} item',
                          style: TextStyle(
                            color: primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    : null,
                children: [
                  if (_items.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.add_shopping_cart_outlined,
                              size: 40,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Belum ada layanan ditambahkan',
                              style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._items.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final item = entry.value;
                      final tipe = item['layanan_tipe']?.toString() ?? '';
                      final satuan = tipe == 'kiloan'
                          ? 'kg'
                          : tipe == 'meter'
                          ? 'm²'
                          : 'pcs';
                      final berat = (item['berat_kg'] as num?)?.toDouble() ?? 0;
                      final beratStr = berat % 1 == 0
                          ? berat.toStringAsFixed(0)
                          : NumberFormat('#,##0.##', 'id_ID').format(berat);
                      final harga =
                          (item['harga_satuan'] as num?)?.toInt() ?? 0;
                      final subtotal = (berat * harga).toInt();
                      final jenis = item['jenis_pakaian']?.toString() ?? '';
                      final catatan = item['catatan']?.toString() ?? '';

                      Color chipColor;
                      switch (tipe) {
                        case 'kiloan':
                          chipColor = Colors.blue;
                          break;
                        case 'meter':
                          chipColor = Colors.orange;
                          break;
                        default:
                          chipColor = Colors.green;
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withOpacity(0.05)
                              : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: chipColor.withOpacity(0.25),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item['layanan_nama']?.toString() ?? '-',
                                    style: Theme.of(context).textTheme.bodyLarge
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                  ),
                                ),
                                Text(
                                  NumberFormat.currency(
                                    locale: 'id_ID',
                                    symbol: 'Rp ',
                                    decimalDigits: 0,
                                  ).format(subtotal),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: chipColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '$beratStr $satuan × Rp ${NumberFormat('#,###', 'id_ID').format(harga)}',
                              style: Theme.of(
                                context,
                              ).textTheme.bodySmall?.copyWith(fontSize: 11),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                if (jenis.isNotEmpty) ...[
                                  _miniPill(jenis, Colors.teal),
                                  const SizedBox(width: 4),
                                ],
                                _miniPill(tipe, chipColor),
                                const Spacer(),
                                GestureDetector(
                                  onTap: () => _hapusItem(idx),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.red.withOpacity(0.3),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: const [
                                        Icon(
                                          Icons.delete_outline,
                                          size: 12,
                                          color: Colors.red,
                                        ),
                                        SizedBox(width: 3),
                                        Text(
                                          'Hapus',
                                          style: TextStyle(
                                            color: Colors.red,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (catatan.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white10
                                      : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.notes_rounded,
                                      size: 12,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        catatan,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(fontSize: 11),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }),

                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _openTambahLayanan,
                      icon: Icon(
                        Icons.add_circle_outline,
                        color: primary,
                        size: 18,
                      ),
                      label: Text(
                        'Tambah Layanan',
                        style: TextStyle(
                          color: primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: primary.withOpacity(0.5)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),

                  if (_items.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: kPrimary.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: kPrimary.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calculate_outlined,
                            color: kPrimary,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Total Sementara',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const Spacer(),
                          Text(
                            NumberFormat.currency(
                              locale: 'id_ID',
                              symbol: 'Rp ',
                              decimalDigits: 0,
                            ).format(_grandTotal),
                            style: TextStyle(
                              color: kPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.event_available_outlined,
                          color: kPrimary,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Est. Selesai: ',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text(
                          _estimasiTerpanjang,
                          style: TextStyle(
                            color: kPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),

              // ── GROUP TANGGAL ORDER ───────────────────────────────────
              _buildCardGroup(
                title: 'Tanggal Order',
                icon: Icons.calendar_today_outlined,
                isDark: isDark,
                children: [
                  GestureDetector(
                    onTap: () => _showDatePickerSheet(),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 13,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _customTanggal != null
                              ? kPrimary.withOpacity(0.5)
                              : Theme.of(context).dividerColor,
                          width: _customTanggal != null ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _customTanggal != null
                                ? Icons.event_available_outlined
                                : Icons.calendar_today_outlined,
                            color: _customTanggal != null
                                ? kPrimary
                                : Theme.of(context).hintColor,
                            size: 18,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _customTanggal != null
                                ? Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        DateFormat(
                                          'EEEE, dd MMMM yyyy',
                                          'id_ID',
                                        ).format(_customTanggal!),
                                        style: TextStyle(
                                          color: kPrimary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                      Text(
                                        'Jam otomatis: 18:00',
                                        style: TextStyle(
                                          color: kPrimary.withOpacity(0.7),
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  )
                                : Text(
                                    'Tanggal sekarang (jam input)',
                                    style: TextStyle(
                                      color: Theme.of(context).hintColor,
                                      fontSize: 13,
                                    ),
                                  ),
                          ),
                          if (_customTanggal != null)
                            GestureDetector(
                              onTap: () =>
                                  setState(() => _customTanggal = null),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.08),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close_rounded,
                                  color: Colors.red,
                                  size: 14,
                                ),
                              ),
                            )
                          else
                            Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: Theme.of(context).hintColor,
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── GROUP BIAYA TAMBAHAN ──────────────────────────────────
              _buildCardGroup(
                title: 'Biaya Tambahan',
                icon: Icons.add_card_outlined,
                isDark: isDark,
                trailingWidget: _biayaTambahan.isNotEmpty
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.purple.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_biayaTambahan.length} item',
                          style: const TextStyle(
                            color: Colors.purple,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    : null,
                children: [
                  if (_biayaTambahan.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: Column(
                          children: [
                            const SizedBox(height: 6),
                            Text(
                              'Belum ada biaya tambahan',
                              style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._biayaTambahan.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final b = entry.value;
                      final nominal = (b['nominal'] as num).toInt();
                      final qty = (b['qty'] as num).toInt();
                      final subtotal = nominal * qty;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withOpacity(0.05)
                              : Colors.purple.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.purple.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Colors.purple.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.receipt_outlined,
                                color: Colors.purple,
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    b['keterangan']?.toString() ?? '-',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                  ),
                                  Text(
                                    '${_formatRupiah(nominal)} × $qty',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  _formatRupiah(subtotal),
                                  style: const TextStyle(
                                    color: Colors.purple,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => setState(
                                    () => _biayaTambahan.removeAt(idx),
                                  ),
                                  child: Container(
                                    margin: const EdgeInsets.only(top: 4),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: Colors.red.withOpacity(0.3),
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.delete_outline,
                                          size: 10,
                                          color: Colors.red,
                                        ),
                                        SizedBox(width: 2),
                                        Text(
                                          'Hapus',
                                          style: TextStyle(
                                            color: Colors.red,
                                            fontSize: 9,
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
                      );
                    }),

                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _showTambahBiayaSheet,
                      icon: const Icon(Icons.add_circle_outline, size: 18),
                      label: const Text(
                        'Tambah Biaya',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.purple,
                        side: BorderSide(color: Colors.purple.withOpacity(0.5)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),

                  if (_biayaTambahan.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.purple.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.summarize_outlined,
                            color: Colors.purple,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Total Biaya Tambahan',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const Spacer(),
                          Text(
                            _formatRupiah(_totalBiayaTambahan),
                            style: const TextStyle(
                              color: Colors.purple,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),

              // ══════════════════════════════════════════════════════════
              // GROUP DISKON — di atas card pembayaran
              // ══════════════════════════════════════════════════════════
              _buildCardGroup(
                title: 'Diskon',
                icon: Icons.local_offer_outlined,
                isDark: isDark,
                trailingWidget: _diskonNominal > 0
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '- ${_formatRupiah(_diskonNominal)}',
                          style: TextStyle(
                            color: Colors.red.shade600,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    : null,
                children: [
                  // ── Tombol/card diskon — selalu sebagai button ──────
                  GestureDetector(
                    onTap: _showDiskonSheet,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: _diskonNominal > 0
                            ? Colors.red.withOpacity(0.05)
                            : Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _diskonNominal > 0
                              ? Colors.red.withOpacity(0.4)
                              : Theme.of(context).dividerColor,
                          width: _diskonNominal > 0 ? 1.5 : 1,
                        ),
                      ),
                      child: _diskonNominal == 0
                          ? Row(
                              children: [
                                Icon(
                                  Icons.local_offer_outlined,
                                  color: Colors.red.shade400,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Tambahkan Diskon',
                                  style: TextStyle(
                                    color: Theme.of(context).hintColor,
                                    fontSize: 14,
                                  ),
                                ),
                                const Spacer(),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  color: Theme.of(context).hintColor,
                                ),
                              ],
                            )
                          : Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.local_offer_rounded,
                                    color: Colors.red.shade500,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '- ${_formatRupiah(_diskonNominal)}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: Colors.red.shade600,
                                        ),
                                      ),
                                      if (_diskonCatatan.isNotEmpty)
                                        Text(
                                          _diskonCatatan,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Theme.of(context).hintColor,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Ubah',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.red.shade500,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),

                  // Preview kalkulasi diskon jika sudah diisi
                  if (_diskonNominal > 0) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.withOpacity(0.15)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Subtotal',
                                style: Theme.of(
                                  context,
                                ).textTheme.bodySmall?.copyWith(fontSize: 12),
                              ),
                              Text(
                                _formatRupiah(_grandTotalSebelumDiskon),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Diskon',
                                style: TextStyle(
                                  color: Colors.red.shade400,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                '- ${_formatRupiah(_diskonNominal)}',
                                style: TextStyle(
                                  color: Colors.red.shade400,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          Divider(
                            height: 14,
                            color: Colors.red.withOpacity(0.2),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Total Akhir',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: kPrimary,
                                ),
                              ),
                              Text(
                                _formatRupiah(_grandTotalFinal),
                                style: TextStyle(
                                  color: kPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),

              // ── GROUP 3: PEMBAYARAN ───────────────────────────────────
              _buildCardGroup(
                title: 'Pembayaran',
                icon: Icons.payments_outlined,
                isDark: isDark,
                children: [
                  Text(
                    'Status Pembayaran',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: kPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildBayarChip(
                        'belum_bayar',
                        'Bayar Akhir',
                        Icons.schedule_outlined,
                        Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      _buildBayarChip(
                        'dp',
                        'DP',
                        Icons.payments_outlined,
                        Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      _buildBayarChip(
                        'lunas',
                        'Lunas',
                        Icons.check_circle_outline,
                        Colors.green,
                      ),
                    ],
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    child: _statusBayar == 'dp'
                        ? Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: TextFormField(
                              controller: _dpCtrl,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                CurrencyInputFormatter(),
                              ],
                              style: TextStyle(
                                color: isDark ? Colors.white : kTextDark,
                                fontSize: 14,
                              ),
                              validator: (v) {
                                if (_statusBayar == 'dp' &&
                                    (v == null || v.isEmpty)) {
                                  return 'Nominal DP tidak boleh kosong';
                                }
                                return null;
                              },
                              decoration: InputDecoration(
                                hintText: 'Nominal DP',
                                prefixIcon: SizedBox(
                                  width: 48,
                                  child: Center(
                                    child: Text(
                                      'Rp',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.orange,
                                      ),
                                    ),
                                  ),
                                ),
                                prefixIconConstraints: const BoxConstraints(
                                  minWidth: 48,
                                  minHeight: 48,
                                ),
                                filled: true,
                                fillColor: Colors.orange.withOpacity(0.05),
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 15,
                                  horizontal: 16,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.orange.withOpacity(0.4),
                                    width: 1.5,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Colors.orange,
                                    width: 2,
                                  ),
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Colors.red,
                                    width: 1,
                                  ),
                                ),
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 14),
                  _buildStatusTopologi(),
                ],
              ),

              const SizedBox(height: 24),

              // Tombol simpan
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    elevation: 2,
                  ),
                  onPressed: _isSubmitting ? null : _submitData,
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long_outlined, size: 20),
                            SizedBox(width: 10),
                            Text(
                              'SIMPAN & LIHAT ORDER',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  Widget _buildCardGroup({
    required String title,
    required IconData icon,
    required List<Widget> children,
    required bool isDark,
    Widget? trailingWidget,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: isDark
            ? null
            : Border.all(color: const Color(0xFFE5E7EB), width: 1),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.3)
                : Colors.black.withOpacity(0.06),
            blurRadius: isDark ? 12 : 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: kPrimary, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: kPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (trailingWidget != null) ...[const Spacer(), trailingWidget],
            ],
          ),
          Divider(height: 24, color: Theme.of(context).dividerColor),
          ...children,
        ],
      ),
    );
  }

  Widget _buildBayarChip(
    String value,
    String label,
    IconData icon,
    Color color,
  ) {
    final isSelected = _statusBayar == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _statusBayar = value;
          if (value != 'dp') _dpCtrl.clear();
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? color : color.withOpacity(0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : color.withOpacity(0.3),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 18, color: isSelected ? Colors.white : color),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniPill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildStatusTopologi() {
    final steps = [
      {
        'label': 'Antrian',
        'icon': Icons.queue_outlined,
        'color': Colors.orange,
      },
      {
        'label': 'Proses',
        'icon': Icons.local_laundry_service_outlined,
        'color': Colors.blue,
      },
      {
        'label': 'Selesai',
        'icon': Icons.done_all_outlined,
        'color': Colors.teal,
      },
      {
        'label': 'Bayar',
        'icon': Icons.payment_outlined,
        'color': Colors.purple,
      },
      {
        'label': 'Ambil',
        'icon': Icons.shopping_bag_outlined,
        'color': Colors.green,
      },
    ];
    return Row(
      children: steps.asMap().entries.map((entry) {
        final i = entry.key;
        final s = entry.value;
        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: (s['color'] as Color).withOpacity(0.12),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: (s['color'] as Color).withOpacity(0.4),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        s['icon'] as IconData,
                        color: s['color'] as Color,
                        size: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      s['label'] as String,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: s['color'] as Color,
                      ),
                    ),
                  ],
                ),
              ),
              if (i < steps.length - 1)
                Container(
                  width: 10,
                  height: 1,
                  color: Theme.of(context).dividerColor,
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  int _toInt(dynamic val) {
    if (val == null) return 0;
    if (val is int) return val;
    if (val is double) return val.round();
    if (val is num) return val.toInt();
    try {
      return int.parse(val.toString().replaceAll(RegExp(r'[^0-9]'), ''));
    } catch (_) {
      return 0;
    }
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  BOTTOM SHEET: Pilih Layanan
// ════════════════════════════════════════════════════════════════════════════
class _LayananPickerSheet extends StatefulWidget {
  final List<Layanan> layananList;
  final void Function(Layanan) onSelected;
  const _LayananPickerSheet({
    required this.layananList,
    required this.onSelected,
  });

  @override
  State<_LayananPickerSheet> createState() => _LayananPickerSheetState();
}

class _LayananPickerSheetState extends State<_LayananPickerSheet> {
  String _filterTipe = 'semua';

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
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final filtered = _filterTipe == 'semua'
        ? widget.layananList
        : widget.layananList.where((l) => l.tipe == _filterTipe).toList();

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

// ════════════════════════════════════════════════════════════════════════════
//  BOTTOM SHEET: Input Detail Item
// ════════════════════════════════════════════════════════════════════════════
class _ItemDetailSheet extends StatefulWidget {
  final Layanan layanan;
  final void Function(Map<String, dynamic>) onAdd;
  const _ItemDetailSheet({required this.layanan, required this.onAdd});

  @override
  State<_ItemDetailSheet> createState() => _ItemDetailSheetState();
}

class _ItemDetailSheetState extends State<_ItemDetailSheet> {
  double _jumlah = 1.0;
  final _catatanCtrl = TextEditingController();
  final _jumlahPakaianCtrl = TextEditingController(text: '0');

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
    final now = DateTime.now();
    final selesai = now.add(Duration(hours: widget.layanan.durasiJam));
    return DateFormat('dd-MM-yyyy').format(selesai);
  }

  Future<void> _showKalkulator() async {
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
                  child: const Text('🧮', style: TextStyle(fontSize: 18)),
                ),
                const SizedBox(width: 10),
                Text(
                  'Kalkulator P × L',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(ctx).textTheme.bodyLarge?.color,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _kalkulatorField(ctx, pCtrl, 'Panjang (meter)', 'm', hitung),
                const SizedBox(height: 12),
                _kalkulatorField(ctx, lCtrl, 'Lebar (meter)', 'm', hitung),
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
                          color: Theme.of(ctx).textTheme.bodySmall?.color,
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
                          '≈ ${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format((widget.layanan.harga * hasil).round())}',
                          style: const TextStyle(
                            color: kPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Harga: Rp ${NumberFormat('#,###', 'id_ID').format(widget.layanan.harga.round())} / meter²',
                          style: TextStyle(
                            color: Theme.of(ctx).textTheme.bodySmall?.color,
                            fontSize: 11,
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
                  style: TextStyle(color: Theme.of(ctx).hintColor),
                ),
              ),
              ElevatedButton(
                onPressed: hasil > 0
                    ? () {
                        final nilaiRapi = double.parse(
                          hasilDouble!.toStringAsFixed(2),
                        );
                        setState(() => _jumlah = nilaiRapi);
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
  }

  Widget _kalkulatorField(
    BuildContext ctx,
    TextEditingController ctrl,
    String label,
    String suffix,
    VoidCallback onChange,
  ) {
    return TextField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
      ],
      onChanged: (_) => onChange(),
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        filled: true,
        fillColor: Theme.of(ctx).scaffoldBackgroundColor,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kPrimary, width: 2),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _catatanCtrl.dispose();
    _jumlahPakaianCtrl.dispose();
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
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      if (_jumlah > _min) {
                        setState(
                          () => _jumlah = double.parse(
                            (_jumlah - _step).toStringAsFixed(2),
                          ),
                        );
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
                    child: Center(
                      child: RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: jumlahStr,
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            TextSpan(
                              text: '  $satuan',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(
                      () => _jumlah = double.parse(
                        (_jumlah + _step).toStringAsFixed(2),
                      ),
                    ),
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
                  onPressed: _showKalkulator,
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
            const SizedBox(height: 20),
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
                  _formatRupiah(_subtotal),
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

String _formatRupiah(dynamic val) {
  try {
    final n = val is num ? val.toInt() : int.parse(val.toString());
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(n);
  } catch (_) {
    return 'Rp $val';
  }
}

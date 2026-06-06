import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'screens.dart';
// import _LayananPickerSheet & _ItemDetailSheet

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

  // ── Items (multi layanan, sama seperti OrderDetailScreen) ─────────────────
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _biayaTambahan = [];

  int get _totalBiayaTambahan => _biayaTambahan.fold(0, (sum, b) {
    try {
      return sum + ((b['nominal'] as num).toInt() * (b['qty'] as num).toInt());
    } catch (_) {
      return sum;
    }
  });

  int get _grandTotalFinal => _grandTotal + _totalBiayaTambahan;

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

  // ── Grand total dari semua items ──────────────────────────────────────────
  int get _grandTotal => _items.fold(0, (sum, item) {
    try {
      final berat = (item['berat_kg'] as num).toDouble();
      final harga = (item['harga_satuan'] as num).toInt();
      return sum + (berat * harga).toInt();
    } catch (_) {
      return sum;
    }
  });

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

  // ── Buka picker layanan (sama persis dengan OrderDetailScreen) ────────────
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

  // ── biaya tambahan ────────────────────────────────────────────────────────────
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

              // Keterangan
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

              // Nominal
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

              // QTY stepper
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

              // Preview subtotal
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

  // ── Hapus item ────────────────────────────────────────────────────────────
  void _hapusItem(int idx) {
    setState(() => _items.removeAt(idx));
  }

  // ── dropdwon tanggal ────────────────────────────────────────────────────────────
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

              // Judul
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

              // Header bulan
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

              // Label hari
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

              // Grid tanggal
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

              // Preview jam jika ada pilihan
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

              // Tombol aksi
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

      // Generate nomor struk MDN
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

      // Simpan dokumen order utama
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
        'biaya': _grandTotal,
        'dp_amount': dpInt,
        'status_bayar': _statusBayar,
        'waktu_transaksi': FieldValue.serverTimestamp(),
      });

      if (!context.mounted) return;
      setState(() => _isSubmitting = false);

      final String tanggalStr = DateFormat(
        'dd MMM yyyy HH:mm',
      ).format(_waktuOrderFinal);

      // ── Data struk dengan KEY KONSISTEN ke ThermalPrinterService ──────────
      final Map<String, dynamic> strukData = {
        // Info outlet
        'nama_laundry': OutletSettings.namaMadeenalaundry,
        'alamat': OutletSettings.alamat,
        'no_hp_laundry': OutletSettings.noHpMadeenalaundry,
        // Info order
        'no_order': nomorStruk,
        'waktu': tanggalStr,
        'pelanggan': _selectedNama ?? '-',
        'no_hp': _selectedHp ?? '-',
        'admin': adminFinal,
        // Items (multi)
        'items': List<Map<String, dynamic>>.from(_items),
        // Biaya tambahan
        'biaya_tambahan': List<Map<String, dynamic>>.from(_biayaTambahan),
        // Total & bayar
        'grand_total': _grandTotalFinal,
        'dp_amount': dpInt,
        'sisa_tagihan': _statusBayar == 'lunas'
            ? 0
            : (_grandTotalFinal - dpInt).clamp(0, _grandTotalFinal),
        'sudah_lunas': _statusBayar == 'lunas',
        'estimasi': _estimasiTerpanjang,
        // Untuk tampilan dialog (backward compat)
        'nama': _selectedNama ?? '-',
        'nomor': nomorStruk,
        'hp': _selectedHp ?? '-',
        'status_bayar': _statusBayar,
        'dp': dpInt,
        'tanggal': tanggalStr,
        'tanggal_cetak': tanggalStr,
      };

      // Tampilkan struk visual
      _showStrukPopup(strukData);

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
      });
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

  // ── Struk visual (popup) ──────────────────────────────────────────────────
  Widget _buildStrukWidget(Map<String, dynamic> data) {
    final String nama = data['nama']?.toString() ?? '-';
    final String nomor = data['nomor']?.toString() ?? '-';
    final String hp = data['hp']?.toString() ?? '-';
    final List items = data['items'] as List? ?? [];
    final List biayaTambahanList = data['biaya_tambahan'] as List? ?? [];
    final int grandTotal = _toInt(data['grand_total']);
    final String estimasi = data['estimasi']?.toString() ?? '-';
    final String tanggal = data['tanggal']?.toString() ?? '-';
    final String admin = data['admin']?.toString() ?? '-';
    final String statusBayar =
        data['status_bayar']?.toString() ?? 'belum_bayar';
    final int dp = _toInt(data['dp']);
    final String namaToko = OutletSettings.namaMadeenalaundry;
    final String noHpToko = OutletSettings.noHpMadeenalaundry;

    String labelStatus;
    Color colorStatus;
    switch (statusBayar) {
      case 'lunas':
        labelStatus = 'LUNAS';
        colorStatus = Colors.green;
        break;
      case 'dp':
        labelStatus = 'DP';
        colorStatus = Colors.orange;
        break;
      default:
        labelStatus = 'BELUM BAYAR';
        colorStatus = Colors.red;
    }

    String satuan(String tipe) => tipe == 'kiloan'
        ? 'kg'
        : tipe == 'meter'
        ? 'm²'
        : 'pcs';

    int subtotalItem(Map item) {
      try {
        final b = (item['berat_kg'] as num).toDouble();
        final h = (item['harga_satuan'] as num).toInt();
        return (b * h).toInt();
      } catch (_) {
        return 0;
      }
    }

    String beratStr(dynamic berat) {
      final d = (berat as num?)?.toDouble() ?? 0;
      return d % 1 == 0
          ? d.toStringAsFixed(0)
          : NumberFormat('#,##0.##', 'id_ID').format(d);
    }

    // Hitung total biaya tambahan
    int totalBiayaTambahan = 0;
    for (final b in biayaTambahanList) {
      try {
        totalBiayaTambahan +=
            ((b['nominal'] as num).toInt() * (b['qty'] as num).toInt());
      } catch (_) {}
    }

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 320,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // HEADER
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              decoration: BoxDecoration(
                color: kPrimary,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    namaToko.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '📞 $noHpToko',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'STRUK PRODUKSI',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _dashedLine(),

            // INFO ORDER
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Column(
                children: [
                  _strukRow('No. Struk', nomor, bold: true),
                  _strukRow('Tanggal', tanggal),
                  _strukRow('Admin', admin),
                ],
              ),
            ),
            _dashedLine(),

            // DATA PELANGGAN
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'DATA PELANGGAN',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _strukRow('Nama', nama, bold: true),
                  _strukRow('No. HP', hp),
                ],
              ),
            ),
            _dashedLine(),

            // DETAIL ITEM-ITEM
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'DETAIL ORDER',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...items.asMap().entries.map((e) {
                    final i = e.key;
                    final item = e.value as Map;
                    final tipe = item['layanan_tipe']?.toString() ?? '';
                    final sat = satuan(tipe);
                    final sub = subtotalItem(item);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (items.length > 1)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(
                              'Item ${i + 1}',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        _strukRow(
                          'Layanan',
                          item['layanan_nama']?.toString() ?? '-',
                        ),
                        if ((item['jenis_pakaian']?.toString() ?? '')
                            .isNotEmpty)
                          _strukRow(
                            'Jenis',
                            item['jenis_pakaian']?.toString() ?? '-',
                          ),
                        _strukRow(
                          'Berat/Ukuran',
                          '${beratStr(item['berat_kg'])} $sat',
                        ),
                        _strukRow(
                          'Harga Satuan',
                          'Rp ${NumberFormat('#,###', 'id_ID').format((item['harga_satuan'] as num?)?.toInt() ?? 0)} / $sat',
                        ),
                        _strukRow(
                          'Subtotal',
                          NumberFormat.currency(
                            locale: 'id_ID',
                            symbol: 'Rp ',
                            decimalDigits: 0,
                          ).format(sub),
                        ),
                        if (i < items.length - 1)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 4),
                            child: Divider(height: 1, color: Colors.grey),
                          ),
                      ],
                    );
                  }),
                  _strukRow('Est. Selesai', estimasi, color: kPrimary),
                ],
              ),
            ),

            // BIAYA TAMBAHAN (jika ada)
            if (biayaTambahanList.isNotEmpty) ...[
              _dashedLine(),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'BIAYA TAMBAHAN',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...biayaTambahanList.map((b) {
                      final bMap = b as Map;
                      final nominal = (bMap['nominal'] as num).toInt();
                      final qty = (bMap['qty'] as num).toInt();
                      final subtotal = nominal * qty;
                      return _strukRow(
                        '${bMap['keterangan']} (${qty}×)',
                        NumberFormat.currency(
                          locale: 'id_ID',
                          symbol: 'Rp ',
                          decimalDigits: 0,
                        ).format(subtotal),
                      );
                    }),
                    _strukRow(
                      'Total Tambahan',
                      NumberFormat.currency(
                        locale: 'id_ID',
                        symbol: 'Rp ',
                        decimalDigits: 0,
                      ).format(totalBiayaTambahan),
                      bold: true,
                      color: Colors.purple,
                    ),
                  ],
                ),
              ),
            ],

            _dashedLine(),

            // TOTAL & STATUS
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'TOTAL',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        NumberFormat.currency(
                          locale: 'id_ID',
                          symbol: 'Rp ',
                          decimalDigits: 0,
                        ).format(grandTotal),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: kPrimary,
                        ),
                      ),
                    ],
                  ),
                  if (statusBayar == 'dp' && dp > 0) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'DP Dibayar',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        Text(
                          NumberFormat.currency(
                            locale: 'id_ID',
                            symbol: 'Rp ',
                            decimalDigits: 0,
                          ).format(dp),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Sisa',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        Text(
                          NumberFormat.currency(
                            locale: 'id_ID',
                            symbol: 'Rp ',
                            decimalDigits: 0,
                          ).format((grandTotal - dp).clamp(0, grandTotal)),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Status Bayar',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: colorStatus.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: colorStatus.withOpacity(0.4),
                          ),
                        ),
                        child: Text(
                          labelStatus,
                          style: TextStyle(
                            color: colorStatus,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Status Order',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.orange.withOpacity(0.4),
                          ),
                        ),
                        child: const Text(
                          'ANTRIAN',
                          style: TextStyle(
                            color: Colors.orange,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            _dashedLine(),

            // FOOTER
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Column(
                children: [
                  Text(
                    'Terima kasih telah mempercayakan\ncucian Anda kepada $namaToko',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '★ Simpan struk ini sebagai bukti pengambilan ★',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      color: kPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dashedLine() {
    return Row(
      children: List.generate(
        40,
        (i) => Expanded(
          child: Container(
            height: 1,
            color: i % 2 == 0 ? Colors.grey.shade300 : Colors.transparent,
          ),
        ),
      ),
    );
  }

  Widget _strukRow(
    String label,
    String value, {
    bool bold = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          const Text(': ', style: TextStyle(color: Colors.grey)),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                color: color ?? Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showStrukPopup(Map<String, dynamic> data) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: SingleChildScrollView(child: _buildStrukWidget(data)),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _showCetakDialog(data);
                },
                icon: const Icon(Icons.print_outlined, size: 22),
                label: const Text(
                  'Print Struk',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text(
                'Tutup',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCetakDialog(Map<String, dynamic> data) {
    // ── Ambil semua field dari data (key konsisten) ────────────────────────
    final String nama = data['pelanggan']?.toString() ?? '-';
    final String nomor = data['no_order']?.toString() ?? '-';
    final String hp = data['no_hp']?.toString() ?? '-';
    final String tanggal = data['waktu']?.toString() ?? '-';
    final String admin = data['admin']?.toString() ?? '-';
    final String estimasi = data['estimasi']?.toString() ?? '-';
    final int grandTotal = _toInt(data['grand_total']);
    final int dp = _toInt(data['dp_amount']);
    final bool sudahLunas = data['sudah_lunas'] == true;
    final int sisa = _toInt(data['sisa_tagihan']);

    final List<Map<String, dynamic>> itemsTyped = (data['items'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    final List<Map<String, dynamic>> biayaTambahanList =
        (data['biaya_tambahan'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Header
                Text(
                  OutletSettings.namaMadeenalaundry,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  OutletSettings.alamat,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  'Telp: ${OutletSettings.noHpMadeenalaundry}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Text(
                  '══════════════════════════',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  'STRUK CUSTOMER',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  '══════════════════════════',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),

                // Info order
                Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _cetakRow('No', nomor),
                      _cetakRow('Tgl', tanggal),
                      _cetakRow('Pelanggan', nama),
                      _cetakRow('HP', hp.isNotEmpty ? hp : '-'),
                    ],
                  ),
                ),
                const Divider(),

                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'LAYANAN',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Divider(),

                // Multi-item
                ...itemsTyped.asMap().entries.map((entry) {
                  final i = entry.key;
                  final item = entry.value;
                  final tipe = item['layanan_tipe']?.toString() ?? '';
                  final satuan = tipe == 'kiloan'
                      ? 'kg'
                      : tipe == 'meter'
                      ? 'm²'
                      : 'pcs';
                  final berat = item['berat_kg'];
                  final harga = item['harga_satuan'];
                  int subtotal = 0;
                  try {
                    subtotal =
                        ((berat as num).toDouble() * (harga as num).toInt())
                            .toInt();
                  } catch (_) {}
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${i + 1}. ${item['layanan_nama'] ?? '-'}',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '   $berat $satuan   ${_formatRupiah(harga)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Text(
                            '   = ${_formatRupiah(subtotal)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  );
                }),

                // Biaya tambahan (jika ada)
                if (biayaTambahanList.isNotEmpty) ...[
                  const Divider(),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'BIAYA TAMBAHAN',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Divider(),
                  ...biayaTambahanList.map((b) {
                    final nominal = _toInt(b['nominal']);
                    final qty = _toInt(b['qty'] ?? 1);
                    final subtotal = nominal * qty;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${b['keterangan']} (${qty}×)',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            Text(
                              '   = ${_formatRupiah(subtotal)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],

                const Divider(),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TOTAL: ${_formatRupiah(grandTotal)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dibayar: ${dp > 0 ? _formatRupiah(dp) : 'Rp 0'}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        'Sisa: ${_formatRupiah(sisa)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        'Status: ${sudahLunas ? 'LUNAS' : 'BELUM LUNAS'}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: sudahLunas ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Est Selesai: $estimasi',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                Text(
                  '══════════════════════════',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Terima kasih.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        'Dicetak oleh: $admin',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: kPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Tutup'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PrintScreen(
                                // Teruskan seluruh data (sudah key konsisten)
                                data: data,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.print, size: 16),
                        label: const Text('Cetak'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
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
      ),
    );
  }

  // Helper row untuk dialog cetak
  Widget _cetakRow(String label, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Text(': ', style: Theme.of(context).textTheme.bodySmall),
          Expanded(
            child: Text(
              val,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
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
                  // List item yang sudah ditambahkan
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
                                // Tombol hapus
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

                  // Tombol tambah layanan (SAMA PERSIS dengan OrderDetailScreen)
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

                  // Total preview (muncul jika ada item)
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
                    // Estimasi selesai
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

              // ── GROUP TANGGAL ORDER ───────────────────────────────────────────────
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

              // ── GROUP BIAYA TAMBAHAN ──────────────────────────────────────────────
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
                            Icon(
                              Icons.receipt_outlined,
                              size: 36,
                              color: Colors.grey.shade300,
                            ),
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

                  // Total biaya tambahan
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
              // ── GROUP 3: PEMBAYARAN ───────────────────────────────────
              _buildCardGroup(
                title: 'Pembayaran',
                icon: Icons.payments_outlined,
                isDark: isDark,
                children: [
                  // Status bayar
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

                  // Kolom DP (AnimatedSize)
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

                  // Topologi status
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
                              'SIMPAN & CETAK STRUK',
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

  Widget _buildDatePicker(bool isDark) {
    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, 1);
    final lastDay = DateTime(now.year, now.month + 1, 0);
    final totalDays = lastDay.day;
    // Senin = 0 ... Minggu = 6 (offset awal)
    final startWeekday = (firstDay.weekday - 1) % 7;

    const dayLabels = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

    return Column(
      children: [
        // Header bulan
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_month_outlined, color: kPrimary, size: 16),
            const SizedBox(width: 6),
            Text(
              DateFormat('MMMM yyyy', 'id_ID').format(now),
              style: TextStyle(
                color: kPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Label hari
        Row(
          children: dayLabels
              .map(
                (d) => Expanded(
                  child: Center(
                    child: Text(
                      d,
                      style: TextStyle(
                        fontSize: 10,
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
        const SizedBox(height: 6),
        // Grid tanggal
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
                _customTanggal != null &&
                _customTanggal!.day == day &&
                _customTanggal!.month == now.month &&
                _customTanggal!.year == now.year;
            final isSunday = date.weekday == DateTime.sunday;

            return GestureDetector(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _customTanggal = null;
                  } else {
                    _customTanggal = date;
                  }
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.all(1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? kPrimary
                      : isToday
                      ? kPrimary.withOpacity(0.12)
                      : Colors.transparent,
                  shape: BoxShape.circle,
                  border: isToday && !isSelected
                      ? Border.all(color: kPrimary.withOpacity(0.5), width: 1)
                      : null,
                ),
                child: Center(
                  child: Text(
                    '$day',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected || isToday
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isSelected
                          ? Colors.white
                          : isSunday
                          ? Colors.red.shade400
                          : isDark
                          ? Colors.white70
                          : Colors.black87,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
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

  // ── Helper _toInt (tambahkan di class _AddOrderScreenState) ───────────────
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
          Text(
            'Pilih Layanan',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // Filter chips
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

          // List layanan
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
//  BOTTOM SHEET: Input Detail Item (berat/jumlah + catatan + kalkulator)
// ════════════════════════════════════════════════════════════════════════════
class _ItemDetailSheet extends StatefulWidget {
  final Layanan layanan;
  final void Function(Map<String, dynamic>) onAdd;
  const _ItemDetailSheet({required this.layanan, required this.onAdd});

  @override
  State<_ItemDetailSheet> createState() => _ItemDetailSheetState();
}

class _ItemDetailSheetState extends State<_ItemDetailSheet> {
  // FIX: gunakan double agar nilai desimal (2.4) tersimpan dengan benar
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

  // ── Kalkulator P × L ─────────────────────────────────────────────────────
  Future<void> _showKalkulator() async {
    final pCtrl = TextEditingController();
    final lCtrl = TextEditingController();
    // FIX: gunakan double? agar nilai kalkulator dapat disimpan sepenuhnya
    double? hasilDouble;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          void hitung() {
            final p = double.tryParse(pCtrl.text) ?? 0;
            final l = double.tryParse(lCtrl.text) ?? 0;
            // FIX: simpan hasil penuh sebagai double, bukan diformat
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
                              // FIX: tampilkan dengan format desimal yang benar
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
                        // FIX UTAMA: Simpan nilai double penuh (2.4), bukan dibulatkan ke int
                        // Gunakan hasilDouble langsung, bukan parse dari string yang diformat
                        final nilaiAsli = hasilDouble!;
                        // Bulatkan ke 2 desimal saja
                        final nilaiRapi = double.parse(
                          nilaiAsli.toStringAsFixed(2),
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
    // FIX: tampilkan sesuai tipe — desimal untuk kiloan & meter, bulat untuk satuan
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

            // Header
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

            // Jumlah / Berat
            Text(
              'Jumlah / Berat',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),

            // Stepper
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  // Minus
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
                  // Nilai
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
                  // Plus
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

            // Kalkulator P × L (hanya jika meter)
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

            // Catatan
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

            // Jumlah Pakaian (opsional)
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

            // Subtotal
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

            // Tombol Tambah ke Order
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => widget.onAdd({
                  'layanan_nama': widget.layanan.nama,
                  'layanan_tipe': widget.layanan.tipe,
                  'layanan_id': widget.layanan.id,
                  'jenis_pakaian': '',
                  // FIX: kirim sebagai double agar nilai desimal (2.4) tidak terpotong
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

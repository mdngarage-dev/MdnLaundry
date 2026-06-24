import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:mdnlaundry_project/screens/settings/outlet/wa_settings.dart';
import '../main_screens.dart';

// ════════════════════════════════════════════════════════════════════════════
//  ORDER DETAIL SCREEN
// ════════════════════════════════════════════════════════════════════════════
class OrderDetailScreen extends StatefulWidget {
  final String storeId;
  final String outletId;
  final String docId;
  final Map<String, dynamic> data;
  const OrderDetailScreen({
    super.key,
    required this.docId,
    required this.data,
    required this.storeId,
    required this.outletId,
  });

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late Map<String, dynamic> _data;
  bool _statusExpanded = false;
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _biayaTambahan = [];
  bool _isLoadingItems = true;

  @override
  void initState() {
    super.initState();
    _data = Map.from(widget.data);
    _loadItemsFromFirestore();
  }

  // ── Popup pilih rak saat "Selesai Dicuci" ────────────────────────────────
  void _showPilihRakDialog(String newStatus) {
    showDialog(
      context: context,
      builder: (ctx) => _PilihRakDialog(
        storeId: widget.storeId,
        outletId: widget.outletId,
        onRakSelected: (rakId, rakNama) async {
          Navigator.pop(ctx);
          await _updateStatusDenganRak(newStatus, rakId, rakNama);
        },
      ),
    );
  }

  Future<void> _updateStatusDenganRak(
    String newStatus,
    String rakId,
    String rakNama,
  ) async {
    await FirebaseFirestore.instance
        .collection('order')
        .doc(widget.docId)
        .update({
          'status': newStatus,
          'rak_id': rakId,
          'rak_nama': rakNama,
          'waktu_masuk_rak': FieldValue.serverTimestamp(),
        });
    if (!mounted) return;
    setState(() {
      _data['status'] = newStatus;
      _data['rak_id'] = rakId;
      _data['rak_nama'] = rakNama;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Status diperbarui: $newStatus · Rak: $rakNama'),
        backgroundColor: _statusColor(newStatus),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Kirim notifikasi WA: cucian siap diambil ──────────────────────────────
  Future<void> _kirimNotifikasiSiapAmbil(String rakNama) async {
    final mode = await WaSettings.getMode();

    if (mode == 'off') return; // tidak lakukan apa-apa

    if (_noHp.isEmpty) return; // tidak ada nomor HP pelanggan

    // Bersihkan & format nomor HP
    String hp = _noHp.replaceAll(RegExp(r'[^0-9]'), '');
    if (hp.startsWith('0')) hp = '62${hp.substring(1)}';
    if (!hp.startsWith('62')) hp = '62$hp';

    final trackingUrl = 'https://laundry-ku-id.web.app/$_noPelanggan';
    final totalFmt = _formatRupiah(_grandTotal);
    final sisaFmt = _formatRupiah(_sisaTagihan);

    final infoBayar = _sudahLunas ? '✅ Lunas' : '💳 Sisa Tagihan: $sisaFmt';

    final pesan =
        'Halo, *$_namaPelangganStr* 👋\n\n'
        '🎉 Laundry Anda sudah *selesai* dan siap diambil!\n\n'
        '📋 *Detail Order:*\n'
        '• No. Order    : *$_noPelanggan*\n'
        '• Layanan      : ${_data['layanan_nama'] ?? '-'}\n'
        '• Total           : *$totalFmt*\n'
        '• Pembayaran: $infoBayar\n'
        '🔍 *Lacak status order Anda:*\n'
        '$trackingUrl\n\n'
        'Silakan diambil di outlet kami. Terima kasih! 🙏\n'
        'Jika antar jemput silahkan konfimrasi saat berada di rumah\n\n'
        '_Madeena Laundry_';

    if (mode == 'auto') {
      final token = await WaSettings.getToken();
      if (token.isEmpty) {
        await _bukaWaManualDetail(hp, pesan);
        return;
      }
      try {
        final res = await http.post(
          Uri.parse('https://api.fonnte.com/send'),
          headers: {'Authorization': token},
          body: {'target': hp, 'message': pesan},
        );
        final json = jsonDecode(res.body);
        if (mounted && json['status'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.send, color: Colors.white, size: 16),
                  SizedBox(width: 8),
                  Text('Notifikasi WA terkirim otomatis'),
                ],
              ),
              backgroundColor: const Color(0xFF25D366),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      } catch (e) {
        await _bukaWaManualDetail(hp, pesan); // fallback kalau error
      }
    } else {
      // mode == 'manual'
      await _bukaWaManualDetail(hp, pesan);
    }
  }

  Future<void> _bukaWaManualDetail(String hp, String pesan) async {
    final encoded = Uri.encodeComponent(pesan);
    final url = Uri.parse('https://wa.me/$hp?text=$encoded');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  // ── Getter langsung dari dokumen order ────────────────────────────────────
  String get _noPelanggan => _data['nomor_pelanggan']?.toString() ?? '-';
  String get _namaPelangganStr {
    final nama = _data['nama_pelanggan']?.toString() ?? '';
    return nama.isNotEmpty ? nama : _noPelanggan;
  }

  String get _noHp => _data['no_hp']?.toString() ?? '';
  String get _status => _data['status']?.toString() ?? '-';
  String get _estimasi => _data['estimasi_selesai']?.toString() ?? '-';
  String get _admin => _data['admin']?.toString() ?? '-';

  Timestamp? get _waktuOrder => _data['waktu_order'] is Timestamp
      ? _data['waktu_order'] as Timestamp
      : null;

  String get _tanggalStr {
    final ts = _waktuOrder;
    if (ts == null) return '-';
    return DateFormat('dd MMM yyyy').format(ts.toDate());
  }

  String get _jamStr {
    final ts = _waktuOrder;
    if (ts == null) return '-';
    return DateFormat('HH:mm').format(ts.toDate());
  }

  String get _waktuStr {
    final ts = _waktuOrder;
    if (ts == null) return '-';
    return DateFormat('dd MMM yyyy HH:mm').format(ts.toDate());
  }

  // ── Load items + biaya_tambahan dari Firestore ────────────────────────────

  Future<void> _loadItemsFromFirestore() async {
    setState(() => _isLoadingItems = true);
    try {
      final orderRef = FirebaseFirestore.instance
          .collection('order')
          .doc(widget.docId);

      // Load items
      final itemsSnap = await orderRef
          .collection('items')
          .orderBy('created_at', descending: false)
          .get();

      List<Map<String, dynamic>> loadedItems;
      if (itemsSnap.docs.isNotEmpty) {
        loadedItems = itemsSnap.docs
            .map(
              (d) => Map<String, dynamic>.from(d.data()..['_itemDocId'] = d.id),
            )
            .toList();
      } else {
        loadedItems = [_buildItemFromData(_data)];
      }

      // Load biaya_tambahan ← BARU
      final biayaSnap = await orderRef
          .collection('biaya_tambahan')
          .orderBy('created_at', descending: false)
          .get();

      final loadedBiaya = biayaSnap.docs
          .map(
            (d) => Map<String, dynamic>.from(d.data()..['_biayaDocId'] = d.id),
          )
          .toList();

      setState(() {
        _items = loadedItems;
        _biayaTambahan = loadedBiaya;
        _isLoadingItems = false;
      });
    } catch (e) {
      setState(() {
        _items = [_buildItemFromData(_data)];
        _biayaTambahan = [];
        _isLoadingItems = false;
      });
    }
  }

  Map<String, dynamic> _buildItemFromData(Map<String, dynamic> d) {
    return {
      'layanan_nama': d['layanan_nama']?.toString() ?? '-',
      'layanan_tipe': d['layanan_tipe']?.toString() ?? '',
      'jenis_pakaian': d['jenis_pakaian']?.toString() ?? '',
      'berat_kg': d['berat_kg'],
      'harga_satuan': d['harga_satuan'],
      'estimasi_selesai': d['estimasi_selesai']?.toString() ?? '-',
      'catatan': d['catatan']?.toString() ?? '',
    };
  }

  int _itemTotal(Map<String, dynamic> item) {
    try {
      final berat = item['berat_kg'] is num
          ? (item['berat_kg'] as num).toDouble()
          : double.parse(item['berat_kg'].toString());
      final harga = item['harga_satuan'] is num
          ? (item['harga_satuan'] as num).toInt()
          : int.parse(item['harga_satuan'].toString());
      return (berat * harga).toInt();
    } catch (_) {
      return 0;
    }
  }

  // Total layanan saja (tanpa biaya tambahan)
  int get _totalLayanan =>
      _items.fold(0, (sum, item) => sum + _itemTotal(item));

  // Total biaya tambahan
  int get _totalBiayaTambahan => _biayaTambahan.fold(0, (sum, b) {
    try {
      final nominal = b['nominal'] is num
          ? (b['nominal'] as num).toInt()
          : int.parse(b['nominal'].toString());
      final qty = b['qty'] is num
          ? (b['qty'] as num).toInt()
          : int.parse((b['qty'] ?? 1).toString());
      return sum + (nominal * qty);
    } catch (_) {
      return sum;
    }
  });

  // Grand total = layanan + biaya tambahan ← DIPERBAIKI
  // Subtotal sebelum diskon
  int get _subtotalSebelumDiskon => _totalLayanan + _totalBiayaTambahan;

  // Grand total final setelah diskon (sinkron dengan add.dart → _grandTotalFinal)
  int get _grandTotal {
    final hasil = _subtotalSebelumDiskon - _diskonNominal;
    return hasil < 0 ? 0 : hasil;
  }

  bool get _sudahLunas =>
      (_data['status_bayar']?.toString() ?? '').toLowerCase() == 'lunas';

  int get _dpAmount {
    final dp = _data['dp_amount'];
    if (dp == null) return 0;
    try {
      return dp is num ? dp.toInt() : int.parse(dp.toString());
    } catch (_) {
      return 0;
    }
  }

  int get _sisaTagihan {
    if (_sudahLunas) return 0;
    final sisa = _grandTotal - _dpAmount;
    return sisa < 0 ? 0 : sisa;
  }

  // ── Getter diskon ──────────────────────────────────────────────────────────
  int get _diskonNominal {
    final d = _data['diskon_nominal'];
    if (d == null) return 0;
    try {
      return d is num ? d.toInt() : int.parse(d.toString());
    } catch (_) {
      return 0;
    }
  }

  String get _diskonCatatan => _data['diskon_catatan']?.toString() ?? '';

  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'antrian':
        return const Color(0xFF4F6FE8);
      case 'proses':
        return const Color(0xFFF59E0B);
      case 'siap ambil':
        return const Color(0xFF0D9488);
      case 'siap antar':
        return const Color(0xFF7C3AED);
      case 'selesai':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _statusIcon(String s) {
    switch (s.toLowerCase()) {
      case 'antrian':
        return Icons.hourglass_empty_rounded;
      case 'proses':
        return Icons.local_laundry_service_outlined;
      case 'siap ambil':
        return Icons.inventory_2_outlined;
      case 'siap antar':
        return Icons.local_shipping_outlined;
      case 'selesai':
        return Icons.check_circle_outline_rounded;
      default:
        return Icons.circle_outlined;
    }
  }

  static const _statusFlow = ['antrian', 'proses', 'siap ambil', 'selesai'];

  String? get _nextStatus {
    final idx = _statusFlow.indexOf(_status.toLowerCase());
    if (idx < 0 || idx >= _statusFlow.length - 1) return null;
    return _statusFlow[idx + 1];
  }

  String _nextStatusLabel() {
    switch (_nextStatus) {
      case 'proses':
        return 'Mulai Proses';
      case 'siap ambil':
        return 'Selesai Dicuci';
      case 'selesai':
        return 'Selesai (Sudah Diambil)';
      default:
        return _nextStatus ?? '';
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    await FirebaseFirestore.instance
        .collection('order')
        .doc(widget.docId)
        .update({'status': newStatus});
    if (!mounted) return;
    setState(() => _data['status'] = newStatus);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Status diperbarui: $newStatus'),
        backgroundColor: _statusColor(newStatus),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _bayar() async {
    await FirebaseFirestore.instance
        .collection('order')
        .doc(widget.docId)
        .update({'status_bayar': 'lunas'});
    if (!mounted) return;
    setState(() => _data['status_bayar'] = 'lunas');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Pembayaran berhasil dicatat sebagai Lunas'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── _shareWA juga diperbaiki — include biaya tambahan ─────────────────────
  Future<void> _shareWA() async {
    final noHp = _noHp;
    final totalFmt = _formatRupiah(_grandTotal);
    final sisaFmt = _formatRupiah(_sisaTagihan);
    final namaFmt = _namaPelangganStr;

    final StringBuffer detailBuffer = StringBuffer();
    for (int i = 0; i < _items.length; i++) {
      final item = _items[i];
      final nama = item['layanan_nama']?.toString() ?? '-';
      final tipe = item['layanan_tipe']?.toString() ?? '';
      final satuan = _satuanLabel(tipe);
      final berat = item['berat_kg'];
      final harga = item['harga_satuan'];
      final subtotal = _itemTotal(item);
      detailBuffer.writeln(
        '${i + 1}. $nama\n'
        '   $berat $satuan × ${_formatRupiah(harga)}\n'
        '   Subtotal: ${_formatRupiah(subtotal)}',
      );
    }

    // Biaya tambahan di WA ← BARU
    StringBuffer biayaBuffer = StringBuffer();
    if (_biayaTambahan.isNotEmpty) {
      biayaBuffer.writeln('━━━━━━━━━━━━━━━━━');
      biayaBuffer.writeln('*Biaya Tambahan:*');
      for (final b in _biayaTambahan) {
        final nominal = b['nominal'] is num
            ? (b['nominal'] as num).toInt()
            : int.tryParse(b['nominal'].toString()) ?? 0;
        final qty = b['qty'] is num
            ? (b['qty'] as num).toInt()
            : int.tryParse((b['qty'] ?? 1).toString()) ?? 1;
        final subtotal = nominal * qty;
        biayaBuffer.writeln(
          '• ${b['keterangan']} (${qty}×): ${_formatRupiah(subtotal)}',
        );
      }
    }

    final dpBaris = _dpAmount > 0
        ? '💵 DP / Uang Muka : ${_formatRupiah(_dpAmount)}\n'
        : '';

    final diskonBaris = _diskonNominal > 0
        ? '🏷️ Diskon         : - ${_formatRupiah(_diskonNominal)}' +
              (_diskonCatatan.isNotEmpty ? ' (${_diskonCatatan})' : '') +
              '\n'
        : '';

    final pesan =
        '🧺 *Informasi Order Laundry*\n'
        '━━━━━━━━━━━━━━━━━\n'
        '🪪 No Order       : $_noPelanggan\n'
        '👤 Nama           : $namaFmt\n'
        '📅 Estimasi       : $_estimasi\n'
        '📌 Status         : $_status\n'
        '━━━━━━━━━━━━━━━━━\n'
        '*Detail Layanan:*\n'
        '${detailBuffer.toString().trim()}\n'
        '${biayaBuffer.toString()}'
        '━━━━━━━━━━━━━━━━━\n'
        '${_diskonNominal > 0 ? '💰 Subtotal       : ${_formatRupiah(_subtotalSebelumDiskon)}\n' : ''}'
        '$diskonBaris'
        '💰 Total          : $totalFmt\n'
        '$dpBaris'
        '💳 Sisa Tagihan   : $sisaFmt\n'
        '━━━━━━━━━━━━━━━━━\n'
        'Terima kasih 🙏';

    final encoded = Uri.encodeComponent(pesan);
    final Uri uri = noHp.isNotEmpty
        ? Uri.parse(
            'https://wa.me/62${noHp.replaceFirst(RegExp(r'^0'), '')}?text=$encoded',
          )
        : Uri.parse('https://wa.me/?text=$encoded');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // ── Cetak Struk ── KEY KONSISTEN dengan ThermalPrinterService ─────────────
  void _cetak() {
    final tanggalCetak = DateFormat('dd MMM yyyy HH:mm').format(DateTime.now());
    final namaLaundry = OutletSettings.namaLaundry;
    final alamat = OutletSettings.alamat;
    final noHpLaundry = OutletSettings.noHpLaundry;
    final namaPelangganDisplay = PrinterSettings.namaPelangganBesar
        ? _namaPelangganStr.toUpperCase()
        : _namaPelangganStr;
    final noHpDisplay = PrinterSettings.sembunyikanNoHpPelanggan
        ? ''
        : (_noHp.isNotEmpty ? _noHp : '-');

    // ── Key harus cocok dengan ThermalPrinterService ──────────────
    final printData = {
      // ── Untuk printStruk (customer) ──
      'nama_laundry': namaLaundry,
      'alamat': PrinterSettings.tampilkanAlamatOutlet ? alamat : '',
      'no_hp_laundry': PrinterSettings.tampilkanNoHpOutlet ? noHpLaundry : '',
      'waktu': _waktuStr,
      'no_hp': noHpDisplay,
      'subtotal_sebelum_diskon': _subtotalSebelumDiskon,
      'diskon_nominal': _diskonNominal,
      'diskon_catatan': _diskonCatatan,
      'grand_total': _grandTotal,
      'dp_amount': _dpAmount,
      'sisa_tagihan': _sisaTagihan,
      'sudah_lunas': _sudahLunas,
      'admin': _admin,
      'tanggal_cetak': tanggalCetak,
      'rekening_list': PrinterSettings.rekeningList,
      'pesan_kaki': PrinterSettings.pesanKaki,

      // ── Key yang dipakai KEDUA jenis struk ──
      'no_order':
          _noPelanggan, // printStruk: no_order ✅  printStrukProduksi: no_order ✅
      'pelanggan':
          namaPelangganDisplay, // printStruk: pelanggan ✅  printStrukProduksi: pelanggan ✅
      'estimasi':
          _estimasi, // printStruk: estimasi ✅  printStrukProduksi: estimasi ✅
      'items': List<Map<String, dynamic>>.from(
        _items.map((e) {
          final m = Map<String, dynamic>.from(e)..remove('_itemDocId');
          // Pastikan field yang dibutuhkan printStrukProduksi ada:
          // layanan_nama ✅, layanan_tipe ✅, berat_kg ✅, catatan ✅
          // Pastikan field yang dibutuhkan printStruk ada:
          // layanan_nama ✅, layanan_tipe ✅, berat_kg ✅, harga_satuan ✅, catatan ✅
          return m;
        }),
      ),
      'biaya_tambahan': List<Map<String, dynamic>>.from(
        _biayaTambahan.map(
          (e) => Map<String, dynamic>.from(e)..remove('_biayaDocId'),
        ),
      ),
    };

    // ── Bottom sheet pilih jenis struk ──────────────────────────────
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
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
              'Pilih Jenis Struk',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Pilih struk yang ingin dicetak',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),

            _pilihStrukTile(
              icon: Icons.person_outline_rounded,
              color: Theme.of(context).colorScheme.primary,
              title: 'Struk Customer',
              subtitle: 'Total, status bayar, rekening pembayaran',
              onTap: () {
                Navigator.pop(ctx);
                _showPreviewStruk(
                  printData: printData,
                  jenisCetak: 'customer',
                  namaPelangganDisplay: namaPelangganDisplay,
                  noHpDisplay: noHpDisplay,
                );
              },
            ),
            const SizedBox(height: 12),

            _pilihStrukTile(
              icon: Icons.local_laundry_service_outlined,
              color: Colors.orange.shade700,
              title: 'Struk Produksi',
              subtitle:
                  'QR order, detail item, catatan cucian, estimasi selesai',
              onTap: () {
                Navigator.pop(ctx);
                _showPreviewStruk(
                  printData: printData,
                  jenisCetak: 'produksi',
                  namaPelangganDisplay: namaPelangganDisplay,
                  noHpDisplay: noHpDisplay,
                );
              },
            ),
            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(ctx),
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

  Widget _pilihStrukTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(fontSize: 11),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  void _showPreviewStruk({
    required Map<String, dynamic> printData,
    required String jenisCetak,
    required String namaPelangganDisplay,
    required String noHpDisplay,
  }) {
    final isProduksi = jenisCetak == 'produksi';
    final headerColor = isProduksi
        ? Colors.orange.shade700
        : Theme.of(context).colorScheme.primary;
    final ScrollController scrollController = ScrollController();

    final String noOrder = printData['no_order']?.toString() ?? '-';
    final String pelanggan = printData['pelanggan']?.toString() ?? '-';
    final String estimasi = printData['estimasi']?.toString() ?? '-';
    final List<Map<String, dynamic>> items = List<Map<String, dynamic>>.from(
      printData['items'] ?? [],
    );
    final List<Map<String, dynamic>> biayaTambahan =
        List<Map<String, dynamic>>.from(printData['biaya_tambahan'] ?? []);

    showDialog(
      context: context,
      builder: (ctx) {
        // ── Auto scroll ke atas setelah frame pertama ──────────────
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (scrollController.hasClients) {
            scrollController.jumpTo(0);
          }
        });

        return Dialog(
          backgroundColor: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          // ── Gunakan Column agar tombol sticky di bawah ───────────
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Konten struk yang bisa di-scroll ─────────────────
              Flexible(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // ── Badge jenis ──────────────────────────────────
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: headerColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: headerColor.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isProduksi
                                    ? Icons.local_laundry_service_outlined
                                    : Icons.person_outline_rounded,
                                size: 13,
                                color: headerColor,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                isProduksi
                                    ? 'Preview Struk Produksi'
                                    : 'Preview Struk Customer',
                                style: TextStyle(
                                  color: headerColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // ════════════════════════════════════════════════
                        // PREVIEW PRODUKSI
                        // ════════════════════════════════════════════════
                        if (isProduksi) ...[
                          Text(
                            'STRUK PRODUKSI',
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                          ),
                          const Divider(),

                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.qr_code_2_rounded,
                                  size: 48,
                                  color: Colors.grey.shade400,
                                ),
                                Text(
                                  'QR: $noOrder',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),

                          Text(
                            noOrder,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const Divider(),

                          Text(
                            'PELANGGAN :',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            pelanggan,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                            textAlign: TextAlign.center,
                          ),
                          const Divider(),

                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'INSTRUKSI CUCIAN :',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                          const Divider(),
                          ...items.asMap().entries.map((entry) {
                            final i = entry.key;
                            final item = entry.value;
                            final tipe = item['layanan_tipe']?.toString() ?? '';
                            final nama =
                                item['layanan_nama']?.toString() ?? '-';
                            final catatan = item['catatan']?.toString() ?? '';

                            String satuan;
                            switch (tipe) {
                              case 'kiloan':
                                satuan = 'kg';
                                break;
                              case 'meter':
                                satuan = 'm²';
                                break;
                              default:
                                satuan = 'pcs';
                                break;
                            }

                            final dynamic beratRaw = item['berat_kg'];
                            final double berat = beratRaw is num
                                ? beratRaw.toDouble()
                                : double.tryParse(beratRaw?.toString() ?? '') ??
                                      0;
                            final String beratStr = berat % 1 == 0
                                ? berat.toStringAsFixed(0)
                                : berat.toStringAsFixed(1);

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${i + 1}. $nama ($beratStr $satuan)',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    const SizedBox(height: 3),
                                    catatan.isNotEmpty
                                        ? Container(
                                            margin: const EdgeInsets.only(
                                              left: 12,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 5,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.orange.withOpacity(
                                                0.07,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              border: Border.all(
                                                color: Colors.orange
                                                    .withOpacity(0.25),
                                              ),
                                            ),
                                            child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Icon(
                                                  Icons.arrow_forward_rounded,
                                                  size: 11,
                                                  color: Colors.orange.shade600,
                                                ),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    catatan,
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .bodySmall
                                                        ?.copyWith(
                                                          fontSize: 11,
                                                        ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )
                                        : Padding(
                                            padding: const EdgeInsets.only(
                                              left: 12,
                                            ),
                                            child: Text(
                                              '(tidak ada catatan)',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    fontSize: 11,
                                                    color: Colors.grey.shade400,
                                                    fontStyle: FontStyle.italic,
                                                  ),
                                            ),
                                          ),
                                    if (i < items.length - 1)
                                      Divider(
                                        height: 16,
                                        color: Colors.grey.withOpacity(0.3),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          }),

                          const Divider(),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'EST. SELESAI :',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  estimasi,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),

                          // ════════════════════════════════════════════════
                          // PREVIEW CUSTOMER
                          // ════════════════════════════════════════════════
                        ] else ...[
                          Text(
                            OutletSettings.namaLaundry,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          if (PrinterSettings.tampilkanAlamatOutlet &&
                              OutletSettings.alamat.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              OutletSettings.alamat,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                          if (PrinterSettings.tampilkanNoHpOutlet &&
                              OutletSettings.noHpLaundry.isNotEmpty)
                            Text(
                              'Telp: ${OutletSettings.noHpLaundry}',
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
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '══════════════════════════',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 8),

                          Align(
                            alignment: Alignment.centerLeft,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _strRow('No', noOrder),
                                _strRow(
                                  'Tgl',
                                  printData['waktu']?.toString() ?? '-',
                                ),
                                _strRow('Pelanggan', namaPelangganDisplay),
                                if (!PrinterSettings.sembunyikanNoHpPelanggan)
                                  _strRow('HP', noHpDisplay),
                              ],
                            ),
                          ),
                          const Divider(),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'LAYANAN',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                          const Divider(),
                          ...items.asMap().entries.map((entry) {
                            final i = entry.key;
                            final item = entry.value;
                            final tipe = item['layanan_tipe']?.toString() ?? '';
                            final catatan = item['catatan']?.toString() ?? '';

                            String satuan;
                            switch (tipe) {
                              case 'kiloan':
                                satuan = 'kg';
                                break;
                              case 'meter':
                                satuan = 'm²';
                                break;
                              default:
                                satuan = 'pcs';
                                break;
                            }

                            final dynamic beratRaw = item['berat_kg'];
                            final double berat = beratRaw is num
                                ? beratRaw.toDouble()
                                : double.tryParse(beratRaw?.toString() ?? '') ??
                                      0;
                            final dynamic hargaRaw = item['harga_satuan'];
                            final int harga = hargaRaw is num
                                ? hargaRaw.toInt()
                                : int.tryParse(hargaRaw?.toString() ?? '') ?? 0;
                            final int subtotal = (berat * harga).round();

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${i + 1}. ${item['layanan_nama'] ?? '-'}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    Text(
                                      '   ${berat % 1 == 0 ? berat.toStringAsFixed(0) : berat.toStringAsFixed(1)} $satuan   ${_formatRupiah(harga)}',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                    Text(
                                      '   = ${_formatRupiah(subtotal)}',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                    if (catatan.isNotEmpty)
                                      Text(
                                        '   Catatan: $catatan',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              fontStyle: FontStyle.italic,
                                              color: Colors.grey.shade500,
                                            ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          }),

                          if (biayaTambahan.isNotEmpty) ...[
                            const Divider(),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'BIAYA TAMBAHAN',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                            const Divider(),
                            ...biayaTambahan.map((b) {
                              final int nominal = b['nominal'] is num
                                  ? (b['nominal'] as num).toInt()
                                  : int.tryParse(b['nominal'].toString()) ?? 0;
                              final int qty = b['qty'] is num
                                  ? (b['qty'] as num).toInt()
                                  : int.tryParse((b['qty'] ?? 1).toString()) ??
                                        1;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${b['keterangan']} (${qty}×)',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                      Text(
                                        '   = ${_formatRupiah(nominal * qty)}',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
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
                                if (biayaTambahan.isNotEmpty) ...[
                                  Text(
                                    'Layanan  : ${_formatRupiah(_totalLayanan)}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                  Text(
                                    'Biaya Tmb: ${_formatRupiah(_totalBiayaTambahan)}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                ],
                                if (_diskonNominal > 0) ...[
                                  Text(
                                    'Subtotal : ${_formatRupiah(_subtotalSebelumDiskon)}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                  Text(
                                    'Diskon   : - ${_formatRupiah(_diskonNominal)}'
                                    '${_diskonCatatan.isNotEmpty ? ' ($_diskonCatatan)' : ''}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(color: Colors.red.shade600),
                                  ),
                                ],
                                Text(
                                  'TOTAL    : ${_formatRupiah(_grandTotal)}',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
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
                                  _sudahLunas && _dpAmount == 0
                                      ? 'Dibayar : ${_formatRupiah(_grandTotal)}'
                                      : 'Dibayar : ${_dpAmount > 0 ? _formatRupiah(_dpAmount) : 'Rp 0'}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                Text(
                                  'Sisa    : ${_formatRupiah(_sisaTagihan)}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                Text(
                                  'Status  : ${_sudahLunas ? 'LUNAS' : 'BELUM LUNAS'}',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: _sudahLunas
                                            ? Colors.green
                                            : Colors.red,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          const Divider(),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Est Selesai : $estimasi',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                          if (PrinterSettings.rekeningList.isNotEmpty) ...[
                            Text(
                              '══════════════════════════',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            Text(
                              'PEMBAYARAN VIA',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            ...PrinterSettings.rekeningList.map((rek) {
                              final hasQr = (rek['qr_url'] ?? '').isNotEmpty;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Column(
                                  children: [
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            rek['nama_bank'] ?? '',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                          Text(
                                            rek['no_rekening'] ?? '',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodySmall,
                                          ),
                                          if ((rek['atas_nama'] ?? '')
                                              .isNotEmpty)
                                            Text(
                                              'a.n ${rek['atas_nama']}',
                                              style: Theme.of(
                                                context,
                                              ).textTheme.bodySmall,
                                            ),
                                        ],
                                      ),
                                    ),
                                    if (hasQr) ...[
                                      const SizedBox(height: 6),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: Image.network(
                                          rek['qr_url']!,
                                          width: 160,
                                          height: 160,
                                          fit: BoxFit.contain,
                                          loadingBuilder: (_, child, prog) =>
                                              prog == null
                                              ? child
                                              : const SizedBox(
                                                  width: 160,
                                                  height: 160,
                                                  child: Center(
                                                    child:
                                                        CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                        ),
                                                  ),
                                                ),
                                          errorBuilder: (_, __, ___) =>
                                              const Icon(
                                                Icons.qr_code_2_rounded,
                                                size: 60,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            }),
                          ],
                          Text(
                            '══════════════════════════',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          if (PrinterSettings.pesanKaki.isNotEmpty) ...[
                            Text(
                              PrinterSettings.pesanKaki,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 4),
                          ] else
                            Text(
                              'Terima kasih.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Dicetak oleh: $_admin',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ],

                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Tombol Tutup & Cetak — STICKY di bawah ───────────
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 8,
                      offset: const Offset(0, -3),
                    ),
                  ],
                ),
                child: Row(
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
                                data: printData,
                                jenisCetak: jenisCetak,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.print, size: 16),
                        label: const Text('Cetak'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: headerColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ).then((_) => scrollController.dispose());
  }

  // ── Konfirmasi Status ─────────────────────────────────────────────────────
  void _showKonfirmasiStatus(String newStatus) {
    if (newStatus == 'siap ambil') {
      _showPilihRakDialog(newStatus);
    } else {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Update Status',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Ubah status ke "${newStatus[0].toUpperCase()}${newStatus.substring(1)}"?',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _updateStatus(newStatus);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    Theme.of(context).appBarTheme.backgroundColor ?? kPrimary,
                foregroundColor:
                    Theme.of(context).appBarTheme.foregroundColor ??
                    Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Ya'),
            ),
          ],
        ),
      );
    }
  }

  // ── Konfirmasi Bayar ──────────────────────────────────────────────────────
  void _showKonfirmasiBayar() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.payment, color: Colors.green),
            SizedBox(width: 10),
            Text(
              'Konfirmasi Pembayaran',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
          ],
        ),
        content: RichText(
          text: TextSpan(
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(height: 1.5),
            children: [
              const TextSpan(text: 'Tandai pembayaran pelanggan\n\n'),
              TextSpan(
                text: _namaPelangganStr,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              TextSpan(text: '\n\nsebesar  ${_formatRupiah(_sisaTagihan)}'),
              if (_dpAmount > 0)
                TextSpan(
                  text: '  (sisa dari ${_formatRupiah(_grandTotal)})',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              const TextSpan(text: '  sudah '),
              const TextSpan(
                text: 'LUNAS',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                  fontSize: 15,
                ),
              ),
              const TextSpan(text: '?'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _bayar();
            },
            icon: const Icon(Icons.check_circle_outline, size: 18),
            label: const Text(
              'Ya, Lunas',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Konfirmasi Hapus ──────────────────────────────────────────────────────
  void _showKonfirmasiHapus() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 10),
            Text(
              'Hapus Order',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
          ],
        ),
        content: RichText(
          text: TextSpan(
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(height: 1.5),
            children: [
              const TextSpan(text: 'Yakin ingin menghapus order\n\n'),
              TextSpan(
                text: _namaPelangganStr,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const TextSpan(
                text: '\n\nTindakan ini tidak dapat dibatalkan.',
                style: TextStyle(color: Colors.red, fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _hapusOrder();
            },
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            label: const Text(
              'Ya, Hapus',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _hapusOrder() async {
    try {
      final orderRef = FirebaseFirestore.instance
          .collection('order')
          .doc(widget.docId);

      // Hapus subcollection items
      final itemsSnap = await orderRef.collection('items').get();
      for (final doc in itemsSnap.docs) {
        await doc.reference.delete();
      }

      // FIX: Hapus subcollection biaya_tambahan juga ← TAMBAHAN
      final biayaSnap = await orderRef.collection('biaya_tambahan').get();
      for (final doc in biayaSnap.docs) {
        await doc.reference.delete();
      }

      // Hapus dokumen order utama
      await orderRef.delete();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order berhasil dihapus'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menghapus order: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ── Helper widgets ────────────────────────────────────────────────────────
  Widget _strRow(String label, String val) {
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

  Future<void> _openTambahLayanan() async {
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _LayananPickerSheet(
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
                waktuOrder: _waktuOrder?.toDate() ?? DateTime.now(),
                onAdd: (item) async {
                  Navigator.pop(ctx2);
                  await _saveItemToFirestore(item);
                },
              ),
            );
          });
        },
      ),
    );
  }

  Future<void> _saveItemToFirestore(Map<String, dynamic> newItem) async {
    try {
      final orderRef = FirebaseFirestore.instance
          .collection('order')
          .doc(widget.docId);

      final existingSnap = await orderRef.collection('items').limit(1).get();

      if (existingSnap.docs.isEmpty && _items.length == 1) {
        final firstItem = _items[0];
        final firstItemData = {
          ...firstItem,
          'created_at': FieldValue.serverTimestamp(),
        };
        firstItemData.remove('_itemDocId');
        await orderRef.collection('items').add(firstItemData);
      }

      final itemData = {...newItem, 'created_at': FieldValue.serverTimestamp()};
      itemData.remove('_itemDocId');

      final docRef = await orderRef.collection('items').add(itemData);
      final newItemWithId = {...newItem, '_itemDocId': docRef.id};

      if (!mounted) return;
      setState(() => _items.add(newItemWithId));
      await _syncOrderSummary();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Layanan berhasil ditambahkan'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menyimpan layanan: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _deleteItemFromFirestore(int idx) async {
    final item = _items[idx];
    final itemDocId = item['_itemDocId']?.toString();

    if (itemDocId != null && itemDocId.isNotEmpty) {
      try {
        await FirebaseFirestore.instance
            .collection('order')
            .doc(widget.docId)
            .collection('items')
            .doc(itemDocId)
            .delete();
      } catch (e) {
        // ignore, still remove from UI
      }
    }

    setState(() => _items.removeAt(idx));
    await _syncOrderSummary();
  }

  Future<void> _syncOrderSummary() async {
    if (_items.isEmpty) return;

    final firstItem = _items[0];
    String estimasiTerpanjang = '-';
    DateTime? tglTerpanjang;
    for (final item in _items) {
      final estStr = item['estimasi_selesai']?.toString() ?? '';
      if (estStr.isEmpty || estStr == '-') continue;
      try {
        final parts = estStr.split('-');
        if (parts.length == 3) {
          final tgl = DateTime(
            int.parse(parts[2]), // tahun
            int.parse(parts[1]), // bulan
            int.parse(parts[0]), // hari
          );
          if (tglTerpanjang == null || tgl.isAfter(tglTerpanjang)) {
            tglTerpanjang = tgl;
            estimasiTerpanjang = estStr;
          }
        }
      } catch (_) {}
    }
    if (estimasiTerpanjang == '-' && _items.isNotEmpty) {
      estimasiTerpanjang = _items.last['estimasi_selesai']?.toString() ?? '-';
    }

    // PASTIKAN nama layanan diambil dari item yang sudah diedit
    final layananNamaSync = _items.length == 1
        ? (firstItem['layanan_nama']?.toString() ?? '-')
        : _items.map((i) => i['layanan_nama']?.toString() ?? '-').join(' + ');

    // Hitung ulang total berat dari semua item
    double totalBerat = 0;
    for (final item in _items) {
      try {
        final berat = item['berat_kg'] is num
            ? (item['berat_kg'] as num).toDouble()
            : double.parse(item['berat_kg'].toString());
        totalBerat += berat;
      } catch (_) {}
    }

    final updateData = {
      'harga_total': _grandTotal,
      'jumlah_item': _items.length,
      'estimasi_selesai': estimasiTerpanjang,
      'layanan_nama': layananNamaSync,
      'jenis_pakaian': firstItem['jenis_pakaian']?.toString() ?? '',
      'berat_kg': totalBerat, // ← tambahkan ini
    };

    try {
      await FirebaseFirestore.instance
          .collection('order')
          .doc(widget.docId)
          .update(updateData);

      if (mounted) {
        setState(() {
          _data['harga_total'] = _grandTotal;
          _data['estimasi_selesai'] = estimasiTerpanjang;
          _data['layanan_nama'] = layananNamaSync;
          _data['jenis_pakaian'] = firstItem['jenis_pakaian']?.toString() ?? '';
        });
      }
    } catch (_) {}
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final sColor = _statusColor(_status);
    final sIcon = _statusIcon(_status);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final next = _nextStatus;
    final totalFmt = _formatRupiah(_grandTotal);

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
              _noPelanggan,
              style:
                  Theme.of(context).appBarTheme.titleTextStyle?.copyWith(
                    fontWeight: FontWeight.bold,
                  ) ??
                  const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor:
                Theme.of(context).appBarTheme.backgroundColor ?? kPrimary,
            foregroundColor:
                Theme.of(context).appBarTheme.foregroundColor ?? Colors.white,
            elevation: 2,
            centerTitle: true,
          ),
        ),
      ),
      body: _isLoadingItems
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF0D9488)),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Action chips (WA + Cetak) ─────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: _actionChip(
                          context,
                          icon: Icons.send_rounded,
                          label: 'WhatsApp',
                          color: const Color(0xFF25D366),
                          onTap: _shareWA,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _actionChip(
                          context,
                          icon: Icons.receipt_long_outlined,
                          label: 'Cetak',
                          color: primary,
                          onTap: _cetak,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Status card ───────────────────────────────────────────
                  _card(
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: sColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(sIcon, color: sColor, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Status Pesanan',
                                style: Theme.of(
                                  context,
                                ).textTheme.bodySmall?.copyWith(fontSize: 11),
                              ),
                              Text(
                                _status[0].toUpperCase() + _status.substring(1),
                                style: TextStyle(
                                  color: sColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _tanggalStr,
                              style: Theme.of(
                                context,
                              ).textTheme.bodySmall?.copyWith(fontSize: 11),
                            ),
                            Text(
                              _jamStr,
                              style: Theme.of(
                                context,
                              ).textTheme.bodySmall?.copyWith(fontSize: 11),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // ── Banner belum lunas ────────────────────────────────────
                  if (!_sudahLunas)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.orange.withOpacity(0.15)
                            : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.orange.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.orange.shade700,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Pesanan belum lunas. Selesaikan pembayaran terlebih dahulu.',
                              style: TextStyle(
                                color: Colors.orange.shade800,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // ── Tombol lanjut status ──────────────────────────────────
                  if (next != null) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _showKonfirmasiStatus(next),
                        icon: const Icon(
                          Icons.check_circle_outline_rounded,
                          size: 18,
                        ),
                        label: Text(
                          _nextStatusLabel(),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).appBarTheme.backgroundColor ??
                              kPrimary,
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
                    const SizedBox(height: 10),
                  ],

                  // ── Estimasi selesai ──────────────────────────────────────
                  Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 15,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Estimasi selesai: $_estimasi',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Riwayat Status (collapsible) ──────────────────────────
                  _card(
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: () => setState(
                            () => _statusExpanded = !_statusExpanded,
                          ),
                          behavior: HitTestBehavior.opaque,
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.timeline_rounded,
                                  color: primary,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Riwayat Status',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    Text(
                                      'Status saat ini: $_status',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              AnimatedRotation(
                                turns: _statusExpanded ? 0.5 : 0,
                                duration: const Duration(milliseconds: 200),
                                child: Icon(
                                  Icons.expand_more_rounded,
                                  color: Colors.grey.shade400,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_statusExpanded) ...[
                          const SizedBox(height: 14),
                          const Divider(height: 1),
                          const SizedBox(height: 14),
                          _buildStatusTimeline(),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // ── Info Pelanggan card ───────────────────────────────────
                  _card(
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: primary.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.person_outline_rounded,
                            color: primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _namaPelangganStr,
                                style: Theme.of(context).textTheme.bodyLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                              ),
                              if (_noHp.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.phone_outlined,
                                        size: 12,
                                        color: Colors.grey.shade500,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _noHp,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        FutureBuilder<bool>(
                          future: canAccess(
                            'can_eit_layanan',
                          ), // ganti key sesuai kebutuhan
                          builder: (context, snap) {
                            if (!(snap.data ?? false)) {
                              return const SizedBox.shrink();
                            }
                            return GestureDetector(
                              onTap: _gantiPelanggan,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.edit_outlined,
                                  color: primary,
                                  size: 18,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Item Pesanan ──────────────────────────────────────────────────────────
                  Row(
                    children: [
                      Text(
                        'Item Pesanan',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _miniPill('${_items.length} layanan', primary),
                      const Spacer(),

                      FutureBuilder<bool>(
                        future: canAccess('can_eit_layanan'),
                        builder: (context, snap) {
                          if (!(snap.data ?? false)) {
                            return const SizedBox.shrink();
                          }
                          return GestureDetector(
                            onTap: () => _openEditLayanan(),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: primary.withOpacity(0.10),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: primary.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.edit_outlined,
                                    size: 12,
                                    color: primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Edit',
                                    style: TextStyle(
                                      color: primary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  ..._items.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final item = entry.value;
                    final tipe = item['layanan_tipe']?.toString() ?? '';
                    final satuanLabel = _satuanLabel(tipe);
                    final beratVal = item['berat_kg'];
                    final hargaVal = item['harga_satuan'];
                    final jenis = item['jenis_pakaian']?.toString() ?? '';

                    final catatan = item['catatan']?.toString() ?? '';
                    final subtotal = _itemTotal(item);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
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
                                  _formatRupiah(subtotal),
                                  style: Theme.of(context).textTheme.bodyLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${beratVal ?? '-'} $satuanLabel × ${_formatRupiah(hargaVal)}',
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
                                if (tipe.isNotEmpty)
                                  _miniPill(tipe, Colors.grey),
                                const Spacer(),
                                Text(
                                  item['estimasi_selesai']?.toString() ?? '-',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodySmall?.copyWith(fontSize: 10),
                                ),

                                if (_items.length > 1) ...[
                                  const SizedBox(width: 6),

                                  FutureBuilder<bool>(
                                    future: canAccess('can_hapus_order'),
                                    builder: (context, snapshot) {
                                      if (!(snapshot.data ?? false)) {
                                        return const SizedBox.shrink();
                                      }
                                      return GestureDetector(
                                        // ← TAMBAHKAN return DI SINI
                                        onTap: () =>
                                            _deleteItemFromFirestore(idx),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.red.withOpacity(0.08),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: Colors.red.withOpacity(
                                                0.3,
                                              ),
                                            ),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
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
                                      );
                                    },
                                  ),
                                ],
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
                                      : Colors.grey.shade50,
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
                      ),
                    );
                  }),

                  // ── Tombol Tambah Layanan ─────────────────────────────────
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
                  const SizedBox(height: 16),

                  // ── Pembayaran ────────────────────────────────────────────
                  Text(
                    'Pembayaran',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 10),

                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Total Layanan ───────────────────────────────────────────
                        _pembRow('Total Layanan', _formatRupiah(_totalLayanan)),

                        // ── Biaya Tambahan (jika ada) ───────────────────────────────
                        if (_biayaTambahan.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Divider(
                            height: 1,
                            color: Theme.of(
                              context,
                            ).dividerColor.withOpacity(0.4),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Biaya Tambahan',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade500,
                                  letterSpacing: 0.5,
                                ),
                          ),
                          const SizedBox(height: 8),
                          ..._biayaTambahan.map((b) {
                            final nominal = b['nominal'] is num
                                ? (b['nominal'] as num).toInt()
                                : int.tryParse(b['nominal'].toString()) ?? 0;
                            final qty = b['qty'] is num
                                ? (b['qty'] as num).toInt()
                                : int.tryParse((b['qty'] ?? 1).toString()) ?? 1;
                            final subtotal = nominal * qty;
                            final keterangan =
                                b['keterangan']?.toString() ?? '-';
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    margin: const EdgeInsets.only(
                                      right: 8,
                                      top: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade400,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      qty > 1
                                          ? '$keterangan (${qty}×)'
                                          : keterangan,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(fontSize: 12),
                                    ),
                                  ),
                                  Text(
                                    _formatRupiah(subtotal),
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],

                        // ── Subtotal sebelum diskon (jika ada biaya tambahan atau diskon) ──
                        if (_biayaTambahan.isNotEmpty ||
                            _diskonNominal > 0) ...[
                          const SizedBox(height: 8),
                          Divider(
                            height: 1,
                            color: Theme.of(
                              context,
                            ).dividerColor.withOpacity(0.4),
                          ),
                          const SizedBox(height: 8),
                          _pembRow(
                            'Subtotal',
                            _formatRupiah(_subtotalSebelumDiskon),
                            valueStyle: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ],

                        // ── Diskon (jika ada) ───────────────────────────────────────
                        if (_diskonNominal > 0) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: Colors.red.withOpacity(0.2),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.local_offer_outlined,
                                      size: 10,
                                      color: Colors.red.shade400,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      'Diskon',
                                      style: TextStyle(
                                        color: Colors.red.shade400,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_diskonCatatan.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    _diskonCatatan,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          fontSize: 11,
                                          color: Colors.grey.shade500,
                                        ),
                                  ),
                                ),
                              ] else
                                const Spacer(),
                              Text(
                                '- ${_formatRupiah(_diskonNominal)}',
                                style: TextStyle(
                                  color: Colors.red.shade500,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],

                        // ── Divider Total ───────────────────────────────────────────
                        const Divider(height: 24),

                        // ── Grand Total ─────────────────────────────────────────────
                        _pembRow(
                          'Total',
                          totalFmt,
                          valueStyle: TextStyle(
                            color: primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),

                        // ── DP ──────────────────────────────────────────────────────
                        if (_dpAmount > 0) ...[
                          const SizedBox(height: 8),
                          _pembRow(
                            'DP / Uang Muka',
                            '- ${_formatRupiah(_dpAmount)}',
                            valueStyle: TextStyle(
                              color: Colors.teal.shade600,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],

                        // ── Sisa Tagihan ────────────────────────────────────────────
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: _sudahLunas
                                ? Colors.green.withOpacity(0.07)
                                : Colors.red.withOpacity(0.07),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _sudahLunas
                                  ? Colors.green.withOpacity(0.25)
                                  : Colors.red.withOpacity(0.25),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    _sudahLunas
                                        ? Icons.check_circle_outline_rounded
                                        : Icons.pending_outlined,
                                    size: 14,
                                    color: _sudahLunas
                                        ? Colors.green
                                        : Colors.red.shade400,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Sisa Tagihan',
                                    style: TextStyle(
                                      color: _sudahLunas
                                          ? Colors.green
                                          : Colors.red.shade600,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                _sudahLunas
                                    ? 'Lunas'
                                    : _formatRupiah(_sisaTagihan),
                                style: TextStyle(
                                  color: _sudahLunas
                                      ? Colors.green
                                      : Colors.red.shade600,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                    ),
                  ),

                  // ── Tombol Bayar ──────────────────────────────────────────
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: _sudahLunas
                        ? Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.green.shade300),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.check_circle_rounded,
                                  color: Colors.green,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Sudah Lunas',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ElevatedButton.icon(
                            onPressed: _showKonfirmasiBayar,
                            icon: const Icon(Icons.payment_rounded, size: 18),
                            label: Text(
                              'Bayar ${_formatRupiah(_sisaTagihan)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  Theme.of(
                                    context,
                                  ).appBarTheme.backgroundColor ??
                                  kPrimary,
                              foregroundColor:
                                  Theme.of(
                                    context,
                                  ).appBarTheme.foregroundColor ??
                                  Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                  ),

                  // ── Tombol Hapus Order ────────────────────────────────────
                  // Menu yang hanya muncul untuk owner (hanya Admin yang diizinkan)
                  const SizedBox(height: 10),
                  FutureBuilder<bool>(
                    future: canAccess('can_hapus_order'),
                    builder: (context, snapshot) {
                      if (!(snapshot.data ?? false)) {
                        return const SizedBox.shrink();
                      }
                      return SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _showKonfirmasiHapus,
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                            color: Colors.red,
                          ),
                          label: const Text(
                            'Hapus Order',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.red.shade300),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _actionChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.4)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
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

  Widget _pembRow(String label, String val, {TextStyle? valueStyle}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 14),
        ),
        Text(
          val,
          style:
              valueStyle ??
              Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildStatusTimeline() {
    const allStatus = ['antrian', 'proses', 'siap ambil', 'selesai'];
    final currentIdx = allStatus.indexOf(_status.toLowerCase());
    return Column(
      children: List.generate(allStatus.length, (i) {
        final s = allStatus[i];
        final isLast = i == allStatus.length - 1;
        final isDone = i <= currentIdx;
        final sColor = _statusColor(s);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isDone ? sColor : Colors.grey.shade200,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isDone ? Icons.check_rounded : Icons.circle,
                    color: isDone ? Colors.white : Colors.grey.shade400,
                    size: 14,
                  ),
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 30,
                    color: i < currentIdx ? sColor : Colors.grey.shade200,
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 8),
              child: Text(
                s[0].toUpperCase() + s.substring(1),
                style: TextStyle(
                  color: isDone ? sColor : Colors.grey.shade400,
                  fontWeight: isDone ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  // ── Buka edit item ────────────────────────────────────────────────────────
  void _openEditLayanan() {
    if (_items.isEmpty) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EditItemListSheet(
        items: List<Map<String, dynamic>>.from(_items),
        onSave: (updatedItems) async {
          Navigator.pop(ctx);
          await _saveEditedItems(updatedItems);
        },
      ),
    );
  }

  Future<void> _gantiPelanggan() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => DaftarPelangganPage(
          storeId: widget.storeId,
          outletId: widget.outletId,
          isSelecting: true,
        ),
      ),
    );

    if (result != null && mounted) {
      final namaBaru = result['nama']?.toString() ?? '';
      final hpBaru = result['no_hp']?.toString() ?? '';

      await FirebaseFirestore.instance
          .collection('order')
          .doc(widget.docId)
          .update({'nama_pelanggan': namaBaru, 'no_hp': hpBaru});

      setState(() {
        _data['nama_pelanggan'] = namaBaru;
        _data['no_hp'] = hpBaru;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Pelanggan diperbarui: $namaBaru'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _saveEditedItems(List<Map<String, dynamic>> updatedItems) async {
    try {
      final orderRef = FirebaseFirestore.instance
          .collection('order')
          .doc(widget.docId);

      for (final item in updatedItems) {
        final docId = item['_itemDocId']?.toString();

        if (docId != null && docId.isNotEmpty) {
          final dataToUpdate = Map<String, dynamic>.from(item)
            ..remove('_itemDocId');
          await orderRef.collection('items').doc(docId).update(dataToUpdate);
          debugPrint('✅ Item updated di Firestore: $docId'); // ← TAMBAHKAN INI
        } else {
          debugPrint(
            '❌ docId null/kosong — item tidak tersimpan di subcollection',
          ); // ← TAMBAHKAN INI
        }
      }

      setState(() => _items = updatedItems);
      await _syncOrderSummary();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Item berhasil diperbarui'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      debugPrint('❌ ERROR _saveEditedItems: $e'); // ← TAMBAHKAN INI
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memperbarui item: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  DIALOG: Pilih Rak
// ════════════════════════════════════════════════════════════════════════════
class _PilihRakDialog extends StatefulWidget {
  final String storeId;
  final String outletId;

  final void Function(String rakId, String rakNama) onRakSelected;

  const _PilihRakDialog({
    required this.storeId,
    required this.outletId,
    required this.onRakSelected,
  });

  @override
  State<_PilihRakDialog> createState() => _PilihRakDialogState();
}

class _PilihRakDialogState extends State<_PilihRakDialog> {
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
    final snap = await FirebaseFirestore.instance.collection('rak').get();
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
    await FirebaseFirestore.instance.collection('rak').doc(rakId).delete();
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
                      'Cucian selesai, masukkan ke rak',
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

// ════════════════════════════════════════════════════════════════════════════
//  BOTTOM SHEET: Edit Item Pesanan (dengan Ganti Layanan)
// ════════════════════════════════════════════════════════════════════════════
class _EditItemListSheet extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  final void Function(List<Map<String, dynamic>>) onSave;

  const _EditItemListSheet({required this.items, required this.onSave});

  @override
  State<_EditItemListSheet> createState() => _EditItemListSheetState();
}

class _EditItemListSheetState extends State<_EditItemListSheet> {
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
      return TextEditingController(
        text: harga != null ? harga.toString() : '0',
      );
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
      final harga = int.parse(_hargaControllers[idx].text);
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
      builder: (ctx) => _LayananPickerSheet(
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
          int.tryParse(_hargaControllers[i].text) ??
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
                              _formatRupiah(subtotal),
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
// ════════════════════════════════════════════════════════════════════════════
//  BOTTOM SHEET: Pilih Layanan
// ════════════════════════════════════════════════════════════════════════════

class _LayananPickerSheet extends StatefulWidget {
  final void Function(Layanan) onSelected;

  const _LayananPickerSheet({required this.onSelected});

  @override
  State<_LayananPickerSheet> createState() => _LayananPickerSheetState();
}

class _LayananPickerSheetState extends State<_LayananPickerSheet> {
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
          await FirebaseFirestore.instance.collection('layanan').add({
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
    // Refresh list setelah form ditutup
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
            'Pilih Layanan',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          // Search
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
          const SizedBox(height: 12),

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

          // Content
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
                    ElevatedButton.icon(
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

// ════════════════════════════════════════════════════════════════════════════
//  BOTTOM SHEET: Input Detail Item
// ════════════════════════════════════════════════════════════════════════════
class _ItemDetailSheet extends StatefulWidget {
  final Layanan layanan;
  final DateTime waktuOrder;
  final void Function(Map<String, dynamic>) onAdd;
  const _ItemDetailSheet({
    required this.layanan,
    required this.waktuOrder,
    required this.onAdd,
  });

  @override
  State<_ItemDetailSheet> createState() => _ItemDetailSheetState();
}

class _ItemDetailSheetState extends State<_ItemDetailSheet> {
  double _jumlah = 1.0;
  final _catatanCtrl = TextEditingController();
  final _jumlahPakaianCtrl = TextEditingController(text: '0');
  late TextEditingController _jumlahCtrl;

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
    final selesai = widget.waktuOrder.add(
      Duration(hours: widget.layanan.durasiJam),
    );
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
  void initState() {
    super.initState();
    _jumlahCtrl = TextEditingController(
      text: _jumlah.toStringAsFixed(widget.layanan.tipe == 'kiloan' ? 1 : 0),
    );
  }

  @override
  void dispose() {
    _catatanCtrl.dispose();
    _jumlahPakaianCtrl.dispose();
    _jumlahCtrl.dispose();
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
                  // Tombol minus
                  GestureDetector(
                    onTap: () {
                      if (_jumlah > _min) {
                        setState(() {
                          _jumlah = double.parse(
                            (_jumlah - _step).toStringAsFixed(2),
                          );
                          _jumlahCtrl.text = _jumlah % 1 == 0
                              ? _jumlah.toStringAsFixed(0)
                              : _jumlah.toString();
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

                  // Input manual di tengah
                  Expanded(
                    child: TextField(
                      controller: _jumlahCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,2}'),
                        ),
                      ],
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        suffixText: _satuanLabel,
                        suffixStyle: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(color: Colors.grey.shade500),
                      ),
                      onChanged: (val) {
                        final parsed = double.tryParse(val);
                        if (parsed != null && parsed >= _min) {
                          setState(() => _jumlah = parsed);
                        }
                      },
                    ),
                  ),

                  // Tombol plus
                  GestureDetector(
                    onTap: () => setState(() {
                      _jumlah = double.parse(
                        (_jumlah + _step).toStringAsFixed(2),
                      );
                      _jumlahCtrl.text = _jumlah % 1 == 0
                          ? _jumlah.toStringAsFixed(0)
                          : _jumlah.toString();
                    }),
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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:mdnlaundry_project/features/settings/outlet/wa_settings.dart';
import 'package:mdnlaundry_project/core/app_exports.dart';
import 'package:mdnlaundry_project/services/order_payment_service.dart';
import 'package:mdnlaundry_project/features/order/widgets/detail/biaya_tambahan_sheet.dart';
import 'package:mdnlaundry_project/core/utils/format_utils.dart';
import 'package:mdnlaundry_project/features/order/widgets/detail/pilih_rak_dialog.dart';
import 'package:mdnlaundry_project/features/order/widgets/detail/edit_item_list_sheet.dart';
import 'package:mdnlaundry_project/features/order/widgets/detail/layanan_picker_sheet.dart';
import 'package:mdnlaundry_project/features/order/widgets/detail/item_detail_sheet.dart';
import 'package:mdnlaundry_project/features/order/widgets/detail/bayar_sheet.dart';

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
  List<Map<String, dynamic>> _riwayatBayar = [];
  bool _bolehEditBiaya = false; // izin edit/hapus biaya tambahan (sama dgn edit layanan)
  bool _isLoadingItems = true;

  @override
  void initState() {
    super.initState();
    _data = Map.from(widget.data);
    _loadItemsFromFirestore();
    _muatRiwayatBayar();
    canAccess('can_eit_layanan').then((v) {
      if (mounted) setState(() => _bolehEditBiaya = v);
    });
  }

  Future<void> _muatRiwayatBayar() async {
    try {
      final list = await OrderPaymentService.riwayat(widget.docId);
      if (mounted) setState(() => _riwayatBayar = list);
    } catch (_) {
      // riwayat hanya tampilan tambahan; abaikan jika gagal
    }
  }

  // ── Popup pilih rak saat order selesai diproses ────────────────────────────────
  void _showPilihRakDialog(String newStatus) {
    showDialog(
      context: context,
      builder: (ctx) => PilihRakDialog(
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

    // Kirim notif WA "siap ambil"
    if (newStatus.toLowerCase() == 'siap ambil') {
      await _kirimNotifikasiSiapAmbil(rakNama);
    }
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
    final totalFmt = formatRupiah(_grandTotal);
    final sisaFmt = formatRupiah(_sisaTagihan);

    final infoBayar = _sudahLunas ? '✅ Lunas' : '💳 Sisa Tagihan: $sisaFmt';

    final footer = await WaSettings.getFooter();
    final footerLine = footer.trim().isEmpty ? '' : '_${footer}_\n';

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
            'Jika antar jemput silahkan konfimrasi saat berada di rumah\n\n' +
        footerLine;

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

      // Load biaya_tambahan
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

  // Grand total = layanan + biaya tambahan
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

  /// Total uang yang sudah masuk untuk order ini.
  /// - lunas  → sebesar grand total (order lama juga dibaca benar walau dp_amount = 0)
  /// - lainnya → dp_amount (kumulatif DP + cicilan)
  int get _totalTerbayar => _sudahLunas ? _grandTotal : _dpAmount;

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
        return _labelSelesaiProses();
      case 'selesai':
        return 'Selesai (Sudah Diambil)';
      default:
        return _nextStatus ?? '';
    }
  }

  /// Label tombol "selesai proses" menyesuaikan jenis layanan:
  /// - semua layanan setrika saja  → "Selesai Disetrika"
  /// - semua layanan cuci saja     → "Selesai Dicuci"
  /// - selain itu (cuci+setrika, dry clean, bedcover, campuran, dll)
  ///   → "Selesai Diproses"
  String _labelSelesaiProses() {
    const kataSetrika = ['setrika', 'gosok', 'iron'];
    const kataCuci = ['cuci', 'laundry', 'wash'];
    bool mengandung(String n, List<String> kata) => kata.any(n.contains);

    final names = _items
        .map((i) => (i['layanan_nama'] ?? '').toString().toLowerCase())
        .where((n) => n.isNotEmpty)
        .toList();
    if (names.isEmpty) return 'Selesai Diproses';

    final semuaSetrikaSaja = names.every(
      (n) => mengandung(n, kataSetrika) && !mengandung(n, kataCuci),
    );
    if (semuaSetrikaSaja) return 'Selesai Disetrika';

    final semuaCuciSaja = names.every(
      (n) => mengandung(n, kataCuci) && !mengandung(n, kataSetrika),
    );
    if (semuaCuciSaja) return 'Selesai Dicuci';

    return 'Selesai Diproses';
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

  /// Catat pembayaran (sebagian / pelunasan). Order, keuangan & riwayat
  /// pembayaran ditulis sekaligus lewat [OrderPaymentService].
  Future<void> _catatPembayaran(
    int nominal,
    String metode,
    String catatan,
  ) async {
    final admin =
        FirebaseAuth.instance.currentUser?.displayName?.split('|')[0] ??
        'Admin';
    final hasil = await OrderPaymentService.catatPembayaran(
      orderId: widget.docId,
      storeId: widget.storeId,
      nomorPelanggan: _noPelanggan,
      grandTotal: _grandTotal,
      sudahDibayar: _totalTerbayar,
      nominal: nominal,
      metode: metode,
      catatan: catatan,
      admin: admin,
    );
    if (!mounted) return;
    setState(() {
      _data['status_bayar'] = hasil.statusBayar;
      _data['dp_amount'] = hasil.totalDibayar;
      _data['harga_total'] = _grandTotal;
    });
    await _muatRiwayatBayar();
    if (!mounted) return;
    final lunas = hasil.statusBayar == StatusBayar.lunas;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          lunas
              ? 'Pembayaran lunas dicatat'
              : 'Pembayaran ${formatRupiah(nominal)} dicatat · Sisa ${formatRupiah(hasil.sisa)}',
        ),
        backgroundColor: lunas ? Colors.green : Colors.teal,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── _shareWA juga diperbaiki — include biaya tambahan ─────────────────────
  Future<void> _shareWA() async {
    final noHp = _noHp;
    final totalFmt = formatRupiah(_grandTotal);
    final sisaFmt = formatRupiah(_sisaTagihan);
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
        '   $berat $satuan × ${formatRupiah(harga)}\n'
        '   Subtotal: ${formatRupiah(subtotal)}',
      );
    }

    // Biaya tambahan di WA
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
          '• ${b['keterangan']} (${qty}×): ${formatRupiah(subtotal)}',
        );
      }
    }

    final dpBaris = _totalTerbayar > 0
        ? '💵 Sudah Dibayar  : ${formatRupiah(_totalTerbayar)}\n'
        : '';

    final diskonBaris = _diskonNominal > 0
        ? '🏷️ Diskon         : - ${formatRupiah(_diskonNominal)}' +
              (_diskonCatatan.isNotEmpty ? ' (${_diskonCatatan})' : '') +
              '\n'
        : '';
    final trackingUrl = 'https://laundry-ku-id.web.app/$_noPelanggan';
    final footer = await WaSettings.getFooter();
    final footerLine = footer.trim().isEmpty ? '' : '_${footer}_\n';

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
            '${_diskonNominal > 0 ? '💰 Subtotal       : ${formatRupiah(_subtotalSebelumDiskon)}\n' : ''}'
            '$diskonBaris'
            '💰 Total          : $totalFmt\n'
            '$dpBaris'
            '💳 Sisa Tagihan   : $sisaFmt\n'
            '━━━━━━━━━━━━━━━━━\n'
            '🔍 *Lacak status order Anda:*\n'
            '$trackingUrl\n\n'
            'Terima kasih 🙏\n' +
        footerLine;

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
      'dp_amount': _totalTerbayar,
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
                                      '   ${berat % 1 == 0 ? berat.toStringAsFixed(0) : berat.toStringAsFixed(1)} $satuan   ${formatRupiah(harga)}',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                    Text(
                                      '   = ${formatRupiah(subtotal)}',
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
                                        '   = ${formatRupiah(nominal * qty)}',
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
                                    'Layanan  : ${formatRupiah(_totalLayanan)}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                  Text(
                                    'Biaya Tmb: ${formatRupiah(_totalBiayaTambahan)}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                ],
                                if (_diskonNominal > 0) ...[
                                  Text(
                                    'Subtotal : ${formatRupiah(_subtotalSebelumDiskon)}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                  Text(
                                    'Diskon   : - ${formatRupiah(_diskonNominal)}'
                                    '${_diskonCatatan.isNotEmpty ? ' ($_diskonCatatan)' : ''}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(color: Colors.red.shade600),
                                  ),
                                ],
                                Text(
                                  'TOTAL    : ${formatRupiah(_grandTotal)}',
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
                                  'Dibayar : ${_totalTerbayar > 0 ? formatRupiah(_totalTerbayar) : 'Rp 0'}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                Text(
                                  'Sisa    : ${formatRupiah(_sisaTagihan)}',
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

  // ── Bayar (penuh / sebagian) ──────────────────────────────────────────────
  void _showBayarSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BayarSheet(
        namaPelanggan: _namaPelangganStr,
        grandTotal: _grandTotal,
        sudahDibayar: _totalTerbayar,
        sisa: _sisaTagihan,
        onSubmit: _catatPembayaran,
      ),
    );
  }

  Widget _riwayatBayarRow(Map<String, dynamic> r) {
    final nominal = r['nominal'] is num ? (r['nominal'] as num).toInt() : 0;
    final metode = r['metode']?.toString() ?? '';
    final catatan = r['catatan']?.toString() ?? '';
    final waktu = r['waktu'] is Timestamp
        ? DateFormat('dd MMM yyyy HH:mm').format((r['waktu'] as Timestamp).toDate())
        : 'Baru saja';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.payments_outlined, size: 16, color: Colors.teal.shade400),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  metode.isEmpty ? waktu : '$metode · $waktu',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                  ),
                ),
                if (catatan.isNotEmpty)
                  Text(
                    catatan,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            '+ ${formatRupiah(nominal)}',
            style: TextStyle(
              color: Colors.teal.shade600,
              fontWeight: FontWeight.w600,
              fontSize: 13,
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

      // 1. Hapus subcollection items
      final itemsSnap = await orderRef.collection('items').get();
      for (final doc in itemsSnap.docs) {
        await doc.reference.delete();
      }

      // 2. Hapus subcollection biaya_tambahan
      final biayaSnap = await orderRef.collection('biaya_tambahan').get();
      for (final doc in biayaSnap.docs) {
        await doc.reference.delete();
      }

      // 3. Hapus riwayat pembayaran + dokumen keuangan yang terkait
      //    (difilter store_id agar tidak menyentuh toko lain)
      await OrderPaymentService.hapusSemua(
        orderId: widget.docId,
        storeId: widget.storeId,
        nomorPelanggan: _noPelanggan,
      );

      // 4. Hapus dokumen order utama
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
      builder: (ctx) => DetailLayananPickerSheet(
        storeId: widget.storeId,
        outletId: widget.outletId,
        onSelected: (layanan) {
          Navigator.pop(ctx);
          Future.delayed(const Duration(milliseconds: 200), () {
            if (!mounted) return;
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (ctx2) => DetailItemDetailSheet(
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

    // Total berubah → hitung ulang status bayar & samakan koleksi keuangan.
    // Uang yang sudah masuk dihitung dari total LAMA (harga_total tersimpan).
    final hargaLama = _data['harga_total'] is num
        ? (_data['harga_total'] as num).toInt()
        : int.tryParse(_data['harga_total']?.toString() ?? '') ?? 0;
    final sudahMasuk = _sudahLunas
        ? (hargaLama > _dpAmount ? hargaLama : _dpAmount)
        : _dpAmount;

    final updateData = {
      'jumlah_item': _items.length,
      'estimasi_selesai': estimasiTerpanjang,
      'layanan_nama': layananNamaSync,
      'jenis_pakaian': firstItem['jenis_pakaian']?.toString() ?? '',
      'berat_kg': totalBerat, //
    };

    try {
      await FirebaseFirestore.instance
          .collection('order')
          .doc(widget.docId)
          .update(updateData);

      final statusBaru = await OrderPaymentService.sinkronSetelahTotalBerubah(
        orderId: widget.docId,
        storeId: widget.storeId,
        nomorPelanggan: _noPelanggan,
        grandTotalBaru: _grandTotal,
        sudahDibayar: sudahMasuk,
      );

      if (mounted) {
        setState(() {
          _data['status_bayar'] = statusBaru;
          _data['dp_amount'] = sudahMasuk;
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
    final totalFmt = formatRupiah(_grandTotal);

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
                              _totalTerbayar > 0
                                  ? 'Belum lunas. Sudah dibayar ${formatRupiah(_totalTerbayar)}, sisa ${formatRupiah(_sisaTagihan)}.'
                                  : 'Pesanan belum lunas. Selesaikan pembayaran terlebih dahulu.',
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
                                  formatRupiah(subtotal),
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
                              '${beratVal ?? '-'} $satuanLabel × ${formatRupiah(hargaVal)}',
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
                  const SizedBox(height: 10),

                  // ── Tombol Tambah Biaya Tambahan ───────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _bukaBiayaSheet(),
                      icon: Icon(
                        Icons.add_card_outlined,
                        color: Colors.orange.shade700,
                        size: 18,
                      ),
                      label: Text(
                        'Tambah Biaya Tambahan',
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: Colors.orange.shade400.withOpacity(0.6),
                        ),
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
                        _pembRow('Total Layanan', formatRupiah(_totalLayanan)),

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
                            final idxBiaya = _biayaTambahan.indexOf(b);
                            return InkWell(
                              onTap: _bolehEditBiaya
                                  ? () => _bukaBiayaSheet(idx: idxBiaya)
                                  : null,
                              borderRadius: BorderRadius.circular(6),
                              child: Padding(
                              padding: const EdgeInsets.only(bottom: 6, top: 2),
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
                                    formatRupiah(subtotal),
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                  ),
                                  if (_bolehEditBiaya) ...[
                                    const SizedBox(width: 6),
                                    Icon(
                                      Icons.edit_outlined,
                                      size: 14,
                                      color: Colors.grey.shade500,
                                    ),
                                  ],
                                ],
                              ),
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
                            formatRupiah(_subtotalSebelumDiskon),
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
                                '- ${formatRupiah(_diskonNominal)}',
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
                        if (_totalTerbayar > 0) ...[
                          const SizedBox(height: 8),
                          _pembRow(
                            _sudahLunas ? 'Total Dibayar' : 'Sudah Dibayar',
                            '- ${formatRupiah(_totalTerbayar)}',
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
                                    : formatRupiah(_sisaTagihan),
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
                        if (_riwayatBayar.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Text(
                            'Riwayat Pembayaran',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade500,
                                  letterSpacing: 0.5,
                                ),
                          ),
                          const SizedBox(height: 6),
                          for (final r in _riwayatBayar) _riwayatBayarRow(r),
                        ],
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
                            onPressed: _showBayarSheet,
                            icon: const Icon(Icons.payment_rounded, size: 18),
                            label: Text(
                              _totalTerbayar > 0
                                  ? 'Bayar Lagi · Sisa ${formatRupiah(_sisaTagihan)}'
                                  : 'Bayar · Sisa ${formatRupiah(_sisaTagihan)}',
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

  // ── Biaya tambahan: tambah / edit / hapus ─────────────────────────────────
  void _bukaBiayaSheet({int? idx}) {
    final existing = idx != null ? _biayaTambahan[idx] : null;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BiayaTambahanSheet(
        existing: existing,
        onSave: (ket, nominal, qty) => _simpanBiaya(idx, ket, nominal, qty),
        onDelete: idx == null ? null : () => _hapusBiaya(idx),
      ),
    );
  }

  Future<void> _simpanBiaya(int? idx, String ket, int nominal, int qty) async {
    final col = FirebaseFirestore.instance
        .collection('order')
        .doc(widget.docId)
        .collection('biaya_tambahan');

    if (idx == null) {
      final ref = await col.add({
        'keterangan': ket,
        'nominal': nominal,
        'qty': qty,
        'created_at': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      setState(
        () => _biayaTambahan.add({
          'keterangan': ket,
          'nominal': nominal,
          'qty': qty,
          '_biayaDocId': ref.id,
        }),
      );
    } else {
      final docId = _biayaTambahan[idx]['_biayaDocId']?.toString() ?? '';
      if (docId.isEmpty) {
        throw StateError('Data biaya tidak ditemukan di server');
      }
      await col.doc(docId).update({
        'keterangan': ket,
        'nominal': nominal,
        'qty': qty,
      });
      if (!mounted) return;
      setState(() {
        _biayaTambahan[idx] = {
          ..._biayaTambahan[idx],
          'keterangan': ket,
          'nominal': nominal,
          'qty': qty,
        };
      });
    }

    // Total berubah → hitung ulang harga_total, status bayar & data keuangan.
    await _syncOrderSummary();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          idx == null
              ? 'Biaya tambahan ditambahkan'
              : 'Biaya tambahan diperbarui',
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _hapusBiaya(int idx) async {
    final docId = _biayaTambahan[idx]['_biayaDocId']?.toString() ?? '';
    if (docId.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection('order')
          .doc(widget.docId)
          .collection('biaya_tambahan')
          .doc(docId)
          .delete();
    }
    if (!mounted) return;
    setState(() => _biayaTambahan.removeAt(idx));
    await _syncOrderSummary();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Biaya tambahan dihapus'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Buka edit item ────────────────────────────────────────────────────────
  void _openEditLayanan() {
    if (_items.isEmpty) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => EditItemListSheet(
        storeId: widget.storeId,
        outletId: widget.outletId,
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
          debugPrint('✅ Item updated di Firestore: $docId'); //
        } else {
          debugPrint(
            '❌ docId null/kosong — item tidak tersimpan di subcollection',
          ); //
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
      debugPrint('❌ ERROR _saveEditedItems: $e'); //
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

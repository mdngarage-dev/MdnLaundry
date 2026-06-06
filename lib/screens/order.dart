import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'screens.dart';

// ════════════════════════════════════════════════════════════════════════════
//  ORDER SCREEN  –  List + Chip Filter
// ════════════════════════════════════════════════════════════════════════════
class OrderScreen extends StatefulWidget {
  final String? initialStatus;
  final bool initialBelumBayar;

  const OrderScreen({
    super.key,
    this.initialStatus,
    this.initialBelumBayar = false,
  });

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  late String? _filterStatus;
  late bool _filterBelumBayar;

  late final Stream<QuerySnapshot> _orderStream;

  @override
  void initState() {
    super.initState();
    _filterStatus = widget.initialStatus;
    _filterBelumBayar = widget.initialBelumBayar;
    _orderStream = FirebaseFirestore.instance
        .collection('order')
        .orderBy('waktu_order', descending: true)
        .snapshots();
  }

  static const _chips = [
    _ChipData(label: 'Antrian', status: 'antrian'),
    _ChipData(label: 'Proses', status: 'proses'),
    _ChipData(label: 'Selesai', status: 'selesai'),
  ];

  bool _passesClientFilter(Map<String, dynamic> data) {
    if (_filterStatus != null) {
      final status = data['status']?.toString().toLowerCase() ?? '';
      if (status != _filterStatus!.toLowerCase()) return false;
    }
    if (_filterBelumBayar) {
      final statusBayar = data['status_bayar']?.toString().toLowerCase() ?? '';
      if (statusBayar == 'lunas') return false;
    }
    return true;
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
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

  IconData _statusIcon(String status) {
    switch (status.toLowerCase()) {
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

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(context),
      body: Column(
        children: [
          Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _filterChip(
                    context,
                    label: 'Semua',
                    selected: _filterStatus == null && !_filterBelumBayar,
                    onTap: () => setState(() {
                      _filterStatus = null;
                      _filterBelumBayar = false;
                    }),
                    primary: primary,
                    isDark: isDark,
                  ),
                  const SizedBox(width: 8),
                  ..._chips.map(
                    (c) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _filterChip(
                        context,
                        label: c.label,
                        selected: _filterStatus == c.status,
                        onTap: () => setState(() {
                          _filterStatus = _filterStatus == c.status
                              ? null
                              : c.status;
                        }),
                        primary: primary,
                        isDark: isDark,
                      ),
                    ),
                  ),
                  _filterChipIcon(
                    context,
                    label: 'Belum Bayar',
                    icon: Icons.payment_outlined,
                    selected: _filterBelumBayar,
                    onTap: () =>
                        setState(() => _filterBelumBayar = !_filterBelumBayar),
                    activeColor: Colors.orange.shade700,
                    isDark: isDark,
                  ),
                ],
              ),
            ),
          ),
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Colors.grey.withOpacity(0.18),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _orderStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF0D9488)),
                  );
                }
                if (snapshot.hasError) {
                  debugPrint('Firestore error: ${snapshot.error}');
                  return _emptyState(
                    icon: Icons.wifi_off_rounded,
                    title: 'Gagal memuat data',
                    subtitle: 'Periksa koneksi internet Anda',
                  );
                }
                final allDocs = snapshot.data?.docs ?? [];
                final docs = allDocs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return _passesClientFilter(data);
                }).toList();

                if (docs.isEmpty) {
                  return _emptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'Belum ada order',
                    subtitle: 'Tarik ke bawah untuk muat ulang',
                  );
                }

                return GlobalRefresh(
                  onRefresh: () async => setState(() {}),
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                    itemCount: docs.length,
                    itemBuilder: (context, i) {
                      final doc = docs[i];
                      final data = doc.data() as Map<String, dynamic>;
                      final status = data['status']?.toString() ?? '-';
                      final noPelanggan =
                          data['nomor_pelanggan']?.toString() ?? '-';
                      final layananNama =
                          data['layanan_nama']?.toString() ?? '-';
                      final estimasi =
                          data['estimasi_selesai']?.toString() ?? '-';
                      final harga = data['harga_total'] ?? data['harga_satuan'];
                      final jenis = data['jenis_pakaian']?.toString() ?? '';
                      final hargaFmt = harga != null
                          ? _formatRupiah(harga)
                          : '-';
                      final sColor = _statusColor(status);
                      final sIcon = _statusIcon(status);
                      final statusBayar =
                          data['status_bayar']?.toString().toLowerCase() ?? '';
                      final belumLunas = statusBayar != 'lunas';

                      return GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                OrderDetailScreen(docId: doc.id, data: data),
                          ),
                        ),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 5,
                                height: 90,
                                decoration: BoxDecoration(
                                  color: sColor,
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(16),
                                    bottomLeft: Radius.circular(16),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 14,
                                ),
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: sColor.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(sIcon, color: sColor, size: 20),
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        noPelanggan,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        layananNama +
                                            (jenis.isNotEmpty
                                                ? ' · $jenis'
                                                : ''),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(fontSize: 12),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          _miniChip(context, status, sColor),
                                          const SizedBox(width: 6),
                                          if (belumLunas)
                                            _miniChip(
                                              context,
                                              'Belum Bayar',
                                              Colors.orange.shade700,
                                            ),
                                          if (!belumLunas)
                                            Text(
                                              hargaFmt,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 12,
                                                  ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(right: 14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      estimasi,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(fontSize: 11),
                                    ),
                                    const SizedBox(height: 4),
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      color: Colors.grey.shade400,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(
    BuildContext context, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
    required Color primary,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? primary
              : (isDark ? Colors.white10 : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? primary : Colors.transparent),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? Colors.white
                : Theme.of(context).textTheme.bodySmall?.color,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _filterChipIcon(
    BuildContext context, {
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
    required Color activeColor,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? activeColor
              : (isDark ? Colors.white10 : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? activeColor : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: selected
                  ? Colors.white
                  : Theme.of(context).textTheme.bodySmall?.color,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: selected
                    ? Colors.white
                    : Theme.of(context).textTheme.bodySmall?.color,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniChip(BuildContext context, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.25), width: 0.8),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.18),
            blurRadius: 4,
            offset: const Offset(0, 1.5),
          ),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 14),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        child: AppBar(
          title: Text(
            'Daftar Order',
            style:
                Theme.of(context).appBarTheme.titleTextStyle?.copyWith(
                  fontWeight: FontWeight.bold,
                ) ??
                const TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor:
              Theme.of(context).appBarTheme.backgroundColor ?? kPrimary,
          elevation: 2,
          centerTitle: true,
        ),
      ),
    );
  }
}

class _ChipData {
  final String label;
  final String status;
  const _ChipData({required this.label, required this.status});
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

// ════════════════════════════════════════════════════════════════════════════
//  ORDER DETAIL SCREEN
// ════════════════════════════════════════════════════════════════════════════
class OrderDetailScreen extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;
  const OrderDetailScreen({super.key, required this.docId, required this.data});

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

  int get _grandTotal => _totalLayanan + _totalBiayaTambahan;

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

  // ── Cetak Struk ───────────────────────────────────────────────────────────
  void _cetak() {
    final tanggalCetak = DateFormat('dd MMM yyyy HH:mm').format(DateTime.now());

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
                      _strRow('No', _noPelanggan),
                      _strRow('Tgl', _waktuStr),
                      _strRow('Pelanggan', _namaPelangganStr),
                      _strRow('HP', _noHp.isNotEmpty ? _noHp : '-'),
                    ],
                  ),
                ),
                const Divider(),

                // Layanan
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
                ..._items.asMap().entries.map((entry) {
                  final i = entry.key;
                  final item = entry.value;
                  final tipe = item['layanan_tipe']?.toString() ?? '';
                  final satuan = _satuanLabel(tipe);
                  final berat = item['berat_kg'];
                  final harga = item['harga_satuan'];
                  final subtotal = _itemTotal(item);
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

                // Biaya tambahan (jika ada) ← BARU
                if (_biayaTambahan.isNotEmpty) ...[
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
                  ..._biayaTambahan.map((b) {
                    final nominal = b['nominal'] is num
                        ? (b['nominal'] as num).toInt()
                        : int.tryParse(b['nominal'].toString()) ?? 0;
                    final qty = b['qty'] is num
                        ? (b['qty'] as num).toInt()
                        : int.tryParse((b['qty'] ?? 1).toString()) ?? 1;
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

                // Total
                Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Layanan: ${_formatRupiah(_totalLayanan)}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      if (_biayaTambahan.isNotEmpty)
                        Text(
                          'Biaya Tambahan: ${_formatRupiah(_totalBiayaTambahan)}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      Text(
                        'TOTAL: ${_formatRupiah(_grandTotal)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(),

                // Pembayaran
                Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dibayar: ${_dpAmount > 0 ? _formatRupiah(_dpAmount) : 'Rp 0'}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        'Sisa: ${_formatRupiah(_sisaTagihan)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        'Status: ${_sudahLunas ? 'LUNAS' : 'BELUM LUNAS'}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: _sudahLunas ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Est Selesai: $_estimasi',
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
                        'Dicetak oleh: $_admin',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Tombol
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
                                data: {
                                  // Info outlet
                                  'nama_laundry':
                                      OutletSettings.namaMadeenalaundry,
                                  'alamat': OutletSettings.alamat,
                                  'no_hp_laundry':
                                      OutletSettings.noHpMadeenalaundry,
                                  // Info order — KEY KONSISTEN
                                  'no_order': _noPelanggan,
                                  'waktu': _waktuStr,
                                  'pelanggan': _namaPelangganStr,
                                  'no_hp': _noHp.isNotEmpty ? _noHp : '-',
                                  // Items & biaya tambahan
                                  'items': List<Map<String, dynamic>>.from(
                                    _items.map(
                                      (e) =>
                                          Map<String, dynamic>.from(e)
                                            ..remove('_itemDocId'),
                                    ),
                                  ),
                                  'biaya_tambahan':
                                      List<Map<String, dynamic>>.from(
                                        _biayaTambahan.map(
                                          (e) =>
                                              Map<String, dynamic>.from(e)
                                                ..remove('_biayaDocId'),
                                        ),
                                      ),
                                  // Total & bayar
                                  'grand_total': _grandTotal,
                                  'dp_amount': _dpAmount,
                                  'sisa_tagihan': _sisaTagihan,
                                  'sudah_lunas': _sudahLunas,
                                  'estimasi': _estimasi,
                                  'admin': _admin,
                                  'tanggal_cetak': tanggalCetak,
                                },
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

  // ── Konfirmasi Status ─────────────────────────────────────────────────────
  void _showKonfirmasiStatus(String newStatus) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                  Theme.of(context).appBarTheme.foregroundColor ?? Colors.white,
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
      final itemsSnap = await FirebaseFirestore.instance
          .collection('order')
          .doc(widget.docId)
          .collection('items')
          .get();
      for (final doc in itemsSnap.docs) {
        await doc.reference.delete();
      }
      await FirebaseFirestore.instance
          .collection('order')
          .doc(widget.docId)
          .delete();

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
    final estimasiTerpanjang = firstItem['estimasi_selesai']?.toString() ?? '-';

    try {
      await FirebaseFirestore.instance
          .collection('order')
          .doc(widget.docId)
          .update({
            'harga_total': _grandTotal,
            'jumlah_item': _items.length,
            'estimasi_selesai': estimasiTerpanjang,
          });
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
                  const SizedBox(height: 16),

                  // ── Item Pesanan ──────────────────────────────────────────
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
                    final estimasiItem =
                        item['estimasi_selesai']?.toString() ?? '-';
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
                                  estimasiItem,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodySmall?.copyWith(fontSize: 10),
                                ),
                                if (_items.length > 1) ...[
                                  const SizedBox(width: 6),
                                  GestureDetector(
                                    onTap: () => _deleteItemFromFirestore(idx),
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
                      children: [
                        _pembRow(
                          'Total Layanan',
                          _formatRupiah(_grandTotal),
                          valueStyle: null,
                        ),
                        if (_dpAmount > 0) ...[
                          const SizedBox(height: 8),
                          _pembRow(
                            'DP / Uang Muka',
                            '- ${_formatRupiah(_dpAmount)}',
                            valueStyle: TextStyle(
                              color: Colors.teal.shade600,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                        const Divider(height: 20),
                        _pembRow(
                          'Total',
                          totalFmt,
                          valueStyle: TextStyle(
                            color: primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _pembRow(
                          'Sisa Tagihan',
                          _sudahLunas ? 'Rp 0' : _formatRupiah(_sisaTagihan),
                          valueStyle: TextStyle(
                            color: _sudahLunas ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 12),
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

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mdnlaundry_project/screens/main_screens.dart';

class LaporanOrderPage extends StatefulWidget {
  final String storeId;
  final String outletId;
  final bool isGabungan;
  const LaporanOrderPage({
    super.key,
    required this.storeId,
    required this.outletId,
    this.isGabungan = false,
  });

  @override
  State<LaporanOrderPage> createState() => _LaporanOrderPageState();
}

class _LaporanOrderPageState extends State<LaporanOrderPage> {
  String _selectedPeriode = '30 Hari Terakhir';
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 29));
  DateTime _endDate = DateTime.now();

  String _searchQuery = '';
  bool _showSearch = false;
  final TextEditingController _searchCtrl = TextEditingController();

  bool _isLoading = true;
  int _totalTransaksi = 0;
  double _totalOmzet = 0;
  double _totalTerbayar = 0;
  double _totalPiutang = 0;
  double _totalMeter = 0;
  double _totalKg = 0;

  List<Map<String, dynamic>> _allOrders = [];
  Map<String, List<Map<String, dynamic>>> _grouped = {};

  // ── Current user role (parsed dari displayName "Nama|NIP|Role")
  String _currentUserNama = '';
  String _currentUserRole = ''; // 'owner' | 'admin'

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _startDate = today.subtract(const Duration(days: 29));
    _endDate = today;
    _parseCurrentUser();
    _fetchData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ════════════════════════════════════════════════════════════
  // PARSE CURRENT USER
  // displayName format: "Nama|NIP|Role"
  // ════════════════════════════════════════════════════════════
  void _parseCurrentUser() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final parts = (user.displayName ?? '').split('|');
    _currentUserNama = parts.isNotEmpty ? parts[0].trim() : '';
    _currentUserRole = parts.length >= 3
        ? parts[2].trim().toLowerCase()
        : 'admin';
  }

  bool get _isOwner => _currentUserRole == 'owner';

  // ════════════════════════════════════════════════════════════
  // FETCH
  // ════════════════════════════════════════════════════════════
  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      Query<Map<String, dynamic>> orderQuery = FirebaseFirestore.instance
          .collection('order')
          .where('store_id', isEqualTo: widget.storeId);
      Query<Map<String, dynamic>> pelangganQuery = FirebaseFirestore.instance
          .collection('pelanggan')
          .where('store_id', isEqualTo: widget.storeId);

      if (!widget.isGabungan) {
        orderQuery = orderQuery.where('outlet_id', isEqualTo: widget.outletId);
        pelangganQuery = pelangganQuery.where(
          'outlet_id',
          isEqualTo: widget.outletId,
        );
      }

      final results = await Future.wait([
        orderQuery.get(),
        pelangganQuery.get(),
      ]);

      final orderSnap = results[0];
      final pelangganSnap = results[1];

      // Build pelanggan lookup
      final Map<String, Map<String, String>> pelangganMap = {};
      for (final doc in pelangganSnap.docs) {
        final d = doc.data();
        final key = (d['nomor_pelanggan'] ?? '').toString().trim();
        if (key.isEmpty) continue;
        pelangganMap[key] = {
          'nama': (d['nama_lengkap'] ?? key).toString().trim(),
          'nomer_hp': (d['nomer_hp'] ?? '').toString().trim(),
          'alamat': (d['alamat'] ?? '').toString().trim(),
        };
      }

      final List<Map<String, dynamic>> orders = [];

      for (final doc in orderSnap.docs) {
        final data = doc.data();

        // waktu_order
        final dynamic rawWaktu = data['waktu_order'];
        if (rawWaktu == null) continue;
        DateTime tgl;
        if (rawWaktu is Timestamp) {
          tgl = rawWaktu.toDate();
        } else {
          try {
            final s = rawWaktu.toString().trim();
            tgl = s.contains('/')
                ? DateFormat('dd/MM/yyyy HH:mm').parse(s)
                : DateFormat('dd-MM-yyyy').parse(s);
          } catch (_) {
            continue;
          }
        }

        // ── Nama admin — parse dari field 'admin' (bisa "Nama" atau "Nama|NIP|Role")
        final String rawAdmin = (data['admin'] ?? '').toString().trim();
        final String namaAdmin = rawAdmin.contains('|')
            ? rawAdmin.split('|').first.trim()
            : rawAdmin;

        // ── FILTER ROLE: Admin hanya lihat order miliknya sendiri
        if (!_isOwner && namaAdmin != _currentUserNama) continue;

        final String nomorPelanggan = (data['nomor_pelanggan'] ?? '')
            .toString()
            .trim();
        if (nomorPelanggan.isEmpty) continue;

        final info = pelangganMap[nomorPelanggan];
        final String namaDariOrder = (data['nama_pelanggan'] ?? '')
            .toString()
            .trim();
        final String hpDariOrder = (data['no_hp'] ?? '').toString().trim();

        final String nama = namaDariOrder.isNotEmpty
            ? namaDariOrder
            : (info?['nama'] ?? nomorPelanggan);
        final String nomerHp = hpDariOrder.isNotEmpty
            ? hpDariOrder
            : (info?['nomer_hp'] ?? '');
        final String alamat = info?['alamat'] ?? '';

        final double hargaTotal = (data['harga_total'] ?? 0).toDouble();
        final double dpAmount = (data['dp_amount'] ?? 0).toDouble();

        final String statusBayar = (data['status_bayar'] ?? '')
            .toString()
            .toLowerCase();
        final String statusOrder = (data['status'] ?? '').toString();
        final String layananNama = (data['layanan_nama'] ?? '-')
            .toString()
            .trim();
        final String layananTipe = (data['layanan_tipe'] ?? '')
            .toString()
            .toLowerCase()
            .trim();
        final double beratKg = (data['berat_kg'] ?? 0).toDouble();

        final String orderId =
            '${DateFormat('yyyyMMdd').format(tgl)}'
            '-'
            '${doc.id.substring(0, 4).toUpperCase()}';

        orders.add({
          'doc_id': doc.id,
          'order_id': orderId,
          'nomor_pelanggan': nomorPelanggan,
          'nama': nama,
          'nomer_hp': nomerHp,
          'alamat': alamat,
          'harga_total': hargaTotal,
          'dp_amount': dpAmount,
          'status_bayar': statusBayar,
          'status_order': statusOrder,
          'layanan_nama': layananNama,
          'admin': namaAdmin, // sudah di-parse bersih
          'waktu': tgl,
          'layanan_tipe': layananTipe,
          'berat_kg': beratKg,
        });
      }

      orders.sort(
        (a, b) => (b['waktu'] as DateTime).compareTo(a['waktu'] as DateTime),
      );

      final result = _computeFilter(orders, _startDate, _endDate, _searchQuery);

      setState(() {
        _allOrders = orders;
        _isLoading = false;
        _totalTransaksi = result['totalTransaksi'] as int;
        _totalOmzet = result['totalOmzet'] as double;
        _totalTerbayar = result['totalTerbayar'] as double;
        _totalPiutang = result['totalPiutang'] as double;
        _totalMeter = result['totalMeter'] as double;
        _totalKg = result['totalKg'] as double;
        _grouped = result['grouped'] as Map<String, List<Map<String, dynamic>>>;
      });
    } catch (e, stack) {
      debugPrint('ERROR fetch laporan order: $e\n$stack');
      setState(() => _isLoading = false);
    }
  }

  // ════════════════════════════════════════════════════════════
  // COMPUTE FILTER
  // ════════════════════════════════════════════════════════════
  Map<String, dynamic> _computeFilter(
    List<Map<String, dynamic>> orders,
    DateTime startDate,
    DateTime endDate,
    String searchQuery,
  ) {
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);

    final filtered = orders.where((item) {
      final DateTime tgl = item['waktu'] as DateTime;
      final DateTime hari = DateTime(tgl.year, tgl.month, tgl.day);
      final bool inRange = !hari.isBefore(start) && !hari.isAfter(end);

      final bool matchSearch =
          searchQuery.isEmpty ||
          (item['nama'] as String).toLowerCase().contains(
            searchQuery.toLowerCase(),
          ) ||
          (item['nomor_pelanggan'] as String).toLowerCase().contains(
            searchQuery.toLowerCase(),
          ) ||
          (item['order_id'] as String).toLowerCase().contains(
            searchQuery.toLowerCase(),
          );

      return inRange && matchSearch;
    }).toList();

    double omzet = 0, terbayar = 0, piutang = 0, totalMeter = 0, totalKg = 0;
    for (final o in filtered) {
      final double harga = o['harga_total'] as double;
      final double dp = o['dp_amount'] as double;
      final String status = o['status_bayar'] as String;
      final String layananTipe = o['layanan_tipe'] as String;
      final double beratKg = o['berat_kg'] as double;

      omzet += harga;

      if (status == 'lunas') {
        terbayar += harga;
      } else if (status == 'dp') {
        terbayar += dp;
        piutang += (harga - dp).clamp(0, double.infinity);
      } else {
        piutang += harga;
      }

      if (layananTipe == 'meter') {
        totalMeter += beratKg;
      } else if (layananTipe == 'kiloan') {
        totalKg += beratKg;
      }
    }

    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final o in filtered) {
      final String key = DateFormat(
        'd MMM yyyy',
        'id',
      ).format(o['waktu'] as DateTime);
      grouped.putIfAbsent(key, () => []).add(o);
    }

    return {
      'totalTransaksi': filtered.length,
      'totalOmzet': omzet,
      'totalTerbayar': terbayar,
      'totalPiutang': piutang,
      'totalMeter': totalMeter,
      'totalKg': totalKg,
      'grouped': grouped,
    };
  }

  // ════════════════════════════════════════════════════════════
  // APPLY FILTER
  // ════════════════════════════════════════════════════════════
  void _applyFilter() {
    final result = _computeFilter(
      _allOrders,
      _startDate,
      _endDate,
      _searchQuery,
    );
    setState(() {
      _totalTransaksi = result['totalTransaksi'] as int;
      _totalOmzet = result['totalOmzet'] as double;
      _totalTerbayar = result['totalTerbayar'] as double;
      _totalPiutang = result['totalPiutang'] as double;
      _totalMeter = result['totalMeter'] as double;
      _totalKg = result['totalKg'] as double;
      _grouped = result['grouped'] as Map<String, List<Map<String, dynamic>>>;
    });
  }

  // ════════════════════════════════════════════════════════════
  // DETAIL BOTTOM SHEET
  // ════════════════════════════════════════════════════════════
  void _showDetailOrder(Map<String, dynamic> order) {
    final double harga = order['harga_total'] as double;
    final double dp = order['dp_amount'] as double;
    final String statusBayar = order['status_bayar'] as String;
    final bool lunas = statusBayar == 'lunas';
    final bool hasDP = statusBayar == 'dp' && dp > 0;
    final double sisaBayar = lunas ? 0 : (harga - dp).clamp(0, double.infinity);

    final DateTime tgl = order['waktu'] as DateTime;
    final String layanan = order['layanan_nama'] as String;
    final String statusOrder = order['status_order'] as String;
    final String admin = order['admin'] as String;
    final String nomerHp = order['nomer_hp'] as String;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final bodyLarge = theme.textTheme.bodyLarge;
        final bodySmall = theme.textTheme.bodySmall;

        final Color statusColor = lunas
            ? const Color(0xff16A34A)
            : hasDP
            ? const Color(0xffD97706)
            : const Color(0xffDC2626);
        final String statusLabel = lunas
            ? 'Lunas'
            : hasDP
            ? 'DP'
            : 'Belum Bayar';

        return Container(
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
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
                      color: theme.dividerColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      order['nomor_pelanggan'] as String,
                      style: bodyLarge?.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _formatRp(harga),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withOpacity(0.4)),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                _sheetSection('PELANGGAN', Icons.person_outline_rounded),
                const SizedBox(height: 8),
                Text(
                  order['nama'] as String,
                  style: bodyLarge?.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  order['nomor_pelanggan'] as String,
                  style: bodySmall?.copyWith(fontSize: 13),
                ),
                if (nomerHp.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        Icons.phone_outlined,
                        size: 13,
                        color: theme.textTheme.bodySmall?.color,
                      ),
                      const SizedBox(width: 4),
                      Text(nomerHp, style: bodySmall?.copyWith(fontSize: 12)),
                    ],
                  ),
                ],
                const SizedBox(height: 16),

                _sheetSection('LAYANAN', Icons.local_laundry_service_outlined),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(top: 5, right: 8),
                      decoration: const BoxDecoration(
                        color: Color(0xff0284C7),
                        shape: BoxShape.circle,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '$layanan — ${_formatRp(harga)}',
                        style: bodyLarge?.copyWith(fontSize: 13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                _sheetSection('STATUS ORDER', Icons.assignment_outlined),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _statusBadge(statusOrder),
                    const SizedBox(width: 10),
                    // ── Tampilkan nama admin di detail sheet
                    Row(
                      children: [
                        Icon(
                          Icons.badge_rounded,
                          size: 13,
                          color: theme.textTheme.bodySmall?.color,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          admin.isEmpty ? '-' : admin,
                          style: bodySmall?.copyWith(fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                _sheetSection('WAKTU ORDER', Icons.calendar_month_outlined),
                const SizedBox(height: 8),
                _sheetTimeRow(
                  Icons.access_time_rounded,
                  'Masuk',
                  DateFormat('d MMM yyyy, HH:mm', 'id').format(tgl),
                  bodySmall,
                ),
                const SizedBox(height: 16),

                _sheetSection('PEMBAYARAN', Icons.credit_card_outlined),
                const SizedBox(height: 8),
                _sheetPayRow(
                  'Total',
                  _formatRp(harga),
                  bodySmall: bodySmall,
                  valueStyle: bodyLarge?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (hasDP) ...[
                  const SizedBox(height: 6),
                  _sheetPayRow(
                    'DP Terbayar',
                    _formatRp(dp),
                    bodySmall: bodySmall,
                    valueStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xffD97706),
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                _sheetPayRow(
                  lunas ? 'Status' : 'Sisa Tagihan',
                  lunas ? 'Lunas' : _formatRp(sisaBayar),
                  bodySmall: bodySmall,
                  valueStyle: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: lunas
                        ? const Color(0xff16A34A)
                        : const Color(0xffDC2626),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  // ════════════════════════════════════════════════════════════
  // PERIODE PICKER
  // ════════════════════════════════════════════════════════════
  void _showPeriodePicker() {
    final options = [
      'Hari Ini',
      'Kemarin',
      'Minggu Ini',
      'Bulan Ini',
      'Bulan Lalu',
      '30 Hari Terakhir',
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
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
            const SizedBox(height: 20),
            Text(
              'Pilih Periode',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Filter laporan berdasarkan rentang tanggal',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: options.map((opt) {
                final bool sel = _selectedPeriode == opt;
                return GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    _setPeriode(opt);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: sel
                          ? kPrimary.withOpacity(0.1)
                          : Theme.of(context).scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: sel ? kPrimary : Theme.of(context).dividerColor,
                        width: sel ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (sel) ...[
                          Icon(
                            Icons.check_circle_rounded,
                            color: kPrimary,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          opt,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: sel
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: sel
                                ? kPrimary
                                : Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () async {
                Navigator.pop(context);
                final DateTimeRange? range = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                  initialDateRange: DateTimeRange(
                    start: _startDate,
                    end: _endDate,
                  ),
                  builder: (ctx, child) => Theme(
                    data: Theme.of(ctx).copyWith(
                      colorScheme: Theme.of(
                        ctx,
                      ).colorScheme.copyWith(primary: kPrimary),
                    ),
                    child: child!,
                  ),
                );
                if (range != null) {
                  setState(() {
                    _selectedPeriode = 'Custom';
                    _startDate = range.start;
                    _endDate = range.end;
                  });
                  _applyFilter();
                }
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: kPrimary, width: 1.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.calendar_month_rounded,
                      color: kPrimary,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Pilih Tanggal Custom',
                      style: TextStyle(
                        color: kPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _setPeriode(String label) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime s, e;
    switch (label) {
      case 'Hari Ini':
        s = e = today;
        break;
      case 'Kemarin':
        s = e = today.subtract(const Duration(days: 1));
        break;
      case 'Minggu Ini':
        s = today.subtract(Duration(days: today.weekday - 1));
        e = today;
        break;
      case 'Bulan Ini':
        s = DateTime(now.year, now.month, 1);
        e = today;
        break;
      case 'Bulan Lalu':
        s = DateTime(now.year, now.month - 1, 1);
        e = DateTime(now.year, now.month, 0);
        break;
      default:
        s = today.subtract(const Duration(days: 29));
        e = today;
    }
    setState(() {
      _selectedPeriode = label;
      _startDate = s;
      _endDate = e;
    });
    _applyFilter();
  }

  // ════════════════════════════════════════════════════════════
  // HELPERS
  // ════════════════════════════════════════════════════════════
  String _formatRp(double val) => NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  ).format(val);

  String _formatNumber(double val) =>
      val.toStringAsFixed(2).replaceAll('.', ',');

  String _formatPeriodeLabel() {
    if (_selectedPeriode == 'Custom') {
      return '${DateFormat('d MMM', 'id').format(_startDate)} – '
          '${DateFormat('d MMM yyyy', 'id').format(_endDate)}';
    }
    return _selectedPeriode;
  }

  double _grupTotal(List<Map<String, dynamic>> items) =>
      items.fold(0, (sum, e) => sum + (e['harga_total'] as double));

  Color _orderStatusColor(String status) {
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
        return const Color(0xFF16A34A);
      default:
        return Colors.grey;
    }
  }

  Widget _statusBadge(String status) {
    final color = _orderStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        status.isEmpty ? '-' : status,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final cardColor = Theme.of(context).cardColor;
    final bodyLarge = Theme.of(context).textTheme.bodyLarge;
    final bodySmall = Theme.of(context).textTheme.bodySmall;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(context),
      body: GlobalRefresh(
        onRefresh: _fetchData,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: kPrimary))
            : CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Info banner untuk Admin ───────────────────────
                          if (!_isOwner)
                            Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: kPrimary.withOpacity(0.07),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: kPrimary.withOpacity(0.25),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline_rounded,
                                    color: kPrimary,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Menampilkan order Anda: $_currentUserNama',
                                      style: TextStyle(
                                        color: kPrimary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // ── Periode + search bar ──────────────────────────
                          Row(
                            children: [
                              GestureDetector(
                                onTap: _showPeriodePicker,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: kPrimary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: kPrimary,
                                      width: 1.2,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.calendar_month_rounded,
                                        color: kPrimary,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _formatPeriodeLabel(),
                                        style: TextStyle(
                                          color: kPrimary,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Icon(
                                        Icons.keyboard_arrow_down_rounded,
                                        color: kPrimary,
                                        size: 18,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${DateFormat('d MMM', 'id').format(_startDate)} – '
                                '${DateFormat('d MMM yyyy', 'id').format(_endDate)}',
                                style: bodySmall?.copyWith(fontSize: 11),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () =>
                                    setState(() => _showSearch = !_showSearch),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: _showSearch
                                        ? kPrimary.withOpacity(0.1)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.search_rounded,
                                    color: _showSearch
                                        ? kPrimary
                                        : Theme.of(
                                            context,
                                          ).textTheme.bodySmall?.color,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          if (_showSearch) ...[
                            const SizedBox(height: 10),
                            TextField(
                              controller: _searchCtrl,
                              autofocus: true,
                              onChanged: (val) {
                                _searchQuery = val;
                                _applyFilter();
                              },
                              decoration: InputDecoration(
                                hintText:
                                    'Cari nama, nomor pelanggan, atau ID order...',
                                prefixIcon: const Icon(
                                  Icons.search_rounded,
                                  size: 20,
                                ),
                                suffixIcon: _searchQuery.isNotEmpty
                                    ? GestureDetector(
                                        onTap: () {
                                          _searchCtrl.clear();
                                          _searchQuery = '';
                                          _applyFilter();
                                        },
                                        child: const Icon(
                                          Icons.close,
                                          size: 18,
                                        ),
                                      )
                                    : null,
                                filled: true,
                                fillColor: cardColor,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                  horizontal: 14,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                    color: Theme.of(context).dividerColor,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                    color: Theme.of(context).dividerColor,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: kPrimary,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),

                          // ── Summary cards 2×3 ─────────────────────────────
                          Row(
                            children: [
                              _summaryCard(
                                cardColor: cardColor,
                                bodySmall: bodySmall,
                                icon: Icons.receipt_long_outlined,
                                iconColor: kPrimary,
                                iconBg: kPrimary.withOpacity(0.1),
                                label: 'Transaksi',
                                value: _totalTransaksi.toString(),
                                valueColor: kPrimary,
                                isCurrency: false,
                              ),
                              const SizedBox(width: 8),
                              _summaryCard(
                                cardColor: cardColor,
                                bodySmall: bodySmall,
                                icon: Icons.hourglass_empty_rounded,
                                iconColor: const Color(0xffD97706),
                                iconBg: const Color(0xffFEF3C7),
                                label: 'Piutang',
                                value: _formatRp(_totalPiutang),
                                valueColor: const Color(0xffD97706),
                                isCurrency: true,
                              ),
                              const SizedBox(width: 8),
                              _summaryCard(
                                cardColor: cardColor,
                                bodySmall: bodySmall,
                                icon: Icons.account_balance_wallet_outlined,
                                iconColor: kPrimary,
                                iconBg: kPrimary.withOpacity(0.1),
                                label: 'Omzet',
                                value: _formatRp(_totalOmzet),
                                valueColor: kPrimary,
                                isCurrency: true,
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              _summaryCard(
                                cardColor: cardColor,
                                bodySmall: bodySmall,
                                icon: Icons.check_circle_outline_rounded,
                                iconColor: const Color(0xff16A34A),
                                iconBg: const Color(0xffDCFCE7),
                                label: 'Terbayar',
                                value: _formatRp(_totalTerbayar),
                                valueColor: const Color(0xff16A34A),
                                isCurrency: true,
                              ),
                              const SizedBox(width: 8),
                              _summaryCard(
                                cardColor: cardColor,
                                bodySmall: bodySmall,
                                icon: Icons.scale_outlined,
                                iconColor: const Color(0xff8B5CF6),
                                iconBg: const Color(0xffF3E8FF),
                                label: 'Total KG',
                                value: _formatNumber(_totalKg),
                                valueColor: const Color(0xff8B5CF6),
                                isCurrency: false,
                              ),
                              const SizedBox(width: 8),
                              _summaryCard(
                                cardColor: cardColor,
                                bodySmall: bodySmall,
                                icon: Icons.straighten_outlined,
                                iconColor: const Color(0xff06B6D4),
                                iconBg: const Color(0xffCFFAFE),
                                label: 'Total Meter',
                                value: _formatNumber(_totalMeter),
                                valueColor: const Color(0xff06B6D4),
                                isCurrency: false,
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),

                  // ── Grouped list ─────────────────────────────────────────
                  if (_grouped.isEmpty)
                    SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.receipt_long_outlined,
                              size: 56,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Tidak ada transaksi',
                              style: bodyLarge?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Tarik ke bawah untuk refresh',
                              style: bodySmall,
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate((ctx, i) {
                        final String tanggal = _grouped.keys.elementAt(i);
                        final List<Map<String, dynamic>> items =
                            _grouped[tanggal]!;
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today_rounded,
                                    color: kPrimary,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    tanggal,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: kPrimary,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${items.length} Trx  ${_formatRp(_grupTotal(items))}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: kPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ...items.map(
                                (order) => _buildOrderCard(
                                  order,
                                  cardColor,
                                  bodyLarge,
                                  bodySmall,
                                ),
                              ),
                            ],
                          ),
                        );
                      }, childCount: _grouped.length),
                    ),

                  const SliverToBoxAdapter(child: SizedBox(height: 80)),
                ],
              ),
      ),

      // ── Bottom bar ───────────────────────────────────────────────────────
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: cardColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: kPrimary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.bar_chart_rounded, color: kPrimary, size: 22),
            ),
            const SizedBox(width: 12),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isOwner ? 'Pendapatan Kotor' : 'Omzet Saya',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontSize: 11),
                ),
                Text(
                  _formatRp(_totalOmzet),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: kPrimary,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Terbayar',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontSize: 11),
                ),
                Text(
                  _formatRp(_totalTerbayar),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xff16A34A),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // WIDGET HELPERS
  // ════════════════════════════════════════════════════════════
  Widget _summaryCard({
    required Color cardColor,
    required TextStyle? bodySmall,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String label,
    required String value,
    required Color valueColor,
    required bool isCurrency,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: bodySmall?.copyWith(fontSize: 10),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor, size: 16),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: isCurrency ? 12 : 18,
                        fontWeight: FontWeight.bold,
                        color: valueColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCard(
    Map<String, dynamic> order,
    Color cardColor,
    TextStyle? bodyLarge,
    TextStyle? bodySmall,
  ) {
    final String nomorPelanggan = order['nomor_pelanggan'] as String;
    final String nama = order['nama'] as String;
    final String layanan = order['layanan_nama'] as String;
    final double harga = order['harga_total'] as double;
    final double dp = order['dp_amount'] as double;
    final String statusBayar = order['status_bayar'] as String;
    final String statusOrder = order['status_order'] as String;
    final DateTime waktu = order['waktu'] as DateTime;
    final String adminNama = order['admin'] as String;

    final bool lunas = statusBayar == 'lunas';
    final bool hasDP = statusBayar == 'dp' && dp > 0;
    final double sisaBayar = lunas ? 0 : (harga - dp).clamp(0, double.infinity);

    final Color bayarColor = lunas
        ? const Color(0xff16A34A)
        : hasDP
        ? const Color(0xffD97706)
        : const Color(0xffDC2626);
    final String bayarLabel = lunas
        ? 'Lunas'
        : hasDP
        ? 'DP'
        : 'Belum Bayar';
    final IconData bayarIcon = lunas
        ? Icons.check_circle_outline_rounded
        : hasDP
        ? Icons.payments_outlined
        : Icons.hourglass_empty_rounded;

    final Color nilaiColor = lunas
        ? const Color(0xff16A34A)
        : const Color(0xffDC2626);
    final String nilaiText = lunas ? _formatRp(harga) : _formatRp(sisaBayar);

    return GestureDetector(
      onTap: () => _showDetailOrder(order),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Theme.of(context).dividerColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nomorPelanggan,
                          style: bodyLarge?.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          nama,
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (!lunas && dp > 0)
                        Text(
                          _formatRp(harga),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade400,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      Text(
                        nilaiText,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: nilaiColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 6),

              Row(
                children: [
                  Icon(
                    Icons.local_laundry_service_outlined,
                    size: 12,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      layanan,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: bodySmall?.copyWith(fontSize: 11),
                    ),
                  ),
                  Icon(
                    Icons.access_time_rounded,
                    size: 11,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    DateFormat('d MMM, HH:mm', 'id').format(waktu),
                    style: bodySmall?.copyWith(fontSize: 11),
                  ),
                ],
              ),

              // ── Nama admin (hanya tampil jika owner yang lihat)
              if (_isOwner && adminNama.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.badge_rounded,
                      size: 12,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                    const SizedBox(width: 4),
                    Text(adminNama, style: bodySmall?.copyWith(fontSize: 11)),
                  ],
                ),
              ],

              const SizedBox(height: 8),

              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: bayarColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: bayarColor.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(bayarIcon, color: bayarColor, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          bayarLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: bayarColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (statusOrder.isNotEmpty) _statusBadge(statusOrder),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => _showDetailOrder(order),
                    child: Row(
                      children: [
                        Text(
                          'Detail',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: kPrimary,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 11,
                          color: kPrimary,
                        ),
                      ],
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

  Widget _sheetSection(String label, IconData icon) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: kPrimary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Icon(
          icon,
          size: 14,
          color: Theme.of(context).textTheme.bodySmall?.color,
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }

  Widget _sheetTimeRow(
    IconData icon,
    String label,
    String value,
    TextStyle? bodySmall, {
    Color? color,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 14,
          color: color ?? Theme.of(context).textTheme.bodySmall?.color,
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 60,
          child: Text(label, style: bodySmall?.copyWith(fontSize: 13)),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: color ?? Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
      ],
    );
  }

  Widget _sheetPayRow(
    String label,
    String value, {
    TextStyle? bodySmall,
    TextStyle? valueStyle,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: bodySmall?.copyWith(fontSize: 13)),
        Text(value, style: valueStyle),
      ],
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
            _isOwner ? 'Laporan Order' : 'Laporan Order Saya',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: kPrimary,
          foregroundColor: Colors.white,
          elevation: 2,
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              onPressed: _fetchData,
            ),
          ],
          leading: Navigator.canPop(context)
              ? IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                )
              : null,
        ),
      ),
    );
  }
}

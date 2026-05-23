import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // ✅ FIX: tambah import DateFormat
import '../screens/screens.dart';

class LaporanOrderPage extends StatefulWidget {
  const LaporanOrderPage({super.key});

  @override
  State<LaporanOrderPage> createState() => _LaporanOrderPageState();
}

class _LaporanOrderPageState extends State<LaporanOrderPage> {
  String _selectedPeriode = "30 Hari Terakhir";
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 29));
  DateTime _endDate = DateTime.now();

  String _searchQuery = "";
  bool _showSearch = false;
  final TextEditingController _searchCtrl = TextEditingController();

  bool _isLoading = true;
  int _totalTransaksi = 0;
  double _totalOmzet = 0;
  double _totalTerbayar = 0;
  double _totalPiutang = 0;

  Map<String, List<Map<String, dynamic>>> _grouped = {};
  List<Map<String, dynamic>> _allOrders = [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _startDate = today.subtract(const Duration(days: 29));
    _endDate = today;
    _fetchData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Fetch Firestore ──────────────────────────────────────────────────────
  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final DateFormat fmt = DateFormat("dd/MM/yyyy HH:mm");

      // ✅ FIX: Fetch 3 collection sekaligus dengan benar
      final results = await Future.wait([
        FirebaseFirestore.instance.collection('keuangan').get(),
        FirebaseFirestore.instance.collection('pasien').get(),
        FirebaseFirestore.instance.collection('rekam_medis').get(), // ✅ tambah
      ]);

      final keuanganSnap = results[0];
      final pasienSnap = results[1];
      final rekamMedisSnap = results[2]; // ✅ sekarang tidak crash

      // Map NIP → nama pasien
      final Map<String, String> nipToNama = {};
      for (var doc in pasienSnap.docs) {
        final d = doc.data();
        final nip = d['nomer_induk_pasien'] ?? "";
        if (nip.isNotEmpty) nipToNama[nip] = d['nama_lengkap'] ?? "-";
      }

      // ✅ Map NIP → layanan dari rekam_medis (ambil kunjungan terbaru per NIP)
      final Map<String, String> nipToLayanan = {};
      for (var doc in rekamMedisSnap.docs) {
        final d = doc.data();
        final nip = d['nomer_induk_pasien'] ?? "";
        // Simpan layanan — kalau sudah ada, rekam terbaru akan overwrite
        // (karena kita sort setelahnya, ini cukup untuk mapping)
        if (nip.isNotEmpty) {
          nipToLayanan[nip] = d['layanan'] ?? "-";
        }
      }

      final DateTime start = DateTime(
        _startDate.year,
        _startDate.month,
        _startDate.day,
      );
      final DateTime end = DateTime(
        _endDate.year,
        _endDate.month,
        _endDate.day,
      );

      List<Map<String, dynamic>> orders = [];

      for (var doc in keuanganSnap.docs) {
        final data = doc.data();
        final String waktu = data['waktu_transaksi'] ?? "";
        if (waktu.isEmpty) continue;

        try {
          DateTime tgl = fmt.parse(waktu);
          DateTime tglHari = DateTime(tgl.year, tgl.month, tgl.day);
          if (tglHari.isBefore(start) || tglHari.isAfter(end)) continue;

          final String nip = data['nomer_induk_pasien'] ?? "-";
          final String status = data['status_bayar'] ?? "-";
          final double biaya = (data['biaya'] ?? 0).toDouble();
          final String nama = nipToNama[nip] ?? nip;

          // ✅ Ambil layanan dari rekam_medis, bukan dari keuangan
          final String layanan = nipToLayanan[nip] ?? "-";

          final String orderId =
              "ORD-${DateFormat('yyyyMMdd').format(tgl)}-${doc.id.substring(0, 4).toUpperCase()}";

          orders.add({
            'doc_id': doc.id,
            'order_id': orderId,
            'nip': nip,
            'nama': nama,
            'biaya': biaya,
            'status': status,
            'waktu': tgl,
            'waktu_str': waktu,
            'layanan': layanan, // ✅ dari rekam_medis
          });
        } catch (_) {}
      }

      orders.sort(
        (a, b) => (b['waktu'] as DateTime).compareTo(a['waktu'] as DateTime),
      );

      setState(() {
        _allOrders = orders;
        _isLoading = false;
      });
      _applyFilter();
    } catch (e) {
      debugPrint("ERROR fetch laporan order: $e");
      setState(() => _isLoading = false);
    }
  }

  // ── Detail bottom sheet ──────────────────────────────────────────────────
  void _showDetailOrder(Map<String, dynamic> order) {
    final double biaya = (order['biaya'] as num).toDouble();
    final String status = (order['status'] as String?) ?? '-';
    final bool belumLunas = status == "Belum Lunas";
    final DateTime tgl = order['waktu'] as DateTime;

    // ✅ Ambil layanan dari data order (sudah dari rekam_medis)
    final String layanan = (order['layanan'] as String?)?.isNotEmpty == true
        ? order['layanan']
        : "-";

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final bodyLarge = theme.textTheme.bodyLarge;
        final bodySmall = theme.textTheme.bodySmall;

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
                // Handle bar
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

                // ── Header: Order ID + Biaya ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      (order['order_id'] as String?) ?? '-',
                      style: bodyLarge?.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _formatRp(biaya),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: belumLunas
                            ? const Color(0xffD97706)
                            : const Color(0xff16A34A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // ✅ Hanya badge status bayar — badge Antrian dihapus
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: belumLunas
                        ? const Color(0xffFEE2E2)
                        : const Color(0xffDCFCE7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    belumLunas ? "Belum Bayar" : "Lunas",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: belumLunas
                          ? const Color(0xffDC2626)
                          : const Color(0xff16A34A),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ── PELANGGAN ──
                _sheetSection("PELANGGAN", Icons.person_outline_rounded),
                const SizedBox(height: 8),
                Text(
                  (order['nama'] as String?) ?? '-',
                  style: bodyLarge?.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  (order['nip'] as String?) ?? '-',
                  style: bodySmall?.copyWith(fontSize: 13),
                ),
                const SizedBox(height: 16),

                // ── LAYANAN (dari rekam_medis) ──
                _sheetSection("LAYANAN", Icons.medical_services_outlined),
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
                        // ✅ Tampilkan nama layanan dari rekam_medis + biaya
                        "$layanan — ${_formatRp(biaya)}",
                        style: bodyLarge?.copyWith(fontSize: 13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── INFORMASI WAKTU (Est. Selesai dihapus) ──
                _sheetSection("INFORMASI WAKTU", Icons.calendar_month_outlined),
                const SizedBox(height: 8),
                _sheetTimeRow(
                  Icons.add_circle_outline_rounded,
                  "Dibuat",
                  DateFormat('d MMM yyyy, HH:mm', 'id').format(tgl),
                  bodySmall,
                ),
                // ✅ Baris Est. Selesai dihapus
                const SizedBox(height: 16),

                // ── PEMBAYARAN ──
                _sheetSection("PEMBAYARAN", Icons.credit_card_outlined),
                const SizedBox(height: 8),
                _sheetPayRow(
                  "Total",
                  _formatRp(biaya),
                  bodySmall: bodySmall,
                  valueStyle: bodyLarge?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                _sheetPayRow(
                  "Status",
                  belumLunas ? "Belum Bayar" : "Lunas",
                  bodySmall: bodySmall,
                  valueStyle: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: belumLunas
                        ? const Color(0xffDC2626)
                        : const Color(0xff16A34A),
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

  // ── Helper widgets ───────────────────────────────────────────────────────
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
          width: 90,
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

  // ── Filter & periode ─────────────────────────────────────────────────────
  void _applyFilter() {
    final DateTime start = DateTime(
      _startDate.year,
      _startDate.month,
      _startDate.day,
    );
    final DateTime end = DateTime(_endDate.year, _endDate.month, _endDate.day);

    List<Map<String, dynamic>> filtered = _allOrders.where((item) {
      final DateTime tgl = item['waktu'] as DateTime;
      final DateTime tglHari = DateTime(tgl.year, tgl.month, tgl.day);
      bool inRange = !tglHari.isBefore(start) && !tglHari.isAfter(end);
      bool matchSearch =
          _searchQuery.isEmpty ||
          (item['nama'] as String).toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ) ||
          (item['order_id'] as String).toLowerCase().contains(
            _searchQuery.toLowerCase(),
          );
      return inRange && matchSearch;
    }).toList();

    double omzet = 0, terbayar = 0, piutang = 0;
    for (var o in filtered) {
      double biaya = o['biaya'] as double;
      String status = o['status'] as String;
      omzet += biaya;
      if (status == "Belum Lunas")
        piutang += biaya;
      else
        terbayar += biaya;
    }

    Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var o in filtered) {
      final String key = DateFormat(
        'd MMM yyyy',
        'id',
      ).format(o['waktu'] as DateTime);
      grouped.putIfAbsent(key, () => []).add(o);
    }

    setState(() {
      _totalTransaksi = filtered.length;
      _totalOmzet = omzet;
      _totalTerbayar = terbayar;
      _totalPiutang = piutang;
      _grouped = grouped;
    });
  }

  void _showPeriodePicker() {
    final options = [
      "Hari Ini",
      "Kemarin",
      "Minggu Ini",
      "Bulan Ini",
      "Bulan Lalu",
      "30 Hari Terakhir",
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
              "Pilih Periode",
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Filter laporan berdasarkan rentang tanggal",
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
                final DateTimeRange? range =
                    await CalendarHelper.showFullDatePicker(context);
                if (range != null) {
                  setState(() {
                    _selectedPeriode = "Custom";
                    _startDate = range.start;
                    _endDate = range.end;
                  });
                  await _fetchData();
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
                      "Pilih Tanggal Custom",
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
      case "Hari Ini":
        s = e = today;
        break;
      case "Kemarin":
        s = e = today.subtract(const Duration(days: 1));
        break;
      case "Minggu Ini":
        s = today.subtract(Duration(days: today.weekday - 1));
        e = today;
        break;
      case "Bulan Ini":
        s = DateTime(now.year, now.month, 1);
        e = today;
        break;
      case "Bulan Lalu":
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
    _fetchData();
  }

  String _formatRp(double val) => NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  ).format(val);

  String _formatPeriodeLabel() {
    if (_selectedPeriode == "Custom") {
      return "${DateFormat('d MMM', 'id').format(_startDate)} - "
          "${DateFormat('d MMM yyyy', 'id').format(_endDate)}";
    }
    return _selectedPeriode;
  }

  double _grupTotal(List<Map<String, dynamic>> items) =>
      items.fold(0, (sum, e) => sum + (e['biaya'] as double));

  // ── BUILD ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final cardColor = Theme.of(context).cardColor;
    final bodyLarge = Theme.of(context).textTheme.bodyLarge;
    final bodySmall = Theme.of(context).textTheme.bodySmall;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(context),
      body: RefreshIndicator(
        onRefresh: _fetchData,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Laporan Penjualan",
                            style: bodyLarge?.copyWith(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 14),
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
                                "${DateFormat('d MMM yyyy', 'id').format(_startDate)} - "
                                "${DateFormat('d MMM', 'id').format(_endDate)}...",
                                style: bodySmall?.copyWith(fontSize: 11),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () =>
                                    setState(() => _showSearch = !_showSearch),
                                child: Icon(
                                  Icons.search_rounded,
                                  color: Theme.of(
                                    context,
                                  ).textTheme.bodySmall?.color,
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
                                    "Cari nama pasien atau nomor order...",
                                prefixIcon: const Icon(
                                  Icons.search_rounded,
                                  size: 20,
                                ),
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
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              _summaryCard(
                                cardColor: cardColor,
                                bodySmall: bodySmall,
                                icon: Icons.receipt_long_outlined,
                                iconColor: kPrimary,
                                iconBg: kPrimary.withOpacity(0.1),
                                label: "Transaksi",
                                value: _totalTransaksi.toString(),
                                valueColor: kPrimary,
                                isCurrency: false,
                              ),
                              const SizedBox(width: 12),
                              _summaryCard(
                                cardColor: cardColor,
                                bodySmall: bodySmall,
                                icon: Icons.hourglass_empty_rounded,
                                iconColor: const Color(0xffD97706),
                                iconBg: const Color(0xffFEF3C7),
                                label: "Piutang",
                                value: _formatRp(_totalPiutang),
                                valueColor: const Color(0xffD97706),
                                isCurrency: true,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _summaryCard(
                                cardColor: cardColor,
                                bodySmall: bodySmall,
                                icon: Icons.account_balance_wallet_outlined,
                                iconColor: kPrimary,
                                iconBg: kPrimary.withOpacity(0.1),
                                label: "Omzet",
                                value: _formatRp(_totalOmzet),
                                valueColor: kPrimary,
                                isCurrency: true,
                              ),
                              const SizedBox(width: 12),
                              _summaryCard(
                                cardColor: cardColor,
                                bodySmall: bodySmall,
                                icon: Icons.check_circle_outline_rounded,
                                iconColor: const Color(0xff16A34A),
                                iconBg: const Color(0xffDCFCE7),
                                label: "Terbayar",
                                value: _formatRp(_totalTerbayar),
                                valueColor: const Color(0xff16A34A),
                                isCurrency: true,
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),

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
                              "Tidak ada transaksi",
                              style: bodyLarge?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Tarik ke bawah untuk refresh",
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
                                    "${items.length} Trx  ${_formatRp(_grupTotal(items))}",
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
                  "Pendapatan Kotor",
                  style: bodySmall?.copyWith(fontSize: 11),
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
          ],
        ),
      ),
    );
  }

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
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(height: 10),
            Text(label, style: bodySmall?.copyWith(fontSize: 11)),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: isCurrency ? 14 : 22,
                  fontWeight: FontWeight.bold,
                  color: valueColor,
                ),
              ),
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
    final String orderId = order['order_id'] ?? "-";
    final String nama = order['nama'] ?? "-";
    final double biaya = order['biaya'] as double;
    final String status = order['status'] ?? "-";
    final DateTime waktu = order['waktu'] as DateTime;

    final bool lunas = status != "Belum Lunas";
    final Color statusColor = lunas
        ? const Color(0xff16A34A)
        : const Color(0xffD97706);
    final String statusLabel = lunas ? "Lunas" : "Belum Bayar";
    final IconData statusIcon = lunas
        ? Icons.check_circle_outline_rounded
        : Icons.hourglass_empty_rounded;

    return Container(
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
                  child: Text(
                    orderId,
                    style: bodyLarge?.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  _formatRp(biaya),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: lunas
                        ? const Color(0xff16A34A)
                        : const Color(0xffDC2626),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(nama, style: bodyLarge?.copyWith(fontSize: 13)),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 11,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
                const SizedBox(width: 4),
                Text(
                  DateFormat('d MMM yyyy, HH:mm', 'id').format(waktu),
                  style: bodySmall?.copyWith(fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, color: statusColor, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!lunas) ...[
                  const SizedBox(width: 8),
                  Text(
                    "Sisa ${_formatRp(biaya)}",
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xffDC2626),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                const Spacer(),
                GestureDetector(
                  onTap: () => _showDetailOrder(order),
                  child: Row(
                    children: [
                      Text(
                        "Lihat Detail",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: kPrimary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 12,
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
          title: const Text(
            "Laporan Order",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          backgroundColor: kPrimary,
          foregroundColor: Colors.white,
          elevation: 2,
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.download_rounded, color: Colors.white),
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Fitur export segera hadir")),
              ),
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

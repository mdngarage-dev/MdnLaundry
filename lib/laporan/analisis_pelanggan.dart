import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../screens/screens.dart';

// ════════════════════════════════════════════════════════════
// MODEL
// ════════════════════════════════════════════════════════════
class _CustomerData {
  final String nip;
  final String nama;
  int orderCount;
  double totalRevenue;
  DateTime? lastOrderDate;

  _CustomerData({
    required this.nip,
    required this.nama,
    required this.orderCount,
    required this.totalRevenue,
    this.lastOrderDate,
  });
}

// ════════════════════════════════════════════════════════════
// ENUM
// ════════════════════════════════════════════════════════════
enum _SortMode { topSpending, palingSering }

// ════════════════════════════════════════════════════════════
// SCREEN
// ════════════════════════════════════════════════════════════
class AnalisisPelangganPage extends StatefulWidget {
  const AnalisisPelangganPage({super.key});

  @override
  State<AnalisisPelangganPage> createState() => _AnalisisPelangganPageState();
}

class _AnalisisPelangganPageState extends State<AnalisisPelangganPage> {
  // ── Periode ──
  String _selectedPeriode = '30 Hari Terakhir';
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 29));
  DateTime _endDate = DateTime.now();
  List<Map<String, dynamic>> _rawTransaksi = []; // semua transaksi mentah
  Map<String, String> _nipToNama = {};
  // ── Sort & Search ──
  _SortMode _sortMode = _SortMode.topSpending;
  String _searchQuery = '';
  bool _showSearch = false;
  final TextEditingController _searchCtrl = TextEditingController();

  // ── Data ──
  bool _isLoading = true;
  List<_CustomerData> _allCustomers = [];
  List<_CustomerData> _filtered = [];

  // ── Summary ──
  int _totalCustomer = 0;
  int _totalOrder = 0;
  double _totalRevenue = 0;

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

  // ════════════════════════════════════════════════════════════
  // FETCH FIRESTORE — ikuti pola laporan_order.dart
  // (koleksi: keuangan + pasien, field: sama persis)
  // ════════════════════════════════════════════════════════════
  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final DateFormat fmt = DateFormat('dd/MM/yyyy HH:mm');

      final results = await Future.wait([
        FirebaseFirestore.instance.collection('keuangan').get(),
        FirebaseFirestore.instance.collection('pasien').get(),
      ]);

      final keuanganSnap = results[0];
      final pasienSnap = results[1];

      // Map NIP → nama
      final Map<String, String> nipToNama = {};
      for (var doc in pasienSnap.docs) {
        final d = doc.data();
        final nip = (d['nomer_induk_pasien'] ?? '').toString().trim();
        final nama = (d['nama_lengkap'] ?? '-').toString().trim();
        if (nip.isNotEmpty) nipToNama[nip] = nama;
      }

      // Simpan semua transaksi mentah (tanpa filter periode)
      final List<Map<String, dynamic>> rawList = [];
      for (var doc in keuanganSnap.docs) {
        final data = doc.data();
        final String waktu = (data['waktu_transaksi'] ?? '').toString().trim();
        if (waktu.isEmpty) continue;

        DateTime tgl;
        try {
          tgl = fmt.parse(waktu);
        } catch (_) {
          continue;
        }

        final String nip = (data['nomer_induk_pasien'] ?? '-')
            .toString()
            .trim();
        final double biaya = (data['biaya'] ?? 0).toDouble();

        rawList.add({
          'nip': nip,
          'nama': nipToNama[nip] ?? nip,
          'biaya': biaya,
          'tgl': tgl,
        });
      }

      setState(() {
        _rawTransaksi = rawList;
        _nipToNama = nipToNama;
        _isLoading = false;
      });
      _applyFilter();
    } catch (e) {
      debugPrint('ERROR fetch analisis pelanggan: $e');
      setState(() => _isLoading = false);
    }
  }

  void _applyFilter() {
    final DateTime start = DateTime(
      _startDate.year,
      _startDate.month,
      _startDate.day,
    );
    final DateTime end = DateTime(_endDate.year, _endDate.month, _endDate.day);

    // ── Group transaksi dalam periode by NIP ──
    final Map<String, _CustomerData> map = {};

    for (var t in _rawTransaksi) {
      final DateTime tgl = t['tgl'] as DateTime;
      final DateTime hari = DateTime(tgl.year, tgl.month, tgl.day);

      // Filter periode per transaksi (bukan lastOrderDate)
      if (hari.isBefore(start) || hari.isAfter(end)) continue;

      final String nip = t['nip'] as String;
      final String nama = t['nama'] as String;
      final double biaya = t['biaya'] as double;

      // Filter search
      if (_searchQuery.isNotEmpty &&
          !nama.toLowerCase().contains(_searchQuery.toLowerCase()) &&
          !nip.contains(_searchQuery)) {
        continue;
      }

      if (map.containsKey(nip)) {
        map[nip]!.orderCount += 1;
        map[nip]!.totalRevenue += biaya;
        if (map[nip]!.lastOrderDate == null ||
            tgl.isAfter(map[nip]!.lastOrderDate!)) {
          map[nip]!.lastOrderDate = tgl;
        }
      } else {
        map[nip] = _CustomerData(
          nip: nip,
          nama: nama,
          orderCount: 1,
          totalRevenue: biaya,
          lastOrderDate: tgl,
        );
      }
    }

    List<_CustomerData> list = map.values.toList();

    // Sort
    if (_sortMode == _SortMode.topSpending) {
      list.sort((a, b) => b.totalRevenue.compareTo(a.totalRevenue));
    } else {
      list.sort((a, b) => b.orderCount.compareTo(a.orderCount));
    }

    final totalOrder = list.fold<int>(0, (s, c) => s + c.orderCount);
    final totalRevenue = list.fold<double>(0, (s, c) => s + c.totalRevenue);

    setState(() {
      _filtered = list;
      _totalCustomer = list.length;
      _totalOrder = totalOrder;
      _totalRevenue = totalRevenue;
    });
  }

  // ════════════════════════════════════════════════════════════
  // PERIODE PICKER — persis seperti laporan_order.dart
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
              'Filter analisis berdasarkan rentang tanggal',
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
                    _selectedPeriode = 'Custom';
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
        s = today;
        e = today;
        break;
      case 'Kemarin':
        s = today.subtract(const Duration(days: 1));
        e = s;
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
      default: // 30 Hari Terakhir
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

  // ════════════════════════════════════════════════════════════
  // HELPERS
  // ════════════════════════════════════════════════════════════
  String _formatRp(double val) => NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  ).format(val);

  String _formatPeriodeLabel() {
    if (_selectedPeriode == 'Custom') {
      return '${DateFormat('d MMM', 'id').format(_startDate)} - '
          '${DateFormat('d MMM yyyy', 'id').format(_endDate)}';
    }
    return _selectedPeriode;
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '-';
    return DateFormat('d MMM yyyy', 'id').format(dt);
  }

  Widget _medal(int rank) {
    if (rank == 1) {
      return const Icon(
        Icons.emoji_events_rounded,
        color: Color(0xFFFFD700),
        size: 30,
      );
    } else if (rank == 2) {
      return const Icon(
        Icons.emoji_events_rounded,
        color: Color(0xFFB0B0B0),
        size: 30,
      );
    } else if (rank == 3) {
      return const Icon(
        Icons.emoji_events_rounded,
        color: Color(0xFFCD7F32),
        size: 30,
      );
    }
    return CircleAvatar(
      radius: 15,
      backgroundColor: Theme.of(context).dividerColor,
      child: Text(
        '$rank',
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.bold,
          fontSize: 12,
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
                          // ── Judul ──
                          Text(
                            'Analisis Pelanggan',
                            style: bodyLarge?.copyWith(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 14),

                          // ── Periode + Search toggle ──
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

                          // ── Search bar ──
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
                                hintText: 'Cari nama atau nomor pasien...',
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

                          const SizedBox(height: 14),

                          // ── Sort tabs ──
                          Row(
                            children: [
                              _sortTab(_SortMode.topSpending, 'Top Spending'),
                              const SizedBox(width: 8),
                              _sortTab(_SortMode.palingSering, 'Paling Sering'),
                            ],
                          ),

                          const SizedBox(height: 14),

                          // ── Summary 3 item ──
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Theme.of(context).dividerColor,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _summaryItem(
                                  icon: Icons.people_alt_outlined,
                                  value: '$_totalCustomer',
                                  label: 'Pelanggan',
                                  color: kPrimary,
                                  bodySmall: bodySmall,
                                ),
                                _vDivider(),
                                _summaryItem(
                                  icon: Icons.shopping_bag_outlined,
                                  value: '$_totalOrder',
                                  label: 'Order',
                                  color: const Color(0xff16A34A),
                                  bodySmall: bodySmall,
                                ),
                                _vDivider(),
                                _summaryItem(
                                  icon: Icons.account_balance_wallet_outlined,
                                  value: _formatRp(_totalRevenue),
                                  label: 'Revenue',
                                  color: Colors.blue.shade700,
                                  bodySmall: bodySmall,
                                  smallFont: true,
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),

                  // ── List pelanggan ──
                  if (_filtered.isEmpty)
                    SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.people_outline_rounded,
                              size: 56,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Tidak ada data pelanggan',
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
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) => Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: _customerCard(
                            _filtered[i],
                            i + 1,
                            cardColor,
                            bodyLarge,
                            bodySmall,
                          ),
                        ),
                        childCount: _filtered.length,
                      ),
                    ),

                  const SliverToBoxAdapter(child: SizedBox(height: 80)),
                ],
              ),
      ),

      // ── Bottom total bar ──
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
                  'Total Revenue Periode',
                  style: bodySmall?.copyWith(fontSize: 11),
                ),
                Text(
                  _formatRp(_totalRevenue),
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

  // ════════════════════════════════════════════════════════════
  // WIDGETS
  // ════════════════════════════════════════════════════════════

  Widget _sortTab(_SortMode mode, String label) {
    final isActive = _sortMode == mode;
    return GestureDetector(
      onTap: () {
        setState(() => _sortMode = mode);
        _applyFilter();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? kPrimary : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isActive ? kPrimary : Theme.of(context).dividerColor,
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive
                ? Colors.white
                : Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
      ),
    );
  }

  Widget _summaryItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    required TextStyle? bodySmall,
    bool smallFont = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: smallFont ? 12 : 16,
            ),
          ),
        ),
        Text(label, style: bodySmall?.copyWith(fontSize: 11)),
      ],
    );
  }

  Widget _vDivider() =>
      Container(height: 40, width: 1, color: Theme.of(context).dividerColor);

  Widget _customerCard(
    _CustomerData c,
    int rank,
    Color cardColor,
    TextStyle? bodyLarge,
    TextStyle? bodySmall,
  ) {
    return Container(
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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Medal / Rank ──
            Padding(
              padding: const EdgeInsets.only(top: 2, right: 12),
              child: _medal(rank),
            ),

            // ── Info kiri ──
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.nama,
                    style: bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(c.nip, style: bodySmall?.copyWith(fontSize: 12)),
                  const SizedBox(height: 8),
                  // Chip order count
                  _chip(
                    Icons.shopping_bag_outlined,
                    '${c.orderCount} order',
                    const Color(0xffDCFCE7),
                    const Color(0xff16A34A),
                  ),
                ],
              ),
            ),

            // ── Revenue + tanggal ──
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.account_balance_wallet_outlined,
                      color: Colors.blue.shade700,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatRp(c.totalRevenue),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
                Text('Revenue', style: bodySmall?.copyWith(fontSize: 11)),
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 11,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Terakhir: ${_formatDate(c.lastOrderDate)}',
                      style: bodySmall?.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ── AppBar — persis pola laporan_order.dart ──
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
            'Analisis Pelanggan',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          backgroundColor: kPrimary,
          foregroundColor: Colors.white,
          elevation: 2,
          centerTitle: true,
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

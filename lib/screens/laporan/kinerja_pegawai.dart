import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mdnlaundry_project/screens/main_screens.dart';

// ════════════════════════════════════════════════════════════
// MODEL
// ════════════════════════════════════════════════════════════
class _PegawaiKinerja {
  final String nama;
  int totalOrder;
  int orderSelesai; // status == 'selesai'
  double totalRevenue;
  Map<String, int> layananCount; // layanan_nama → jumlah

  _PegawaiKinerja({required this.nama})
    : totalOrder = 0,
      orderSelesai = 0,
      totalRevenue = 0,
      layananCount = {};

  String get id => nama;

  /// Completion rate = selesai / total × 100
  double get completionRate =>
      totalOrder == 0 ? 0 : (orderSelesai / totalOrder) * 100;

  double progressRatio(double maxRevenue) =>
      maxRevenue == 0 ? 0 : (totalRevenue / maxRevenue).clamp(0.0, 1.0);
}

// ════════════════════════════════════════════════════════════
// SCREEN
// ════════════════════════════════════════════════════════════
class KinerjaPegawaiPage extends StatefulWidget {
  final String storeId;
  final String outletId;

  const KinerjaPegawaiPage({
    super.key,
    required this.storeId,
    required this.outletId,
  });

  @override
  State<KinerjaPegawaiPage> createState() => _KinerjaPegawaiPageState();
}

class _KinerjaPegawaiPageState extends State<KinerjaPegawaiPage> {
  String _selectedPeriode = '30 Hari Terakhir';
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 29));
  DateTime _endDate = DateTime.now();

  bool _isLoading = true;
  List<_PegawaiKinerja> _pegawaiList = [];

  double _totalPendapatan = 0;
  double _rerataPegawai = 0;
  int _totalOrder = 0;
  double _avgCompletionRate = 0;

  final Map<String, bool> _expanded = {};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _startDate = today.subtract(const Duration(days: 29));
    _endDate = today;
    _fetchData();
  }

  // ════════════════════════════════════════════════════════════
  // FETCH — collection: order
  //   Fields yang dipakai:
  //     admin           → nama pegawai
  //     waktu_order     → Timestamp, filter periode
  //     harga_total     → revenue per order
  //     status          → untuk hitung completion rate
  //     layanan_nama    → breakdown layanan
  // ════════════════════════════════════════════════════════════
  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('order')
          .where('store_id', isEqualTo: widget.storeId)
          .where('outlet_id', isEqualTo: widget.outletId)
          .get();

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

      final Map<String, _PegawaiKinerja> map = {};

      for (final doc in snap.docs) {
        final data = doc.data();

        // ── Filter periode via waktu_order (Timestamp)
        final dynamic rawWaktu = data['waktu_order'];
        if (rawWaktu == null) continue;

        DateTime tgl;
        if (rawWaktu is Timestamp) {
          tgl = rawWaktu.toDate();
        } else {
          // fallback: string "dd-MM-yyyy" atau "dd/MM/yyyy HH:mm"
          try {
            final s = rawWaktu.toString().trim();
            tgl = s.contains('/')
                ? DateFormat('dd/MM/yyyy HH:mm').parse(s)
                : DateFormat('dd-MM-yyyy').parse(s);
          } catch (_) {
            continue;
          }
        }

        final hari = DateTime(tgl.year, tgl.month, tgl.day);
        if (hari.isBefore(start) || hari.isAfter(end)) continue;

        // ── Nama admin (bisa "Ameena" atau "Ameena|ROLE")
        final String rawAdmin = (data['admin'] ?? '').toString().trim();
        final String namaAdmin = rawAdmin.contains('|')
            ? rawAdmin.split('|').first.trim()
            : rawAdmin;
        if (namaAdmin.isEmpty) continue;

        final String status = (data['status'] ?? '').toString().toLowerCase();
        final String layanan = (data['layanan_nama'] ?? 'Lainnya')
            .toString()
            .trim();
        final double hargaTotal = (data['harga_total'] ?? 0).toDouble();

        map.putIfAbsent(namaAdmin, () => _PegawaiKinerja(nama: namaAdmin));
        final p = map[namaAdmin]!;

        p.totalOrder += 1;
        if (status == 'selesai') p.orderSelesai += 1;
        p.totalRevenue += hargaTotal;
        p.layananCount[layanan] = (p.layananCount[layanan] ?? 0) + 1;
      }

      // ── Sort by revenue desc
      final list = map.values.where((p) => p.totalOrder > 0).toList()
        ..sort((a, b) => b.totalRevenue.compareTo(a.totalRevenue));

      final totalPend = list.fold<double>(0, (s, p) => s + p.totalRevenue);
      final totalOrd = list.fold<int>(0, (s, p) => s + p.totalOrder);
      final avgCompletion = list.isEmpty
          ? 0.0
          : list.fold<double>(0, (s, p) => s + p.completionRate) / list.length;

      setState(() {
        _pegawaiList = list;
        _totalPendapatan = totalPend;
        _rerataPegawai = list.isEmpty ? 0 : totalPend / list.length;
        _totalOrder = totalOrd;
        _avgCompletionRate = avgCompletion;
        _isLoading = false;
      });
    } catch (e, stack) {
      debugPrint('ERROR fetch kinerja pegawai: $e\n$stack');
      setState(() => _isLoading = false);
    }
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
              'Filter kinerja berdasarkan rentang tanggal',
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
            // Custom date range
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
    symbol: 'Rp',
    decimalDigits: 0,
  ).format(val);

  String _formatPeriodeLabel() {
    if (_selectedPeriode == 'Custom') {
      return '${DateFormat('d MMM', 'id').format(_startDate)} - '
          '${DateFormat('d MMM yyyy', 'id').format(_endDate)}';
    }
    return _selectedPeriode;
  }

  String _formatDateRange() =>
      '${DateFormat('d MMM yyyy', 'id').format(_startDate)}'
      ' – '
      '${DateFormat('d MMM yyyy', 'id').format(_endDate)}';

  Widget _medal(int rank) {
    if (rank == 1) {
      return const Icon(
        Icons.emoji_events_rounded,
        color: Color(0xFFFFD700),
        size: 32,
      );
    } else if (rank == 2) {
      return const Icon(
        Icons.emoji_events_rounded,
        color: Color(0xFFB0B0B0),
        size: 32,
      );
    } else if (rank == 3) {
      return const Icon(
        Icons.emoji_events_rounded,
        color: Color(0xFFCD7F32),
        size: 32,
      );
    }
    return CircleAvatar(
      radius: 16,
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
    final double maxRevenue = _pegawaiList.isEmpty
        ? 1
        : _pegawaiList.first.totalRevenue;

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
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Periode bar ──────────────────────────────────
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: cardColor,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: Theme.of(context).dividerColor,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.calendar_month_rounded,
                                        color: kPrimary,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _formatDateRange(),
                                          style: bodySmall?.copyWith(
                                            fontSize: 12,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              GestureDetector(
                                onTap: _showPeriodePicker,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
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
                                    children: [
                                      Text(
                                        _formatPeriodeLabel(),
                                        style: TextStyle(
                                          color: kPrimary,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.keyboard_arrow_down_rounded,
                                        color: kPrimary,
                                        size: 18,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // ── Summary Grid 2×2 ─────────────────────────────
                          Row(
                            children: [
                              _summaryCard(
                                cardColor: cardColor,
                                bodySmall: bodySmall,
                                icon: Icons.account_balance_wallet_outlined,
                                iconColor: kPrimary,
                                iconBg: kPrimary.withOpacity(0.1),
                                label: 'Total Pendapatan',
                                value: _formatRp(_totalPendapatan),
                                isCurrency: true,
                              ),
                              const SizedBox(width: 12),
                              _summaryCard(
                                cardColor: cardColor,
                                bodySmall: bodySmall,
                                icon: Icons.people_alt_outlined,
                                iconColor: const Color(0xff0284C7),
                                iconBg: const Color(0xffE0F2FE),
                                label: 'Rerata per Admin',
                                value: _formatRp(_rerataPegawai),
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
                                icon: Icons.local_laundry_service_outlined,
                                iconColor: const Color(0xff16A34A),
                                iconBg: const Color(0xffDCFCE7),
                                label: 'Total Order',
                                value: '$_totalOrder',
                                isCurrency: false,
                              ),
                              const SizedBox(width: 12),
                              _summaryCard(
                                cardColor: cardColor,
                                bodySmall: bodySmall,
                                icon: Icons.check_circle_outline_rounded,
                                iconColor: const Color(0xffD97706),
                                iconBg: const Color(0xffFEF3C7),
                                label: 'Completion Rate',
                                value:
                                    '${_avgCompletionRate.toStringAsFixed(1)}%',
                                isCurrency: false,
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),

                  // ── List pegawai ─────────────────────────────────────────
                  if (_pegawaiList.isEmpty)
                    SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.badge_outlined,
                              size: 56,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Tidak ada data admin',
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
                        final p = _pegawaiList[i];
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: _pegawaiCard(
                            p,
                            i + 1,
                            maxRevenue,
                            cardColor,
                            bodyLarge,
                            bodySmall,
                          ),
                        );
                      }, childCount: _pegawaiList.length),
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
                  'Total Pendapatan Periode',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontSize: 11),
                ),
                Text(
                  _formatRp(_totalPendapatan),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: kPrimary,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              '${_pegawaiList.length} Admin',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: kPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // WIDGETS
  // ════════════════════════════════════════════════════════════

  Widget _summaryCard({
    required Color cardColor,
    required TextStyle? bodySmall,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String label,
    required String value,
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
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pegawaiCard(
    _PegawaiKinerja p,
    int rank,
    double maxRevenue,
    Color cardColor,
    TextStyle? bodyLarge,
    TextStyle? bodySmall,
  ) {
    final isExpanded = _expanded[p.id] ?? false;

    // Completion rate color
    final Color rateColor = p.completionRate >= 80
        ? const Color(0xFF16A34A)
        : p.completionRate >= 50
        ? const Color(0xFFF59E0B)
        : Colors.red.shade600;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
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
            // ── Row 1: Medal + Nama + Revenue ───────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _medal(rank),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              p.nama,
                              style: bodyLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            Icons.verified_rounded,
                            color: kPrimary,
                            size: 18,
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${p.totalOrder} Order Diproses',
                        style: bodySmall?.copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatRp(p.totalRevenue),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: kPrimary,
                      ),
                    ),
                    Text('Revenue', style: bodySmall?.copyWith(fontSize: 11)),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ── Row 2: Stats (Completion Rate | Selesai | Total) ────
            Row(
              children: [
                _statItem(
                  icon: Icons.check_circle_outline_rounded,
                  iconColor: rateColor,
                  label: 'Completion',
                  value: '${p.completionRate.toStringAsFixed(1)}%',
                  bodySmall: bodySmall,
                ),
                const SizedBox(width: 20),
                _statItem(
                  icon: Icons.done_all_rounded,
                  iconColor: const Color(0xff16A34A),
                  label: 'Selesai',
                  value: '${p.orderSelesai}',
                  bodySmall: bodySmall,
                ),
                const SizedBox(width: 20),
                _statItem(
                  icon: Icons.local_laundry_service_outlined,
                  iconColor: const Color(0xFF4F6FE8),
                  label: 'Total Order',
                  value: '${p.totalOrder}',
                  bodySmall: bodySmall,
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ── Progress bar (revenue) ──────────────────────────────
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: p.progressRatio(maxRevenue),
                      minHeight: 6,
                      backgroundColor: Theme.of(context).dividerColor,
                      valueColor: AlwaysStoppedAnimation<Color>(kPrimary),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${(p.progressRatio(maxRevenue) * 100).toStringAsFixed(0)}%',
                  style: bodySmall?.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ── Rincian Layanan toggle ──────────────────────────────
            GestureDetector(
              onTap: () =>
                  setState(() => _expanded[p.id] = !(_expanded[p.id] ?? false)),
              child: Row(
                children: [
                  Icon(
                    Icons.format_list_bulleted_rounded,
                    color: kPrimary,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Rincian Layanan (${p.layananCount.length})',
                    style: TextStyle(
                      color: kPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: kPrimary,
                    size: 20,
                  ),
                ],
              ),
            ),

            // ── Layanan list (expandable) ───────────────────────────
            if (isExpanded && p.layananCount.isNotEmpty) ...[
              const SizedBox(height: 10),
              Divider(color: Theme.of(context).dividerColor, height: 1),
              const SizedBox(height: 10),
              // Sort by count desc
              ...(p.layananCount.entries.toList()
                    ..sort((a, b) => b.value.compareTo(a.value)))
                  .map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: kPrimary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              e.key,
                              style: bodySmall?.copyWith(fontSize: 12),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: kPrimary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${e.value}x',
                              style: TextStyle(
                                color: kPrimary,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statItem({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required TextStyle? bodySmall,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: iconColor, size: 14),
            const SizedBox(width: 4),
            Text(label, style: bodySmall?.copyWith(fontSize: 11)),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
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
          title: const Text(
            'Kinerja Admin',
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

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../screens/screens.dart';

// ════════════════════════════════════════════════════════════
// MODEL
// ════════════════════════════════════════════════════════════
class _PegawaiKinerja {
  final String nama;
  String role;
  int orderSelesai;
  int totalOrder;
  double totalRevenue;
  int pasienBaruCount; // untuk on-time rate baru
  Map<String, int> layananCount;

  _PegawaiKinerja({
    required this.nama,
    this.role = 'KARYAWAN',
    Map<String, int>? layananCount,
  }) : orderSelesai = 0,
       totalOrder = 0,
       totalRevenue = 0,
       pasienBaruCount = 0,
       layananCount = layananCount ?? {};

  String get id => nama;

  // Rate = (Jumlah Pasien yang Baru Pertama Datang / Total Kunjungan) × 100%
  double get onTimeRate =>
      totalOrder == 0 ? 0 : (pasienBaruCount / totalOrder) * 100;

  double progressRatio(double maxRevenue) =>
      maxRevenue == 0 ? 0 : (totalRevenue / maxRevenue).clamp(0.0, 1.0);
}

// ════════════════════════════════════════════════════════════
// SCREEN
// ════════════════════════════════════════════════════════════
class KinerjaPegawaiPage extends StatefulWidget {
  const KinerjaPegawaiPage({super.key});

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
  double _avgOnTimeRate = 0;

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
  // FETCH FIRESTORE
  //
  // Struktur Firestore (dari foto):
  //   rekam_medis: admin_pemeriksa, layanan, waktu_kunjungan,
  //                nomer_induk_pasien, diagnosa, tindakan, dll
  //   keuangan:    biaya, nomer_induk_pasien, status_bayar,
  //                waktu_transaksi
  //
  // Join: rekam_medis.nomer_induk_pasien == keuangan.nomer_induk_pasien
  //
  // On-Time Rate (logika baru):
  //   Rate = (Pasien yang baru pertama datang / Total Kunjungan) × 100%
  //   "Baru pertama datang" = nomer_induk_pasien hanya muncul
  //   1x di seluruh rekam_medis (ALL TIME), bukan hanya periode ini.
  // ════════════════════════════════════════════════════════════
  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final DateFormat fmtRekam = DateFormat('dd/MM/yyyy HH:mm');
      final DateFormat fmtKeuangan = DateFormat('dd/MM/yyyy HH:mm');

      final results = await Future.wait([
        FirebaseFirestore.instance.collection('rekam_medis').get(),
        FirebaseFirestore.instance.collection('keuangan').get(),
      ]);

      final rekamSnap = results[0];
      final keuanganSnap = results[1];

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

      // ── Hitung berapa kali tiap pasien pernah datang (ALL TIME)
      //    untuk menentukan apakah pasien "baru pertama datang"
      final Map<String, int> pasienVisitCount = {};
      for (var doc in rekamSnap.docs) {
        final data = doc.data();
        final String noInduk = (data['nomer_induk_pasien'] ?? '')
            .toString()
            .trim();
        if (noInduk.isEmpty) continue;
        pasienVisitCount[noInduk] = (pasienVisitCount[noInduk] ?? 0) + 1;
      }

      // ── Build map keuangan: nomer_induk_pasien → total biaya (dalam periode)
      //    Satu pasien bisa punya beberapa transaksi; kita sum per pasien.
      final Map<String, double> keuanganByPasien = {};
      for (var doc in keuanganSnap.docs) {
        final data = doc.data();
        final String waktu = data['waktu_transaksi'] ?? '';
        if (waktu.isEmpty) continue;

        DateTime tgl;
        try {
          tgl = fmtKeuangan.parse(waktu);
        } catch (_) {
          continue;
        }

        final DateTime hari = DateTime(tgl.year, tgl.month, tgl.day);
        if (hari.isBefore(start) || hari.isAfter(end)) continue;

        final String noInduk = (data['nomer_induk_pasien'] ?? '')
            .toString()
            .trim();
        if (noInduk.isEmpty) continue;

        final double biaya = (data['biaya'] ?? 0).toDouble();
        keuanganByPasien[noInduk] = (keuanganByPasien[noInduk] ?? 0) + biaya;
      }

      // ── Baca rekam_medis dalam periode untuk akumulasi per pegawai
      final Map<String, _PegawaiKinerja> map = {};

      for (var doc in rekamSnap.docs) {
        final data = doc.data();

        final String waktu = data['waktu_kunjungan'] ?? '';
        if (waktu.isEmpty) continue;

        DateTime tgl;
        try {
          tgl = fmtRekam.parse(waktu);
        } catch (_) {
          continue;
        }

        final DateTime hari = DateTime(tgl.year, tgl.month, tgl.day);
        if (hari.isBefore(start) || hari.isAfter(end)) continue;

        final String namaPegawai = (data['admin_pemeriksa'] ?? '')
            .toString()
            .trim();
        if (namaPegawai.isEmpty) continue;

        final String noInduk = (data['nomer_induk_pasien'] ?? '')
            .toString()
            .trim();
        final String layanan = (data['layanan'] ?? 'Lainnya').toString();

        if (!map.containsKey(namaPegawai)) {
          map[namaPegawai] = _PegawaiKinerja(nama: namaPegawai);
        }

        final p = map[namaPegawai]!;
        p.totalOrder += 1;
        p.layananCount[layanan] = (p.layananCount[layanan] ?? 0) + 1;

        // Revenue: ambil dari keuangan via nomer_induk_pasien
        if (noInduk.isNotEmpty && keuanganByPasien.containsKey(noInduk)) {
          // Tambahkan revenue proporsional per kunjungan jika pasien
          // punya lebih dari 1 kunjungan di periode ini.
          // Cara sederhana: langsung tambah biaya per rekam_medis.
          p.totalRevenue += keuanganByPasien[noInduk] ?? 0;
          // Hapus dari map agar tidak double-count jika pasien
          // punya lebih dari 1 rekam_medis di periode yang sama.
          keuanganByPasien.remove(noInduk);
        }

        // Pasien baru = total kunjungan ALL TIME == 1
        if (noInduk.isNotEmpty && (pasienVisitCount[noInduk] ?? 0) == 1) {
          p.pasienBaruCount += 1;
        }

        // Order selesai (opsional: semua rekam_medis dianggap selesai)
        p.orderSelesai += 1;
      }

      final list = map.values
          .where((p) => p.totalOrder > 0 || p.totalRevenue > 0)
          .toList();
      list.sort((a, b) => b.totalRevenue.compareTo(a.totalRevenue));

      final totalPend = list.fold<double>(0, (s, p) => s + p.totalRevenue);
      final totalOrd = list.fold<int>(0, (s, p) => s + p.totalOrder);
      final avgOnTime = list.isEmpty
          ? 0.0
          : list.fold<double>(0, (s, p) => s + p.onTimeRate) / list.length;

      setState(() {
        _pegawaiList = list;
        _totalPendapatan = totalPend;
        _rerataPegawai = list.isEmpty ? 0 : totalPend / list.length;
        _totalOrder = totalOrd;
        _avgOnTimeRate = avgOnTime;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('ERROR fetch kinerja pegawai: $e');
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
      ' - '
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
      body: RefreshIndicator(
        onRefresh: _fetchData,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Date range + periode dropdown ──
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

                          // ── Summary Grid 2x2 ──
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
                                label: 'Rerata per Pegawai',
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
                                icon: Icons.shopping_bag_outlined,
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
                                icon: Icons.person_add_outlined,
                                iconColor: const Color(0xffD97706),
                                iconBg: const Color(0xffFEF3C7),
                                label: 'Pasien Baru Rate',
                                value: '${_avgOnTimeRate.toStringAsFixed(1)}%',
                                isCurrency: false,
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),

                  // ── List pegawai ──
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
                              'Tidak ada data pegawai',
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

      // ── Bottom bar ──
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
              '${_pegawaiList.length} Pegawai',
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
            // ── Row 1: Medal + Nama + Verified icon + Revenue ──
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
                          // ── Verified checkmark badge ──
                          Icon(
                            Icons.verified_rounded,
                            color: kPrimary,
                            size: 18,
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${p.orderSelesai} Kunjungan Selesai',
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

            // ── Row 2: Stats (Pasien Baru Rate | Order) — Berat dihapus ──
            Row(
              children: [
                _statItem(
                  icon: Icons.person_add_outlined,
                  iconColor: const Color(0xffD97706),
                  label: 'Pasien Baru',
                  value: '${p.onTimeRate.toStringAsFixed(1)}%',
                  bodySmall: bodySmall,
                ),
                const SizedBox(width: 20),
                _statItem(
                  icon: Icons.shopping_bag_outlined,
                  iconColor: const Color(0xff16A34A),
                  label: 'Kunjungan',
                  value: '${p.totalOrder}',
                  bodySmall: bodySmall,
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ── Progress bar ──
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: p.progressRatio(maxRevenue),
                minHeight: 6,
                backgroundColor: Theme.of(context).dividerColor,
                valueColor: AlwaysStoppedAnimation<Color>(kPrimary),
              ),
            ),

            const SizedBox(height: 12),

            // ── Rincian Layanan toggle ──
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

            // ── Layanan list (expandable) ──
            if (isExpanded && p.layananCount.isNotEmpty) ...[
              const SizedBox(height: 10),
              Divider(color: Theme.of(context).dividerColor, height: 1),
              const SizedBox(height: 10),
              ...p.layananCount.entries.map(
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
            'Kinerja Pegawai',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          backgroundColor: kPrimary,
          foregroundColor: Colors.white,
          elevation: 2,
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.download_rounded, color: Colors.white),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Fitur export segera hadir')),
                );
              },
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

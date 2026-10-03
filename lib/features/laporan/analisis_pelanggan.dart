import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mdnlaundry_project/core/app_exports.dart';

// ════════════════════════════════════════════════════════════
// MODEL
// ════════════════════════════════════════════════════════════
class _CustomerData {
  String nomorPelanggan; // non-final: diupdate ke order terbaru
  String nama; // non-final: bisa diupdate saat nama dari pelanggan ditemukan
  final String noHp; // FIX: field Firestore adalah 'no_hp'
  final String alamat;
  int orderCount;
  int orderSelesai;
  double totalRevenue;
  DateTime? lastOrderDate;
  Map<String, int> layananCount;

  _CustomerData({
    required this.nomorPelanggan,
    required this.nama,
    this.noHp = '',
    this.alamat = '',
  }) : orderCount = 0,
       orderSelesai = 0,
       totalRevenue = 0,
       layananCount = {};
}

// ════════════════════════════════════════════════════════════
// ENUM
// ════════════════════════════════════════════════════════════
enum _SortMode { topSpending, palingSering }

// ════════════════════════════════════════════════════════════
// SCREEN
// ════════════════════════════════════════════════════════════
class AnalisisPelangganPage extends StatefulWidget {
  final String storeId;
  final String outletId;
  const AnalisisPelangganPage({
    super.key,
    required this.storeId,
    required this.outletId,
  });

  @override
  State<AnalisisPelangganPage> createState() => _AnalisisPelangganPageState();
}

class _AnalisisPelangganPageState extends State<AnalisisPelangganPage> {
  String _selectedPeriode = '30 Hari Terakhir';
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 29));
  DateTime _endDate = DateTime.now();

  List<Map<String, dynamic>> _rawOrders = [];

  // FIX: key map adalah nomor_pelanggan, value pakai field 'nama' & 'no_hp'
  // no_hp → nama (join key dari collection pelanggan)
  Map<String, String> _noHpToNama = {};

  _SortMode _sortMode = _SortMode.topSpending;
  String _searchQuery = '';
  bool _showSearch = false;
  final TextEditingController _searchCtrl = TextEditingController();

  bool _isLoading = true;
  List<_CustomerData> _filtered = [];

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
  // FETCH
  // Firestore 'pelanggan': nomor_pelanggan (atau doc.id), nama, no_hp, alamat
  // Firestore 'order': nomor_pelanggan, waktu_order, harga_total, status, layanan_nama
  // ════════════════════════════════════════════════════════════
  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        FirebaseFirestore.instance
            .collection('order')
            .where('store_id', isEqualTo: widget.storeId)
            .where('outlet_id', isEqualTo: widget.outletId)
            .get(),
        FirebaseFirestore.instance
            .collection('pelanggan')
            .where('store_id', isEqualTo: widget.storeId)
            .where('outlet_id', isEqualTo: widget.outletId)
            .get(),
      ]);

      final orderSnap = results[0];
      final pelangganSnap = results[1];

      // ── Build lookup: no_hp → nama ──────────────────────────────────────
      // Collection 'pelanggan' fields: nama, no_hp, created_at, updated_at
      // TIDAK ada nomor_pelanggan di sini.
      // Join dilakukan via no_hp yang juga ada di collection 'order'.
      final Map<String, String> noHpToNama = {};
      for (final doc in pelangganSnap.docs) {
        final d = doc.data();
        final hp = (d['no_hp'] ?? '').toString().trim();
        final nm = (d['nama'] ?? '').toString().trim();
        if (hp.isEmpty || nm.isEmpty) continue;

        // Simpan berbagai format agar matching robust
        noHpToNama[hp] = nm;
        if (hp.startsWith('0') && hp.length > 1) {
          noHpToNama[hp.substring(1)] = nm; // tanpa 0 depan
        }
        if (hp.startsWith('+62')) {
          noHpToNama[hp.substring(3)] = nm; // tanpa +62
          noHpToNama['0${hp.substring(3)}'] = nm; // ganti +62 → 0
        }
        if (hp.startsWith('62') && hp.length > 2) {
          noHpToNama[hp.substring(2)] = nm;
          noHpToNama['0${hp.substring(2)}'] = nm;
        }
      }

      // ── Parse semua order ke raw list ───────────────────────────────────
      final List<Map<String, dynamic>> rawOrders = [];
      for (final doc in orderSnap.docs) {
        final data = doc.data();

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

        final String nomorPelanggan = (data['nomor_pelanggan'] ?? '')
            .toString()
            .trim();
        if (nomorPelanggan.isEmpty) continue;

        // no_hp dari order untuk join ke pelanggan
        final String noHp = (data['no_hp'] ?? '').toString().trim();
        final String namaPelanggan = (data['nama_pelanggan'] ?? '')
            .toString()
            .trim();

        final dynamic rawHarga =
            data['harga_total'] ?? data['harga_satuan'] ?? 0;
        final double harga = rawHarga is num ? rawHarga.toDouble() : 0.0;

        rawOrders.add({
          'nomor_pelanggan': nomorPelanggan,
          'no_hp': noHp,
          'nama_pelanggan': namaPelanggan,
          'harga_total': harga,
          'status': (data['status'] ?? '').toString().toLowerCase(),
          'layanan_nama': (data['layanan_nama'] ?? 'Lainnya').toString().trim(),
          'tgl': tgl,
        });
      }

      setState(() {
        _rawOrders = rawOrders;
        _noHpToNama = noHpToNama;
        _isLoading = false;
      });

      _applyFilter();
    } catch (e, stack) {
      debugPrint('ERROR fetch analisis pelanggan: $e\n$stack');
      setState(() => _isLoading = false);
    }
  }

  // ════════════════════════════════════════════════════════════
  // APPLY FILTER — pure client-side, tidak fetch ulang
  // Grouping by nomor_pelanggan → 1 pelanggan meski 3 order
  // ════════════════════════════════════════════════════════════
  void _applyFilter() {
    final DateTime start = DateTime(
      _startDate.year,
      _startDate.month,
      _startDate.day,
    );
    final DateTime end = DateTime(_endDate.year, _endDate.month, _endDate.day);

    // FIX UTAMA: Map dengan key nomor_pelanggan
    // Setiap pelanggan HANYA muncul 1x meski punya banyak order
    final Map<String, _CustomerData> map = {};

    for (final t in _rawOrders) {
      final DateTime tgl = t['tgl'] as DateTime;
      final DateTime hari = DateTime(tgl.year, tgl.month, tgl.day);
      if (hari.isBefore(start) || hari.isAfter(end)) continue;

      final String nomor = t['nomor_pelanggan'] as String;
      final String noHp = (t['no_hp'] as String?) ?? '';
      final String namaDariOrder = (t['nama_pelanggan'] as String?) ?? '';
      final String status = t['status'] as String;
      final String layanan = t['layanan_nama'] as String;
      final double harga = t['harga_total'] as double;

      // ── Prioritas nama: 1) nama_pelanggan di order, 2) join no_hp→pelanggan, 3) nomor ──
      String nama = namaDariOrder;
      if (nama.isEmpty) {
        nama = _noHpToNama[noHp] ?? '';
        if (nama.isEmpty && noHp.startsWith('0') && noHp.length > 1) {
          nama = _noHpToNama[noHp.substring(1)] ?? '';
        }
      }
      if (nama.isEmpty) nama = nomor;

      // ── Filter search ─────────────────────────────────────────
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        if (!nama.toLowerCase().contains(q) &&
            !nomor.toLowerCase().contains(q) &&
            !noHp.contains(q)) {
          continue;
        }
      }

      // ── Grouping: pakai no_hp sebagai key utama ────────────────
      // Satu pelanggan bisa punya banyak nomor_pelanggan (MDN...001, 002, dst)
      // tapi no_hp-nya sama → grouping by no_hp agar muncul 1 card
      // Jika no_hp kosong (data lama), fallback ke nomor_pelanggan
      final String groupKey = noHp.isNotEmpty ? noHp : nomor;

      map.putIfAbsent(
        groupKey,
        () => _CustomerData(
          nomorPelanggan: nomor, // tampilkan nomor order pertama
          noHp: noHp,
          nama: nama,
        ),
      );
      final c = map[groupKey]!;
      // Update nama jika sebelumnya masih fallback
      if ((c.nama == c.nomorPelanggan || c.nama.isEmpty) && nama != nomor) {
        c.nama = nama;
      }
      // Simpan nomor_pelanggan terbaru (opsional: bisa juga tampilkan semua)
      if (c.nomorPelanggan != nomor) c.nomorPelanggan = nomor;
      c.orderCount += 1;
      c.totalRevenue += harga;
      c.layananCount[layanan] = (c.layananCount[layanan] ?? 0) + 1;
      if (status == 'selesai') c.orderSelesai += 1;
      if (c.lastOrderDate == null || tgl.isAfter(c.lastOrderDate!)) {
        c.lastOrderDate = tgl;
      }
    }

    List<_CustomerData> list = map.values.toList();

    // Sort
    if (_sortMode == _SortMode.topSpending) {
      list.sort((a, b) => b.totalRevenue.compareTo(a.totalRevenue));
    } else {
      list.sort((a, b) => b.orderCount.compareTo(a.orderCount));
    }

    setState(() {
      _filtered = list;
      _totalCustomer = list.length; // jumlah UNIK pelanggan
      _totalOrder = list.fold(0, (s, c) => s + c.orderCount);
      _totalRevenue = list.fold(0.0, (s, c) => s + c.totalRevenue);
    });
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

  String _formatPeriodeLabel() {
    if (_selectedPeriode == 'Custom') {
      return '${DateFormat('d MMM', 'id').format(_startDate)} – '
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
    }
    if (rank == 2) {
      return const Icon(
        Icons.emoji_events_rounded,
        color: Color(0xFFB0B0B0),
        size: 30,
      );
    }
    if (rank == 3) {
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
                          // ── Periode + Search toggle ──────────────────
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
                                child: Container(
                                  padding: const EdgeInsets.all(8),
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

                          // ── Search bar ───────────────────────────────
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
                                hintText: 'Cari nama atau nomor pelanggan...',
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
                                  borderSide: BorderSide(
                                    color: kPrimary,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ],

                          const SizedBox(height: 14),

                          // ── Sort tabs ────────────────────────────────
                          Row(
                            children: [
                              _sortTab(_SortMode.topSpending, 'Top Spending'),
                              const SizedBox(width: 8),
                              _sortTab(_SortMode.palingSering, 'Paling Sering'),
                            ],
                          ),

                          const SizedBox(height: 14),

                          // ── Summary bar ──────────────────────────────
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
                                  icon: Icons.local_laundry_service_outlined,
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

                  // ── List pelanggan ───────────────────────────────────
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

      // ── Bottom bar ───────────────────────────────────────────────────
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
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontSize: 11),
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
            const Spacer(),
            Text(
              '$_totalCustomer Pelanggan',
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
    final double rate = c.orderCount == 0
        ? 0
        : (c.orderSelesai / c.orderCount) * 100;
    final Color rateColor = rate >= 80
        ? const Color(0xFF16A34A)
        : rate >= 50
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2, right: 12),
                  child: _medal(rank),
                ),
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
                      Row(
                        children: [
                          Icon(
                            Icons.tag_rounded,
                            size: 12,
                            color: Theme.of(context).textTheme.bodySmall?.color,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            c.nomorPelanggan,
                            style: bodySmall?.copyWith(fontSize: 12),
                          ),
                        ],
                      ),
                      // FIX: tampilkan no_hp jika ada
                      if (c.noHp.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              Icons.phone_outlined,
                              size: 12,
                              color: Theme.of(
                                context,
                              ).textTheme.bodySmall?.color,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              c.noHp,
                              style: bodySmall?.copyWith(fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
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
                    const SizedBox(height: 6),
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
                          _formatDate(c.lastOrderDate),
                          style: bodySmall?.copyWith(fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                _chip(
                  Icons.local_laundry_service_outlined,
                  '${c.orderCount} order',
                  const Color(0xffDCFCE7),
                  const Color(0xff16A34A),
                ),
                const SizedBox(width: 8),
                _chip(
                  Icons.check_circle_outline_rounded,
                  '${c.orderSelesai} selesai',
                  rateColor.withOpacity(0.12),
                  rateColor,
                ),
                const Spacer(),
                if (c.layananCount.isNotEmpty)
                  Expanded(
                    child: Text(
                      _topLayanan(c.layananCount),
                      textAlign: TextAlign.right,
                      style: bodySmall?.copyWith(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _topLayanan(Map<String, int> map) {
    if (map.isEmpty) return '';
    final top = map.entries.reduce((a, b) => a.value >= b.value ? a : b);
    return '⭐ ${top.key}';
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

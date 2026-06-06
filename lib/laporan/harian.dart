import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../screens/screens.dart';

class LaporanHarianPage extends StatefulWidget {
  const LaporanHarianPage({super.key});

  @override
  State<LaporanHarianPage> createState() => _LaporanHarianPageState();
}

class _LaporanHarianPageState extends State<LaporanHarianPage> {
  DateTime selectedDate = DateTime.now();
  bool _isLoading = true;

  // ── Ringkasan keuangan ────────────────────────────────────────────────────
  double _totalOmzet = 0; // Semua harga_total order di hari itu
  double _uangMasuk = 0; // Yang sudah lunas (bayar penuh)
  double _uangDP = 0; // Yang statusnya dp
  double _belumBayar = 0; // Yang belum_bayar
  double _pengeluaran = 0; // Total pengeluaran
  double _labaRugi = 0; // (uangMasuk + uangDP) - pengeluaran

  List<Map<String, dynamic>> _transaksiHari = [];
  List<Map<String, dynamic>> _pengeluaranHari = [];

  @override
  void initState() {
    super.initState();
    _fetchData(selectedDate);
  }

  // ════════════════════════════════════════════════════════════
  // PARSE DATE — handle Timestamp Firestore & String fallback
  // ════════════════════════════════════════════════════════════
  DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is Timestamp) return raw.toDate();
    if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
    if (raw is String) {
      final s = raw.trim();
      if (s.isEmpty) return null;
      final formats = [
        'dd/MM/yyyy HH:mm',
        'dd/MM/yyyy',
        'yyyy-MM-dd HH:mm:ss',
        'yyyy-MM-dd',
        'd/M/yyyy HH:mm',
        'd/M/yyyy',
        'dd-MM-yyyy HH:mm',
        'dd-MM-yyyy',
      ];
      for (final fmt in formats) {
        try {
          return DateFormat(fmt).parseStrict(s);
        } catch (_) {}
      }
      try {
        return DateTime.parse(s);
      } catch (_) {}
    }
    return null;
  }

  double _parseDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is double) return val;
    if (val is int) return val.toDouble();
    if (val is String) return double.tryParse(val.trim()) ?? 0.0;
    return 0.0;
  }

  // ════════════════════════════════════════════════════════════
  // FETCH DATA — gabungan keuangan + order
  // ════════════════════════════════════════════════════════════
  Future<void> _fetchData(DateTime date) async {
    setState(() => _isLoading = true);

    try {
      final hariIni = DateTime(date.year, date.month, date.day);

      // Ambil keuangan, order, pengeluaran paralel
      final results = await Future.wait([
        FirebaseFirestore.instance.collection('keuangan').get(),
        FirebaseFirestore.instance.collection('order').get(),
        FirebaseFirestore.instance.collection('pengeluaran').get(),
      ]);

      final keuanganSnap = results[0];
      final orderSnap = results[1];
      final pengeluaranSnap = results[2];

      // ── 1. Proses keuangan (pembayaran yg sudah dicatat) ─────────────────
      // Collection keuangan adalah catatan transaksi bayar dari pelanggan.
      // status_bayar: 'lunas' | 'dp' | 'belum_bayar'
      // biaya = jumlah yang dibayar saat transaksi ini
      // dp_amount = nominal DP (jika status dp)

      double omzetKeuangan = 0;
      double masukLunas = 0;
      double masukDP = 0;
      double belumBayar = 0;

      List<Map<String, dynamic>> transaksiList = [];

      // Map nomor_pelanggan → nama_pelanggan dari order (untuk ditampilkan)
      final Map<String, String> noPelToNama = {};
      for (final doc in orderSnap.docs) {
        final d = doc.data();
        final noPel = d['nomor_pelanggan']?.toString() ?? '';
        final nama = d['nama_pelanggan']?.toString() ?? '';
        if (noPel.isNotEmpty && nama.isNotEmpty) {
          noPelToNama[noPel] = nama;
        }
      }

      for (final doc in keuanganSnap.docs) {
        final data = doc.data();
        final DateTime? tgl = _parseDate(data['waktu_transaksi']);
        if (tgl == null) continue;

        final tglHari = DateTime(tgl.year, tgl.month, tgl.day);
        if (tglHari != hariIni) continue;

        final double biaya = _parseDouble(data['biaya']);
        final double dpAmount = _parseDouble(data['dp_amount']);
        final String status = (data['status_bayar'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
        final String noPel = (data['nomor_pelanggan'] ?? '-').toString().trim();

        omzetKeuangan += biaya;

        switch (status) {
          case 'lunas':
            masukLunas += biaya;
            break;
          case 'dp':
            // Yang masuk ke kas adalah sebesar dp_amount, bukan biaya penuh
            masukDP += dpAmount > 0 ? dpAmount : biaya;
            break;
          case 'belum_bayar':
          default:
            belumBayar += biaya;
        }

        transaksiList.add({
          'nomor_pelanggan': noPel,
          'nama': noPelToNama[noPel] ?? noPel,
          'biaya': biaya,
          'dp_amount': dpAmount,
          'status': status,
          'waktu': DateFormat('HH:mm').format(tgl),
          'tanggal': DateFormat('dd/MM/yyyy').format(tgl),
        });
      }

      // ── 2. Proses pengeluaran ─────────────────────────────────────────────
      double totalPengeluaran = 0;
      List<Map<String, dynamic>> listPengeluaran = [];

      for (final doc in pengeluaranSnap.docs) {
        final data = doc.data();
        final DateTime? tgl = _parseDate(data['tanggal']);
        if (tgl == null) continue;

        final tglHari = DateTime(tgl.year, tgl.month, tgl.day);
        if (tglHari != hariIni) continue;

        final double nominal = _parseDouble(data['nominal']);
        final String keterangan = (data['keterangan'] ?? '-').toString();
        totalPengeluaran += nominal;

        listPengeluaran.add({
          'keterangan': keterangan,
          'nominal': nominal,
          'tanggal': tgl,
        });
      }

      // ── 3. Hitung ringkasan ───────────────────────────────────────────────
      // Uang yang benar-benar masuk ke kas = lunas + dp_amount
      final double totalMasukKas = masukLunas + masukDP;

      setState(() {
        selectedDate = date;
        _totalOmzet = omzetKeuangan;
        _uangMasuk = masukLunas;
        _uangDP = masukDP;
        _belumBayar = belumBayar;
        _pengeluaran = totalPengeluaran;
        // Laba = kas masuk (lunas + dp) - pengeluaran
        _labaRugi = totalMasukKas - totalPengeluaran;
        _transaksiHari = transaksiList;
        _pengeluaranHari = listPengeluaran;
        _isLoading = false;
      });
    } catch (e, stack) {
      debugPrint('ERROR fetchData harian: $e\n$stack');
      setState(() => _isLoading = false);
    }
  }

  // ════════════════════════════════════════════════════════════
  // HELPERS
  // ════════════════════════════════════════════════════════════
  String _formatRp(double val) => NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  ).format(val);

  String _formatTanggal(DateTime date) {
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    final d = DateTime(date.year, date.month, date.day);
    if (d == today) {
      return 'Hari Ini - ${DateFormat('d MMM yyyy', 'id').format(date)}';
    }
    if (d == today.subtract(const Duration(days: 1))) {
      return 'Kemarin - ${DateFormat('d MMM yyyy', 'id').format(date)}';
    }
    return DateFormat('EEEE, d MMM yyyy', 'id').format(date);
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2060),
    );
    if (picked != null) _fetchData(picked);
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'lunas':
        return const Color(0xff16A34A);
      case 'dp':
        return const Color(0xff0284C7);
      case 'belum_bayar':
        return const Color(0xffDC2626);
      default:
        return Colors.grey;
    }
  }

  Color _statusBgColor(String status) {
    switch (status.toLowerCase()) {
      case 'lunas':
        return const Color(0xffDCFCE7);
      case 'dp':
        return const Color(0xffE0F2FE);
      case 'belum_bayar':
        return const Color(0xffFEE2E2);
      default:
        return Colors.grey.shade100;
    }
  }

  IconData _statusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'lunas':
        return Icons.check_circle_outline_rounded;
      case 'dp':
        return Icons.payments_outlined;
      case 'belum_bayar':
        return Icons.hourglass_empty_rounded;
      default:
        return Icons.circle_outlined;
    }
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'lunas':
        return 'Lunas';
      case 'dp':
        return 'DP';
      case 'belum_bayar':
        return 'Belum Bayar';
      default:
        return status;
    }
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _fetchData(selectedDate),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date picker
                    _buildDatePicker(),
                    const SizedBox(height: 20),

                    // ── Ringkasan 4 kartu ───────────────────────────────
                    _buildSectionLabel('RINGKASAN HARI INI', bodySmall),
                    const SizedBox(height: 12),
                    _buildSummaryGrid(cardColor, bodyLarge, bodySmall),
                    const SizedBox(height: 20),

                    // ── Detail kas masuk ────────────────────────────────
                    _buildSectionLabel('DETAIL PEMASUKAN', bodySmall),
                    const SizedBox(height: 12),
                    _buildDetailPemasukan(cardColor, bodyLarge, bodySmall),
                    const SizedBox(height: 20),

                    // ── Transaksi ───────────────────────────────────────
                    _buildSectionLabel(
                      'TRANSAKSI HARI INI (${_transaksiHari.length})',
                      bodySmall,
                    ),
                    const SizedBox(height: 12),
                    _transaksiHari.isEmpty
                        ? _buildEmpty('Belum ada transaksi hari ini')
                        : _buildTransaksiList(cardColor, bodyLarge, bodySmall),

                    // ── Pengeluaran ─────────────────────────────────────
                    if (_pengeluaranHari.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _buildSectionLabel(
                        'PENGELUARAN HARI INI (${_pengeluaranHari.length})',
                        bodySmall,
                      ),
                      const SizedBox(height: 12),
                      _buildPengeluaranList(cardColor, bodyLarge, bodySmall),
                    ],

                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
    );
  }

  // ─── AppBar ──────────────────────────────────────────────────────────────
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
            'Laporan Harian',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          backgroundColor: kPrimary,
          foregroundColor: Colors.white,
          elevation: 2,
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.help_outline_rounded, color: Colors.white),
              onPressed: () => showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  title: const Text('Info Laporan Harian'),
                  content: const Text(
                    'Total Omzet    = semua biaya yang tercatat hari itu\n'
                    'Kas Masuk      = lunas + dp_amount (yang benar-benar diterima)\n'
                    'Belum Bayar    = order yang belum dibayar sama sekali\n'
                    'Laba/Rugi      = Kas Masuk - Pengeluaran.\n\n'
                    'Tarik ke bawah untuk refresh data.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Mengerti'),
                    ),
                  ],
                ),
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

  // ─── Date picker ─────────────────────────────────────────────────────────
  Widget _buildDatePicker() {
    return GestureDetector(
      onTap: _pickDate,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [kPrimary, kPrimary.withOpacity(0.75)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: kPrimary.withOpacity(0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_today_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              _formatTanggal(selectedDate),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text, TextStyle? bodySmall) {
    return Text(
      text,
      style: bodySmall?.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildEmpty(String msg) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 40,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 8),
          Text(
            msg,
            style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
          ),
        ],
      ),
    );
  }

  // ─── Summary Grid ─────────────────────────────────────────────────────────
  // 4 kartu: Total Omzet, Kas Masuk (lunas+dp), Pengeluaran, Laba/Rugi
  Widget _buildSummaryGrid(
    Color cardColor,
    TextStyle? bodyLarge,
    TextStyle? bodySmall,
  ) {
    final totalKasMasuk = _uangMasuk + _uangDP;
    final items = [
      _CardData(
        'Total Omzet',
        _formatRp(_totalOmzet),
        Icons.account_balance_wallet_outlined,
        const Color(0xffE0F2FE),
        const Color(0xff0284C7),
        const Color(0xff0284C7),
      ),
      _CardData(
        'Kas Masuk',
        _formatRp(totalKasMasuk),
        Icons.trending_up_rounded,
        const Color(0xffDCFCE7),
        const Color(0xff16A34A),
        const Color(0xff16A34A),
      ),
      _CardData(
        'Pengeluaran',
        _formatRp(_pengeluaran),
        Icons.trending_down_rounded,
        const Color(0xffFEE2E2),
        const Color(0xffDC2626),
        const Color(0xffDC2626),
      ),
      _CardData(
        'Laba / Rugi',
        _formatRp(_labaRugi),
        Icons.bar_chart_rounded,
        _labaRugi >= 0 ? const Color(0xffDCFCE7) : const Color(0xffFEE2E2),
        _labaRugi >= 0 ? const Color(0xff16A34A) : const Color(0xffDC2626),
        _labaRugi >= 0 ? const Color(0xff16A34A) : const Color(0xffDC2626),
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.45,
      children: items
          .map(
            (c) => Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: c.iconBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(c.icon, color: c.iconColor, size: 20),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.label, style: bodySmall?.copyWith(fontSize: 11)),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          c.value,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: c.valueColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  // ─── Detail pemasukan ────────────────────────────────────────────────────
  Widget _buildDetailPemasukan(
    Color cardColor,
    TextStyle? bodyLarge,
    TextStyle? bodySmall,
  ) {
    final totalKasMasuk = _uangMasuk + _uangDP;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xffDCFCE7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.account_balance_rounded,
                  color: Color(0xff16A34A),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Detail Pemasukan',
                style: bodyLarge?.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Baris-baris
          _detailRow(
            'Total Omzet (tagihan)',
            _formatRp(_totalOmzet),
            bodySmall,
          ),
          const SizedBox(height: 4),

          // Breakdown status
          _detailRowWithBadge(
            'Lunas',
            _formatRp(_uangMasuk),
            bodySmall,
            badgeColor: const Color(0xff16A34A),
            badgeBg: const Color(0xffDCFCE7),
          ),
          _detailRowWithBadge(
            'DP Masuk',
            _formatRp(_uangDP),
            bodySmall,
            badgeColor: const Color(0xff0284C7),
            badgeBg: const Color(0xffE0F2FE),
          ),
          _detailRowWithBadge(
            'Belum Bayar',
            _formatRp(_belumBayar),
            bodySmall,
            badgeColor: const Color(0xffDC2626),
            badgeBg: const Color(0xffFEE2E2),
          ),

          const Divider(height: 24, thickness: 1),
          _detailRow(
            'Total Kas Masuk',
            _formatRp(totalKasMasuk),
            bodySmall,
            isTotal: true,
            totalColor: const Color(0xff16A34A),
          ),
          const SizedBox(height: 4),
          _detailRow(
            'Total Pengeluaran',
            '- ${_formatRp(_pengeluaran)}',
            bodySmall,
            isTotal: false,
            totalColor: const Color(0xffDC2626),
          ),
          const Divider(height: 16, thickness: 0.5),
          _detailRow(
            'Laba / Rugi',
            _formatRp(_labaRugi),
            bodySmall,
            isTotal: true,
            totalColor: _labaRugi >= 0
                ? const Color(0xff16A34A)
                : const Color(0xffDC2626),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(
    String label,
    String value,
    TextStyle? bodySmall, {
    bool isTotal = false,
    Color? totalColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: bodySmall?.copyWith(
              fontSize: 13,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
              color: totalColor ?? Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRowWithBadge(
    String label,
    String value,
    TextStyle? bodySmall, {
    required Color badgeColor,
    required Color badgeBg,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: badgeColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: badgeColor,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Transaksi List ───────────────────────────────────────────────────────
  Widget _buildTransaksiList(
    Color cardColor,
    TextStyle? bodyLarge,
    TextStyle? bodySmall,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        children: _transaksiHari.asMap().entries.map((entry) {
          final i = entry.key;
          final t = entry.value;
          final String status = t['status'] ?? 'belum_bayar';
          final String nama = t['nama'] ?? t['nomor_pelanggan'] ?? '-';
          final String noPel = t['nomor_pelanggan'] ?? '-';
          final double biaya = _parseDouble(t['biaya']);
          final double dpAmount = _parseDouble(t['dp_amount']);
          final sColor = _statusColor(status);
          final sBg = _statusBgColor(status);
          final sIcon = _statusIcon(status);
          final sLabel = _statusLabel(status);

          // Nilai yang ditampilkan: dp = dp_amount, lunas/belum = biaya
          final double tampil = status == 'dp' && dpAmount > 0
              ? dpAmount
              : biaya;

          return Column(
            children: [
              if (i > 0)
                Divider(height: 1, color: Theme.of(context).dividerColor),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    // Icon status
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: sBg,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(sIcon, size: 16, color: sColor),
                    ),
                    const SizedBox(width: 12),
                    // Nama & waktu
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nama,
                            style: bodyLarge?.copyWith(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$noPel  •  ${t['tanggal'] ?? ''} ${t['waktu'] ?? ''}',
                            style: bodySmall?.copyWith(fontSize: 10),
                          ),
                          // Jika DP, tampilkan juga total tagihan
                          if (status == 'dp' && dpAmount > 0)
                            Text(
                              'Total tagihan: ${_formatRp(biaya)}',
                              style: bodySmall?.copyWith(
                                fontSize: 10,
                                color: Colors.grey.shade500,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Nominal & badge
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _formatRp(tampil),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: sColor,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: sBg,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            sLabel,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: sColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  // ─── Pengeluaran List ─────────────────────────────────────────────────────
  Widget _buildPengeluaranList(
    Color cardColor,
    TextStyle? bodyLarge,
    TextStyle? bodySmall,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        children: _pengeluaranHari.asMap().entries.map((entry) {
          final i = entry.key;
          final p = entry.value;
          final String ket = p['keterangan'] ?? '-';
          final double nom = _parseDouble(p['nominal']);
          final DateTime? tgl = p['tanggal'];

          return Column(
            children: [
              if (i > 0)
                Divider(height: 1, color: Theme.of(context).dividerColor),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(0xffFEE2E2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.upload_rounded,
                        size: 16,
                        color: Color(0xffDC2626),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ket,
                            style: bodyLarge?.copyWith(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (tgl != null)
                            Text(
                              DateFormat('HH:mm', 'id').format(tgl),
                              style: bodySmall?.copyWith(fontSize: 11),
                            ),
                        ],
                      ),
                    ),
                    Text(
                      _formatRp(nom),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xffDC2626),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ─── Helper model ─────────────────────────────────────────────────────────
class _CardData {
  final String label, value;
  final IconData icon;
  final Color iconBg, iconColor, valueColor;
  const _CardData(
    this.label,
    this.value,
    this.icon,
    this.iconBg,
    this.iconColor,
    this.valueColor,
  );
}

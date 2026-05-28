import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../screens/screens.dart';

class LaporanHarianPage extends StatefulWidget {
  const LaporanHarianPage({super.key});

  @override
  State<LaporanHarianPage> createState() => _LaporanHarianPageState();
}

class _LaporanHarianPageState extends State<LaporanHarianPage> {
  DateTime selectedDate = DateTime.now();
  bool _isLoading = true;

  double _totalOmzet = 0;
  double _uangMasuk = 0;
  double _pengeluaran = 0;
  double _labaRugi = 0;
  double _uangMasukNota = 0;
  double _pendapatanJasa = 0;

  List<Map<String, dynamic>> _transaksiHari = [];
  List<Map<String, dynamic>> _pengeluaranHari = [];

  @override
  void initState() {
    super.initState();
    debugPrint('DateTime.now() = ${DateTime.now()}');
    _fetchData(selectedDate);
  }

  // ════════════════════════════════════════════════════════════
  // HELPER: parse date fleksibel (String ATAU Timestamp)
  // FIX: Tambah lebih banyak format fallback & trim karakter tersembunyi
  // ════════════════════════════════════════════════════════════
  DateTime? _parseFlexibleDate(dynamic raw) {
    if (raw == null) return null;

    // Handle Timestamp dari Firestore
    if (raw is Timestamp) return raw.toDate();

    // Handle int (milliseconds epoch)
    if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);

    if (raw is String) {
      final s = raw.trim();
      if (s.isEmpty) return null;

      // Coba berbagai format secara berurutan
      final formats = [
        'dd/MM/yyyy HH:mm',
        'dd/MM/yyyy H:mm',
        'dd/MM/yyyy HH:mm:ss',
        'dd/MM/yyyy',
        'yyyy-MM-dd HH:mm:ss',
        'yyyy-MM-dd HH:mm',
        'yyyy-MM-dd',
        'MM/dd/yyyy HH:mm',
        'MM/dd/yyyy',
        'd/M/yyyy HH:mm',
        'd/M/yyyy',
      ];

      for (final fmt in formats) {
        try {
          return DateFormat(fmt).parseStrict(s);
        } catch (_) {
          // lanjut ke format berikutnya
        }
      }

      // Fallback: DateTime.parse (ISO 8601)
      try {
        return DateTime.parse(s);
      } catch (_) {}
    }

    return null;
  }

  // ════════════════════════════════════════════════════════════
  // FETCH DATA
  // FIX: Perbaiki field name, tambah debug log, handle null dengan aman
  // ════════════════════════════════════════════════════════════
  Future<void> _fetchData(DateTime date) async {
    setState(() => _isLoading = true);

    try {
      final DateTime hariIni = DateTime(date.year, date.month, date.day);

      // Fetch keuangan & pengeluaran paralel
      final results = await Future.wait([
        FirebaseFirestore.instance.collection('keuangan').get(),
        FirebaseFirestore.instance.collection('pengeluaran').get(),
      ]);

      final keuanganSnap = results[0];
      final pengeluaranSnap = results[1];

      debugPrint('Total keuangan docs: ${keuanganSnap.docs.length}');
      debugPrint('Total pengeluaran docs: ${pengeluaranSnap.docs.length}');

      // ── Loop keuangan ──
      double omzet = 0;
      double masuk = 0;
      List<Map<String, dynamic>> transaksi = [];

      for (var doc in keuanganSnap.docs) {
        final data = doc.data();

        // FIX: debug setiap dokumen untuk lihat struktur data
        debugPrint(
          'Keuangan doc ${doc.id}: waktu_transaksi=${data['waktu_transaksi']}, biaya=${data['biaya']}',
        );

        final dynamic rawWaktu = data['waktu_transaksi'];
        final DateTime? tgl = _parseFlexibleDate(rawWaktu);

        if (tgl == null) {
          debugPrint('  -> SKIP: gagal parse waktu_transaksi: $rawWaktu');
          continue;
        }

        final DateTime tglHari = DateTime(tgl.year, tgl.month, tgl.day);
        debugPrint(
          '  -> tglHari=$tglHari, hariIni=$hariIni, match=${tglHari == hariIni}',
        );

        if (tglHari != hariIni) continue;

        // FIX: handle berbagai tipe data untuk biaya (int, double, String)
        final double biaya = _parseDouble(data['biaya']);
        // FIX: field name konsisten dengan Firestore
        final String status = (data['status_bayar'] ?? '').toString().trim();
        final String nip = (data['nomer_induk_pasien'] ?? '-')
            .toString()
            .trim();

        omzet += biaya;
        // FIX: logika status — hitung masuk jika BUKAN "Belum Lunas"
        if (status.toLowerCase() != 'belum lunas') {
          masuk += biaya;
        }

        transaksi.add({
          'nip': nip,
          'biaya': biaya,
          'status': status,
          'waktu': DateFormat('dd/MM/yyyy HH:mm').format(tgl),
        });
      }

      debugPrint(
        'Transaksi hari ini: ${transaksi.length}, omzet=$omzet, masuk=$masuk',
      );

      // ── Loop pengeluaran ──
      double totalPengeluaran = 0;
      List<Map<String, dynamic>> listPengeluaran = [];

      for (var doc in pengeluaranSnap.docs) {
        final data = doc.data();

        debugPrint(
          'Pengeluaran doc ${doc.id}: tanggal=${data['tanggal']}, nominal=${data['nominal']}',
        );

        final DateTime? tglDoc = _parseFlexibleDate(data['tanggal']);
        if (tglDoc == null) {
          debugPrint('  -> SKIP: gagal parse tanggal');
          continue;
        }

        final DateTime tglHari = DateTime(
          tglDoc.year,
          tglDoc.month,
          tglDoc.day,
        );
        if (tglHari != hariIni) continue;

        final double nominal = _parseDouble(data['nominal']);
        final String keterangan = (data['keterangan'] ?? '-').toString();
        totalPengeluaran += nominal;

        listPengeluaran.add({
          'keterangan': keterangan,
          'nominal': nominal,
          'tanggal': tglDoc,
        });
      }

      // ── Fetch nama pasien (batch by NIP) ──
      final Set<String> nipSet = transaksi
          .map((e) => e['nip'] as String)
          .where((nip) => nip != '-' && nip.isNotEmpty)
          .toSet();

      final Map<String, String> nipToNama = {};

      if (nipSet.isNotEmpty) {
        try {
          final pasienSnap = await FirebaseFirestore.instance
              .collection('pasien')
              .get();
          for (var doc in pasienSnap.docs) {
            final d = doc.data();
            // FIX: cek kedua kemungkinan field name NIP di collection pasien
            final nip =
                (d['nomer_induk_pasien'] ?? d['nomor_induk_pasien'] ?? '')
                    .toString()
                    .trim();
            if (nipSet.contains(nip)) {
              nipToNama[nip] = (d['nama_lengkap'] ?? d['nama'] ?? nip)
                  .toString();
            }
          }
        } catch (e) {
          debugPrint('Error fetch pasien: $e');
        }
      }

      for (var t in transaksi) {
        t['nama'] = nipToNama[t['nip']] ?? t['nip'];
      }

      setState(() {
        selectedDate = date;
        _totalOmzet = omzet;
        _uangMasuk = masuk;
        _pengeluaran = totalPengeluaran;
        _labaRugi = masuk - totalPengeluaran;
        _uangMasukNota = masuk;
        _pendapatanJasa = masuk;
        _transaksiHari = transaksi;
        _pengeluaranHari = listPengeluaran;
        _isLoading = false;
      });
    } catch (e, stack) {
      debugPrint('ERROR fetchData harian: $e\n$stack');
      setState(() => _isLoading = false);
    }
  }

  // ════════════════════════════════════════════════════════════
  // FIX BARU: helper parse double dari berbagai tipe Firestore
  // Firestore bisa return int, double, atau String untuk field angka
  // ════════════════════════════════════════════════════════════
  double _parseDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is double) return val;
    if (val is int) return val.toDouble();
    if (val is String) return double.tryParse(val.trim()) ?? 0.0;
    return 0.0;
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
          : GlobalRefresh(
              onRefresh: () => _fetchData(selectedDate),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDatePicker(),
                    const SizedBox(height: 20),
                    _buildSectionLabel('LAPORAN HARIAN', bodySmall),
                    const SizedBox(height: 12),
                    _buildSummaryGrid(cardColor, bodyLarge, bodySmall),
                    const SizedBox(height: 20),
                    _buildSectionLabel('LAPORAN KEUANGAN', bodySmall),
                    const SizedBox(height: 12),
                    _buildDetailKeuangan(cardColor, bodyLarge, bodySmall),
                    if (_transaksiHari.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _buildSectionLabel('TRANSAKSI HARI INI', bodySmall),
                      const SizedBox(height: 12),
                      _buildTransaksiList(cardColor, bodyLarge, bodySmall),
                    ],
                    if (_pengeluaranHari.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _buildSectionLabel('PENGELUARAN HARI INI', bodySmall),
                      const SizedBox(height: 12),
                      _buildPengeluaranList(cardColor, bodyLarge, bodySmall),
                    ],
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionLabel(String text, TextStyle? bodySmall) {
    return Text(
      text,
      style: bodySmall?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
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
                    'Laporan ini menampilkan ringkasan transaksi, pemasukan, '
                    'dan pengeluaran pada tanggal yang dipilih.\n\n'
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

  Widget _buildSummaryGrid(
    Color cardColor,
    TextStyle? bodyLarge,
    TextStyle? bodySmall,
  ) {
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
        'Uang Masuk',
        _formatRp(_uangMasuk),
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
        'Laba/Rugi',
        _formatRp(_labaRugi),
        Icons.bar_chart_rounded,
        const Color(0xffDCFCE7),
        const Color(0xff16A34A),
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
      children: items.map((c) {
        return Container(
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
        );
      }).toList(),
    );
  }

  Widget _buildDetailKeuangan(
    Color cardColor,
    TextStyle? bodyLarge,
    TextStyle? bodySmall,
  ) {
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
                'Detail Keuangan',
                style: bodyLarge?.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _detailRow('Omzet', _formatRp(_totalOmzet), bodySmall),
          _detailRow('Uang Masuk Nota', _formatRp(_uangMasukNota), bodySmall),
          _detailRow('Total Uang Masuk', _formatRp(_uangMasuk), bodySmall),
          _detailRow('Pendapatan Jasa', _formatRp(_pendapatanJasa), bodySmall),
          const Divider(height: 20, thickness: 1),
          _detailRow(
            'Total Pendapatan',
            _formatRp(_uangMasuk),
            bodySmall,
            isTotal: true,
            totalColor: const Color(0xff16A34A),
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
      padding: const EdgeInsets.symmetric(vertical: 5),
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
          final bool lunas =
              (t['status'] ?? '').toString().toLowerCase() != 'belum lunas';
          final String nama = t['nama'] ?? t['nip'] ?? '-';
          final double biaya = _parseDouble(t['biaya']);

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
                      decoration: BoxDecoration(
                        color: lunas
                            ? const Color(0xffDCFCE7)
                            : const Color(0xffFEF3C7),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        lunas
                            ? Icons.check_circle_outline_rounded
                            : Icons.hourglass_empty_rounded,
                        size: 16,
                        color: lunas
                            ? const Color(0xff16A34A)
                            : const Color(0xffD97706),
                      ),
                    ),
                    const SizedBox(width: 12),
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
                          Text(
                            t['waktu'] ?? '-',
                            style: bodySmall?.copyWith(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _formatRp(biaya),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: lunas
                                ? const Color(0xff16A34A)
                                : const Color(0xffD97706),
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.only(top: 3),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: lunas
                                ? const Color(0xffDCFCE7)
                                : const Color(0xffFEF3C7),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            lunas ? 'Lunas' : 'Belum Lunas',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: lunas
                                  ? const Color(0xff16A34A)
                                  : const Color(0xffD97706),
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

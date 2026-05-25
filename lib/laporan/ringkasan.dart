import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'date_range_picker_widget.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../screens/screens.dart';

class RingkasanPage extends StatefulWidget {
  const RingkasanPage({super.key});

  @override
  State<RingkasanPage> createState() => _RingkasanPageState();
}

class _RingkasanPageState extends State<RingkasanPage> {
  DateTime startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime endDate = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );

  String totalOmzet = "0";
  String uangMasuk = "0";
  String piutang = "0";
  String pengeluaran = "0";
  String labaRugi = "0";
  String ppn = "0";

  String pemasukanNota = "0";
  String pelangganAktif = "0";
  String pelangganBaru = "0";
  String repeatCustomer = "0";
  String berpiutang = "0";

  List<Map<String, dynamic>> _dataPiutang = [];
  Map<int, double> chartDataPerHari = {};

  String _formatYLabel(double value) {
    if (value == 0) return '0';
    if (value >= 1000000) {
      double jt = value / 1000000;
      return jt == jt.roundToDouble()
          ? '${jt.toInt()}jt'
          : '${jt.toStringAsFixed(1)}jt';
    }
    if (value >= 1000) {
      double rb = value / 1000;
      return rb == rb.roundToDouble()
          ? '${rb.toInt()}rb'
          : '${rb.toStringAsFixed(1)}rb';
    }
    return value.toInt().toString();
  }

  @override
  void initState() {
    super.initState();
    fetchFirestoreData(startDate, endDate);
  }

  // ════════════════════════════════════════════════════════════
  // HELPER: parse date fleksibel (String ATAU Timestamp)
  // ════════════════════════════════════════════════════════════
  DateTime? _parseFlexibleDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is Timestamp) return raw.toDate();
    if (raw is String) {
      if (raw.trim().isEmpty) return null;
      try {
        return DateFormat('dd/MM/yyyy HH:mm').parse(raw.trim());
      } catch (_) {
        try {
          return DateFormat('dd/MM/yyyy').parse(raw.trim());
        } catch (_) {
          return null;
        }
      }
    }
    return null;
  }

  String _formatDateToString(DateTime dt) =>
      DateFormat('dd/MM/yyyy HH:mm').format(dt);

  // ════════════════════════════════════════════════════════════
  // FETCH FIRESTORE
  // ════════════════════════════════════════════════════════════
  Future<void> fetchFirestoreData(DateTime start, DateTime end) async {
    try {
      final results = await Future.wait([
        FirebaseFirestore.instance.collection('keuangan').get(),
        FirebaseFirestore.instance.collection('pengeluaran').get(),
        FirebaseFirestore.instance.collection('rekam_medis').get(),
        FirebaseFirestore.instance.collection('pasien').get(),
      ]);

      final keuanganSnapshot = results[0];
      final pengeluaranSnapshot = results[1];
      final rekamSnapshot = results[2];
      final pasienSnapshot = results[3];

      // ── Map NIP → data pasien ──
      Map<String, Map<String, String>> dataPasienMap = {};
      for (var doc in pasienSnapshot.docs) {
        final data = doc.data();
        final nip = (data['nomer_induk_pasien'] ?? '').toString().trim();
        if (nip.isNotEmpty) {
          dataPasienMap[nip] = {
            'nama': _resolveNama(data),
            'no_hp': _resolveNoHp(data),
          };
        }
      }

      double hitungOmzet = 0;
      double hitungUangMasuk = 0;
      double hitungPiutang = 0;
      double hitungPengeluaran = 0;

      Map<int, double> omzetPerHari = {};
      Set<String> pasienUnik = {};
      Set<String> pasienBerpiutang = {};
      List<Map<String, dynamic>> listPiutang = [];

      final DateTime tanggalMulaiHanyaHari = DateTime(
        start.year,
        start.month,
        start.day,
      );
      final DateTime tanggalAkhirHanyaHari = DateTime(
        end.year,
        end.month,
        end.day,
      );

      // ── Loop rekam_medis ──
      Map<String, List<DateTime>> semuaKunjungan = {};
      Map<String, Map<String, String>> rekamLayananMap = {};

      for (var doc in rekamSnapshot.docs) {
        final data = doc.data();
        final String nip = (data['nomer_induk_pasien'] ?? '').toString().trim();
        if (nip.isEmpty) continue;

        // ✅ FIX: pakai _parseFlexibleDate
        final DateTime? tglKunjungan = _parseFlexibleDate(
          data['waktu_kunjungan'],
        );
        if (tglKunjungan == null) continue;

        semuaKunjungan.putIfAbsent(nip, () => []).add(tglKunjungan);

        final String layanan = (data['layanan'] as String? ?? '').trim();
        final String tindakan = (data['tindakan'] as String? ?? '').trim();

        String infoLayanan;
        if (layanan.isNotEmpty && tindakan.isNotEmpty) {
          infoLayanan = '$layanan – $tindakan';
        } else if (layanan.isNotEmpty) {
          infoLayanan = layanan;
        } else if (tindakan.isNotEmpty) {
          infoLayanan = tindakan;
        } else {
          infoLayanan = '-';
        }

        final String tglKey = DateFormat('dd/MM/yyyy').format(tglKunjungan);
        final String mapKey = '$nip|$tglKey';

        if (rekamLayananMap.containsKey(mapKey)) {
          final String existing = rekamLayananMap[mapKey]!['layanan'] ?? '-';
          if (existing != infoLayanan && infoLayanan != '-') {
            rekamLayananMap[mapKey] = {'layanan': '$existing, $infoLayanan'};
          }
        } else {
          rekamLayananMap[mapKey] = {'layanan': infoLayanan};
        }
      }

      // ── Loop keuangan ──
      for (var doc in keuanganSnapshot.docs) {
        final data = doc.data();

        // ✅ FIX: pakai _parseFlexibleDate
        final DateTime? tglUtuh = _parseFlexibleDate(data['waktu_transaksi']);
        if (tglUtuh == null) continue;

        final DateTime tglHari = DateTime(
          tglUtuh.year,
          tglUtuh.month,
          tglUtuh.day,
        );
        final bool masukRange =
            !tglHari.isBefore(tanggalMulaiHanyaHari) &&
            !tglHari.isAfter(tanggalAkhirHanyaHari);
        if (!masukRange) continue;

        final double nominalBiaya = (data['biaya'] ?? 0).toDouble();
        final String statusBayar = (data['status_bayar'] ?? '').toString();
        final String noPasien = (data['nomer_induk_pasien'] ?? '')
            .toString()
            .trim();
        final String waktuStr = _formatDateToString(tglUtuh);

        String namaPasien;
        String noHp;
        if (noPasien.isNotEmpty && dataPasienMap.containsKey(noPasien)) {
          namaPasien = dataPasienMap[noPasien]!['nama'] ?? '-';
          noHp = dataPasienMap[noPasien]!['no_hp'] ?? '';
        } else {
          namaPasien = _resolveNamaFromKeuangan(data);
          noHp = '';
        }

        hitungOmzet += nominalBiaya;
        omzetPerHari[tglHari.day] =
            (omzetPerHari[tglHari.day] ?? 0) + nominalBiaya;

        if (statusBayar == 'Belum Lunas') {
          hitungPiutang += nominalBiaya;
          if (noPasien.isNotEmpty) pasienBerpiutang.add(noPasien);

          final String tglKeyP = DateFormat('dd/MM/yyyy').format(tglHari);
          final String rekamKey = '$noPasien|$tglKeyP';
          final String layananFinal = rekamLayananMap.containsKey(rekamKey)
              ? (rekamLayananMap[rekamKey]!['layanan'] ?? '-')
              : '-';

          listPiutang.add({
            'nama': namaPasien,
            'nip': noPasien,
            'layanan': layananFinal,
            'nominal': nominalBiaya,
            'waktu': waktuStr,
            'no_hp': noHp,
          });
        } else {
          hitungUangMasuk += nominalBiaya;
        }

        if (noPasien.isNotEmpty) pasienUnik.add(noPasien);
      }

      // ── Loop pengeluaran ──
      for (var doc in pengeluaranSnapshot.docs) {
        final data = doc.data();

        // ✅ FIX: pakai _parseFlexibleDate
        final DateTime? tglPengeluaran = _parseFlexibleDate(data['tanggal']);
        if (tglPengeluaran == null) continue;

        final DateTime tglHari = DateTime(
          tglPengeluaran.year,
          tglPengeluaran.month,
          tglPengeluaran.day,
        );
        final bool masukRange =
            !tglHari.isBefore(tanggalMulaiHanyaHari) &&
            !tglHari.isAfter(tanggalAkhirHanyaHari);
        if (masukRange) {
          hitungPengeluaran += (data['nominal'] ?? 0).toDouble();
        }
      }

      // ── Hitung pelanggan ──
      final DateTime batas4Bulan = tanggalAkhirHanyaHari.subtract(
        const Duration(days: 120),
      );
      final DateTime batas1Bulan = tanggalAkhirHanyaHari.subtract(
        const Duration(days: 30),
      );

      Set<String> pelangganAktifSet = {};
      Set<String> pasienBaru = {};
      Set<String> pasienRepeat = {};

      for (var entry in semuaKunjungan.entries) {
        final String nip = entry.key;
        final List<DateTime> kunjungan = entry.value
          ..sort((a, b) => a.compareTo(b));

        final DateTime tglPertama = DateTime(
          kunjungan.first.year,
          kunjungan.first.month,
          kunjungan.first.day,
        );
        final DateTime tglTerakhir = DateTime(
          kunjungan.last.year,
          kunjungan.last.month,
          kunjungan.last.day,
        );

        final bool isAktif = !tglTerakhir.isBefore(batas4Bulan);
        if (isAktif) pelangganAktifSet.add(nip);

        final bool isBaru = !tglPertama.isBefore(batas1Bulan);
        if (isBaru) pasienBaru.add(nip);

        if (kunjungan.length > 1 && isAktif) pasienRepeat.add(nip);
      }

      setState(() {
        startDate = start;
        endDate = end;

        final currency = NumberFormat.currency(
          locale: 'id_ID',
          symbol: 'Rp ',
          decimalDigits: 0,
        );

        totalOmzet = currency.format(hitungOmzet);
        uangMasuk = currency.format(hitungUangMasuk);
        piutang = currency.format(hitungPiutang);
        pengeluaran = currency.format(hitungPengeluaran);
        labaRugi = currency.format(hitungUangMasuk - hitungPengeluaran);
        pemasukanNota = currency.format(hitungUangMasuk);

        final double dasarPph = hitungOmzet - hitungPiutang;
        ppn = currency.format(dasarPph * 0.025);

        pelangganAktif = pelangganAktifSet.length.toString();
        pelangganBaru = pasienBaru.length.toString();
        repeatCustomer = pasienRepeat.length.toString();
        berpiutang = pasienBerpiutang.length.toString();

        chartDataPerHari = omzetPerHari;
        _dataPiutang = listPiutang;
      });
    } catch (e, stack) {
      debugPrint('LOG ERROR: Terjadi kesalahan sistem utama: $e\n$stack');
    }
  }

  // ════════════════════════════════════════════════════════════
  // HELPERS nama & HP
  // ════════════════════════════════════════════════════════════
  String _resolveNama(Map<String, dynamic> data) {
    for (final key in ['nama_lengkap', 'nama', 'nama_pasien', 'name']) {
      final val = data[key];
      if (val is String && val.trim().isNotEmpty) return val.trim();
    }
    return '-';
  }

  String _resolveNamaFromKeuangan(Map<String, dynamic> data) {
    for (final key in ['nama_lengkap', 'nama_pasien', 'nama', 'name']) {
      final val = data[key];
      if (val is String && val.trim().isNotEmpty) return val.trim();
    }
    return '-';
  }

  String _resolveNoHp(Map<String, dynamic> data) {
    for (final key in [
      'nomer_hp',
      'no_hp',
      'no_telp',
      'telepon',
      'phone',
      'nomor_hp',
      'hp',
    ]) {
      final val = data[key];
      if (val is String && val.trim().isNotEmpty) return val.trim();
    }
    return '';
  }

  // ════════════════════════════════════════════════════════════
  // KIRIM TAGIHAN VIA WHATSAPP
  // ════════════════════════════════════════════════════════════
  Future<void> _kirimTagihanWA(Map<String, dynamic> item) async {
    final noHp = (item['no_hp'] as String? ?? '').trim();
    if (noHp.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nomor HP pasien tidak tersedia'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final currency = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    final nama = item['nama'] ?? '-';
    final nip = item['nip'] ?? '-';
    final layanan = item['layanan'] ?? '-';
    final nominal = currency.format(item['nominal'] ?? 0);
    final waktu = item['waktu'] ?? '-';

    final pesan =
        'Halo $nama,\n\n'
        'Kami dari Klinik ingin menginformasikan bahwa Anda masih memiliki tagihan yang belum dilunasi.\n\n'
        '📋 *Detail Tagihan*\n'
        'Nama      : $nama\n'
        'No. Pasien: $nip\n'
        'Layanan   : $layanan\n'
        'Tanggal   : $waktu\n'
        'Nominal   : *$nominal*\n\n'
        'Mohon segera melakukan pembayaran. Terima kasih atas kepercayaan Anda.\n\n'
        '_Salam,_\n'
        '_Tim Klinik_';

    String normalizedHp = noHp.replaceAll(RegExp(r'\s+|-'), '');
    if (normalizedHp.startsWith('0')) {
      normalizedHp = '62${normalizedHp.substring(1)}';
    } else if (!normalizedHp.startsWith('62')) {
      normalizedHp = '62$normalizedHp';
    }

    final uri = Uri.parse(
      'https://wa.me/$normalizedHp?text=${Uri.encodeComponent(pesan)}',
    );
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tidak dapat membuka WhatsApp'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('LOG ERROR: WhatsApp launch: $e');
    }
  }

  // ════════════════════════════════════════════════════════════
  // DETAIL PIUTANG
  // ════════════════════════════════════════════════════════════
  void _showDetailPiutang() {
    final currency = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.92,
        minChildSize: 0.4,
        builder: (_, controller) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
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
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(
                    Icons.hourglass_empty_rounded,
                    color: Color(0xffD97706),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Detail Piutang',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xffFEF3C7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_dataPiutang.length} Transaksi',
                      style: const TextStyle(
                        color: Color(0xffD97706),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Daftar transaksi yang belum dilunasi',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              Divider(color: Theme.of(context).dividerColor, height: 1),
              const SizedBox(height: 8),
              Expanded(
                child: _dataPiutang.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.check_circle_outline_rounded,
                              size: 48,
                              color: Color(0xff16A34A),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Tidak ada piutang di periode ini',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        controller: controller,
                        itemCount: _dataPiutang.length,
                        separatorBuilder: (_, __) => Divider(
                          color: Theme.of(context).dividerColor,
                          height: 1,
                        ),
                        itemBuilder: (_, i) {
                          final item = _dataPiutang[i];
                          final noHp = (item['no_hp'] as String? ?? '');
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xffFEF3C7),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.person_outline_rounded,
                                    color: Color(0xffD97706),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        (item['nama']?.toString().isNotEmpty ==
                                                true)
                                            ? item['nama']
                                            : '-',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${item['nip'] ?? '-'}  •  ${noHp.isNotEmpty ? noHp : 'No HP tidak ada'}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(fontSize: 12),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        item['layanan'] ?? '-',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              fontSize: 11,
                                              fontStyle: FontStyle.italic,
                                            ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        item['waktu'] ?? '',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(fontSize: 11),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        currency.format(item['nominal'] ?? 0),
                                        style: const TextStyle(
                                          color: Color(0xffD97706),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      SizedBox(
                                        width: double.infinity,
                                        child: OutlinedButton.icon(
                                          onPressed: () =>
                                              _kirimTagihanWA(item),
                                          icon: const Icon(
                                            Icons.send_rounded,
                                            color: Color(0xff25D366),
                                            size: 18,
                                          ),
                                          label: Text(
                                            noHp.isNotEmpty
                                                ? 'Kirim Tagihan ke WA'
                                                : 'No HP tidak tersedia',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: noHp.isNotEmpty
                                                  ? const Color(0xff25D366)
                                                  : Colors.grey,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            side: BorderSide(
                                              color: noHp.isNotEmpty
                                                  ? const Color(0xff25D366)
                                                  : Colors.grey.shade300,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 8,
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
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // HELPERS chart & periode
  // ════════════════════════════════════════════════════════════
  String _formatPeriodeText() {
    const bulan = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    if (startDate.month == endDate.month && startDate.year == endDate.year) {
      return '${bulan[startDate.month - 1]} ${startDate.year}';
    }
    return '${startDate.day} ${bulan[startDate.month - 1]} - '
        '${endDate.day} ${bulan[endDate.month - 1]} ${endDate.year}';
  }

  List<FlSpot> _buildChartSpots() {
    if (chartDataPerHari.isEmpty) {
      return [const FlSpot(1, 0), const FlSpot(31, 0)];
    }
    final spots =
        chartDataPerHari.entries
            .map((e) => FlSpot(e.key.toDouble(), e.value))
            .toList()
          ..sort((a, b) => a.x.compareTo(b.x));
    if (spots.length == 1) {
      spots.insert(0, FlSpot(spots.first.x - 1 < 1 ? 1 : spots.first.x - 1, 0));
    }
    return spots;
  }

  double _getChartMaxY() {
    if (chartDataPerHari.isEmpty) return 100000;
    final maxVal = chartDataPerHari.values.reduce((a, b) => a > b ? a : b);
    final magnitude = maxVal / 5;
    final rounded =
        (magnitude / _niceStep(magnitude)).ceil() * _niceStep(magnitude) * 5;
    return rounded * 1.2;
  }

  double _niceStep(double val) {
    if (val < 1000) return 500;
    if (val < 10000) return 5000;
    if (val < 100000) return 50000;
    return 100000;
  }

  // ════════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final cardColor = Theme.of(context).cardColor;
    final bodyLarge = Theme.of(context).textTheme.bodyLarge;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(context),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPeriodeSelector(cardColor, bodyLarge),
            const SizedBox(height: 16),
            _buildChartSection(cardColor),
            const SizedBox(height: 24),
            Text(
              'Rincian Laporan',
              style:
                  bodyLarge?.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ) ??
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildReportCard(
              cardColor: cardColor,
              bodyLarge: bodyLarge,
              icon: Icons.receipt_long_rounded,
              iconColor: const Color(0xff0284C7),
              iconBgColor: const Color(0xffE0F2FE),
              title: 'Total Omzet',
              subtitle: 'Semua nota yang dibuat di periode ini',
              value: totalOmzet,
              valueColor: bodyLarge?.color ?? const Color(0xff1E293B),
            ),
            _buildReportCard(
              cardColor: cardColor,
              bodyLarge: bodyLarge,
              icon: Icons.account_balance_wallet_rounded,
              iconColor: const Color(0xff16A34A),
              iconBgColor: const Color(0xffDCFCE7),
              title: 'Uang Masuk',
              subtitle: 'Uang yang aktual diterima di periode ini',
              value: uangMasuk,
              valueColor: bodyLarge?.color ?? const Color(0xff1E293B),
            ),
            _buildReportCard(
              cardColor: cardColor,
              bodyLarge: bodyLarge,
              icon: Icons.hourglass_empty_rounded,
              iconColor: const Color(0xffD97706),
              iconBgColor: const Color(0xffFEF3C7),
              title: 'Piutang',
              subtitle: 'Layanan periode ini yang belum dibayar',
              value: piutang,
              valueColor: bodyLarge?.color ?? const Color(0xff1E293B),
              hasDetail: true,
              onDetailTap: _showDetailPiutang,
            ),
            _buildReportCard(
              cardColor: cardColor,
              bodyLarge: bodyLarge,
              icon: Icons.upload_rounded,
              iconColor: const Color(0xffDC2626),
              iconBgColor: const Color(0xffFEE2E2),
              title: 'Pengeluaran',
              subtitle: 'Total biaya operasional & pengeluaran lain',
              value: pengeluaran,
              valueColor: bodyLarge?.color ?? const Color(0xff1E293B),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FormPengeluaranPage(),
                ),
              ),
            ),
            _buildReportCard(
              cardColor: cardColor,
              bodyLarge: bodyLarge,
              icon: Icons.stars_rounded,
              iconColor: const Color(0xff15803D),
              iconBgColor: const Color(0xffE2F0D9),
              title: 'Laba / Rugi',
              subtitle: 'Total uang masuk yang sudah dikurangi pengeluaran',
              value: labaRugi,
              valueColor: const Color(0xff16A34A),
            ),
            const SizedBox(height: 8),
            _buildDetailSection(
              cardColor: cardColor,
              bodyLarge: bodyLarge,
              title: 'DETAIL UANG MASUK',
              accentColor: const Color(0xff0284C7),
              items: [
                _buildDetailRow(
                  'Pemasukan Nota',
                  pemasukanNota,
                  bodyLarge: bodyLarge,
                ),
                const Divider(height: 24, thickness: 1),
                _buildDetailRow(
                  'Total Uang Masuk',
                  uangMasuk,
                  isTotal: true,
                  totalColor: const Color(0xff16A34A),
                  bodyLarge: bodyLarge,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PPh 2,5%',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(
                                context,
                              ).textTheme.bodyMedium?.color,
                            ),
                          ),
                          Text(
                            'dari Omzet dikurangi Piutang',
                            style: TextStyle(
                              fontSize: 10,
                              color: Theme.of(
                                context,
                              ).textTheme.bodySmall?.color,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        ppn,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xffDC2626),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildDetailSection(
              cardColor: cardColor,
              bodyLarge: bodyLarge,
              title: 'PELANGGAN',
              accentColor: const Color(0xff0284C7),
              items: [
                _buildDetailRow(
                  'Total Pelanggan Aktif',
                  pelangganAktif,
                  isBoldValue: true,
                  bodyLarge: bodyLarge,
                ),
                _buildDetailRow(
                  'Pelanggan Baru',
                  pelangganBaru,
                  isBoldValue: true,
                  bodyLarge: bodyLarge,
                ),
                _buildDetailRow(
                  'Repeat Customer',
                  repeatCustomer,
                  isBoldValue: true,
                  bodyLarge: bodyLarge,
                ),
                _buildDetailRow(
                  'Berpiutang',
                  berpiutang,
                  isBoldValue: true,
                  bodyLarge: bodyLarge,
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // WIDGETS
  // ════════════════════════════════════════════════════════════
  Widget _buildPeriodeSelector(Color cardColor, TextStyle? bodyLarge) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_month_rounded, color: Color(0xff0284C7)),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Periode Laporan',
                style:
                    bodyLarge?.copyWith(fontSize: 12, color: Colors.grey) ??
                    const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              Text(
                _formatPeriodeText(),
                style:
                    bodyLarge?.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ) ??
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: () async {
              final DateTimeRange? pickedRange =
                  await CalendarHelper.showFullDatePicker(context);
              if (pickedRange != null) {
                fetchFirestoreData(pickedRange.start, pickedRange.end);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff007AFF),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            child: const Text('Ubah', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildChartSection(Color cardColor) {
    final spots = _buildChartSpots();
    final maxY = _getChartMaxY();

    return Container(
      height: 220,
      padding: const EdgeInsets.only(right: 16, top: 16, bottom: 8),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) =>
                FlLine(color: Theme.of(context).dividerColor, strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 52,
                getTitlesWidget: (value, meta) {
                  if (value == meta.min || value == meta.max) {
                    return Text(
                      _formatYLabel(value),
                      style: TextStyle(
                        color:
                            Theme.of(context).textTheme.bodySmall?.color ??
                            Colors.grey,
                        fontSize: 10,
                      ),
                    );
                  }
                  final double mid = (meta.min + meta.max) / 2;
                  if ((value - mid).abs() < meta.max * 0.08) {
                    return Text(
                      _formatYLabel(value),
                      style: TextStyle(
                        color:
                            Theme.of(context).textTheme.bodySmall?.color ??
                            Colors.grey,
                        fontSize: 10,
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  const labels = [1, 5, 10, 15, 20, 25, 31];
                  if (labels.contains(value.toInt())) {
                    return Text(
                      value.toInt().toString().padLeft(2, '0'),
                      style: TextStyle(
                        color:
                            Theme.of(context).textTheme.bodySmall?.color ??
                            Colors.grey,
                        fontSize: 11,
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          minX: 1,
          maxX: 31,
          minY: 0,
          maxY: maxY,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: const Color(0xff007AFF),
              barWidth: 3,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: const Color(0xff007AFF).withOpacity(0.08),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard({
    required Color cardColor,
    required TextStyle? bodyLarge,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String subtitle,
    required String value,
    required Color valueColor,
    VoidCallback? onTap,
    bool hasDetail = false,
    VoidCallback? onDetailTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            title,
                            style: bodyLarge?.copyWith(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(
                                context,
                              ).textTheme.bodyMedium?.color,
                            ),
                          ),
                          Text(
                            value,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: valueColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                      ),
                      if (hasDetail && onDetailTap != null) ...[
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: onDetailTap,
                          child: const Row(
                            children: [
                              Text(
                                'Lihat Detail ',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_rounded,
                                size: 14,
                                color: Colors.orange,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailSection({
    required Color cardColor,
    required TextStyle? bodyLarge,
    required String title,
    required Color accentColor,
    required List<Widget> items,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 3, height: 16, color: accentColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: bodyLarge?.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...items,
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    bool isTotal = false,
    Color? totalColor,
    bool isBoldValue = false,
    TextStyle? bodyLarge,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: (bodyLarge ?? const TextStyle()).copyWith(
              fontSize: 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal
                  ? Theme.of(context).textTheme.bodyLarge?.color
                  : Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
          Text(
            value,
            style: (bodyLarge ?? const TextStyle()).copyWith(
              fontSize: 14,
              fontWeight: (isTotal || isBoldValue)
                  ? FontWeight.bold
                  : FontWeight.normal,
              color: totalColor ?? Theme.of(context).textTheme.bodyLarge?.color,
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
            'Ringkasan Klinik',
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

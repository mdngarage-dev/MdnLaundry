import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main_screens.dart';

class RingkasanPage extends StatefulWidget {
  const RingkasanPage({super.key});

  @override
  State<RingkasanPage> createState() => _RingkasanPageState();
}

class _RingkasanPageState extends State<RingkasanPage> {
  // Default: full bulan berjalan — tgl 1 s/d hari terakhir bulan ini
  DateTime startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime endDate = DateTime(
    DateTime.now().year,
    DateTime.now().month + 1, // bulan + 1 hari 0 = hari terakhir bulan ini
    0,
  );

  // ── Nilai yang ditampilkan ──────────────────────────────────────────────
  String totalOmzet = "0";
  String uangMasuk = "0";
  String piutang = "0";
  String pengeluaran = "0";
  String labaRugi = "0";
  String ppn = "0";
  String rataHarian = "0";
  String rataBulanan = "0";
  String pemasukanNota = "0";
  String pelangganAktif = "0";
  String pelangganBaru = "0";
  String repeatCustomer = "0";
  String berpiutang = "0";

  List<Map<String, dynamic>> _dataPiutang = [];
  Map<int, double> chartDataPerHari = {};

  bool _isLoading = false;

  // ──────────────────────────────────────────────────────────────────────────
  // FORMAT Y LABEL CHART
  // ──────────────────────────────────────────────────────────────────────────
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

  // ──────────────────────────────────────────────────────────────────────────
  // FETCH — sumber data: ORDER + KEUANGAN + PENGELUARAN + PELANGGAN
  //
  // Skema pembayaran:
  //   lunas      → omzet += harga_total, masuk += harga_total
  //   dp         → omzet += harga_total, masuk += dp_amount,
  //                piutang += harga_total - dp_amount
  //   belum_bayar→ omzet += harga_total, piutang += harga_total
  //
  // Pelanggan:
  //   aktif   = nomor_pelanggan unik yang punya order dalam range
  //   baru    = pelanggan (collection pelanggan) yang created_at dalam range
  //   repeat  = nomor_pelanggan yang order > 1x dalam range
  //   berpiutang = nomor_pelanggan yang punya piutang dalam range
  // ──────────────────────────────────────────────────────────────────────────
  Future<void> fetchFirestoreData(DateTime start, DateTime end) async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      // ── Fetch paralel ──────────────────────────────────────────────────
      final results = await Future.wait([
        FirebaseFirestore.instance.collection('order').get(),
        FirebaseFirestore.instance.collection('pengeluaran').get(),
        FirebaseFirestore.instance.collection('pelanggan').get(),
      ]);

      final orderSnap = results[0];
      final pengeluaranSnap = results[1];
      final pelangganSnap = results[2];

      final DateTime startDay = DateTime(start.year, start.month, start.day);
      final DateTime endDay = DateTime(end.year, end.month, end.day);

      // ── Akumulator ────────────────────────────────────────────────────
      double hitungOmzet = 0;
      double hitungMasuk = 0;
      double hitungPiutang = 0;
      double hitungPengeluaran = 0;

      Map<int, double> omzetPerHari = {};
      Set<String> nomorAktif = {}; // punya order dalam range
      Set<String> nomorBerpiutang = {};
      Map<String, int> orderCountRange =
          {}; // hitung order per nomor dalam range
      Map<String, List<DateTime>> allOrderDates =
          {}; // semua tanggal order per nomor
      List<Map<String, dynamic>> listPiutang = [];

      // ── Loop ORDER ────────────────────────────────────────────────────
      for (final doc in orderSnap.docs) {
        final data = doc.data();

        // Timestamp waktu_order
        final dynamic rawWaktu = data['waktu_order'];
        if (rawWaktu == null) continue;
        final DateTime? tglUtuh = rawWaktu is Timestamp
            ? rawWaktu.toDate()
            : null;
        if (tglUtuh == null) continue;

        final DateTime tglHari = DateTime(
          tglUtuh.year,
          tglUtuh.month,
          tglUtuh.day,
        );
        final bool inRange =
            !tglHari.isBefore(startDay) && !tglHari.isAfter(endDay);

        // Field sesuai collection order laundry
        final String nomorPelanggan = (data['nomor_pelanggan'] ?? '')
            .toString()
            .trim();
        final String nama = (data['nama_pelanggan'] ?? '-').toString().trim();
        final String noHp = (data['no_hp'] ?? '').toString().trim();
        final String layanan = (data['layanan_nama'] ?? '-').toString().trim();
        final String statusBayar = (data['status_bayar'] ?? '')
            .toString()
            .toLowerCase()
            .trim();

        // harga_total = grand total seluruh items (sudah dihitung saat save)
        final double hargaTotal = (data['harga_total'] ?? 0).toDouble();
        final double dpAmount = (data['dp_amount'] ?? 0).toDouble();

        // ── Identifier unik per ORANG (bukan per struk) ──────────────────
        // nomor_pelanggan di Firestore = nomor struk (MDNxxxxxxx), unik per transaksi
        // Gunakan no_hp sebagai identifier orang; fallback ke nama jika no_hp kosong
        final String idOrang = noHp.isNotEmpty ? noHp : nama;

        // Kumpulkan semua tanggal order per orang (untuk cek pelanggan baru global)
        if (idOrang.isNotEmpty) {
          allOrderDates.putIfAbsent(idOrang, () => []).add(tglHari);
        }

        if (!inRange) continue;

        // ── Keuangan dalam range ──
        hitungOmzet += hargaTotal;
        omzetPerHari[tglHari.day] =
            (omzetPerHari[tglHari.day] ?? 0) + hargaTotal;

        if (statusBayar == 'lunas') {
          hitungMasuk += hargaTotal;
        } else if (statusBayar == 'dp') {
          // Masuk = dp yang sudah dibayar
          // Piutang = sisa (harga_total - dp_amount)
          hitungMasuk += dpAmount;
          final double sisa = (hargaTotal - dpAmount).clamp(
            0.0,
            double.infinity,
          );
          if (sisa > 0) {
            hitungPiutang += sisa;
            if (idOrang.isNotEmpty) nomorBerpiutang.add(idOrang);
            listPiutang.add({
              'nama': nama.isNotEmpty ? nama : '-',
              'nip': nomorPelanggan, // tetap tampilkan nomor struk di detail
              'layanan': layanan,
              'nominal': sisa, // hanya sisa yang belum dibayar
              'waktu': DateFormat('dd/MM/yyyy HH:mm').format(tglUtuh),
              'no_hp': noHp,
              'dp': dpAmount, // tampil di detail untuk info
              'total': hargaTotal,
            });
          }
        } else {
          // belum_bayar — seluruh harga_total masuk piutang
          if (hargaTotal > 0) {
            hitungPiutang += hargaTotal;
            if (idOrang.isNotEmpty) nomorBerpiutang.add(idOrang);
            listPiutang.add({
              'nama': nama.isNotEmpty ? nama : '-',
              'nip': nomorPelanggan,
              'layanan': layanan,
              'nominal': hargaTotal,
              'waktu': DateFormat('dd/MM/yyyy HH:mm').format(tglUtuh),
              'no_hp': noHp,
              'dp': 0.0,
              'total': hargaTotal,
            });
          }
        }

        // ── Pelanggan aktif & repeat dalam range (pakai idOrang) ──
        if (idOrang.isNotEmpty) {
          nomorAktif.add(idOrang);
          orderCountRange[idOrang] = (orderCountRange[idOrang] ?? 0) + 1;
        }
      }

      // ── Repeat customer = orang (by no_hp/nama) dengan >1 order dalam range ──
      final Set<String> nomorRepeat = orderCountRange.entries
          .where((e) => e.value > 1)
          .map((e) => e.key)
          .toSet();

      // ── Pelanggan BARU = dari collection PELANGGAN (field created_at) ─────
      // Juga bisa fallback: orang yang order pertamanya (by idOrang) di range ini
      int hitungPelangganBaru = 0;

      // Cara 1: dari collection pelanggan (paling akurat)
      bool adaDataPelanggan = pelangganSnap.docs.isNotEmpty;
      if (adaDataPelanggan) {
        for (final doc in pelangganSnap.docs) {
          final data = doc.data();
          // Support field created_at (Timestamp) atau waktu_daftar
          final dynamic rawCreated = data['created_at'] ?? data['waktu_daftar'];
          if (rawCreated == null) continue;
          final DateTime? createdDate = rawCreated is Timestamp
              ? rawCreated.toDate()
              : null;
          if (createdDate == null) continue;
          final DateTime createdDay = DateTime(
            createdDate.year,
            createdDate.month,
            createdDate.day,
          );
          if (!createdDay.isBefore(startDay) && !createdDay.isAfter(endDay)) {
            hitungPelangganBaru++;
          }
        }
      }

      // Cara 2 (fallback jika collection pelanggan kosong):
      // orang yang order pertamanya (secara global) jatuh dalam range
      if (!adaDataPelanggan) {
        for (final entry in allOrderDates.entries) {
          final sorted = List<DateTime>.from(entry.value)..sort();
          final firstDay = sorted.first;
          if (!firstDay.isBefore(startDay) && !firstDay.isAfter(endDay)) {
            hitungPelangganBaru++;
          }
        }
      }

      // ── Loop PENGELUARAN ──────────────────────────────────────────────
      for (final doc in pengeluaranSnap.docs) {
        final data = doc.data();
        final dynamic rawTgl = data['tanggal'];
        if (rawTgl == null) continue;
        DateTime? tglP;
        if (rawTgl is Timestamp) {
          tglP = rawTgl.toDate();
        } else if (rawTgl is String) {
          try {
            tglP = DateFormat('dd/MM/yyyy').parse(rawTgl.trim());
          } catch (_) {}
        }
        if (tglP == null) continue;
        final DateTime tglHari = DateTime(tglP.year, tglP.month, tglP.day);
        if (!tglHari.isBefore(startDay) && !tglHari.isAfter(endDay)) {
          hitungPengeluaran += (data['nominal'] ?? 0).toDouble();
        }
      }

      // ── Rata-rata ─────────────────────────────────────────────────────
      final int jumlahHari = endDay.difference(startDay).inDays + 1;
      final int jumlahBulan =
          ((end.year - start.year) * 12 + (end.month - start.month)) + 1;
      final double rataH = jumlahHari > 0 ? hitungOmzet / jumlahHari : 0;
      final double rataB = jumlahBulan > 0
          ? hitungOmzet / jumlahBulan
          : hitungOmzet;

      // PPh 2.5% dari omzet dikurangi piutang
      final double dasarPph = hitungOmzet - hitungPiutang;

      final currency = NumberFormat.currency(
        locale: 'id_ID',
        symbol: 'Rp ',
        decimalDigits: 0,
      );

      if (!mounted) return;
      setState(() {
        startDate = start;
        endDate = end;

        totalOmzet = currency.format(hitungOmzet);
        uangMasuk = currency.format(hitungMasuk);
        piutang = currency.format(hitungPiutang);
        pengeluaran = currency.format(hitungPengeluaran);
        labaRugi = currency.format(hitungMasuk - hitungPengeluaran);
        pemasukanNota = currency.format(hitungMasuk);
        ppn = currency.format(dasarPph * 0.025);
        rataHarian = currency.format(rataH);
        rataBulanan = currency.format(rataB);

        // ── Statistik pelanggan ──
        pelangganAktif = nomorAktif.length.toString();
        pelangganBaru = hitungPelangganBaru.toString();
        repeatCustomer = nomorRepeat.length.toString();
        berpiutang = nomorBerpiutang.length.toString();

        chartDataPerHari = omzetPerHari;
        _dataPiutang = listPiutang;
        _isLoading = false;
      });
    } catch (e, stack) {
      debugPrint('ERROR RingkasanPage: $e\n$stack');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // KIRIM TAGIHAN WA
  // ──────────────────────────────────────────────────────────────────────────
  Future<void> _kirimTagihanWA(Map<String, dynamic> item) async {
    final noHp = (item['no_hp'] as String? ?? '').trim();
    if (noHp.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nomor HP tidak tersedia'),
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
    final total = currency.format(item['total'] ?? 0);
    final dp = (item['dp'] as double? ?? 0) > 0
        ? '\nDP Terbayar : ${currency.format(item['dp'])}'
        : '';
    final waktu = item['waktu'] ?? '-';

    final pesan =
        'Halo $nama,\n\n'
        'Kami dari ${OutletSettings.namaLaundry} ingin menginformasikan '
        'bahwa Anda masih memiliki tagihan yang belum dilunasi.\n\n'
        '📋 *Detail Tagihan*\n'
        'Nama        : $nama\n'
        'No. Order   : $nip\n'
        'Layanan     : $layanan\n'
        'Tanggal     : $waktu\n'
        'Total       : *$total*$dp\n'
        'Sisa Tagihan: *$nominal*\n\n'
        'Mohon segera melakukan pembayaran. Terima kasih 🙏\n\n'
        '_Salam,_\n_${OutletSettings.namaLaundry}_';

    String hp = noHp.replaceAll(RegExp(r'\s+|-'), '');
    if (hp.startsWith('0')) {
      hp = '62${hp.substring(1)}';
    } else if (!hp.startsWith('62'))
      hp = '62$hp';

    final uri = Uri.parse(
      'https://wa.me/$hp?text=${Uri.encodeComponent(pesan)}',
    );
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('WA launch error: $e');
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // DETAIL PIUTANG BOTTOM SHEET
  // ──────────────────────────────────────────────────────────────────────────
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
                          children: const [
                            Icon(
                              Icons.check_circle_outline_rounded,
                              size: 48,
                              color: Color(0xff16A34A),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Tidak ada piutang di periode ini',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        controller: controller,
                        itemCount: _dataPiutang.length,
                        separatorBuilder: (_, _) => Divider(
                          color: Theme.of(context).dividerColor,
                          height: 1,
                        ),
                        itemBuilder: (_, i) {
                          final item = _dataPiutang[i];
                          final noHp = (item['no_hp'] as String? ?? '');
                          final dp = (item['dp'] as double? ?? 0);
                          final total = (item['total'] as double? ?? 0);
                          final sisa = (item['nominal'] as double? ?? 0);

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
                                        item['nama']?.toString().isNotEmpty ==
                                                true
                                            ? item['nama']
                                            : '-',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${item['nip'] ?? '-'}  •  '
                                        '${noHp.isNotEmpty ? noHp : 'No HP tidak ada'}',
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
                                      const SizedBox(height: 6),
                                      // Breakdown harga
                                      if (dp > 0) ...[
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'Total',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(fontSize: 12),
                                            ),
                                            Text(
                                              currency.format(total),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    fontSize: 12,
                                                    decoration: TextDecoration
                                                        .lineThrough,
                                                    color: Colors.grey,
                                                  ),
                                            ),
                                          ],
                                        ),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'DP Terbayar',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    fontSize: 12,
                                                    color: const Color(
                                                      0xffD97706,
                                                    ),
                                                  ),
                                            ),
                                            Text(
                                              currency.format(dp),
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Color(0xffD97706),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text(
                                            'Sisa Tagihan',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                          Text(
                                            currency.format(sisa),
                                            style: const TextStyle(
                                              color: Color(0xffD97706),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      SizedBox(
                                        width: double.infinity,
                                        child: OutlinedButton.icon(
                                          onPressed: () =>
                                              _kirimTagihanWA(item),
                                          icon: Icon(
                                            Icons.send_rounded,
                                            color: noHp.isNotEmpty
                                                ? const Color(0xff25D366)
                                                : Colors.grey,
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

  // ──────────────────────────────────────────────────────────────────────────
  // CHART HELPERS
  // ──────────────────────────────────────────────────────────────────────────
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
    return '${startDate.day} ${bulan[startDate.month - 1]} – '
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

  // ──────────────────────────────────────────────────────────────────────────
  // BUILD
  // ──────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final cardColor = Theme.of(context).cardColor;
    final bodyLarge = Theme.of(context).textTheme.bodyLarge;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(context),
      body: GlobalRefresh(
        onRefresh: () => fetchFirestoreData(startDate, endDate),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: kPrimary))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
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
                          const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 16),

                    // Total Omzet
                    _buildReportCard(
                      cardColor: cardColor,
                      bodyLarge: bodyLarge,
                      icon: Icons.receipt_long_rounded,
                      iconColor: const Color(0xff0284C7),
                      iconBgColor: const Color(0xffE0F2FE),
                      title: 'Total Omzet',
                      subtitle: 'Semua order yang dibuat di periode ini',
                      value: totalOmzet,
                      valueColor: bodyLarge?.color ?? const Color(0xff1E293B),
                    ),

                    // Rata-rata harian & bulanan
                    _buildRataRataRow(
                      cardColor: cardColor,
                      bodyLarge: bodyLarge,
                    ),
                    const SizedBox(height: 12),

                    // Uang Masuk
                    _buildReportCard(
                      cardColor: cardColor,
                      bodyLarge: bodyLarge,
                      icon: Icons.account_balance_wallet_rounded,
                      iconColor: const Color(0xff16A34A),
                      iconBgColor: const Color(0xffDCFCE7),
                      title: 'Uang Masuk',
                      subtitle: 'Uang aktual diterima (lunas + DP)',
                      value: uangMasuk,
                      valueColor: bodyLarge?.color ?? const Color(0xff1E293B),
                    ),

                    // Piutang
                    _buildReportCard(
                      cardColor: cardColor,
                      bodyLarge: bodyLarge,
                      icon: Icons.hourglass_empty_rounded,
                      iconColor: const Color(0xffD97706),
                      iconBgColor: const Color(0xffFEF3C7),
                      title: 'Piutang',
                      subtitle: 'Sisa tagihan yang belum dibayar',
                      value: piutang,
                      valueColor: bodyLarge?.color ?? const Color(0xff1E293B),
                      hasDetail: true,
                      onDetailTap: _showDetailPiutang,
                    ),

                    // Pengeluaran
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
                          builder: (_) => const FormPengeluaranPage(),
                        ),
                      ),
                    ),

                    // Laba / Rugi
                    _buildReportCard(
                      cardColor: cardColor,
                      bodyLarge: bodyLarge,
                      icon: Icons.stars_rounded,
                      iconColor: const Color(0xff15803D),
                      iconBgColor: const Color(0xffE2F0D9),
                      title: 'Laba / Rugi',
                      subtitle: 'Uang masuk dikurangi pengeluaran & piutang',
                      value: labaRugi,
                      valueColor: const Color(0xff16A34A),
                    ),

                    const SizedBox(height: 8),

                    // Detail Uang Masuk
                    _buildDetailSection(
                      cardColor: cardColor,
                      bodyLarge: bodyLarge,
                      title: 'DETAIL UANG MASUK',
                      accentColor: const Color(0xff0284C7),
                      items: [
                        _buildDetailRow(
                          'Pemasukan Order',
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

                    // Detail Pelanggan
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
                        const SizedBox(height: 8),
                        // Keterangan statistik pelanggan
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _keteranganRow(
                                'Aktif',
                                'Punya ≥1 order dalam periode ini',
                              ),
                              _keteranganRow(
                                'Baru',
                                'Terdaftar di collection pelanggan dalam periode ini',
                              ),
                              _keteranganRow(
                                'Repeat',
                                'Punya >1 order dalam periode ini',
                              ),
                              _keteranganRow(
                                'Berpiutang',
                                'Masih punya tagihan belum lunas',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _keteranganRow(String label, String ket) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '• $label: ',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          Expanded(
            child: Text(
              ket,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // WIDGET HELPERS
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildRataRataRow({
    required Color cardColor,
    required TextStyle? bodyLarge,
  }) {
    final primaryColor = Theme.of(context).primaryColor;
    final primaryLight = primaryColor.withOpacity(0.08);

    Widget card(IconData icon, String label, String value, String sub) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: primaryLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: primaryColor.withOpacity(0.18)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: primaryColor, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: primaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style:
                    bodyLarge?.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ) ??
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                sub,
                style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        card(
          Icons.calendar_today_rounded,
          'Rata² Harian',
          rataHarian,
          'per hari dalam periode',
        ),
        const SizedBox(width: 12),
        card(
          Icons.calendar_month_rounded,
          'Rata² Bulanan',
          rataBulanan,
          'per bulan dalam periode',
        ),
      ],
    );
  }

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
              final DateTimeRange? picked =
                  await CalendarHelper.showFullDatePicker(context);
              if (picked != null) fetchFirestoreData(picked.start, picked.end);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimary,
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
            getDrawingHorizontalLine: (v) =>
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
              color: kPrimary,
              barWidth: 3,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: kPrimary.withOpacity(0.08),
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
            'Ringkasan',
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

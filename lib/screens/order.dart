import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:screenshot/screenshot.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'screens.dart';

class OrderScreen extends StatefulWidget {
  const OrderScreen({super.key});

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen>
    with SingleTickerProviderStateMixin {
  final Map<String, bool> _localLunasStatus = {};
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;
  String? _errorMsg;

  late AnimationController _heartController;
  late Animation<double> _heartAnim;

  @override
  void initState() {
    super.initState();
    _heartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    _heartAnim = Tween<double>(begin: 1.0, end: 1.4).animate(
      CurvedAnimation(parent: _heartController, curve: Curves.easeInOut),
    );
    _loadOrders();
  }

  @override
  void dispose() {
    _heartController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders({bool isRefresh = false}) async {
    if (!mounted) return;

    if (!isRefresh) {
      setState(() {
        _isLoading = true;
        _errorMsg = null;
      });
    } else {
      setState(() => _errorMsg = null);
    }

    try {
      final firestore = FirebaseFirestore.instance;

      final rekamSnap = await firestore
          .collection('rekam_medis')
          .orderBy('waktu_kunjungan', descending: true)
          .limit(10)
          .get();

      final List<Map<String, dynamic>> result = [];

      for (final doc in rekamSnap.docs) {
        final rekam = doc.data();
        final String nip = rekam['nomer_induk_pasien']?.toString() ?? "";

        final pasienSnap = await firestore
            .collection('pasien')
            .where('nomer_induk_pasien', isEqualTo: nip)
            .limit(1)
            .get();

        final pasien = pasienSnap.docs.isNotEmpty
            ? pasienSnap.docs.first.data()
            : <String, dynamic>{};

        final keuanganSnap = await firestore
            .collection('keuangan')
            .where('nomer_induk_pasien', isEqualTo: nip)
            .orderBy('waktu_transaksi', descending: true)
            .limit(1)
            .get();

        final keuangan = keuanganSnap.docs.isNotEmpty
            ? keuanganSnap.docs.first.data()
            : <String, dynamic>{};

        final String qrUrl =
            "https://quickchart.io/qr?text=${Uri.encodeComponent(nip)}&size=150";

        result.add({
          'doc_id': doc.id,
          'nip': nip,
          'nama': pasien['nama_lengkap'] ?? "-",
          'jk': pasien['jenis_kelamin'] ?? "-",
          'no_hp': pasien['nomer_hp'] ?? "",
          'tgl_lahir': pasien['tanggal_lahir'] ?? "",
          'layan': rekam['layanan'] ?? "-",
          'keluhan': rekam['diagnosa'] ?? "-",
          'tindakan': rekam['tindakan'] ?? "-",
          'tanggal': rekam['waktu_kunjungan'] ?? "-",
          'tanggal_asli': rekam['waktu_kunjungan'] ?? "-",
          'biaya': keuangan['biaya']?.toString() ?? "0",
          'status_bayar':
              keuangan['status_bayar']?.toString().toLowerCase() ?? "",
          'keuangan_doc_id': keuanganSnap.docs.isNotEmpty
              ? keuanganSnap.docs.first.id
              : "",
          'qr_url': qrUrl,
          'tinggi': rekam['tinggi_badan']?.toString() ?? "-",
          'berat': rekam['berat_badan']?.toString() ?? "-",
          'admin': rekam['admin_pemeriksa']?.toString() ?? "-",
        });
      }

      if (!mounted) return;
      setState(() {
        _orders = result;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Firestore order error: $e");
      await _loadOrdersFallback(isRefresh: isRefresh);
    }
  }

  Future<void> _loadOrdersFallback({bool isRefresh = false}) async {
    try {
      final res = await http
          .get(Uri.parse("$baseAppScriptUrl?action=getRecentOrders"))
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final decoded = _safeJsonDecode(res.body);
        final List<dynamic> raw = decoded?['recentOrders'] ?? [];
        if (!mounted) return;
        setState(() {
          _orders = raw
              .take(10)
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          _isLoading = false;
        });
      } else {
        throw Exception("HTTP ${res.statusCode}");
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        if (_orders.isEmpty) _errorMsg = e.toString();
      });
    }
  }

  Future<void> _updateStatusLunas(
    String docId,
    String nip,
    String tanggalAsli,
  ) async {
    try {
      final firestore = FirebaseFirestore.instance;

      if (docId.isNotEmpty) {
        await firestore.collection('keuangan').doc(docId).update({
          'status_bayar': 'Lunas',
        });
      } else {
        final snap = await firestore
            .collection('keuangan')
            .where('nomer_induk_pasien', isEqualTo: nip)
            .orderBy('waktu_transaksi', descending: true)
            .limit(1)
            .get();
        if (snap.docs.isNotEmpty) {
          await snap.docs.first.reference.update({'status_bayar': 'Lunas'});
        }
      }

      http
          .get(
            Uri.parse(baseAppScriptUrl).replace(
              queryParameters: {
                'action': 'updateStatus',
                'nip': nip,
                'tanggal': tanggalAsli,
              },
            ),
          )
          .catchError((_) {});

      if (!mounted) return;
      setState(() => _localLunasStatus[docId.isNotEmpty ? docId : nip] = true);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("✅ Pembayaran berhasil dicatat sebagai Lunas"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("❌ Gagal update: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _normalizeTglLahir(String raw) {
    if (raw.isEmpty || raw == "-") return "-";
    final regDMY = RegExp(r'^\d{1,2}[\/\-]\d{1,2}[\/\-]\d{4}$');
    if (regDMY.hasMatch(raw)) return raw.replaceAll('/', '-');
    final regISO = RegExp(r'^(\d{4})-(\d{2})-(\d{2})');
    final mISO = regISO.firstMatch(raw);
    if (mISO != null) {
      return "${mISO.group(3)}-${mISO.group(2)}-${mISO.group(1)}";
    }
    try {
      final dt = DateTime.parse(raw);
      return "${dt.day.toString().padLeft(2, '0')}-"
          "${dt.month.toString().padLeft(2, '0')}-${dt.year}";
    } catch (_) {}
    return raw;
  }

  Map<String, dynamic>? _safeJsonDecode(String body) {
    try {
      return Map<String, dynamic>.from(jsonDecode(body) as Map);
    } catch (_) {
      return null;
    }
  }

  Future<void> _kirimKartuKeWA(Map<String, dynamic> patientData) async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("⚠️ Fitur ini hanya tersedia di aplikasi Android"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 12),
            Text("Menyiapkan kartu pasien..."),
          ],
        ),
        duration: Duration(seconds: 10),
        backgroundColor: Colors.teal,
      ),
    );

    try {
      final screenshotController = ScreenshotController();
      final Uint8List imageBytes = await screenshotController
          .captureFromLongWidget(
            _buildPatientCardWidget(patientData),
            pixelRatio: 3.0,
            delay: const Duration(milliseconds: 500),
          );

      final tempDir = await getTemporaryDirectory();
      final String nip = patientData['nip']?.toString() ?? 'mc';
      final String nama = patientData['nama']?.toString() ?? "";
      final filePath = '${tempDir.path}/kartu_pasien_$nip.png';
      await File(filePath).writeAsBytes(imageBytes);

      if (mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();

      final String noHpRaw = patientData['no_hp']?.toString() ?? "";
      final bool adaNomor =
          noHpRaw.isNotEmpty && noHpRaw != "-" && noHpRaw.length >= 8;

      final String caption =
          "🏥 *Kartu Pasien ${OutletSettings.namaKlinik}*\n"
          "Halo $nama, berikut kartu pasien Anda. Harap simpan baik-baik. 🙏";

      if (adaNomor) {
        await Share.shareXFiles(
          [XFile(filePath, mimeType: 'image/png')],
          text: caption,
          subject: "Kartu Pasien ${OutletSettings.namaKlinik}",
        );
      } else {
        await Share.shareXFiles([
          XFile(filePath, mimeType: 'image/png'),
        ], text: "🏥 Kartu Pasien ${OutletSettings.namaKlinik}\n$nama");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("❌ Gagal membuat kartu: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ── Cetak Nota / Print Preview (sama dengan main_screen) ─────────────────
  void _showPrintPreview(Map<String, dynamic> data, bool sudahLunas) {
    final String nama = data['nama']?.toString() ?? "-";
    final String nip = data['nip']?.toString() ?? "-";
    final String gender = data['jk']?.toString() ?? "-";
    final String terakhir = data['tanggal']?.toString() ?? "-";
    final String diagnosa = data['keluhan']?.toString() ?? "-";
    final String tindakan = data['tindakan']?.toString() ?? "-";
    final String berat = data['berat']?.toString() ?? "-";

    final String rawBiaya = data['biaya']?.toString() ?? "0";
    final String cleanBiaya = rawBiaya.replaceAll(RegExp(r'[^0-9]'), '');
    String biayaFormatted = "-";
    if (cleanBiaya.isNotEmpty) {
      try {
        biayaFormatted = NumberFormat.currency(
          locale: 'id_ID',
          symbol: 'Rp ',
          decimalDigits: 0,
        ).format(int.parse(cleanBiaya));
      } catch (_) {
        biayaFormatted = "Rp $rawBiaya";
      }
    }

    final String tanggalCetak = DateFormat(
      'dd-MM-yyyy HH:mm',
    ).format(DateTime.now());
    final String statusBayar = sudahLunas ? "LUNAS" : "BELUM LUNAS";
    final Color statusColor = sudahLunas ? Colors.green : Colors.red;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Center(
                  child: Column(
                    children: [
                      Icon(Icons.local_hospital, color: kPrimary, size: 32),
                      const SizedBox(height: 4),
                      Text(
                        OutletSettings.namaKlinik.isNotEmpty
                            ? OutletSettings.namaKlinik
                            : "Klinik",
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: kPrimary,
                        ),
                      ),
                      Text(
                        "Nota Pembayaran",
                        style: Theme.of(
                          context,
                        ).textTheme.bodyLarge?.copyWith(fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Dicetak: $tanggalCetak",
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const Divider(height: 24),

                // Data pasien
                _printRow(context, "Nama", nama),
                _printRow(context, "NIP", nip),
                _printRow(context, "Gender", gender),
                _printRow(context, "Tanggal Kunjungan", terakhir),
                const Divider(height: 20),

                // Data medis
                _printRow(context, "Diagnosa / Keluhan", diagnosa),
                _printRow(context, "Tindakan", tindakan),
                _printRow(context, "Berat Badan", "$berat kg"),
                const Divider(height: 20),

                // Biaya & status
                _printRow(context, "Biaya", biayaFormatted),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 140,
                        child: Text(
                          "Status Bayar",
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                      ),
                      Text(
                        ": ",
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: statusColor.withOpacity(0.4),
                          ),
                        ),
                        child: Text(
                          statusBayar,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Tombol aksi
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, size: 16),
                        label: const Text("Tutup"),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: kPrimary,
                          side: BorderSide(
                            color: Theme.of(context).dividerColor,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PrintScreen(
                                data: {
                                  'nama': nama,
                                  'nip': nip,
                                  'jk': gender,
                                  'terakhir': terakhir,
                                  'keluhan': diagnosa,
                                  'tindakan': tindakan,
                                  'berat': berat,
                                  'biaya': biayaFormatted,
                                  'tanggalCetak': tanggalCetak,
                                  'status_bayar': statusBayar,
                                },
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.print, size: 16),
                        label: const Text("Cetak"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _printRow(BuildContext context, String label, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            ": ",
            style: TextStyle(
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
          Expanded(
            child: Text(
              val,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(context),
      body: _buildBody(),
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
            "Daftar Pasien Terbaru",
            style:
                Theme.of(context).appBarTheme.titleTextStyle?.copyWith(
                  fontWeight: FontWeight.bold,
                ) ??
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
          ),
          backgroundColor:
              Theme.of(context).appBarTheme.backgroundColor ?? kPrimary,
          elevation: 2,
          centerTitle: true,
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _heartAnim,
              builder: (context, child) =>
                  Transform.scale(scale: _heartAnim.value, child: child),
              child: Icon(Icons.favorite, color: kPrimary, size: 48),
            ),
            const SizedBox(height: 16),
            Text(
              "Memuat data pasien...",
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    if (_errorMsg != null && _orders.isEmpty) {
      return GlobalRefresh(
        onRefresh: () => _loadOrders(isRefresh: true),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.75,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.wifi_off_rounded,
                      size: 48,
                      color: Colors.red.shade300,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      "Koneksi Terputus",
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Gagal menyambungkan ke server.\nPastikan internet Anda aktif.",
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(height: 1.4),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => _loadOrders(isRefresh: true),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text("Coba Lagi"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (_orders.isEmpty) {
      return GlobalRefresh(
        onRefresh: () => _loadOrders(isRefresh: true),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.75,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.assignment_late_outlined,
                    size: 60,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Belum ada data pasien",
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Tarik ke bawah untuk memuat ulang",
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).hintColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return GlobalRefresh(
      onRefresh: () => _loadOrders(isRefresh: true),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(
          top: 20,
          left: 16,
          right: 16,
          bottom: 80,
        ),
        itemCount: _orders.length,
        itemBuilder: (context, index) {
          return _buildPatientCard(_orders[index], index);
        },
      ),
    );
  }

  Widget _buildPatientCard(Map<String, dynamic> data, int index) {
    final Color sideColor = index % 2 == 0
        ? Colors.deepPurpleAccent
        : Colors.teal;

    final String nama = data['nama']?.toString() ?? "-";
    final String jk = data['jk']?.toString() ?? "-";
    final String layan = data['layan']?.toString() ?? "-";
    final String keluhan = data['keluhan']?.toString() ?? "-";
    final String tanggal = data['tanggal']?.toString() ?? "-";
    final String nip = data['nip']?.toString() ?? "";
    String qrUrl = data['qr_url']?.toString() ?? "";
    final String noHp = data['no_hp']?.toString() ?? "";
    final String tanggalAsli = data['tanggal_asli']?.toString() ?? tanggal;
    final String docId = data['keuangan_doc_id']?.toString() ?? "";
    final String statusKey = docId.isNotEmpty ? docId : nip;

    final String rawBiaya = data['biaya']?.toString() ?? "0";
    final String cleanBiaya = rawBiaya.replaceAll(RegExp(r'[^0-9]'), '');
    String biayaFormatted = "-";
    if (cleanBiaya.isNotEmpty) {
      try {
        biayaFormatted = NumberFormat.currency(
          locale: 'id_ID',
          symbol: 'Rp ',
          decimalDigits: 0,
        ).format(int.parse(cleanBiaya));
      } catch (_) {
        biayaFormatted = "Rp $rawBiaya";
      }
    }

    final bool statusDariFirestore =
        (data['status_bayar']?.toString() ?? "").toLowerCase() == "lunas";
    final bool sudahLunas =
        statusDariFirestore || (_localLunasStatus[statusKey] ?? false);

    if (qrUrl.isEmpty && nip.isNotEmpty) {
      qrUrl =
          "https://quickchart.io/qr?text=${Uri.encodeComponent(nip)}&size=150";
    }

    final Map<String, dynamic> patientDataForCard = {
      'nama': nama,
      'nip': nip,
      'jk': jk,
      'tgl_lahir': data['tgl_lahir']?.toString() ?? "",
      'no_hp': noHp,
      'qr_url': qrUrl,
    };

    void shareToWhatsApp() async {
      final String pesan = sudahLunas
          ? "✅ *Konfirmasi Pembayaran Lunas*\n"
                "━━━━━━━━━━━━━━━━━\n"
                "👤 Nama    : $nama\n"
                "⚧  Kelamin : $jk\n"
                "🩺 Layanan : $layan\n"
                "💬 Keluhan : $keluhan\n"
                "📅 Tanggal : $tanggal\n"
                "💰 Biaya   : $biayaFormatted\n"
                "🪪 NIP      : $nip\n"
                "━━━━━━━━━━━━━━━━━\n"
                "Pembayaran Anda telah kami terima. Terima kasih! 🙏"
          : "🏥 *Info Tagihan Pasien*\n"
                "━━━━━━━━━━━━━━━━━\n"
                "👤 Nama    : $nama\n"
                "⚧  Kelamin : $jk\n"
                "🩺 Layanan : $layan\n"
                "💬 Keluhan : $keluhan\n"
                "📅 Tanggal : $tanggal\n"
                "💰 Biaya   : $biayaFormatted\n"
                "🪪 NIP      : $nip\n"
                "━━━━━━━━━━━━━━━━━\n"
                "Mohon segera lakukan pembayaran. Terima kasih 🙏";

      final encoded = Uri.encodeComponent(pesan);
      final Uri waUri = noHp.isNotEmpty
          ? Uri.parse(
              "https://wa.me/62${noHp.replaceFirst(RegExp(r'^0'), '')}?text=$encoded",
            )
          : Uri.parse("https://wa.me/?text=$encoded");

      if (await canLaunchUrl(waUri)) {
        await launchUrl(waUri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("WhatsApp tidak ditemukan")),
          );
        }
      }
    }

    void showKonfirmasiBayar() {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.payment, color: Colors.green),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Konfirmasi Pembayaran",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  softWrap: true,
                ),
              ),
            ],
          ),
          content: RichText(
            text: TextSpan(
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(height: 1.5),
              children: [
                const TextSpan(text: "Tandai pembayaran pasien\n\n"),
                TextSpan(
                  text: nama.toUpperCase(),
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                TextSpan(text: "\n\nsebesar  $biayaFormatted  sudah "),
                const TextSpan(
                  text: "LUNAS",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                    fontSize: 15,
                  ),
                ),
                const TextSpan(text: "?"),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text("Batal", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: const Text(
                "Ya, Lunas",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                Navigator.of(ctx).pop();
                _updateStatusLunas(docId, nip, tanggalAsli);
              },
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Garis sisi kiri
            Container(
              width: 5,
              decoration: BoxDecoration(
                color: sideColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header: nama + badge lunas (TANPA tombol kartu) ──
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      nama.toUpperCase(),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ),
                                  // Badge lunas
                                  if (sudahLunas) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: Colors.grey.shade300,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.check_circle,
                                            size: 11,
                                            color: Colors.grey.shade500,
                                          ),
                                          const SizedBox(width: 3),
                                          Text(
                                            "Lunas",
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color: Colors.grey.shade500,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _buildLabel("Jenis Kelamin"),
                                        _buildValue(jk),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _buildLabel("Layanan"),
                                        _buildValue(layan),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _buildLabel("Keluhan"),
                                        _buildValue(keluhan),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _buildLabel("Biaya"),
                                        _buildValue(biayaFormatted),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        // QR + tanggal
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              tanggal,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 8),
                            Column(
                              children: [
                                Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: sideColor.withOpacity(0.4),
                                      width: 1.5,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(7),
                                    child: qrUrl.isNotEmpty
                                        ? Image.network(
                                            qrUrl,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stack) => Icon(
                                                  Icons.qr_code_2,
                                                  size: 36,
                                                  color: Colors.grey.shade400,
                                                ),
                                          )
                                        : Icon(
                                            Icons.qr_code_2,
                                            size: 36,
                                            color: Colors.grey.shade400,
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  nip,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),
                    const Divider(height: 1, thickness: 1),
                    const SizedBox(height: 12),

                    // ── Tombol 2x2 grid ───────────────────────────────────
                    Column(
                      children: [
                        // Baris 1: Share WA + Bayar
                        Row(
                          children: [
                            // Share ke WA
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: shareToWhatsApp,
                                icon: const Icon(Icons.share, size: 16),
                                label: const Text(
                                  "Share ke WA",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF25D366),
                                  side: const BorderSide(
                                    color: Color(0xFF25D366),
                                    width: 1.5,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Bayar / Lunas
                            Expanded(
                              child: sudahLunas
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.grey.shade300,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.check_circle,
                                            size: 16,
                                            color: Colors.grey.shade500,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            "Lunas",
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.grey.shade500,
                                                  fontSize: 12,
                                                ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : ElevatedButton.icon(
                                      onPressed: showKonfirmasiBayar,
                                      icon: const Icon(Icons.payment, size: 16),
                                      label: const Text(
                                        "Bayar",
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                        elevation: 2,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 10,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                    ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Baris 2: Cetak Kartu + Cetak Nota
                        Row(
                          children: [
                            // Cetak Kartu Pasien
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    _kirimKartuKeWA(patientDataForCard),
                                icon: Icon(
                                  Icons.contact_page_outlined,
                                  size: 16,
                                  color: Colors.teal.shade600,
                                ),
                                label: Text(
                                  "Cetak Kartu",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.teal.shade600,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.teal.shade600,
                                  side: BorderSide(
                                    color: Colors.teal.shade300,
                                    width: 1.5,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Cetak Nota
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    _showPrintPreview(data, sudahLunas),
                                icon: Icon(
                                  Icons.receipt_long_outlined,
                                  size: 16,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                label: Text(
                                  "Cetak Nota",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Theme.of(
                                    context,
                                  ).colorScheme.primary,
                                  side: BorderSide(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary.withOpacity(0.5),
                                    width: 1.5,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
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

  Widget _buildPatientCardWidget(Map<String, dynamic> data) {
    final String nama = data['nama']?.toString() ?? "-";
    final String nip = data['nip']?.toString() ?? "-";
    final String jk = data['jk']?.toString() ?? "-";
    final String tglLahir = _normalizeTglLahir(
      data['tgl_lahir']?.toString() ?? "",
    );
    final String noHp = data['no_hp']?.toString() ?? "-";
    String qrUrl = data['qr_url']?.toString() ?? "";

    if (qrUrl.isEmpty && nip.isNotEmpty && nip != "-") {
      qrUrl =
          "https://quickchart.io/qr?text=${Uri.encodeComponent(nip)}&size=200";
    }

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 380,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0D6E6E), Color(0xFF13A8A8)],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                color: Color(0xFF0A5555),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: OutletSettings.logoPath.isNotEmpty
                          ? Image.file(
                              File(OutletSettings.logoPath),
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const Icon(
                                Icons.local_hospital_rounded,
                                color: Colors.white,
                                size: 26,
                              ),
                            )
                          : const Icon(
                              Icons.local_hospital_rounded,
                              color: Colors.white,
                              size: 26,
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          OutletSettings.namaKlinik.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Row(
                          children: [
                            const Icon(
                              Icons.phone,
                              color: Colors.white70,
                              size: 11,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              OutletSettings.noHpKlinik,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white30),
                    ),
                    child: const Text(
                      "KARTU PASIEN",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nama.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _cardRow(Icons.badge_outlined, "NIP", nip),
                        const SizedBox(height: 10),
                        _cardRow(Icons.wc_rounded, "Jenis Kelamin", jk),
                        const SizedBox(height: 10),
                        _cardRow(Icons.cake_outlined, "Tgl Lahir", tglLahir),
                        const SizedBox(height: 10),
                        _cardRow(
                          Icons.phone_outlined,
                          "No. HP",
                          (noHp.isEmpty || noHp == "-") ? "-" : noHp,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    children: [
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: qrUrl.isNotEmpty
                              ? Image.network(
                                  qrUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => const Icon(
                                    Icons.qr_code_2,
                                    size: 52,
                                    color: Colors.grey,
                                  ),
                                )
                              : const Icon(
                                  Icons.qr_code_2,
                                  size: 52,
                                  color: Colors.grey,
                                ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        nip,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: const BoxDecoration(
                color: Color(0xFF0A5555),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Text(
                "Scan QR untuk melihat riwayat kunjungan • ${OutletSettings.namaKlinik}",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.white54, size: 14),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Colors.teal,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildValue(String text) {
    return Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

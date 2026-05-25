import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import '../scanner_screen.dart';
import 'screens.dart';
import 'notifikasi.dart';
import '../components/global_refresh.dart'; // ← import GlobalRefresh

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  final _biayaController = TextEditingController();
  final _layanController = TextEditingController();
  final _diagnosaController = TextEditingController();
  final _tindakanController = TextEditingController();
  final _beratController = TextEditingController();

  bool _isLoading = false;
  String _jumlahKunjungan = "0";
  String _pasienHariIni = "0";
  String _selectedLayanan = "";
  String _subLayananKIA = "KB 1 Bulan";
  Map<String, dynamic>? _resultData;
  Map<String, dynamic>? _kiaData;
  Map<String, dynamic>? _statsData;

  // _heartController dipakai untuk animasi hati di header (bukan refresh)
  late AnimationController _heartController;
  late Animation<double> _heartAnim;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _heartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    _heartAnim = Tween<double>(begin: 1.0, end: 1.35).animate(
      CurvedAnimation(parent: _heartController, curve: Curves.easeInOut),
    );
    _fetchStats();
  }

  @override
  void dispose() {
    _heartController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    _biayaController.dispose();
    _layanController.dispose();
    _diagnosaController.dispose();
    _tindakanController.dispose();
    _beratController.dispose();
    super.dispose();
  }

  // ─── RESET SEARCH ────────────────────────────────────────────────────────
  void _resetSearch() {
    _searchController.clear();
    setState(() {
      _resultData = null;
      _kiaData = null;
      _statsData = null;
    });
  }

  Future<File?> _loadLocalProfileImage() async {
    if (kIsWeb) return null;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/profile_pic_local.png');
      return await file.exists() ? file : null;
    } catch (e) {
      debugPrint("Gagal memuat gambar profil: $e");
      return null;
    }
  }

  Future<void> _fetchStats() async {
    try {
      final firestore = FirebaseFirestore.instance;
      final now = DateTime.now();

      final String d = now.day.toString().padLeft(2, '0');
      final String m = now.month.toString().padLeft(2, '0');
      final String y = now.year.toString();

      final String targetHariStr = "$d/$m/$y 00:00";
      final String targetBulanStr = "01/$m/$y 00:00";

      final bulanSnap = await firestore
          .collection('rekam_medis')
          .where('waktu_kunjungan', isGreaterThanOrEqualTo: targetBulanStr)
          .count()
          .get();

      final hariSnap = await firestore
          .collection('rekam_medis')
          .where('waktu_kunjungan', isGreaterThanOrEqualTo: targetHariStr)
          .count()
          .get();

      if (!mounted) return;
      setState(() {
        _jumlahKunjungan = (bulanSnap.count ?? 0).toString();
        _pasienHariIni = (hariSnap.count ?? 0).toString();
      });
    } catch (e) {
      debugPrint("Firestore _fetchStats error: $e");
    }
  }

  Future<void> _searchPatient(String nip) async {
    if (nip.isEmpty) return;
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final firestore = FirebaseFirestore.instance;
      final nipUpper = nip.trim().toUpperCase();

      final pasienSnap = await firestore
          .collection('pasien')
          .where('nomer_induk_pasien', isEqualTo: nipUpper)
          .limit(1)
          .get();

      if (pasienSnap.docs.isEmpty) {
        if (!mounted) return;
        setState(() {
          _resultData = null;
          _kiaData = null;
          _statsData = null;
        });
        return;
      }

      final pasienDoc = pasienSnap.docs.first.data();

      final rekamSnap = await firestore
          .collection('rekam_medis')
          .where('nomer_induk_pasien', isEqualTo: nipUpper)
          .orderBy('waktu_kunjungan', descending: true)
          .limit(1)
          .get();

      final totalKunjunganSnap = await firestore
          .collection('rekam_medis')
          .where('nomer_induk_pasien', isEqualTo: nipUpper)
          .count()
          .get();

      final now = DateTime.now();
      final String d = now.day.toString().padLeft(2, '0');
      final String m = now.month.toString().padLeft(2, '0');
      final String y = now.year.toString();

      final bulanSnap = await firestore
          .collection('rekam_medis')
          .where('waktu_kunjungan', isGreaterThanOrEqualTo: "01/$m/$y 00:00")
          .count()
          .get();

      final hariSnap = await firestore
          .collection('rekam_medis')
          .where('waktu_kunjungan', isGreaterThanOrEqualTo: "$d/$m/$y 00:00")
          .count()
          .get();

      final rekamDoc = rekamSnap.docs.isNotEmpty
          ? rekamSnap.docs.first.data()
          : <String, dynamic>{};

      final String terakhir = rekamDoc['waktu_kunjungan']?.toString() ?? "-";
      final String layanan = rekamDoc['layanan']?.toString() ?? "";

      if (!mounted) return;
      setState(() {
        _jumlahKunjungan = (bulanSnap.count ?? 0).toString();
        _pasienHariIni = (hariSnap.count ?? 0).toString();

        _statsData = {
          'total_kunjungan_pasien': totalKunjunganSnap.count ?? 0,
          'pasien_hari_ini': hariSnap.count ?? 0,
          'total_pasien_bulan_ini': bulanSnap.count ?? 0,
        };

        _resultData = {
          'nip': pasienDoc['nomer_induk_pasien'] ?? nipUpper,
          'nama': pasienDoc['nama_lengkap'] ?? "-",
          'jk': pasienDoc['jenis_kelamin'] ?? "-",
          'tempat_lahir': pasienDoc['tempat_lahir'] ?? "-",
          'tgl_lahir': _normalizeTglLahir(
            pasienDoc['tanggal_lahir']?.toString() ?? "",
          ),
          'hp': pasienDoc['nomer_hp'] ?? "-",
          'tinggi': rekamDoc['tinggi_badan']?.toString() ?? "-",
          'berat': rekamDoc['berat_badan']?.toString() ?? "-",
          'keluhan': rekamDoc['diagnosa'] ?? "-",
          'tindakan': rekamDoc['tindakan'] ?? "-",
          'layan': layanan,
          'terakhir': terakhir,
        };

        _diagnosaController.text = _resultData!['keluhan'] ?? "";
        _tindakanController.text = _resultData!['tindakan'] ?? "";
        _beratController.text = _resultData!['berat'] ?? "";
        _biayaController.clear();

        _selectedLayanan = layanan.toUpperCase().contains("KIA")
            ? "KIA"
            : "Umum";
        if (_selectedLayanan == "KIA") _subLayananKIA = "KB 1 Bulan";

        _kiaData = (_selectedLayanan == "KIA")
            ? {'tgl_kembali': rekamDoc['tgl_kembali'] ?? ""}
            : null;
      });
    } catch (e) {
      debugPrint("Error search Firestore: $e");
      await _searchPatientFallback(nip);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _searchPatientFallback(String nip) async {
    try {
      final res = await http
          .get(Uri.parse('$baseAppScriptUrl?action=search&nip=$nip'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = _safeJsonDecode(res.body);
        if (!mounted) return;
        setState(() {
          final infoUtama = data?['visitData'] ?? data;
          _kiaData = data?['kiaData'];
          if (infoUtama?['nip'] != null) {
            _resultData = Map<String, dynamic>.from(infoUtama);
            _resultData!['tgl_lahir'] = _normalizeTglLahir(
              _resultData!['tgl_lahir']?.toString() ?? "",
            );
            _diagnosaController.text = _resultData!['keluhan'] ?? "";
            _tindakanController.text = _resultData!['tindakan'] ?? "";
            _beratController.text = _resultData!['berat'] ?? "";
            _biayaController.clear();
            final layan = (_resultData!['layan'] ?? "")
                .toString()
                .toUpperCase();
            _selectedLayanan = layan.contains("KIA") ? "KIA" : "Umum";
            if (_selectedLayanan == "KIA") _subLayananKIA = "KB 1 Bulan";

            _statsData = {
              'total_kunjungan_pasien':
                  data?['stats']?['total_kunjungan_pasien'] ?? 0,
              'pasien_hari_ini': int.tryParse(_pasienHariIni) ?? 0,
              'total_pasien_bulan_ini': int.tryParse(_jumlahKunjungan) ?? 0,
            };
          } else {
            _resultData = null;
            _kiaData = null;
            _statsData = null;
          }
        });
      }
    } catch (e) {
      debugPrint("Fallback search error: $e");
    }
  }

  Future<void> _saveNewVisit() async {
    if (!_validateBiaya()) return;
    if (_resultData == null) return;
    setState(() => _isLoading = true);

    String tglKembali = "";
    if (_selectedLayanan == "KIA") {
      final now = DateTime.now();
      int bulan = _subLayananKIA == "KB 2 Bulan"
          ? 2
          : _subLayananKIA == "KB 3 Bulan"
          ? 3
          : 1;
      final finalDate = DateTime(
        now.year,
        now.month + bulan,
        now.day,
      ).subtract(const Duration(days: 3));
      tglKembali = DateFormat('dd-MM-yyyy').format(finalDate);
    }

    final String nip = _resultData!['nip']?.toString() ?? "";
    final String nama = _resultData!['nama']?.toString() ?? "";
    final String jk = _resultData!['jk']?.toString() ?? "";
    final String tempat = _resultData!['tempat_lahir']?.toString() ?? "";
    final String tgl = _resultData!['tgl_lahir']?.toString() ?? "";
    final String tinggi = _resultData!['tinggi']?.toString() ?? "";
    final String hp = _resultData!['hp']?.toString() ?? "";
    final String adminFinal =
        FirebaseAuth.instance.currentUser?.displayName ?? 'Admin';
    final String waktuStr = DateFormat(
      'dd/MM/yyyy HH:mm',
    ).format(DateTime.now());
    final String biayaRaw = _biayaController.text.replaceAll('.', '').trim();

    // Simpan snapshot data sebelum direset
    final savedResultData = Map<String, dynamic>.from(_resultData!);
    final savedSubLayananKIA = _subLayananKIA;
    final savedStatsData = _statsData != null
        ? Map<String, dynamic>.from(_statsData!)
        : null;
    final savedKiaData = _kiaData != null
        ? Map<String, dynamic>.from(_kiaData!)
        : null;
    final savedDiagnosa = _diagnosaController.text;
    final savedTindakan = _tindakanController.text;
    final savedBerat = _beratController.text;
    final savedBiaya = _biayaController.text;

    try {
      final firestore = FirebaseFirestore.instance;

      await firestore.collection('rekam_medis').add({
        'nomer_induk_pasien': nip,
        'layanan': _selectedLayanan,
        'diagnosa': _diagnosaController.text,
        'tindakan': _tindakanController.text,
        'berat_badan': double.tryParse(_beratController.text) ?? 0.0,
        'tinggi_badan': double.tryParse(tinggi) ?? 0.0,
        'admin_pemeriksa': adminFinal,
        'waktu_kunjungan': waktuStr,
        'tgl_kembali': tglKembali,
      });

      await firestore.collection('keuangan').add({
        'nomer_induk_pasien': nip,
        'biaya': int.tryParse(biayaRaw) ?? 0,
        'status_bayar': 'Belum Lunas',
        'waktu_transaksi': waktuStr,
        'is_pasien_baru': false,
      });

      http
          .post(
            Uri.parse(baseAppScriptUrl),
            body: {
              "action": "appendNewVisit",
              "nip": nip,
              "nama": nama,
              "jk": jk,
              "layan": _selectedLayanan,
              "tmp_lahir": tempat,
              "tgl_lahir": tgl,
              "tinggi": tinggi,
              "berat": _beratController.text,
              "keluhan": _diagnosaController.text,
              "tindakan": _tindakanController.text,
              "biaya": biayaRaw,
              "hp": hp,
              "admin": adminFinal,
              "tgl_kembali": tglKembali,
            },
          )
          .catchError((_) {});

      await _fetchStats();

      if (mounted) {
        // Tampilkan popup sukses dengan data yang sudah disimpan
        _showSuccessPopup(
          savedResultData: savedResultData,
          savedSubLayananKIA: savedSubLayananKIA,
          savedStatsData: savedStatsData,
          savedKiaData: savedKiaData,
          savedDiagnosa: savedDiagnosa,
          savedTindakan: savedTindakan,
          savedBerat: savedBerat,
          savedBiaya: savedBiaya,
          tglKembali: tglKembali,
        );
      }
    } catch (e) {
      if (mounted) {
        _showModernToast(
          message: "Gagal menyimpan: $e",
          icon: Icons.error_outline_rounded,
          color: Colors.red,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── POPUP SUKSES SETELAH SIMPAN ─────────────────────────────────────────
  void _showSuccessPopup({
    required Map<String, dynamic> savedResultData,
    required String savedSubLayananKIA,
    required Map<String, dynamic>? savedStatsData,
    required Map<String, dynamic>? savedKiaData,
    required String savedDiagnosa,
    required String savedTindakan,
    required String savedBerat,
    required String savedBiaya,
    required String tglKembali,
  }) {
    final tanggalCetak = DateFormat('dd-MM-yyyy HH:mm').format(DateTime.now());
    final visitKe =
        ((savedStatsData?['total_kunjungan_pasien'] ?? 0) as int) + 1;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Ikon sukses ──────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: kPrimary.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_outline_rounded,
                    color: Color(0xFF0D9488),
                    size: 40,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  "Kunjungan Tersimpan!",
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: kPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Data berhasil dicatat. Pilih tindakan selanjutnya:",
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontSize: 13),
                ),
                const SizedBox(height: 24),

                // ── Tombol Share WA ──────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _resetSearch();
                      ButtonBawah.showWhatsAppOptions(
                        context,
                        savedResultData,
                        savedSubLayananKIA,
                      );
                    },
                    icon: const Icon(Icons.send, size: 18),
                    label: const Text("Share via WhatsApp"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // ── Tombol Cetak ─────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      // Buka print preview dengan data snapshot yang sudah disimpan
                      _showPrintPreviewFromData(
                        resultData: savedResultData,
                        statsData: savedStatsData,
                        kiaData: savedKiaData,
                        diagnosa: savedDiagnosa,
                        tindakan: savedTindakan,
                        berat: savedBerat,
                        biaya: savedBiaya,
                        tanggalCetak: tanggalCetak,
                        visitKe: visitKe.toString(),
                        onDone: _resetSearch,
                      );
                    },
                    icon: Icon(
                      Icons.print,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    label: Text(
                      "Cetak Rekam Medis",
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // ── Tombol Close ─────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _resetSearch();
                    },
                    icon: const Icon(Icons.close, size: 16, color: Colors.grey),
                    label: const Text(
                      "Tutup",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _updateHP(String newHP) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final nip = _resultData!['nip']?.toString() ?? "";
      final snap = await firestore
          .collection('pasien')
          .where('nomer_induk_pasien', isEqualTo: nip)
          .get();
      for (final doc in snap.docs) {
        await doc.reference.update({'nomer_hp': newHP});
      }
      http
          .post(
            Uri.parse(baseAppScriptUrl),
            body: {"action": "updatePhoneNumber", "nip": nip, "hp": newHP},
          )
          .catchError((_) {});
      if (!mounted) return;
      setState(() => _resultData!['hp'] = newHP);
      _showModernToast(
        message: "Nomor HP berhasil diperbarui",
        icon: Icons.phone_android_rounded,
        color: kPrimary,
      );
    } catch (e) {
      debugPrint("Error update HP: $e");
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
      return Map<String, dynamic>.from(
        body.isNotEmpty ? (jsonDecode(body) as Map) : {},
      );
    } catch (_) {
      return null;
    }
  }

  bool _validateBiaya() {
    if (_biayaController.text.trim().isEmpty) {
      _showModernToast(
        message: "Kolom biaya wajib diisi sebelum melanjutkan",
        icon: Icons.warning_amber_rounded,
        color: Colors.orange,
      );
      return false;
    }
    return true;
  }

  void _showModernToast({
    required String message,
    required IconData icon,
    required Color color,
  }) {
    if (!mounted) return;
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (context) => Positioned(
        bottom: 32,
        left: 24,
        right: 24,
        child: Material(
          color: Colors.transparent,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutBack,
            builder: (context, val, child) =>
                Transform.scale(scale: val, child: child),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color.withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      message,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
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
    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 3), () => entry.remove());
  }

  // ─── BUILD ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.dark,
              statusBarBrightness: Brightness.light,
            ),
      child: PopScope(
        canPop: false,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── FIXED: Hanya Header (sapaan + lonceng + avatar) ────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 25),
                      _buildHeader(user),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),

                // ── SCROLLABLE: Stats + Search + Konten, dengan GlobalRefresh ─
                Expanded(
                  child: GlobalRefresh(
                    onRefresh: () async {
                      await _fetchStats();
                      if (_searchController.text.isNotEmpty) {
                        await _searchPatient(_searchController.text);
                      }
                    },
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 25),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 27),

                          // Stats card ikut scroll
                          _buildStatsRow(),
                          const SizedBox(height: 35),

                          Text(
                            "Layanan Utama",
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                          const SizedBox(height: 15),
                          _buildSearchBar(),

                          // ── Area bawah search ────────────────────────────
                          if (_isLoading)
                            const Padding(
                              padding: EdgeInsets.all(20.0),
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFF0D9488),
                                ),
                              ),
                            )
                          else if (_resultData != null) ...[
                            const SizedBox(height: 20),
                            _buildPatientDetailCard(),
                            const SizedBox(height: 30),
                          ] else if (_searchController.text.length >= 6)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(20.0),
                                child: Text(
                                  "Data Pasien Tidak Ditemukan",
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                              ),
                            )
                          else ...[
                            const SizedBox(height: 24),
                            _buildRecentPatientsSection(),
                          ],

                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── WIDGET HELPERS ─────────────────────────────────────────────────────

  Widget _buildRecentPatientsSection() {
    final now = DateTime.now();
    final String d = now.day.toString().padLeft(2, '0');
    final String m = now.month.toString().padLeft(2, '0');
    final String y = now.year.toString();
    final String targetHariStr = "$d/$m/$y 00:00";

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('rekam_medis')
          .where('waktu_kunjungan', isGreaterThanOrEqualTo: targetHariStr)
          .orderBy('waktu_kunjungan', descending: true)
          .limit(10)
          .snapshots(),
      builder: (context, snapshot) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Pasien Hari Ini",
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                if (snapshot.hasData)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: kPrimary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "${snapshot.data!.docs.length} kunjungan",
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: kPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            if (snapshot.connectionState == ConnectionState.waiting)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(color: Color(0xFF0D9488)),
                ),
              )
            else if (snapshot.hasError)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  "Gagal memuat data",
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              )
            else if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 32),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.people_outline_rounded,
                      size: 48,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "Belum ada kunjungan hari ini",
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Cari pasien di atas untuk mulai",
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              )
            else
              ...snapshot.data!.docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final waktu = data['waktu_kunjungan']?.toString() ?? "-";
                String jamStr = "-";
                if (waktu.contains(" ") && waktu.split(" ").length > 1) {
                  jamStr = waktu.split(" ").last;
                }
                final nip = data['nomer_induk_pasien']?.toString() ?? "-";
                final layanan = data['layanan']?.toString() ?? "-";
                final isKIA = layanan.toUpperCase().contains("KIA");
                final diagnosa = data['diagnosa']?.toString() ?? "";

                return GestureDetector(
                  onTap: () {
                    _searchController.text = nip;
                    setState(() {});
                    _searchPatient(nip);
                    FocusScope.of(context).unfocus();
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color:
                                (isKIA ? Colors.pink : const Color(0xFF0D9488))
                                    .withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isKIA
                                ? Icons.favorite_outline_rounded
                                : Icons.local_hospital_outlined,
                            color: isKIA
                                ? Colors.pink
                                : const Color(0xFF0D9488),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                nip,
                                style: Theme.of(context).textTheme.bodyLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          (isKIA
                                                  ? Colors.pink
                                                  : const Color(0xFF0D9488))
                                              .withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      layanan,
                                      style: TextStyle(
                                        color: isKIA
                                            ? Colors.pink
                                            : const Color(0xFF0D9488),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  if (diagnosa.isNotEmpty) ...[
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        diagnosa,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(fontSize: 11),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            jamStr,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
          ],
        );
      },
    );
  }

  Widget _buildHeader(User? user) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // ── Sisi kiri: sapaan & subtitle ──────────────────────────────────
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Halo, ${(user?.displayName ?? 'User').split('|')[0].trim()}!",
                style: TextStyle(
                  fontSize: 24,
                  fontFamily: 'BubbbleGum',
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              Text(
                "Sistem Rekam Medis ${OutletSettings.namaKlinik}",
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontSize: 13,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
            ],
          ),
        ),

        // ── Sisi kanan: icon lonceng + avatar ─────────────────────────────
        Row(
          children: [
            // ── Icon lonceng dengan badge notif ───────────────────────────
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('rekam_medis')
                  .where('tgl_kembali', isNotEqualTo: '')
                  .snapshots(),
              builder: (context, snapshot) {
                int jumlahNotif = 0;
                if (snapshot.hasData) {
                  final now = DateTime.now();
                  final hariIni = DateTime(now.year, now.month, now.day);
                  final batasAwal = hariIni.subtract(const Duration(days: 1));
                  final batasAkhir = hariIni.add(const Duration(days: 3));

                  final Set<String> nipSet = {};
                  for (final doc in snapshot.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    final nip = data['nomer_induk_pasien']?.toString() ?? '';
                    if (nip.isEmpty || nipSet.contains(nip)) continue;

                    final tglStr = data['tgl_kembali']?.toString().trim() ?? '';
                    if (tglStr.isEmpty) continue;

                    DateTime? tgl;
                    try {
                      tgl = DateFormat('dd-MM-yyyy').parse(tglStr);
                    } catch (_) {
                      try {
                        tgl = DateFormat('dd-MMM-yyyy', 'id_ID').parse(tglStr);
                      } catch (_) {
                        continue;
                      }
                    }

                    if (!tgl.isBefore(batasAwal) && !tgl.isAfter(batasAkhir)) {
                      nipSet.add(nip);
                      jumlahNotif++;
                    }
                  }
                }

                return GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const NotifikasiScreen()),
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(13),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          jumlahNotif > 0
                              ? Icons.notifications_rounded
                              : Icons.notifications_none_rounded,
                          color: kPrimary,
                          size: 22,
                        ),
                      ),
                      if (jumlahNotif > 0)
                        Positioned(
                          top: -4,
                          right: -4,
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Theme.of(
                                  context,
                                ).scaffoldBackgroundColor,
                                width: 1.5,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                jumlahNotif > 9 ? '9+' : jumlahNotif.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(width: 10),

            // ── Avatar profil ──────────────────────────────────────────────
            GestureDetector(
              onTap: () => Navigator.pushNamed(
                context,
                '/profile',
              ).then((_) => setState(() {})),
              child: FutureBuilder<File?>(
                future: _loadLocalProfileImage(),
                builder: (context, snapshot) {
                  final localImageFile = snapshot.data;
                  return CircleAvatar(
                    radius: 22,
                    backgroundColor: kPrimary,
                    backgroundImage: localImageFile != null
                        ? FileImage(localImageFile)
                        : null,
                    child: localImageFile == null
                        ? const Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 22,
                          )
                        : null,
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        _buildStatCard("Bulan Ini", _jumlahKunjungan, Icons.show_chart),
        const SizedBox(width: 15),
        _buildStatCard("Hari Ini", _pasienHariIni, Icons.person_add),
      ],
    );
  }

  Widget _buildStatCard(String title, String val, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary, size: 24),
            const SizedBox(height: 10),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontSize: 12),
            ),
            Text(
              val,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: TextField(
        controller: _searchController,
        style: Theme.of(context).textTheme.bodyLarge,
        onChanged: (val) {
          setState(() {});
          if (val.length == 6 && !_isLoading) {
            _searchPatient(val);
            FocusScope.of(context).unfocus();
          }
        },
        onSubmitted: (val) {
          if (!_isLoading && val.isNotEmpty) _searchPatient(val);
        },
        decoration: InputDecoration(
          hintText: "Masukkan NIP (Contoh: MC-001)...",
          hintStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).textTheme.bodySmall?.color,
            fontSize: 14,
          ),
          prefixIcon: Icon(
            Icons.search,
            color: Theme.of(context).colorScheme.primary,
          ),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_searchController.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _resultData = null);
                  },
                ),
              IconButton(
                icon: Icon(
                  Icons.qr_code_scanner,
                  color: Theme.of(context).colorScheme.primary,
                ),
                onPressed: () async {
                  final String? result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const QRScannerScreen(),
                    ),
                  );
                  if (result != null && result.isNotEmpty) {
                    _searchController.text = result;
                    _searchPatient(result);
                  }
                },
              ),
            ],
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 15,
          ),
        ),
      ),
    );
  }

  Widget _buildPatientDetailCard() {
    return Card(
      color: Theme.of(context).cardColor,
      elevation: 4,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _resultData!['nama'] ?? "-",
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    "Visit Ke: ${_statsData?['total_kunjungan_pasien'] ?? '0'}",
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 30, thickness: 1),
            _infoRow(Icons.fingerprint, "NIP", _resultData!['nip']),
            _infoRow(Icons.wc, "Gender", _resultData!['jk']),
            _infoRow(
              Icons.cake_outlined,
              "Tgl Lahir",
              _resultData!['tgl_lahir'],
            ),
            _infoRow(
              Icons.calendar_today,
              "Kunjungan Terakhir",
              _resultData!['terakhir'],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: _infoRow(
                    Icons.phone_android,
                    "No. HP",
                    _resultData!['hp'] ?? "-",
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, size: 20, color: kPrimary),
                  onPressed: _showEditHPDialog,
                ),
              ],
            ),
            _buildKIANotification(),
            const Divider(height: 30),
            Text(
              "Riwayat Pemeriksaan (Edit untuk Kunjungan Baru)",
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            Text(
              "Kategori Layanan",
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: RadioListTile<String>(
                    title: Text(
                      "KIA",
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(fontSize: 14),
                    ),
                    value: "KIA",
                    groupValue: _selectedLayanan,
                    activeColor: kPrimary,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (value) => setState(() {
                      _selectedLayanan = value!;
                      _subLayananKIA = "KB 1 Bulan";
                    }),
                  ),
                ),
                Expanded(
                  child: RadioListTile<String>(
                    title: Text(
                      "Umum",
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(fontSize: 14),
                    ),
                    value: "Umum",
                    groupValue: _selectedLayanan,
                    activeColor: kPrimary,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (value) => setState(() {
                      _selectedLayanan = value!;
                      _subLayananKIA = "";
                    }),
                  ),
                ),
              ],
            ),
            if (_selectedLayanan == "KIA") ...[
              Padding(
                padding: const EdgeInsets.only(top: 4.0, bottom: 6.0),
                child: Text(
                  "Tipe KB (Untuk Estimasi Jadwal Kembali)",
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildSubRadio("KB 1 Bln", "KB 1 Bulan"),
                    _buildSubRadio("KB 2 Bln", "KB 2 Bulan"),
                    _buildSubRadio("KB 3 Bln", "KB 3 Bulan"),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            _buildEditableField(
              Icons.psychology_outlined,
              "Diagnosa",
              _diagnosaController,
            ),
            _buildEditableField(
              Icons.healing_outlined,
              "Tindakan",
              _tindakanController,
            ),
            _buildEditableField(
              Icons.monitor_weight_outlined,
              "Berat Badan (kg)",
              _beratController,
            ),
            _buildEditableField(
              Icons.payments_outlined,
              "Biaya (Rp)",
              _biayaController,
              formatters: [
                FilteringTextInputFormatter.digitsOnly,
                CurrencyInputFormatter(),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _saveNewVisit,
                icon: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save, size: 18),
                label: Text(_isLoading ? "Menyimpan..." : "Simpan Kunjungan"),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      Theme.of(context).appBarTheme.backgroundColor ?? kPrimary,
                  foregroundColor:
                      Theme.of(context).appBarTheme.foregroundColor ??
                      Colors.white,
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 19),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKIANotification() {
    if (_kiaData == null ||
        (_kiaData!['tgl_kembali']?.toString() ?? "").trim().isEmpty) {
      return const SizedBox.shrink();
    }
    try {
      final tglStr = _kiaData!['tgl_kembali'].toString().trim();
      DateTime tglKembali;
      try {
        tglKembali = DateFormat("dd-MM-yyyy").parse(tglStr);
      } catch (_) {
        tglKembali = DateFormat("dd-MMM-yyyy", "id_ID").parse(tglStr);
      }
      final tglTampilan = DateFormat("dd-MMM-yyyy", "id_ID").format(tglKembali);
      final now = DateTime.now();
      final hariIniMurni = DateTime(now.year, now.month, now.day);
      final isOverdue = hariIniMurni.isAfter(tglKembali);
      final isDark = Theme.of(context).brightness == Brightness.dark;

      return Container(
        margin: const EdgeInsets.only(top: 10, left: 4, right: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isOverdue
              ? (isDark ? Colors.red.withOpacity(0.2) : Colors.red[50])
              : (isDark ? Colors.blue.withOpacity(0.2) : Colors.blue[50]),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isOverdue ? Colors.red : Colors.blue,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today,
              color: isOverdue ? Colors.red : Colors.blue,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "STATUS KB:",
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    "Jadwal Kembali: $tglTampilan",
                    style: TextStyle(
                      color: isOverdue
                          ? Colors.red
                          : (isDark ? Colors.blue[300] : Colors.blue[800]),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  if (isOverdue)
                    const Text(
                      "JADWAL TERLEWAT!",
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      return const SizedBox.shrink();
    }
  }

  Widget _buildSubRadio(String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Radio<String>(
          value: value,
          groupValue: _subLayananKIA,
          activeColor: kPrimary,
          onChanged: (val) => setState(() => _subLayananKIA = val!),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 13),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  void _showEditHPDialog() {
    final ctrl = TextEditingController(text: _resultData!['hp']);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text(
          "Edit Nomor HP",
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: kPrimary,
          ),
        ),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.phone,
          style: Theme.of(context).textTheme.bodyLarge,
          decoration: InputDecoration(
            labelText: "Nomor HP Baru",
            filled: true,
            fillColor: Theme.of(context).cardColor,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            onPressed: () {
              _updateHP(ctrl.text);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimary,
              foregroundColor: Colors.white,
            ),
            child: const Text("Update"),
          ),
        ],
      ),
    );
  }

  // ─── PRINT PREVIEW DIPANGGIL LANGSUNG (dari tombol di layar, bukan popup) ─
  // Versi ini masih bisa dipakai jika ada tombol cetak di tempat lain
  void _showPrintPreview() {
    if (_resultData == null) return;
    if (!_validateBiaya()) return;

    final nama = _resultData!['nama'] ?? "-";
    final nip = _resultData!['nip'] ?? "-";
    final gender = _resultData!['jk'] ?? "-";
    final terakhir = _resultData!['terakhir'] ?? "-";
    final diagnosa = _diagnosaController.text.isEmpty
        ? "-"
        : _diagnosaController.text;
    final tindakan = _tindakanController.text.isEmpty
        ? "-"
        : _tindakanController.text;
    final berat = _beratController.text.isEmpty ? "-" : _beratController.text;
    final biaya = _biayaController.text.isEmpty ? "-" : _biayaController.text;
    final visitKe = _statsData?['total_kunjungan_pasien']?.toString() ?? "-";
    final tanggalCetak = DateFormat('dd-MM-yyyy HH:mm').format(DateTime.now());

    _showPrintPreviewFromData(
      resultData: _resultData!,
      statsData: _statsData,
      kiaData: _kiaData,
      diagnosa: diagnosa,
      tindakan: tindakan,
      berat: berat,
      biaya: biaya,
      tanggalCetak: tanggalCetak,
      visitKe: visitKe,
      onDone: null, // tidak reset karena belum simpan
    );
  }

  // ─── PRINT PREVIEW DARI DATA SNAPSHOT (dipanggil dari popup sukses) ──────
  void _showPrintPreviewFromData({
    required Map<String, dynamic> resultData,
    required Map<String, dynamic>? statsData,
    required Map<String, dynamic>? kiaData,
    required String diagnosa,
    required String tindakan,
    required String berat,
    required String biaya,
    required String tanggalCetak,
    required String visitKe,
    required VoidCallback? onDone,
  }) {
    final nama = resultData['nama'] ?? "-";
    final nip = resultData['nip'] ?? "-";
    final gender = resultData['jk'] ?? "-";
    final terakhir = resultData['terakhir'] ?? "-";

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
                        "Rekam Medis",
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
                _printRow("Nama", nama),
                _printRow("NIP", nip),
                _printRow("Gender", gender),
                _printRow("Kunjungan Ke", visitKe),
                _printRow("Kunjungan Terakhir", terakhir),
                const Divider(height: 20),
                _printRow("Diagnosa / Keluhan", diagnosa),
                _printRow("Tindakan", tindakan),
                _printRow("Berat Badan", "$berat kg"),
                _printRow("Biaya", "Rp $biaya"),
                if (kiaData != null &&
                    (kiaData['tgl_kembali']?.toString() ?? "")
                        .trim()
                        .isNotEmpty) ...[
                  const Divider(height: 20),
                  _printRow("Jadwal Kembali KB", kiaData['tgl_kembali']),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          onDone?.call(); // reset search jika dari popup sukses
                        },
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
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        onDone?.call(); // reset search
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PrintScreen(
                              data: {
                                'nama': nama,
                                'nip': nip,
                                'jk': gender,
                                'terakhir': terakhir,
                                'visitKe': visitKe,
                                'keluhan': diagnosa,
                                'tindakan': tindakan,
                                'berat': berat,
                                'biaya': biaya,
                                'tanggalCetak': tanggalCetak,
                                if (kiaData != null)
                                  'tgl_kembali': kiaData['tgl_kembali'],
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
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _printRow(String label, String val) {
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

  Widget _infoRow(IconData icon, String label, dynamic val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "$label: ${val ?? '-'}",
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableField(
    IconData icon,
    String label,
    TextEditingController controller, {
    List<TextInputFormatter>? formatters,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        inputFormatters: formatters,
        textAlignVertical: TextAlignVertical.center,
        style: Theme.of(context).textTheme.bodyLarge,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontSize: 13,
            color: Theme.of(context).textTheme.bodySmall?.color,
          ),
          prefixIcon: Icon(
            icon,
            color: Theme.of(context).colorScheme.primary,
            size: 20,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Theme.of(context).cardColor,
        ),
      ),
    );
  }
}

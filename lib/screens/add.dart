import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

// REKONSILIASI PACKAGES FIREBASE
import 'package:cloud_firestore/cloud_firestore.dart';
import 'screens.dart';

class AddPatientScreen extends StatefulWidget {
  const AddPatientScreen({super.key});

  @override
  State<AddPatientScreen> createState() => _AddPatientScreenState();
}

class _AddPatientScreenState extends State<AddPatientScreen> {
  final _formKey = GlobalKey<FormState>();

  final _namaController = TextEditingController();
  final _tmpLahirController = TextEditingController();
  final _tglLahirController = TextEditingController();
  final _tinggiController = TextEditingController();
  final _beratController = TextEditingController();
  final _diagnosaController = TextEditingController();
  final _tindakanController = TextEditingController();
  final _biayaController = TextEditingController();
  final _hpController = TextEditingController();

  String _selectedJK = "Laki-laki";
  String _selectedLayanan = "Umum";
  bool _isSubmitting = false;

  @override
  void dispose() {
    _namaController.dispose();
    _tmpLahirController.dispose();
    _tglLahirController.dispose();
    _tinggiController.dispose();
    _beratController.dispose();
    _diagnosaController.dispose();
    _tindakanController.dispose();
    _biayaController.dispose();
    _hpController.dispose();
    super.dispose();
  }

  void _clearAllFields() {
    _namaController.clear();
    _tmpLahirController.clear();
    _tglLahirController.clear();
    _tinggiController.clear();
    _beratController.clear();
    _diagnosaController.clear();
    _tindakanController.clear();
    _biayaController.clear();
    _hpController.clear();
    setState(() {
      _selectedJK = "Laki-laki";
      _selectedLayanan = "Umum";
    });
  }

  // ─── Date Picker ─────────────────────────────────────────────
  Future<void> _selectDate(BuildContext context) async {
    FocusScope.of(context).unfocus();
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1945),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? const ColorScheme.dark(
                    primary: kPrimary,
                    onPrimary: Colors.white,
                    onSurface: Colors.white,
                  )
                : const ColorScheme.light(
                    primary: kPrimary,
                    onPrimary: Colors.white,
                    onSurface: kTextDark,
                  ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      setState(() {
        _tglLahirController.text =
            "${picked.day}/${picked.month}/${picked.year}";
      });
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
          "${dt.month.toString().padLeft(2, '0')}-"
          "${dt.year}";
    } catch (_) {}
    return raw;
  }

  // ─── FUNGSI UTAMA: SIMPAN KE FIREBASE + BACKUP TO SHEETS ─────
  Future<void> _submitData() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    try {
      String namaFinal = _namaController.text.trim();
      String jkFinal = _selectedJK;
      String tmpLahirFinal = _tmpLahirController.text.trim();
      String tglLahirFinal = _tglLahirController.text.trim();
      String hpFinal = _hpController.text.trim();
      String layananFinal = _selectedLayanan;
      String diagnosaFinal = _diagnosaController.text.trim();
      String tindakanFinal = _tindakanController.text.trim();
      String adminFinal =
          FirebaseAuth.instance.currentUser?.displayName ?? "Admin";
      String nipBaru = "";

      if (kIsWeb) {
        // ✅ WEB: Apps Script via GET (tidak kena CORS, tidak butuh Firestore)
        final uri = Uri.parse(baseAppScriptUrl).replace(
          queryParameters: {
            'action': 'registerPatient',
            'nama': namaFinal,
            'layan': layananFinal,
            'jk': jkFinal,
            'tmp_lahir': tmpLahirFinal,
            'tgl_lahir': tglLahirFinal,
            'tinggi': _tinggiController.text.trim(),
            'berat': _beratController.text.trim(),
            'diagnosa': diagnosaFinal,
            'tindakan': tindakanFinal,
            'biaya': _biayaController.text.replaceAll('.', '').trim(),
            'hp': hpFinal,
            'admin': adminFinal,
          },
        );

        final response = await http
            .get(uri)
            .timeout(const Duration(seconds: 20));

        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          if (decoded['status'] == 'ok') {
            nipBaru = decoded['nip']?.toString() ?? "MC-???";
          } else {
            throw Exception(decoded['message'] ?? "Gagal simpan ke Sheets");
          }
        } else {
          throw Exception("HTTP ${response.statusCode}");
        }
      } else {
        // ✅ ANDROID/iOS: Firestore + backup Sheets
        final firestore = FirebaseFirestore.instance;

        final pasienSnapshot = await firestore
            .collection('pasien')
            .get()
            .timeout(const Duration(seconds: 15));

        nipBaru =
            "MC-${(pasienSnapshot.docs.length + 1).toString().padLeft(3, '0')}";

        await firestore.collection('pasien').add({
          'nomer_induk_pasien': nipBaru,
          'nama_lengkap': namaFinal,
          'jenis_kelamin': jkFinal,
          'tempat_lahir': tmpLahirFinal,
          'tanggal_lahir': tglLahirFinal,
          'nomer_hp': hpFinal,
          'waktu_daftar': FieldValue.serverTimestamp(),
        });

        await firestore.collection('rekam_medis').add({
          'nomer_induk_pasien': nipBaru,
          'layanan': layananFinal,
          'diagnosa': diagnosaFinal,
          'tindakan': tindakanFinal,
          'berat_badan': double.tryParse(_beratController.text.trim()) ?? 0.0,
          'tinggi_badan': double.tryParse(_tinggiController.text.trim()) ?? 0.0,
          'admin_pemeriksa': adminFinal,
          'waktu_kunjungan': FieldValue.serverTimestamp(),
        });

        await firestore.collection('keuangan').add({
          'nomer_induk_pasien': nipBaru,
          'biaya':
              int.tryParse(_biayaController.text.trim().replaceAll('.', '')) ??
              0,
          'status_bayar': "Belum Lunas",
          'is_pasien_baru': true,
          'waktu_transaksi': FieldValue.serverTimestamp(),
        });

        // Backup Sheets di background
        http
            .get(
              Uri.parse(baseAppScriptUrl).replace(
                queryParameters: {
                  'action': 'registerPatient',
                  'nama': namaFinal,
                  'layan': layananFinal,
                  'jk': jkFinal,
                  'tmp_lahir': tmpLahirFinal,
                  'tgl_lahir': tglLahirFinal,
                  'tinggi': _tinggiController.text.trim(),
                  'berat': _beratController.text.trim(),
                  'diagnosa': diagnosaFinal,
                  'tindakan': tindakanFinal,
                  'biaya': _biayaController.text.replaceAll('.', '').trim(),
                  'hp': hpFinal,
                  'admin': adminFinal,
                },
              ),
            )
            .catchError((_) {});
      }

      if (!context.mounted) return;
      setState(() => _isSubmitting = false);

      _showPatientCardPopup({
        'nama': namaFinal,
        'nip': nipBaru,
        'jk': jkFinal,
        'tgl_lahir': tglLahirFinal,
        'no_hp': hpFinal,
        'qr_url':
            "https://quickchart.io/qr?text=${Uri.encodeComponent(nipBaru)}&size=200",
      });

      _clearAllFields();
    } catch (e) {
      if (mounted) setState(() => _isSubmitting = false);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Gagal menyimpan: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ─── Kartu Pasien Widget (Tema Teal Lama) ────────────────────
  Widget _buildPatientCardWidget(Map<String, dynamic> data) {
    String nama = data['nama']?.toString() ?? "-";
    String nip = data['nip']?.toString() ?? "-";
    String jk = data['jk']?.toString() ?? "-";
    String tglLahir = _normalizeTglLahir(data['tgl_lahir']?.toString() ?? "");
    String noHp = data['no_hp']?.toString() ?? "-";
    String qrUrl = data['qr_url']?.toString() ?? "";

    final String namaKlinikDisplay = OutletSettings.namaKlinik;
    final String noHpKlinikDisplay = OutletSettings.noHpKlinik;

    if (qrUrl.isEmpty && nip.isNotEmpty && nip != "-") {
      qrUrl =
          "https://quickchart.io/qr?text=${Uri.encodeComponent(nip)}&size=200";
    }

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 340,
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
            // ── HEADER ──
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
                          namaKlinikDisplay.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            const Icon(
                              Icons.phone,
                              color: Colors.white70,
                              size: 11,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              noHpKlinikDisplay,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
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

            // ── BODY ──
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
                            height: 1.2,
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
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
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
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── FOOTER ──
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
                "Scan QR untuk melihat riwayat kunjungan • $namaKlinikDisplay",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 10,
                  letterSpacing: 0.3,
                ),
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

  // ─── Share Kartu sebagai Gambar ───────────────────────────────
  Future<void> _sharePatientCardAsImage(
    Map<String, dynamic> patientData,
  ) async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("⚠️ Fitur ini hanya tersedia di aplikasi Android"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (mounted) {
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
              Text("Membuat kartu pasien..."),
            ],
          ),
          duration: Duration(seconds: 8),
          backgroundColor: Colors.teal,
        ),
      );
    }

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
      final filePath = '${tempDir.path}/kartu_pasien_$nip.png';
      final file = File(filePath);
      await file.writeAsBytes(imageBytes);

      if (mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();

      final String noHpRaw = patientData['no_hp']?.toString() ?? "";
      final String nama = patientData['nama']?.toString() ?? "";

      if (noHpRaw.isNotEmpty && noHpRaw != "-") {
        final String pesanKartu =
            "🏥 *Kartu Pasien ${OutletSettings.namaKlinik}*\n"
            "━━━━━━━━━━━━━━━━━\n"
            "👤 Nama : $nama\n"
            "🪪 NIP  : $nip\n"
            "━━━━━━━━━━━━━━━━━\n"
            "Kartu pasien Anda terlampir. Harap simpan baik-baik. 🙏";

        await Share.shareXFiles(
          [XFile(filePath, mimeType: 'image/png')],
          text: pesanKartu,
          subject: "Kartu Pasien ${OutletSettings.namaKlinik}",
        );
      } else {
        await Share.shareXFiles([
          XFile(filePath, mimeType: 'image/png'),
        ], text: '🏥 Kartu Pasien ${OutletSettings.namaKlinik}\n$nama');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "⚠️ Nomor HP pasien tidak tersedia. Kartu dibagikan tanpa WA.",
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
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

  // ─── Popup Kartu Pasien ───────────────────────────────────────
  void _showPatientCardPopup(Map<String, dynamic> patientData) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 40,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildPatientCardWidget(patientData),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    await _sharePatientCardAsImage(patientData);
                  },
                  icon: const Icon(Icons.share, size: 22),
                  label: const Text(
                    "Share Kartu ke WhatsApp",
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 4,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text(
                  "Tutup",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── Build Utama ──────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
          child: AppBar(
            title: Text(
              "Registrasi Pasien",
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
            iconTheme:
                Theme.of(context).appBarTheme.iconTheme ??
                const IconThemeData(color: Colors.white),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // GROUP 1: IDENTITAS
              _buildCardGroup(
                title: "Identitas Pasien",
                children: [
                  _buildTextField(
                    "Nama Lengkap",
                    _namaController,
                    Icons.person_outline,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          "Kota Lahir",
                          _tmpLahirController,
                          Icons.map_outlined,
                          isRequired: false,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: () => _selectDate(context),
                          child: AbsorbPointer(
                            child: _buildTextField(
                              "Tgl Lahir",
                              _tglLahirController,
                              Icons.event,
                              isRequired: false,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  _buildGenderRadio(),
                ],
              ),

              const SizedBox(height: 16),

              // GROUP 2: FISIK & KONTAK
              _buildCardGroup(
                title: "Pemeriksaan Fisik",
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          "Tinggi",
                          _tinggiController,
                          Icons.straighten,
                          suffix: "cm",
                          type: TextInputType.number,
                          formatters: [FilteringTextInputFormatter.digitsOnly],
                          isRequired: false,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          "Berat",
                          _beratController,
                          Icons.monitor_weight_outlined,
                          suffix: "kg",
                          type: TextInputType.number,
                          formatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            DecimalInputFormatter(),
                          ],
                          isRequired: false,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Dropdown layanan
                  _buildLayananDropdown(),
                  const SizedBox(height: 12),
                  _buildTextField(
                    "Nomor WhatsApp",
                    _hpController,
                    Icons.chat_outlined,
                    type: TextInputType.phone,
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // GROUP 3: MEDIS
              _buildCardGroup(
                title: "Diagnosa & Tindakan",
                children: [
                  _buildTextField(
                    "Keluhan Pasien",
                    _diagnosaController,
                    Icons.medical_information_outlined,
                    maxLines: 2,
                    isRequired: false,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    "Tindakan / Obat",
                    _tindakanController,
                    Icons.medication_outlined,
                    maxLines: 2,
                    isRequired: false,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    "Biaya",
                    _biayaController,
                    Icons.payments_outlined,
                    type: TextInputType.number,
                    prefix: "Rp ",
                    formatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      CurrencyInputFormatter(),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 24),
              _buildSubmitButton(),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Widget Helpers ───────────────────────────────────────────

  Widget _buildLayananDropdown() {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return DropdownButtonFormField<String>(
      initialValue: _selectedLayanan,
      decoration: InputDecoration(
        hintText: "Layanan Kesehatan",
        prefixIcon: const Icon(
          Icons.health_and_safety_outlined,
          color: kPrimary,
        ),
        filled: true,
        fillColor: Theme.of(context).cardColor,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 15,
          horizontal: 16,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kPrimary, width: 1.5),
        ),
      ),
      dropdownColor: Theme.of(context).cardColor,
      style: TextStyle(color: isDark ? Colors.white : kTextDark, fontSize: 14),
      items: [
        "Umum",
        "KIA",
        "Gigi",
        "Khitan",
      ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: (v) => setState(() => _selectedLayanan = v ?? "Umum"),
    );
  }

  Widget _buildCardGroup({
    required String title,
    required List<Widget> children,
  }) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: isDark
            ? null
            : Border.all(color: const Color(0xFFE5E7EB), width: 1),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.3)
                : Colors.black.withOpacity(0.08),
            blurRadius: isDark ? 12 : 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: kPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          Divider(height: 24, color: Theme.of(context).dividerColor),
          ...children,
        ],
      ),
    );
  }

  Widget _buildGenderRadio() {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        Text(
          "Jenis Kelamin",
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: kPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        Row(
          children: [
            Expanded(
              child: RadioListTile<String>(
                title: Text(
                  "L",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : kTextDark,
                  ),
                ),
                value: "Laki-laki",
                groupValue: _selectedJK,
                activeColor: kPrimary,
                onChanged: (v) => setState(() => _selectedJK = v.toString()),
              ),
            ),
            Expanded(
              child: RadioListTile<String>(
                title: Text(
                  "P",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : kTextDark,
                  ),
                ),
                value: "Perempuan",
                groupValue: _selectedJK,
                activeColor: kPrimary,
                onChanged: (v) => setState(() => _selectedJK = v.toString()),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    IconData icon, {
    TextInputType type = TextInputType.text,
    int maxLines = 1,
    String? suffix,
    String? prefix,
    Widget? prefixWidget,
    List<TextInputFormatter>? formatters,
    bool isRequired = true,
  }) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return TextFormField(
      controller: controller,
      keyboardType: type,
      maxLines: maxLines,
      inputFormatters: formatters,
      textAlignVertical: TextAlignVertical.center,
      style: TextStyle(color: isDark ? Colors.white : kTextDark, fontSize: 14),
      validator: (value) {
        if (isRequired && (value == null || value.isEmpty)) {
          return "Bagian ini tidak boleh kosong";
        }
        return null;
      },
      decoration: InputDecoration(
        hintText: label,
        hintStyle: TextStyle(
          color: isDark ? Colors.white38 : kTextLight,
          fontSize: 14,
        ),
        prefixIcon: Icon(icon, color: kPrimary),
        prefix: prefixWidget,
        prefixText: prefix,
        prefixStyle: TextStyle(
          color: isDark ? Colors.white : kTextDark,
          fontWeight: FontWeight.w500,
        ),
        suffixText: suffix,
        suffixStyle: TextStyle(
          color: isDark ? Colors.white54 : kTextLight,
          fontWeight: FontWeight.bold,
        ),
        filled: true,
        fillColor: Theme.of(context).cardColor,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 15,
          horizontal: 16,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kPrimary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: kPrimary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          elevation: 2,
        ),
        onPressed: _isSubmitting ? null : _submitData,
        child: _isSubmitting
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text(
                "SIMPAN & CETAK KARTU",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
      ),
    );
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../screens/screens.dart';

class OutletPage extends StatefulWidget {
  const OutletPage({super.key});

  @override
  State<OutletPage> createState() => _OutletPageState();
}

class _OutletPageState extends State<OutletPage> {
  final TextEditingController _namaController = TextEditingController();
  final TextEditingController _alamatController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  String? _localLogoPath;
  Uint8List? _webLogoBytes;
  bool _isSaved = false;

  @override
  void initState() {
    super.initState();
    _namaController.text = OutletSettings.namaKlinik;
    _phoneController.text = OutletSettings.noHpKlinik;
    _alamatController.text = OutletSettings.alamat.isNotEmpty
        ? OutletSettings.alamat
        : "Jl. Raya Puncak Km.78";

    if (!kIsWeb) {
      _localLogoPath = OutletSettings.logoPath.isNotEmpty
          ? OutletSettings.logoPath
          : null;
    }
  }

  @override
  void dispose() {
    _namaController.dispose();
    _alamatController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked == null) return;

    if (kIsWeb) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _webLogoBytes = bytes;
        _isSaved = false;
      });
    } else {
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = 'logo_klinik${p.extension(picked.path)}';
      final savedPath = '${appDir.path}/$fileName';
      await File(picked.path).copy(savedPath);
      setState(() {
        _localLogoPath = savedPath;
        _isSaved = false;
      });
    }
  }

  Widget _buildLogoWidget() {
    if (kIsWeb && _webLogoBytes != null) {
      return Image.memory(_webLogoBytes!, fit: BoxFit.cover);
    }
    if (!kIsWeb && _localLogoPath != null) {
      return Image.file(
        File(_localLogoPath!),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) =>
            Icon(Icons.storefront, size: 60, color: kPrimary),
      );
    }
    return Icon(Icons.storefront, size: 60, color: kPrimary);
  }

  void _simpanPerubahan() {
    final nama = _namaController.text.trim();
    final phone = _phoneController.text.trim();
    final alamat = _alamatController.text.trim();

    if (nama.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("⚠️ Nama klinik tidak boleh kosong"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    OutletSettings.namaKlinik = nama;
    OutletSettings.noHpKlinik = phone;
    OutletSettings.alamat = alamat;

    if (!kIsWeb) {
      OutletSettings.logoPath = _localLogoPath ?? "";
    }

    setState(() => _isSaved = true);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text("Pengaturan outlet berhasil disimpan"),
          ],
        ),
        backgroundColor: kPrimary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      // ✅ Adaptive scaffold background
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: _buildAppBar(context),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ✅ Bagian logo menggunakan cardColor
            Container(
              margin: const EdgeInsets.fromLTRB(
                16,
                16,
                16,
                0,
              ), // ✅ padding kanan kiri atas
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(24), // ✅ sudut round
              ),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Column(
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        padding: const EdgeInsets.all(12), // ✅ padding dalam
                        decoration: BoxDecoration(
                          color: kPrimary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(
                            28,
                          ), // ✅ lebih round
                          border: Border.all(
                            color: kPrimary.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(
                            16,
                          ), // ✅ ikut menyesuaikan
                          child: _buildLogoWidget(),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _pickLogo,
                          child: CircleAvatar(
                            backgroundColor: kPrimary,
                            radius: 18,
                            child: const Icon(
                              Icons.edit,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Logo Klinik",
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.textTheme.bodyLarge?.color?.withOpacity(0.5),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Ketuk ikon pensil untuk ganti logo",
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.textTheme.bodyLarge?.color?.withOpacity(0.4),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle("Informasi Klinik"),
                  _buildCustomTextField(
                    label: "Nama Klinik",
                    controller: _namaController,
                    icon: Icons.store,
                    hint: "Masukkan nama klinik",
                    onChanged: (_) => setState(() => _isSaved = false),
                  ),
                  _buildCustomTextField(
                    label: "Nomor WhatsApp / HP",
                    controller: _phoneController,
                    icon: Icons.phone_android,
                    hint: "0812...",
                    keyboardType: TextInputType.phone,
                    onChanged: (_) => setState(() => _isSaved = false),
                  ),
                  _buildCustomTextField(
                    label: "Alamat Lengkap",
                    controller: _alamatController,
                    icon: Icons.location_on_outlined,
                    hint: "Alamat outlet",
                    maxLines: 3,
                    onChanged: (_) => setState(() => _isSaved = false),
                  ),

                  const SizedBox(height: 8),

                  // ✅ Info box adaptive
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: kPrimary.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: kPrimary.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: kPrimary, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            kIsWeb
                                ? "Di versi web, logo hanya tersimpan selama sesi ini. "
                                      "Untuk penyimpanan permanen, gunakan aplikasi Android."
                                : "Nama klinik, nomor HP, dan logo akan tampil "
                                      "di kartu pasien setelah disimpan.",
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontSize: 12,
                              color: kPrimary,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton.icon(
                      onPressed: _simpanPerubahan,
                      icon: Icon(
                        _isSaved ? Icons.check_circle : Icons.save_rounded,
                        size: 20,
                      ),
                      label: Text(
                        _isSaved ? "TERSIMPAN" : "SIMPAN PERUBAHAN",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isSaved ? Colors.green : kPrimary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    // ✅ AppBar otomatis mengikuti appBarTheme
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        child: AppBar(
          title: Text(
            "Kelola Outlet",
            style:
                Theme.of(context).appBarTheme.titleTextStyle ??
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
          ),
          elevation: 2,
          centerTitle: true,
          leading: Navigator.canPop(context)
              ? IconButton(
                  icon: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color:
                        Theme.of(context).appBarTheme.foregroundColor ??
                        Colors.white,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15, left: 5),
      child: Text(
        title,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: kPrimary,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildCustomTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    String? hint,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    void Function(String)? onChanged,
  }) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          // ✅ Adaptive label text
          style: theme.textTheme.bodyLarge?.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            // ✅ cardColor otomatis gelap di dark mode
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextFormField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: keyboardType,
            onChanged: onChanged,
            // ✅ Adaptive input text style
            style: theme.textTheme.bodyLarge,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: theme.textTheme.bodyLarge?.copyWith(
                color: theme.textTheme.bodyLarge?.color?.withOpacity(0.35),
              ),
              prefixIcon: Icon(
                icon,
                color: kPrimary.withOpacity(0.6),
                size: 20,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: kPrimary, width: 1.5),
              ),
              filled: true,
              // ✅ fillColor = cardColor agar konsisten
              fillColor: theme.cardColor,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 15,
                vertical: 15,
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
      ],
    );
  }
}

import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mdnlaundry_project/screens/screens.dart';

// ════════════════════════════════════════════════════════════════════════════
//  PrinterSettings — in-memory static state
// ════════════════════════════════════════════════════════════════════════════
class PrinterSettings {
  static String pesanKaki = '';
  static bool tampilkanNoHpOutlet = true;
  static bool tampilkanAlamatOutlet = true;
  static bool namaPelangganBesar = false;
  static bool sembunyikanNoHpPelanggan = false;
  // rekening: {nama_bank, no_rekening, atas_nama, qr_url}
  static List<Map<String, String>> rekeningList = [];
}

// ════════════════════════════════════════════════════════════════════════════
//  PrinterSettingsService — Firestore read / write
//  Dokumen: settings/printer
// ════════════════════════════════════════════════════════════════════════════
class PrinterSettingsService {
  static final _doc = FirebaseFirestore.instance
      .collection('settings')
      .doc('printer');

  static Future<void> load() async {
    try {
      final snap = await _doc.get();
      if (!snap.exists) return;
      final d = snap.data()!;
      PrinterSettings.pesanKaki = d['pesan_kaki']?.toString() ?? '';
      PrinterSettings.tampilkanNoHpOutlet = d['tampilkan_no_hp_outlet'] ?? true;
      PrinterSettings.tampilkanAlamatOutlet =
          d['tampilkan_alamat_outlet'] ?? true;
      PrinterSettings.namaPelangganBesar = d['nama_pelanggan_besar'] ?? false;
      PrinterSettings.sembunyikanNoHpPelanggan =
          d['sembunyikan_no_hp_pelanggan'] ?? false;
      final rawRek = d['rekening_list'];
      if (rawRek is List) {
        PrinterSettings.rekeningList = rawRek
            .map(
              (e) => Map<String, String>.from(
                (e as Map).map(
                  (k, v) => MapEntry(k.toString(), v?.toString() ?? ''),
                ),
              ),
            )
            .toList();
      }
    } catch (_) {}
  }

  static Future<void> save({
    required String pesanKaki,
    required bool tampilkanNoHpOutlet,
    required bool tampilkanAlamatOutlet,
    required bool namaPelangganBesar,
    required bool sembunyikanNoHpPelanggan,
    required List<Map<String, String>> rekeningList,
  }) async {
    await _doc.set({
      'pesan_kaki': pesanKaki,
      'tampilkan_no_hp_outlet': tampilkanNoHpOutlet,
      'tampilkan_alamat_outlet': tampilkanAlamatOutlet,
      'nama_pelanggan_besar': namaPelangganBesar,
      'sembunyikan_no_hp_pelanggan': sembunyikanNoHpPelanggan,
      'rekening_list': rekeningList,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Resize gambar ke 300×300 px lalu upload ke Firebase Storage.
  /// Return download URL, atau null jika gagal.
  static Future<String?> uploadQr(dynamic imageFile, String namaBank) async {
    try {
      // 1. Baca bytes dari file
      final Uint8List rawBytes = kIsWeb
          ? await (imageFile as XFile).readAsBytes()
          : await (imageFile as File).readAsBytes();

      // 2. Decode ke ui.Image
      final ui.Codec codec = await ui.instantiateImageCodec(
        rawBytes,
        targetWidth: 300,
        targetHeight: 300,
      );
      final ui.FrameInfo frame = await codec.getNextFrame();
      final ui.Image resized = frame.image;

      // 3. Encode kembali ke PNG (lossless, cocok untuk QR)
      final ByteData? byteData = await resized.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (byteData == null) return null;
      final Uint8List pngBytes = byteData.buffer.asUint8List();

      // 4. Upload ke Storage
      final ref = FirebaseStorage.instance
          .ref()
          .child('qr_rekening')
          .child(
            '${namaBank.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.png',
          );

      final task = ref.putData(
        pngBytes,
        SettableMetadata(contentType: 'image/png'),
      );
      final snap = await task;
      return await snap.ref.getDownloadURL();
    } catch (e) {
      return null;
    }
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  PrinterSettingPage
// ════════════════════════════════════════════════════════════════════════════
class PrinterSettingPage extends StatefulWidget {
  const PrinterSettingPage({super.key});

  @override
  State<PrinterSettingPage> createState() => _PrinterSettingPageState();
}

class _PrinterSettingPageState extends State<PrinterSettingPage> {
  final _pesanKakiController = TextEditingController();

  bool _tampilkanNoHpOutlet = true;
  bool _tampilkanAlamatOutlet = true;
  bool _namaPelangganBesar = false;
  bool _sembunyikanNoHpPelanggan = false;

  List<Map<String, String>> _rekeningList = [];

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isSaved = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await PrinterSettingsService.load();
    if (!mounted) return;
    setState(() {
      _pesanKakiController.text = PrinterSettings.pesanKaki;
      _tampilkanNoHpOutlet = PrinterSettings.tampilkanNoHpOutlet;
      _tampilkanAlamatOutlet = PrinterSettings.tampilkanAlamatOutlet;
      _namaPelangganBesar = PrinterSettings.namaPelangganBesar;
      _sembunyikanNoHpPelanggan = PrinterSettings.sembunyikanNoHpPelanggan;
      _rekeningList = List<Map<String, String>>.from(
        PrinterSettings.rekeningList.map((e) => Map<String, String>.from(e)),
      );
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _pesanKakiController.dispose();
    super.dispose();
  }

  void _markUnsaved() => setState(() => _isSaved = false);

  Future<void> _simpan() async {
    setState(() => _isSaving = true);
    try {
      await PrinterSettingsService.save(
        pesanKaki: _pesanKakiController.text.trim(),
        tampilkanNoHpOutlet: _tampilkanNoHpOutlet,
        tampilkanAlamatOutlet: _tampilkanAlamatOutlet,
        namaPelangganBesar: _namaPelangganBesar,
        sembunyikanNoHpPelanggan: _sembunyikanNoHpPelanggan,
        rekeningList: _rekeningList,
      );
      PrinterSettings.pesanKaki = _pesanKakiController.text.trim();
      PrinterSettings.tampilkanNoHpOutlet = _tampilkanNoHpOutlet;
      PrinterSettings.tampilkanAlamatOutlet = _tampilkanAlamatOutlet;
      PrinterSettings.namaPelangganBesar = _namaPelangganBesar;
      PrinterSettings.sembunyikanNoHpPelanggan = _sembunyikanNoHpPelanggan;
      PrinterSettings.rekeningList = _rekeningList;

      if (!mounted) return;
      setState(() {
        _isSaved = true;
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Pengaturan printer berhasil disimpan'),
            ],
          ),
          backgroundColor: kPrimary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Gagal menyimpan: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ── Dialog tambah / edit rekening (dengan QR upload) ─────────────────────
  Future<void> _showRekeningDialog({int? editIndex}) async {
    final namaBank = TextEditingController(
      text: editIndex != null ? _rekeningList[editIndex]['nama_bank'] : '',
    );
    final noRek = TextEditingController(
      text: editIndex != null ? _rekeningList[editIndex]['no_rekening'] : '',
    );
    final atasNama = TextEditingController(
      text: editIndex != null ? _rekeningList[editIndex]['atas_nama'] : '',
    );
    String qrUrl = editIndex != null
        ? (_rekeningList[editIndex]['qr_url'] ?? '')
        : '';
    dynamic qrFile; // File (mobile) atau XFile (web)
    bool isUploadingQr = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          Future<void> pickQr() async {
            final picker = ImagePicker();
            final picked = await picker.pickImage(
              source: ImageSource.gallery,
              imageQuality: 90,
            );
            if (picked == null) return;
            setS(() {
              qrFile = kIsWeb ? picked : File(picked.path);
              qrUrl = ''; // preview lokal, url nanti di-upload saat simpan
            });
          }

          Widget qrPreview() {
            if (qrFile != null) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: kIsWeb
                    ? FutureBuilder<Uint8List>(
                        future: (qrFile as XFile).readAsBytes(),
                        builder: (_, snap) => snap.hasData
                            ? Image.memory(
                                snap.data!,
                                width: 100,
                                height: 100,
                                fit: BoxFit.contain,
                              )
                            : const SizedBox(width: 100, height: 100),
                      )
                    : Image.file(
                        qrFile as File,
                        width: 100,
                        height: 100,
                        fit: BoxFit.contain,
                      ),
              );
            }
            if (qrUrl.isNotEmpty) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  qrUrl,
                  width: 100,
                  height: 100,
                  fit: BoxFit.contain,
                ),
              );
            }
            return Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: kPrimary.withOpacity(0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: kPrimary.withOpacity(0.2),
                  style: BorderStyle.solid,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.qr_code_2_rounded,
                    color: kPrimary.withOpacity(0.4),
                    size: 30,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Upload QR',
                    style: TextStyle(
                      fontSize: 10,
                      color: kPrimary.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            );
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              editIndex != null ? 'Edit Rekening' : 'Tambah Rekening',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _dialogField(
                    namaBank,
                    'Nama Bank / E-Wallet',
                    Icons.account_balance_outlined,
                  ),
                  const SizedBox(height: 12),
                  _dialogField(
                    noRek,
                    'Nomor Rekening',
                    Icons.credit_card_outlined,
                    type: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  _dialogField(
                    atasNama,
                    'Atas Nama',
                    Icons.person_outline_rounded,
                  ),
                  const SizedBox(height: 16),

                  // ── QR Upload section ─────────────────────────────────────────
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'QR Code Pembayaran',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      qrPreview(),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ukuran ideal: 300×300px\nAkan dicetak di struk 58mm',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: pickQr,
                                icon: Icon(
                                  Icons.upload_rounded,
                                  size: 16,
                                  color: kPrimary,
                                ),
                                label: Text(
                                  qrFile != null || qrUrl.isNotEmpty
                                      ? 'Ganti QR'
                                      : 'Pilih Gambar',
                                  style: TextStyle(
                                    color: kPrimary,
                                    fontSize: 12,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: kPrimary),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                            if (qrFile != null || qrUrl.isNotEmpty)
                              TextButton.icon(
                                onPressed: () => setS(() {
                                  qrFile = null;
                                  qrUrl = '';
                                }),
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 14,
                                  color: Colors.red,
                                ),
                                label: const Text(
                                  'Hapus QR',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 11,
                                  ),
                                ),
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  if (isUploadingQr) ...[
                    const SizedBox(height: 12),
                    const LinearProgressIndicator(),
                    const SizedBox(height: 4),
                    const Text(
                      'Mengupload QR...',
                      style: TextStyle(fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: isUploadingQr
                    ? null
                    : () async {
                        if (noRek.text.trim().isEmpty) return;

                        String finalQrUrl = qrUrl;

                        // Upload QR ke Storage jika ada file baru
                        if (qrFile != null) {
                          setS(() => isUploadingQr = true);
                          final uploaded =
                              await PrinterSettingsService.uploadQr(
                                qrFile,
                                namaBank.text.trim().isNotEmpty
                                    ? namaBank.text.trim()
                                    : 'rekening',
                              );
                          if (uploaded != null) finalQrUrl = uploaded;
                          setS(() => isUploadingQr = false);
                        }

                        final entry = {
                          'nama_bank': namaBank.text.trim(),
                          'no_rekening': noRek.text.trim(),
                          'atas_nama': atasNama.text.trim(),
                          'qr_url': finalQrUrl,
                        };
                        setState(() {
                          if (editIndex != null) {
                            _rekeningList[editIndex] = entry;
                          } else {
                            _rekeningList.add(entry);
                          }
                          _isSaved = false;
                        });
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(editIndex != null ? 'Simpan' : 'Tambah'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _dialogField(
    TextEditingController ctrl,
    String hint,
    IconData icon, {
    TextInputType type = TextInputType.text,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, size: 18, color: kPrimary.withOpacity(0.6)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: kPrimary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: _buildAppBar(context),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Pesan Kaki Struk ──────────────────────────────────────
                  _sectionTitle('Pesan Kaki Struk'),
                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Teks ini tampil di bagian bawah struk',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.textTheme.bodySmall?.color
                                ?.withOpacity(0.6),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _pesanKakiController,
                          maxLines: 3,
                          onChanged: (_) => _markUnsaved(),
                          style: theme.textTheme.bodyLarge,
                          decoration: InputDecoration(
                            hintText:
                                'Contoh: Terima kasih telah mempercayai kami 🙏',
                            hintStyle: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.textTheme.bodyLarge?.color
                                  ?.withOpacity(0.35),
                              fontSize: 13,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: kPrimary,
                                width: 1.5,
                              ),
                            ),
                            filled: true,
                            fillColor: theme.scaffoldBackgroundColor,
                            contentPadding: const EdgeInsets.all(12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Pengaturan Struk ──────────────────────────────────────
                  _sectionTitle('Pengaturan Struk'),
                  _card(
                    child: Column(
                      children: [
                        FutureBuilder<bool>(
                          future: canAccess('can_access_togle_hp'),
                          builder: (context, snapshot) {
                            if (!(snapshot.data ?? false))
                              return const SizedBox.shrink();
                            return _toggleRow(
                              icon: Icons.phone_outlined,
                              title: 'Tampilkan No HP Outlet',
                              subtitle: 'Nomor HP outlet muncul di struk',
                              value: _tampilkanNoHpOutlet,
                              onChanged: (v) => setState(() {
                                _tampilkanNoHpOutlet = v;
                                _isSaved = false;
                              }),
                            );
                          },
                        ),
                        _divider(),
                        FutureBuilder<bool>(
                          future: canAccess('can_access_togle_alamat'),
                          builder: (context, snapshot) {
                            if (!(snapshot.data ?? false))
                              return const SizedBox.shrink();
                            return _toggleRow(
                              icon: Icons.location_on_outlined,
                              title: 'Tampilkan Alamat Outlet',
                              subtitle: 'Alamat outlet muncul di struk',
                              value: _tampilkanAlamatOutlet,
                              onChanged: (v) => setState(() {
                                _tampilkanAlamatOutlet = v;
                                _isSaved = false;
                              }),
                            );
                          },
                        ),
                        _divider(),
                        _toggleRow(
                          icon: Icons.text_fields_rounded,
                          title: 'Nama Pelanggan Besar',
                          subtitle:
                              'Nama pelanggan dicetak huruf kapital semua',
                          value: _namaPelangganBesar,
                          onChanged: (v) => setState(() {
                            _namaPelangganBesar = v;
                            _isSaved = false;
                          }),
                        ),
                        _divider(),
                        _toggleRow(
                          icon: Icons.visibility_off_outlined,
                          title: 'Sembunyikan No HP Pelanggan',
                          subtitle: 'No HP pelanggan tidak tampil di struk',
                          value: _sembunyikanNoHpPelanggan,
                          onChanged: (v) => setState(() {
                            _sembunyikanNoHpPelanggan = v;
                            _isSaved = false;
                          }),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Rekening Pembayaran ───────────────────────────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(child: _sectionTitle('Rekening Pembayaran')),
                      FutureBuilder<bool>(
                        future: canAccess('can_kelola_rekening'),
                        builder: (context, snap) {
                          if (!(snap.data ?? false)) {
                            return const SizedBox.shrink();
                          }
                          return GestureDetector(
                            onTap: () => _showRekeningDialog(),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: kPrimary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.add_rounded,
                                    size: 16,
                                    color: kPrimary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Tambah',
                                    style: TextStyle(
                                      color: kPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_rekeningList.isEmpty)
                    _card(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Column(
                            children: [
                              Icon(
                                Icons.account_balance_outlined,
                                size: 36,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Belum ada rekening',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    _card(
                      child: Column(
                        children: List.generate(_rekeningList.length, (i) {
                          final rek = _rekeningList[i];
                          final hasQr = (rek['qr_url'] ?? '').isNotEmpty;
                          return Column(
                            children: [
                              if (i > 0) _divider(),
                              Row(
                                children: [
                                  // QR thumbnail atau icon bank
                                  GestureDetector(
                                    onTap: hasQr
                                        ? () => _showQrPreview(rek['qr_url']!)
                                        : null,
                                    child: Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: kPrimary.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      child: hasQr
                                          ? Image.network(
                                              rek['qr_url']!,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) =>
                                                  Icon(
                                                    Icons.qr_code_2_rounded,
                                                    color: kPrimary,
                                                    size: 24,
                                                  ),
                                            )
                                          : Icon(
                                              Icons.account_balance_outlined,
                                              color: kPrimary,
                                              size: 22,
                                            ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              rek['nama_bank'] ?? '-',
                                              style: theme.textTheme.bodyLarge
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                  ),
                                            ),
                                            if (hasQr) ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.green
                                                      .withOpacity(0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: const Text(
                                                  'QR ✓',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.green,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        Text(
                                          rek['no_rekening'] ?? '-',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(fontSize: 12),
                                        ),
                                        if ((rek['atas_nama'] ?? '').isNotEmpty)
                                          Text(
                                            'a.n ${rek['atas_nama']}',
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  fontSize: 11,
                                                  color: theme
                                                      .textTheme
                                                      .bodySmall
                                                      ?.color
                                                      ?.withOpacity(0.6),
                                                ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  FutureBuilder<bool>(
                                    future: canAccess('can_kelola_rekening'),
                                    builder: (context, snap) {
                                      if (!(snap.data ?? false)) {
                                        return const SizedBox.shrink();
                                      }
                                      return IconButton(
                                        onPressed: () =>
                                            _showRekeningDialog(editIndex: i),
                                        icon: Icon(
                                          Icons.edit_outlined,
                                          size: 18,
                                          color: kPrimary,
                                        ),
                                        splashRadius: 20,
                                      );
                                    },
                                  ),
                                  FutureBuilder<bool>(
                                    future: canAccess('can_kelola_rekening'),
                                    builder: (context, snap) {
                                      if (!(snap.data ?? false)) {
                                        return const SizedBox.shrink();
                                      }
                                      return IconButton(
                                        onPressed: () => setState(() {
                                          _rekeningList.removeAt(i);
                                          _isSaved = false;
                                        }),
                                        icon: Icon(
                                          Icons.delete_outline,
                                          size: 18,
                                          color: Colors.red.shade400,
                                        ),
                                        splashRadius: 20,
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ],
                          );
                        }),
                      ),
                    ),

                  const SizedBox(height: 28),

                  // ── Tombol Simpan ─────────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _simpan,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isSaved ? Colors.green : kPrimary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: kPrimary.withOpacity(0.6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        elevation: 0,
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _isSaved
                                      ? Icons.check_circle
                                      : Icons.cloud_upload_rounded,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _isSaved
                                      ? 'TERSIMPAN DI CLOUD'
                                      : 'SIMPAN KE CLOUD',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
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

  void _showQrPreview(String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'QR Code',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  url,
                  width: 220,
                  height: 220,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Tutup'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helper widgets ────────────────────────────────────────────────────────
  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(left: 4),
    child: Text(
      title,
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
        color: kPrimary,
        fontWeight: FontWeight.bold,
        fontSize: 14,
      ),
    ),
  );

  Widget _card({required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: child,
  );

  Widget _divider() =>
      Divider(height: 20, thickness: 0.5, color: Colors.grey.withOpacity(0.2));

  Widget _toggleRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: kPrimary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: kPrimary, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
        Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeColor: kPrimary,
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
          title: Text(
            'Pengaturan Printer',
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
}

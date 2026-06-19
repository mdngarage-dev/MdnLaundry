import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mdnlaundry_project/screens/main_screens.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';

// ════════════════════════════════════════════════════════════════════════════
//  PrinterSettings — in-memory static state
// ════════════════════════════════════════════════════════════════════════════
class PrinterSettings {
  static String pesanKaki = '';
  static bool tampilkanNoHpOutlet = true;
  static bool tampilkanAlamatOutlet = true;
  static bool namaPelangganBesar = false;
  static bool sembunyikanNoHpPelanggan = false;
  static bool tampilkanQrStruk = true;
  static int ukuranLabelPelanggan = 1;
  static String customNota = '';
  static int ukuranKertas = 58;
  static List<Map<String, String>> rekeningList = [];
}

// ════════════════════════════════════════════════════════════════════════════
//  PrinterSettingsService — Firestore read / write
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
      PrinterSettings.customNota = d['custom_nota']?.toString() ?? '';
      PrinterSettings.tampilkanNoHpOutlet = d['tampilkan_no_hp_outlet'] ?? true;
      PrinterSettings.tampilkanAlamatOutlet =
          d['tampilkan_alamat_outlet'] ?? true;
      PrinterSettings.namaPelangganBesar = d['nama_pelanggan_besar'] ?? false;
      PrinterSettings.sembunyikanNoHpPelanggan =
          d['sembunyikan_no_hp_pelanggan'] ?? false;
      PrinterSettings.ukuranLabelPelanggan =
          (d['ukuran_label_pelanggan'] as int?) ?? 1;
      PrinterSettings.ukuranKertas = (d['ukuran_kertas'] as int?) ?? 58;
      PrinterSettings.tampilkanQrStruk = d['tampilkan_qr_struk'] ?? true;
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
    required int ukuranLabelPelanggan,
    required int ukuranKertas,
    required bool tampilkanQrStruk,
    required String customNota,
    required List<Map<String, String>> rekeningList,
  }) async {
    await _doc.set({
      'pesan_kaki': pesanKaki,
      'tampilkan_no_hp_outlet': tampilkanNoHpOutlet,
      'tampilkan_alamat_outlet': tampilkanAlamatOutlet,
      'nama_pelanggan_besar': namaPelangganBesar,
      'sembunyikan_no_hp_pelanggan': sembunyikanNoHpPelanggan,
      'ukuran_label_pelanggan': ukuranLabelPelanggan,
      'ukuran_kertas': ukuranKertas,
      'tampilkan_qr_struk': tampilkanQrStruk,
      'custom_nota': customNota,
      'rekening_list': rekeningList,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Resize gambar ke 300×300 px lalu upload ke Firebase Storage.
  static Future<String?> uploadQr(dynamic imageFile, String namaBank) async {
    try {
      final Uint8List rawBytes = kIsWeb
          ? await (imageFile as XFile).readAsBytes()
          : await (imageFile as File).readAsBytes();

      final ui.Codec codec = await ui.instantiateImageCodec(
        rawBytes,
        targetWidth: 300,
        targetHeight: 300,
      );
      final ui.FrameInfo frame = await codec.getNextFrame();
      final ui.Image resized = frame.image;

      final ByteData? byteData = await resized.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (byteData == null) return null;
      final Uint8List pngBytes = byteData.buffer.asUint8List();

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
  bool _tampilkanQrStruk = true;
  int _ukuranLabelPelanggan = 1;
  int _ukuranKertas = 58;
  final _customNotaController = TextEditingController();

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
      _ukuranLabelPelanggan = PrinterSettings.ukuranLabelPelanggan;
      _customNotaController.text = PrinterSettings.customNota;
      _tampilkanQrStruk = PrinterSettings.tampilkanQrStruk;
      _ukuranKertas = PrinterSettings.ukuranKertas;
      _rekeningList = List<Map<String, String>>.from(
        PrinterSettings.rekeningList.map((e) => Map<String, String>.from(e)),
      );
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _pesanKakiController.dispose();
    _customNotaController.dispose();
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
        ukuranLabelPelanggan: _ukuranLabelPelanggan,
        tampilkanQrStruk: _tampilkanQrStruk,
        ukuranKertas: _ukuranKertas,
        customNota: _customNotaController.text.trim(),
        rekeningList: _rekeningList,
      );
      PrinterSettings.pesanKaki = _pesanKakiController.text.trim();
      PrinterSettings.tampilkanNoHpOutlet = _tampilkanNoHpOutlet;
      PrinterSettings.tampilkanAlamatOutlet = _tampilkanAlamatOutlet;
      PrinterSettings.namaPelangganBesar = _namaPelangganBesar;
      PrinterSettings.sembunyikanNoHpPelanggan = _sembunyikanNoHpPelanggan;
      PrinterSettings.ukuranLabelPelanggan = _ukuranLabelPelanggan;
      PrinterSettings.tampilkanQrStruk = _tampilkanQrStruk;
      PrinterSettings.ukuranKertas = _ukuranKertas;
      PrinterSettings.customNota = _customNotaController.text.trim();
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

  Future<String?> _scanQrFromImage(dynamic imageFile) async {
    try {
      final InputImage inputImage;
      if (kIsWeb) {
        return null;
      } else {
        inputImage = InputImage.fromFilePath((imageFile as File).path);
      }

      final barcodeScanner = BarcodeScanner(formats: [BarcodeFormat.qrCode]);
      final barcodes = await barcodeScanner.processImage(inputImage);
      await barcodeScanner.close();

      if (barcodes.isNotEmpty) {
        return barcodes.first.rawValue;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ── Validasi: minimal no_rekening ATAU qr_string/qr_file harus diisi ──────
  bool _isRekeningValid({
    required String noRek,
    required String qrString,
    required dynamic qrFile,
  }) {
    return noRek.trim().isNotEmpty ||
        qrString.trim().isNotEmpty ||
        qrFile != null;
  }

  // ── Dialog TAMBAH rekening (dengan QR section) ────────────────────────────
  Future<void> _showTambahRekeningDialog() async {
    final namaBank = TextEditingController();
    final noRek = TextEditingController();
    final atasNama = TextEditingController();
    final qrStringCtrl = TextEditingController();
    String qrString = '';
    dynamic qrFile;
    bool isUploadingQr = false;
    bool isScanningQr = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          Future<void> pickQr() async {
            final picker = ImagePicker();
            final picked = await picker.pickImage(
              source: ImageSource.gallery,
              imageQuality: 100,
            );
            if (picked == null) return;

            setS(() => isScanningQr = true);

            final file = kIsWeb ? picked : File(picked.path);
            final scanned = await _scanQrFromImage(file);

            if (scanned != null) {
              setS(() {
                qrString = scanned;
                qrStringCtrl.text = scanned;
                qrFile = file;
                isScanningQr = false;
              });
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ QR berhasil dibaca'),
                    backgroundColor: Colors.green,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            } else {
              setS(() {
                qrFile = file;
                qrString = '';
                qrStringCtrl.clear();
                isScanningQr = false;
              });
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('⚠️ QR tidak terbaca, isi manual di bawah'),
                    backgroundColor: Colors.orange,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            }
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
                                width: 110,
                                height: 110,
                                fit: BoxFit.contain,
                              )
                            : const SizedBox(width: 110, height: 110),
                      )
                    : Image.file(
                        qrFile as File,
                        width: 110,
                        height: 110,
                        fit: BoxFit.contain,
                      ),
              );
            }
            return _emptyQrBox();
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Tambah Rekening',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
                    'Nomor Rekening (opsional)',
                    Icons.credit_card_outlined,
                    type: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  _dialogField(
                    atasNama,
                    'Atas Nama',
                    Icons.person_outline_rounded,
                  ),
                  const SizedBox(height: 20),

                  // ── Divider QR ───────────────────────────────────────────
                  Row(
                    children: [
                      Expanded(child: Divider(color: Colors.grey.shade300)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          'QR Code Pembayaran',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: Colors.grey.shade300)),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // ── Info validasi ────────────────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: kPrimary.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Minimal isi Nomor Rekening atau QR Code',
                      style: TextStyle(
                        fontSize: 11,
                        color: kPrimary.withOpacity(0.8),
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── QR Preview ───────────────────────────────────────────
                  Center(child: qrPreview()),
                  const SizedBox(height: 12),
                  Text(
                    'Ukuran ideal: 300×300px • Akan dicetak di struk',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),

                  // ── Tombol Upload & Hapus ────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: pickQr,
                          icon: Icon(
                            Icons.upload_rounded,
                            size: 16,
                            color: kPrimary,
                          ),
                          label: Text(
                            qrFile != null ? 'Ganti QR' : 'Upload QR',
                            style: TextStyle(color: kPrimary, fontSize: 13),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: kPrimary),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      if (qrFile != null) ...[
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () => setS(() {
                            qrFile = null;
                            qrString = '';
                            qrStringCtrl.clear();
                          }),
                          icon: const Icon(
                            Icons.delete_outline,
                            size: 16,
                            color: Colors.red,
                          ),
                          label: const Text(
                            'Hapus',
                            style: TextStyle(color: Colors.red, fontSize: 13),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 14),

                  // ── QR String ────────────────────────────────────────────
                  if (isScanningQr)
                    const Center(child: CircularProgressIndicator())
                  else ...[
                    Text(
                      'String QR QRIS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: qrStringCtrl,
                      maxLines: 3,
                      onChanged: (v) {
                        qrString = v;
                        setS(() {});
                      },
                      decoration: InputDecoration(
                        hintText: 'Otomatis terisi saat scan, atau isi manual',
                        hintStyle: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 12,
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: kPrimary, width: 1.5),
                        ),
                        suffixIcon: qrString.isNotEmpty
                            ? const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                                size: 18,
                              )
                            : Icon(
                                Icons.qr_code_outlined,
                                color: Colors.grey.shade400,
                                size: 18,
                              ),
                      ),
                    ),
                    if (qrString.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.07),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.green.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle_outline,
                              color: Colors.green,
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'QR string siap dicetak ke struk',
                                style: TextStyle(
                                  color: Colors.green.shade700,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],

                  if (isUploadingQr) ...[
                    const SizedBox(height: 14),
                    const LinearProgressIndicator(),
                    const SizedBox(height: 6),
                    Text(
                      'Mengupload QR ke server...',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
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
                        // ── Validasi: minimal salah satu harus diisi ─────
                        final valid = _isRekeningValid(
                          noRek: noRek.text,
                          qrString: qrString,
                          qrFile: qrFile,
                        );
                        if (!valid) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Row(
                                children: [
                                  Icon(
                                    Icons.warning_amber_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Isi minimal Nomor Rekening atau QR Code',
                                    ),
                                  ),
                                ],
                              ),
                              backgroundColor: Colors.orange.shade700,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          );
                          return;
                        }

                        String finalQrUrl = '';

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

                        setState(() {
                          _rekeningList.add({
                            'nama_bank': namaBank.text.trim(),
                            'no_rekening': noRek.text.trim(),
                            'atas_nama': atasNama.text.trim(),
                            'qr_url': finalQrUrl,
                            'qr_string': qrString,
                          });
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
                child: const Text('Tambah'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Dialog EDIT rekening (dengan QR upload) ───────────────────────────────
  Future<void> _showEditRekeningDialog(int editIndex) async {
    final namaBank = TextEditingController(
      text: _rekeningList[editIndex]['nama_bank'],
    );
    final noRek = TextEditingController(
      text: _rekeningList[editIndex]['no_rekening'],
    );
    final atasNama = TextEditingController(
      text: _rekeningList[editIndex]['atas_nama'],
    );
    String qrUrl = _rekeningList[editIndex]['qr_url'] ?? '';
    String qrString = _rekeningList[editIndex]['qr_string'] ?? '';
    final qrStringCtrl = TextEditingController(text: qrString);
    dynamic qrFile;
    bool isUploadingQr = false;
    bool isScanningQr = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          Future<void> pickQr() async {
            final picker = ImagePicker();
            final picked = await picker.pickImage(
              source: ImageSource.gallery,
              imageQuality: 100,
            );
            if (picked == null) return;

            setS(() => isScanningQr = true);

            final file = kIsWeb ? picked : File(picked.path);
            final scanned = await _scanQrFromImage(file);

            if (scanned != null) {
              setS(() {
                qrString = scanned;
                qrStringCtrl.text = scanned;
                qrFile = file;
                qrUrl = '';
                isScanningQr = false;
              });
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ QR berhasil dibaca'),
                    backgroundColor: Colors.green,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            } else {
              setS(() {
                qrFile = file;
                qrString = '';
                qrStringCtrl.clear();
                isScanningQr = false;
              });
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('⚠️ QR tidak terbaca, isi manual di bawah'),
                    backgroundColor: Colors.orange,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            }
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
                                width: 110,
                                height: 110,
                                fit: BoxFit.contain,
                              )
                            : const SizedBox(width: 110, height: 110),
                      )
                    : Image.file(
                        qrFile as File,
                        width: 110,
                        height: 110,
                        fit: BoxFit.contain,
                      ),
              );
            }
            if (qrUrl.isNotEmpty) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  qrUrl,
                  width: 110,
                  height: 110,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => _emptyQrBox(),
                ),
              );
            }
            return _emptyQrBox();
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Edit Rekening & QR',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
                    'Nomor Rekening (opsional)',
                    Icons.credit_card_outlined,
                    type: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  _dialogField(
                    atasNama,
                    'Atas Nama',
                    Icons.person_outline_rounded,
                  ),
                  const SizedBox(height: 20),

                  // ── Divider QR ───────────────────────────────────────────
                  Row(
                    children: [
                      Expanded(child: Divider(color: Colors.grey.shade300)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          'QR Code Pembayaran',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: Colors.grey.shade300)),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // ── QR Preview ───────────────────────────────────────────
                  Center(child: qrPreview()),
                  const SizedBox(height: 12),
                  Text(
                    'Ukuran ideal: 300×300px • Akan dicetak di struk',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),

                  // ── Tombol Upload & Hapus ────────────────────────────────
                  Row(
                    children: [
                      Expanded(
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
                                : 'Upload QR',
                            style: TextStyle(color: kPrimary, fontSize: 13),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: kPrimary),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      if (qrFile != null || qrUrl.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () => setS(() {
                            qrFile = null;
                            qrUrl = '';
                            qrStringCtrl.clear();
                            qrString = '';
                          }),
                          icon: const Icon(
                            Icons.delete_outline,
                            size: 16,
                            color: Colors.red,
                          ),
                          label: const Text(
                            'Hapus',
                            style: TextStyle(color: Colors.red, fontSize: 13),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 14),

                  if (isScanningQr)
                    const Center(child: CircularProgressIndicator())
                  else ...[
                    Text(
                      'String QR QRIS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: qrStringCtrl,
                      maxLines: 3,
                      onChanged: (v) {
                        qrString = v;
                        setS(() {});
                      },
                      decoration: InputDecoration(
                        hintText: 'Otomatis terisi saat scan, atau isi manual',
                        hintStyle: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 12,
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: kPrimary, width: 1.5),
                        ),
                        suffixIcon: qrString.isNotEmpty
                            ? const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                                size: 18,
                              )
                            : Icon(
                                Icons.qr_code_outlined,
                                color: Colors.grey.shade400,
                                size: 18,
                              ),
                      ),
                    ),
                    if (qrString.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.07),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.green.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle_outline,
                              color: Colors.green,
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'QR string siap dicetak ke struk',
                                style: TextStyle(
                                  color: Colors.green.shade700,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],

                  if (isUploadingQr) ...[
                    const SizedBox(height: 14),
                    const LinearProgressIndicator(),
                    const SizedBox(height: 6),
                    Text(
                      'Mengupload QR ke server...',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
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
                        // ── Validasi: minimal salah satu harus diisi ─────
                        final valid = _isRekeningValid(
                          noRek: noRek.text,
                          qrString: qrString,
                          qrFile: qrFile,
                        );
                        // Edit: qrUrl yang sudah ada juga dianggap valid
                        if (!valid && qrUrl.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Row(
                                children: [
                                  Icon(
                                    Icons.warning_amber_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Isi minimal Nomor Rekening atau QR Code',
                                    ),
                                  ),
                                ],
                              ),
                              backgroundColor: Colors.orange.shade700,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          );
                          return;
                        }

                        String finalQrUrl = qrUrl;

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
                          'qr_string': qrString,
                        };
                        setState(() {
                          _rekeningList[editIndex] = entry;
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
                child: const Text('Simpan'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _emptyQrBox() => Container(
    width: 110,
    height: 110,
    decoration: BoxDecoration(
      color: kPrimary.withOpacity(0.06),
      borderRadius: BorderRadius.circular(10),
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
          size: 34,
        ),
        const SizedBox(height: 6),
        Text(
          'Belum ada QR',
          style: TextStyle(fontSize: 11, color: kPrimary.withOpacity(0.5)),
        ),
      ],
    ),
  );

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
                  // ── Ukuran Kertas ─────────────────────────────────────────
                  _sectionTitle('Ukuran Kertas Printer'),
                  const SizedBox(height: 10),
                  _paperSizeSelector(),
                  const SizedBox(height: 20),

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
                        FutureBuilder<bool>(
                          future: canAccess('can_access_nota'),
                          builder: (context, snapshot) {
                            if (!(snapshot.data ?? false))
                              return const SizedBox.shrink();
                            return _toggleRow(
                              icon: Icons.text_fields_rounded,
                              title: 'Nama Pelanggan Besar',
                              subtitle:
                                  'Nama besar & label "Pelanggan:" disembunyikan',
                              value: _namaPelangganBesar,
                              onChanged: (v) => setState(() {
                                _namaPelangganBesar = v;
                                _isSaved = false;
                              }),
                            );
                          },
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
                        _divider(),
                        _toggleRow(
                          icon: Icons.qr_code_rounded,
                          title: 'Tampilkan QR di Struk Customer',
                          subtitle: 'QR nomor order muncul di struk pelanggan',
                          value: _tampilkanQrStruk,
                          onChanged: (v) => setState(() {
                            _tampilkanQrStruk = v;
                            _isSaved = false;
                          }),
                        ),
                        _divider(),
                        Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: kPrimary.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.edit_note_rounded,
                                color: kPrimary,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Custom Nomor Order/Nota',
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    'Sesuaikan kode awal nomor struk',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontSize: 11,
                                      color: theme.textTheme.bodySmall?.color
                                          ?.withOpacity(0.6),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _customNotaController,
                          maxLines: 1,
                          maxLength: 3,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[a-zA-Z0-9]'),
                            ),
                            UpperCaseTextFormatter(),
                          ],
                          onChanged: (_) => _markUnsaved(),
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontSize: 13,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Contoh: MDN',
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
                        _divider(),
                        if (!_namaPelangganBesar)
                          Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: kPrimary.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.format_size_rounded,
                                  color: kPrimary,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Ukuran Label "Pelanggan:"',
                                      style: theme.textTheme.bodyLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                    ),
                                    Text(
                                      'Size teks label di atas nama pelanggan',
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
                              DropdownButton<int>(
                                value: _ukuranLabelPelanggan,
                                underline: const SizedBox(),
                                items: const [
                                  DropdownMenuItem(
                                    value: 1,
                                    child: Text(
                                      'Kecil (1)',
                                      style: TextStyle(fontSize: 13),
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 2,
                                    child: Text(
                                      'Sedang (2)',
                                      style: TextStyle(fontSize: 13),
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 3,
                                    child: Text(
                                      'Besar (3)',
                                      style: TextStyle(fontSize: 13),
                                    ),
                                  ),
                                ],
                                onChanged: (v) => setState(() {
                                  _ukuranLabelPelanggan = v!;
                                  _isSaved = false;
                                }),
                              ),
                            ],
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
                          if (!(snap.data ?? false))
                            return const SizedBox.shrink();
                          return GestureDetector(
                            onTap: _showTambahRekeningDialog,
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
                          final hasQrString =
                              (rek['qr_string'] ?? '').isNotEmpty;
                          return Column(
                            children: [
                              if (i > 0) _divider(),
                              Row(
                                children: [
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
                                            if (hasQrString) ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.blue
                                                      .withOpacity(0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: const Text(
                                                  'String ✓',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.blue,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        if ((rek['no_rekening'] ?? '')
                                            .isNotEmpty)
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
                                      if (!(snap.data ?? false))
                                        return const SizedBox.shrink();
                                      return Tooltip(
                                        message: 'Edit & Upload QR',
                                        child: IconButton(
                                          onPressed: () =>
                                              _showEditRekeningDialog(i),
                                          icon: Icon(
                                            Icons.qr_code_scanner_rounded,
                                            size: 20,
                                            color: kPrimary,
                                          ),
                                          splashRadius: 20,
                                        ),
                                      );
                                    },
                                  ),
                                  FutureBuilder<bool>(
                                    future: canAccess('can_kelola_rekening'),
                                    builder: (context, snap) {
                                      if (!(snap.data ?? false))
                                        return const SizedBox.shrink();
                                      return IconButton(
                                        onPressed: () =>
                                            _showEditRekeningDialog(i),
                                        icon: Icon(
                                          Icons.edit_outlined,
                                          size: 18,
                                          color: Colors.grey.shade600,
                                        ),
                                        splashRadius: 20,
                                      );
                                    },
                                  ),
                                  FutureBuilder<bool>(
                                    future: canAccess('can_kelola_rekening'),
                                    builder: (context, snap) {
                                      if (!(snap.data ?? false))
                                        return const SizedBox.shrink();
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

  // ── Paper Size Selector ───────────────────────────────────────────────────
  Widget _paperSizeSelector() {
    return Row(
      children: [
        Expanded(
          child: _paperCard(
            58,
            Icons.receipt_long_outlined,
            '58 mm',
            'Printer kecil',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _paperCard(
            80,
            Icons.receipt_outlined,
            '80 mm',
            'Printer standar',
          ),
        ),
      ],
    );
  }

  Widget _paperCard(int size, IconData icon, String label, String sub) {
    final bool selected = _ukuranKertas == size;
    return GestureDetector(
      onTap: () => setState(() {
        _ukuranKertas = size;
        _isSaved = false;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? kPrimary : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? kPrimary : Colors.grey.withOpacity(0.2),
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: kPrimary.withOpacity(0.28),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 30,
              color: selected ? Colors.white : kPrimary.withOpacity(0.7),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: selected
                    ? Colors.white
                    : Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              sub,
              style: TextStyle(
                fontSize: 11,
                color: selected
                    ? Colors.white.withOpacity(0.8)
                    : Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? Colors.white : Colors.transparent,
                border: Border.all(
                  color: selected ? Colors.white : Colors.grey.shade400,
                  width: 2,
                ),
              ),
              child: selected
                  ? Icon(Icons.check, size: 12, color: kPrimary)
                  : null,
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
    padding: const EdgeInsets.only(left: 4, bottom: 8),
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

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}

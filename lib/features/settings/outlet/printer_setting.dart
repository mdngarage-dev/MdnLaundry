import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mdnlaundry_project/core/app_exports.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:mdnlaundry_project/features/subscription/payment_page.dart';
import 'package:mdnlaundry_project/services/subscription_service.dart';
import 'package:mdnlaundry_project/features/printer/printer_dialog.dart';

// ════════════════════════════════════════════════════════════════════════════
//  PrinterSettingPage
// ════════════════════════════════════════════════════════════════════════════
class PrinterSettingPage extends StatefulWidget {
  final String storeId;
  final String outletId;
  const PrinterSettingPage({
    super.key,
    required this.storeId,
    required this.outletId,
  });

  @override
  State<PrinterSettingPage> createState() => _PrinterSettingPageState();
}

class _PrinterSettingPageState extends State<PrinterSettingPage> {
  final _pesanKakiController = TextEditingController();
  final _pesanPromoController = TextEditingController();
  final _customNotaController = TextEditingController();
  final _footerPoweredController = TextEditingController();

  bool _tampilkanNoHpOutlet = true;
  bool _tampilkanAlamatOutlet = true;
  bool _namaPelangganBesar = false;
  bool _sembunyikanNoHpPelanggan = false;
  bool _tampilkanQrStruk = true;
  bool _strukGambar = true;
  bool _tampilkanQrWa = true;
  double _strukFontScale = PrinterSettings.defaultStrukFontScale;
  double _strukStripRows = PrinterSettings.defaultStrukStripRows.toDouble();
  double _strukJedaMs = PrinterSettings.defaultStrukJedaMs.toDouble();
  bool _footerPoweredEnabled = true;
  int _ukuranLabelPelanggan = 1;
  int _ukuranKertas = 58;

  List<Map<String, String>> _rekeningList = [];

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isSaved = false;
  bool _hasEditNotaAccess = false;

  // ── Tinggi header section yang menindih card ──────────────────────────────
  static const double _kHeaderOverlap = 18.0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await PrinterSettingsService.load(widget.storeId, widget.outletId);
    final hasAccess = await SubscriptionService.isFeatureEnabled(
      storeId: widget.storeId,
      outletId: widget.outletId,
      feature: 'edit_nota',
    );
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
      _strukGambar = PrinterSettings.strukGambar;
      _tampilkanQrWa = PrinterSettings.tampilkanQrWa;
      _strukFontScale = PrinterSettings.strukFontScale;
      _strukStripRows = PrinterSettings.strukStripRows.toDouble();
      _strukJedaMs = PrinterSettings.strukJedaMs.toDouble();
      _pesanPromoController.text = PrinterSettings.pesanPromo;
      _ukuranKertas = PrinterSettings.ukuranKertas;
      _footerPoweredController.text = PrinterSettings.footerPowered;
      _footerPoweredEnabled = PrinterSettings.footerPoweredEnabled; //
      _hasEditNotaAccess = hasAccess;
      _rekeningList = List<Map<String, String>>.from(
        PrinterSettings.rekeningList.map((e) => Map<String, String>.from(e)),
      );
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _pesanKakiController.dispose();
    _pesanPromoController.dispose();
    _customNotaController.dispose();
    _footerPoweredController.dispose();
    super.dispose();
  }

  void _markUnsaved() => setState(() => _isSaved = false);

  Future<void> _toggleFooterPoweredEnabled(bool value) async {
    if (!_hasEditNotaAccess) {
      _showUpgradeDialog();
      return;
    }
    setState(() {
      _footerPoweredEnabled = value;
      _isSaved = false;
    });
  }

  // ════════════════════════════════════════════════════════════════════════
  //  Simpan
  // ════════════════════════════════════════════════════════════════════════
  Future<void> _simpan() async {
    setState(() => _isSaving = true);
    try {
      await PrinterSettingsService.save(
        storeId: widget.storeId,
        outletId: widget.outletId,
        pesanKaki: _pesanKakiController.text.trim(),
        tampilkanNoHpOutlet: _tampilkanNoHpOutlet,
        tampilkanAlamatOutlet: _tampilkanAlamatOutlet,
        namaPelangganBesar: _namaPelangganBesar,
        sembunyikanNoHpPelanggan: _sembunyikanNoHpPelanggan,
        ukuranLabelPelanggan: _ukuranLabelPelanggan,
        tampilkanQrStruk: _tampilkanQrStruk,
        strukGambar: _strukGambar,
        strukFontScale: _strukFontScale,
        strukStripRows: _strukStripRows.round(),
        strukJedaMs: _strukJedaMs.round(),
        tampilkanQrWa: _tampilkanQrWa,
        pesanPromo: _pesanPromoController.text.trim(),
        ukuranKertas: _ukuranKertas,
        customNota: _customNotaController.text.trim(),
        rekeningList: _rekeningList,
        footerPowered: _hasEditNotaAccess
            ? _footerPoweredController.text.trim()
            : '',
        footerPoweredEnabled: _hasEditNotaAccess
            ? _footerPoweredEnabled
            : true, //
      );
      PrinterSettings.pesanKaki = _pesanKakiController.text.trim();
      PrinterSettings.tampilkanNoHpOutlet = _tampilkanNoHpOutlet;
      PrinterSettings.tampilkanAlamatOutlet = _tampilkanAlamatOutlet;
      PrinterSettings.namaPelangganBesar = _namaPelangganBesar;
      PrinterSettings.sembunyikanNoHpPelanggan = _sembunyikanNoHpPelanggan;
      PrinterSettings.ukuranLabelPelanggan = _ukuranLabelPelanggan;
      PrinterSettings.tampilkanQrStruk = _tampilkanQrStruk;
      PrinterSettings.strukGambar = _strukGambar;
      PrinterSettings.strukFontScale = _strukFontScale;
      PrinterSettings.strukStripRows = _strukStripRows.round();
      PrinterSettings.strukJedaMs = _strukJedaMs.round();
      PrinterSettings.tampilkanQrWa = _tampilkanQrWa;
      PrinterSettings.pesanPromo = _pesanPromoController.text.trim();
      PrinterSettings.ukuranKertas = _ukuranKertas;
      PrinterSettings.customNota = _customNotaController.text.trim();
      PrinterSettings.rekeningList = _rekeningList;
      PrinterSettings.footerPowered = _hasEditNotaAccess
          ? _footerPoweredController.text.trim()
          : '';
      PrinterSettings.footerPoweredEnabled = _hasEditNotaAccess
          ? _footerPoweredEnabled
          : true; //

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

  // ════════════════════════════════════════════════════════════════════════
  //  QR Scanner
  // ════════════════════════════════════════════════════════════════════════
  Future<String?> _scanQrFromImage(dynamic imageFile) async {
    try {
      if (kIsWeb) return null;
      final inputImage = InputImage.fromFilePath((imageFile as File).path);
      final barcodeScanner = BarcodeScanner(formats: [BarcodeFormat.qrCode]);
      final barcodes = await barcodeScanner.processImage(inputImage);
      await barcodeScanner.close();
      return barcodes.isNotEmpty ? barcodes.first.rawValue : null;
    } catch (e) {
      return null;
    }
  }

  bool _isRekeningValid({
    required String noRek,
    required String qrString,
    required dynamic qrFile,
  }) => noRek.trim().isNotEmpty || qrString.trim().isNotEmpty || qrFile != null;

  // ════════════════════════════════════════════════════════════════════════
  //  Dialog TAMBAH rekening
  // ════════════════════════════════════════════════════════════════════════
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
                  Center(child: qrPreview()),
                  const SizedBox(height: 12),
                  Text(
                    'Ukuran ideal: 300×300px • Akan dicetak di struk',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
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
                                widget.storeId,
                                widget.outletId,
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

  // ════════════════════════════════════════════════════════════════════════
  //  Dialog EDIT rekening
  // ════════════════════════════════════════════════════════════════════════
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
                  Center(child: qrPreview()),
                  const SizedBox(height: 12),
                  Text(
                    'Ukuran ideal: 300×300px • Akan dicetak di struk',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
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
                        final valid = _isRekeningValid(
                          noRek: noRek.text,
                          qrString: qrString,
                          qrFile: qrFile,
                        );
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
                                widget.storeId,
                                widget.outletId,
                              );
                          if (uploaded != null) finalQrUrl = uploaded;
                          setS(() => isUploadingQr = false);
                        }
                        setState(() {
                          _rekeningList[editIndex] = {
                            'nama_bank': namaBank.text.trim(),
                            'no_rekening': noRek.text.trim(),
                            'atas_nama': atasNama.text.trim(),
                            'qr_url': finalQrUrl,
                            'qr_string': qrString,
                          };
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

  // ════════════════════════════════════════════════════════════════════════
  //  Upgrade dialog & page
  // ════════════════════════════════════════════════════════════════════════
  void _showUpgradeDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.workspace_premium_rounded,
                color: Colors.orange,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('Fitur Premium', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
        content: const Text(
          'Custom footer struk hanya tersedia untuk paket dengan fitur "Edit Nota". '
          'Upgrade paket outlet Anda untuk mengaktifkan fitur ini.',
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimary,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _goToUpgradePage();
            },
            child: const Text('Upgrade Sekarang'),
          ),
        ],
      ),
    );
  }

  Future<void> _goToUpgradePage() async {
    String outletName = 'Outlet';
    try {
      final outletSnap = await FirebaseFirestore.instance
          .collection('stores')
          .doc(widget.storeId)
          .collection('outlets')
          .doc(widget.outletId)
          .get();
      outletName = outletSnap.data()?['nama_outlet']?.toString() ?? 'Outlet';
    } catch (_) {}
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SubscriptionPaymentPage(
          storeId: widget.storeId,
          outletId: widget.outletId,
          outletName: outletName,
          isUpgradeFlow: true,
          onPaymentSuccess: () {
            if (Navigator.canPop(context)) Navigator.pop(context);
          },
        ),
      ),
    );
    if (mounted) {
      setState(() => _isLoading = true);
      await _loadData();
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════════════════
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
                  // ══ Ukuran Kertas ══════════════════════════════════════════
                  _sectionTitle('Ukuran Kertas Printer'),
                  const SizedBox(height: 10),
                  _paperSizeSelector(),
                  const SizedBox(height: 24),

                  // ══ Pesan Kaki Struk ═══════════════════════════════════════
                  // Header menindih card
                  _cardWithHeader(
                    title: 'Pesan Kaki Struk',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Teks penutup di bagian bawah struk. Kosong = "Terima kasih. Sampai jumpa kembali."',
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
                  const SizedBox(height: 24),

                  // ══ Tampilan Struk Gambar ══════════════════════════════════
                  if (_strukGambar) ...[
                    _cardWithHeader(
                      title: 'Tampilan Struk Gambar',
                      child: _buildStrukGambarSettings(theme),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // ══ Pengaturan Struk ═══════════════════════════════════════
                  _cardWithHeader(
                    title: 'Pengaturan Struk',
                    child: Column(
                      children: [
                        FutureBuilder<bool>(
                          future: canAccess('can_access_togle_hp'),
                          builder: (context, snapshot) {
                            if (!(snapshot.data ?? false))
                              return const SizedBox.shrink();
                            return Column(
                              children: [
                                _toggleRow(
                                  icon: Icons.phone_outlined,
                                  title: 'Tampilkan No HP Outlet',
                                  subtitle: 'Nomor HP outlet muncul di struk',
                                  value: _tampilkanNoHpOutlet,
                                  onChanged: (v) => setState(() {
                                    _tampilkanNoHpOutlet = v;
                                    _isSaved = false;
                                  }),
                                ),
                                _divider(),
                              ],
                            );
                          },
                        ),
                        FutureBuilder<bool>(
                          future: canAccess('can_access_togle_alamat'),
                          builder: (context, snapshot) {
                            if (!(snapshot.data ?? false))
                              return const SizedBox.shrink();
                            return Column(
                              children: [
                                _toggleRow(
                                  icon: Icons.location_on_outlined,
                                  title: 'Tampilkan Alamat Outlet',
                                  subtitle: 'Alamat outlet muncul di struk',
                                  value: _tampilkanAlamatOutlet,
                                  onChanged: (v) => setState(() {
                                    _tampilkanAlamatOutlet = v;
                                    _isSaved = false;
                                  }),
                                ),
                                _divider(),
                              ],
                            );
                          },
                        ),
                        FutureBuilder<bool>(
                          future: canAccess('can_access_nota'),
                          builder: (context, snapshot) {
                            if (!(snapshot.data ?? false))
                              return const SizedBox.shrink();
                            return Column(
                              children: [
                                _toggleRow(
                                  icon: Icons.text_fields_rounded,
                                  title: 'Nama Pelanggan Besar',
                                  subtitle:
                                      'Nama besar & label "Pelanggan:" disembunyikan',
                                  value: _namaPelangganBesar,
                                  onChanged: (v) => setState(() {
                                    _namaPelangganBesar = v;
                                    _isSaved = false;
                                  }),
                                ),
                                _divider(),
                              ],
                            );
                          },
                        ),
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
                        _toggleRow(
                          icon: Icons.image_outlined,
                          title: 'Struk Tampilan Gambar',
                          subtitle:
                              'Desain modern (logo, kotak total, QR lacak & WhatsApp). '
                              'Matikan untuk kembali ke struk teks yang lebih cepat',
                          value: _strukGambar,
                          onChanged: (v) => setState(() {
                            _strukGambar = v;
                            _isSaved = false;
                          }),
                        ),
                        _divider(),
                        // Custom Nota
                        FutureBuilder<bool>(
                          future: canAccess('can_access_nota'),
                          builder: (context, snapshot) {
                            if (!(snapshot.data ?? false))
                              return const SizedBox.shrink();
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
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
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Custom Nomor Order/Nota',
                                            style: theme.textTheme.bodyLarge
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 13,
                                                ),
                                          ),
                                          Text(
                                            'Sesuaikan kode awal nomor struk',
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
                                    hintStyle: theme.textTheme.bodyLarge
                                        ?.copyWith(
                                          color: theme
                                              .textTheme
                                              .bodyLarge
                                              ?.color
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
                            );
                          },
                        ),

                        if (!_namaPelangganBesar) ...[
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
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ══ Rekening Pembayaran ════════════════════════════════════
                  // Stack: judul kiri menindih, tombol kanan menindih
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Card konten — padding atas extra supaya tidak tertutup header
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(top: _kHeaderOverlap),
                        padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
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
                        child: _rekeningList.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
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
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: Colors.grey.shade500,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : Column(
                                children: List.generate(_rekeningList.length, (
                                  i,
                                ) {
                                  final rek = _rekeningList[i];
                                  final hasQr =
                                      (rek['qr_url'] ?? '').isNotEmpty;
                                  final hasQrString =
                                      (rek['qr_string'] ?? '').isNotEmpty;
                                  return Column(
                                    children: [
                                      if (i > 0) _divider(),
                                      Row(
                                        children: [
                                          GestureDetector(
                                            onTap: hasQr
                                                ? () => _showQrPreview(
                                                    rek['qr_url']!,
                                                  )
                                                : null,
                                            child: Container(
                                              width: 48,
                                              height: 48,
                                              decoration: BoxDecoration(
                                                color: kPrimary.withOpacity(
                                                  0.08,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              clipBehavior: Clip.antiAlias,
                                              child: hasQr
                                                  ? Image.network(
                                                      rek['qr_url']!,
                                                      fit: BoxFit.cover,
                                                      errorBuilder:
                                                          (_, __, ___) => Icon(
                                                            Icons
                                                                .qr_code_2_rounded,
                                                            color: kPrimary,
                                                            size: 24,
                                                          ),
                                                    )
                                                  : Icon(
                                                      Icons
                                                          .account_balance_outlined,
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
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodyLarge
                                                          ?.copyWith(
                                                            fontWeight:
                                                                FontWeight.bold,
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
                                                              BorderRadius.circular(
                                                                6,
                                                              ),
                                                        ),
                                                        child: const Text(
                                                          'QR ✓',
                                                          style: TextStyle(
                                                            fontSize: 10,
                                                            color: Colors.green,
                                                            fontWeight:
                                                                FontWeight.w600,
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
                                                              BorderRadius.circular(
                                                                6,
                                                              ),
                                                        ),
                                                        child: const Text(
                                                          'String ✓',
                                                          style: TextStyle(
                                                            fontSize: 10,
                                                            color: Colors.blue,
                                                            fontWeight:
                                                                FontWeight.w600,
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
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .bodySmall
                                                        ?.copyWith(
                                                          fontSize: 12,
                                                        ),
                                                  ),
                                                if ((rek['atas_nama'] ?? '')
                                                    .isNotEmpty)
                                                  Text(
                                                    'a.n ${rek['atas_nama']}',
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .bodySmall
                                                        ?.copyWith(
                                                          fontSize: 11,
                                                          color:
                                                              Theme.of(context)
                                                                  .textTheme
                                                                  .bodySmall
                                                                  ?.color
                                                                  ?.withOpacity(
                                                                    0.6,
                                                                  ),
                                                        ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          FutureBuilder<bool>(
                                            future: canAccess(
                                              'can_kelola_rekening',
                                            ),
                                            builder: (context, snap) {
                                              if (!(snap.data ?? false))
                                                return const SizedBox.shrink();
                                              return Tooltip(
                                                message: 'Edit & Upload QR',
                                                child: IconButton(
                                                  onPressed: () =>
                                                      _showEditRekeningDialog(
                                                        i,
                                                      ),
                                                  icon: Icon(
                                                    Icons
                                                        .qr_code_scanner_rounded,
                                                    size: 20,
                                                    color: kPrimary,
                                                  ),
                                                  splashRadius: 20,
                                                ),
                                              );
                                            },
                                          ),
                                          FutureBuilder<bool>(
                                            future: canAccess(
                                              'can_kelola_rekening',
                                            ),
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
                                            future: canAccess(
                                              'can_kelola_rekening',
                                            ),
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

                      // ── Label "Rekening Pembayaran" — menindih pojok kiri atas
                      Positioned(
                        top: _kHeaderOverlap - 14,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          child: const Text(
                            'Rekening Pembayaran',
                            style: TextStyle(
                              color: kPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                      // ── Tombol "+ Tambah" — menindih pojok kanan atas
                      Positioned(
                        top: 0,
                        right: 0,
                        child: FutureBuilder<bool>(
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
                                  color: kPrimary.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: kPrimary.withOpacity(0.4),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: kPrimary.withOpacity(0.15),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
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
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ══ Footer Struk ═══════════════════════════════════════════
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Card konten
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(top: _kHeaderOverlap),
                        padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              !_hasEditNotaAccess
                                  ? 'Perlu upgrade paket untuk mengubah teks ini'
                                  : (_footerPoweredEnabled
                                        ? 'Teks ini tampil di baris paling bawah struk (Customer & Produksi)'
                                        : 'Footer dinonaktifkan, tidak akan dicetak'),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: !_hasEditNotaAccess
                                        ? Colors.orange.shade700
                                        : (_footerPoweredEnabled
                                              ? Theme.of(context)
                                                    .textTheme
                                                    .bodySmall
                                                    ?.color
                                                    ?.withOpacity(0.6)
                                              : Colors.grey.shade500),
                                  ),
                            ),
                            const SizedBox(height: 10),

                            // ── Field footer, dikunci kalau OFF atau basic ──────
                            GestureDetector(
                              onTap:
                                  (_hasEditNotaAccess && _footerPoweredEnabled)
                                  ? null
                                  : (!_hasEditNotaAccess
                                        ? _showUpgradeDialog
                                        : null),
                              child: AbsorbPointer(
                                absorbing:
                                    !(_hasEditNotaAccess &&
                                        _footerPoweredEnabled),
                                child: TextFormField(
                                  controller: _footerPoweredController,
                                  maxLines: 2,
                                  enabled:
                                      _hasEditNotaAccess &&
                                      _footerPoweredEnabled,
                                  onChanged: (_) => _markUnsaved(),
                                  style: Theme.of(context).textTheme.bodyLarge,
                                  decoration: InputDecoration(
                                    hintText: !_footerPoweredEnabled
                                        ? '(Footer dinonaktifkan)'
                                        : PrinterSettings.defaultFooterPowered,
                                    hintStyle: Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .textTheme
                                              .bodyLarge
                                              ?.color
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
                                    fillColor:
                                        (_hasEditNotaAccess &&
                                            _footerPoweredEnabled)
                                        ? Theme.of(
                                            context,
                                          ).scaffoldBackgroundColor
                                        : Theme.of(context)
                                              .scaffoldBackgroundColor
                                              .withOpacity(0.5),
                                    contentPadding: const EdgeInsets.all(12),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                          ],
                        ),
                      ),

                      // ── Label "Footer Setruk" — menindih pojok kiri atas, sama seperti Rekening
                      Positioned(
                        top: _kHeaderOverlap - 14,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          child: const Text(
                            'Footer Setruk',
                            style: TextStyle(
                              color: kPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                      // ── Badge kanan — menindih pojok kanan atas, sejajar dengan label kiri
                      Positioned(
                        top: 0,
                        right: 10,
                        child: !_hasEditNotaAccess
                            ? GestureDetector(
                                onTap: _showUpgradeDialog,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade600,
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.orange.withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.lock_outline_rounded,
                                        size: 13,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 4),
                                      const Text(
                                        'Upgrade',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : GestureDetector(
                                onTap: () => _toggleFooterPoweredEnabled(
                                  !_footerPoweredEnabled,
                                ),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  width: 52,
                                  height: 28,
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    color: _footerPoweredEnabled
                                        ? kPrimary
                                        : Colors.grey.shade300,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: _footerPoweredEnabled
                                          ? kPrimary
                                          : Colors.grey.shade400,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            (_footerPoweredEnabled
                                                    ? kPrimary
                                                    : Colors.grey)
                                                .withOpacity(0.2),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: AnimatedAlign(
                                    duration: const Duration(milliseconds: 180),
                                    alignment: _footerPoweredEnabled
                                        ? Alignment.centerRight
                                        : Alignment.centerLeft,
                                    child: Container(
                                      width: 20,
                                      height: 20,
                                      decoration: const BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // ══ Tombol Simpan ══════════════════════════════════════════
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

  // ════════════════════════════════════════════════════════════════════════
  //  _cardWithHeader — Card dengan judul menindih di pojok kiri atas
  // ════════════════════════════════════════════════════════════════════════
  Widget _cardWithHeader({
    required String title,
    required Widget child,
    Widget? trailing, // <--- Tombol '+ Tambah' atau 'Upgrade' di sisi kanan
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // 1. Kotak Konten Utama (Putih)
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: _kHeaderOverlap),
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
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
        ),

        // 2. Teks Judul di Sisi Kiri (Memotong Garis)
        Positioned(
          top:
              _kHeaderOverlap -
              14, // <--- Menggunakan hitungan pas dari kode FOOTER SETRUK Anda
          left: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: Text(
              title,
              style: const TextStyle(
                color: kPrimary, // <--- Warna teks biru utama
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),

        // 3. Tombol Aksi di Sisi Kanan (Jika Ada, seperti + Tambah atau Upgrade)
        if (trailing != null)
          Positioned(
            top:
                _kHeaderOverlap -
                20, // <--- Menyeimbangkan tinggi tombol orange/biru agar pas di tengah garis
            right: 10,
            child: trailing,
          ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  Paper Size
  // ════════════════════════════════════════════════════════════════════════
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

  // ════════════════════════════════════════════════════════════════════════
  //  QR Preview dialog
  // ════════════════════════════════════════════════════════════════════════
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

  // ════════════════════════════════════════════════════════════════════════
  //  Helper widgets
  // ════════════════════════════════════════════════════════════════════════
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

  // ════════════════════════════════════════════════════════════════════════
  //  Pengaturan tampilan struk gambar
  // ════════════════════════════════════════════════════════════════════════
  Widget _buildStrukGambarSettings(ThemeData theme) {
    final int pct = (_strukFontScale * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sliderRow(
          icon: Icons.format_size_rounded,
          title: 'Ukuran Font Struk',
          subtitle: 'Naikkan bila tulisan terlalu kecil / sulit dibaca',
          valueLabel: '$pct%',
          value: _strukFontScale,
          min: 0.8,
          max: 2.0,
          divisions: 24,
          onChanged: (v) => setState(() {
            _strukFontScale = double.parse(v.toStringAsFixed(2));
            _isSaved = false;
          }),
        ),
        // Pratinjau ukuran relatif
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 4, bottom: 4),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            'Contoh: Cuci Lipat Regular  28,4 kg',
            style: TextStyle(
              fontSize: 13.5 * _strukFontScale,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        _divider(),
        _toggleRow(
          icon: Icons.chat_outlined,
          title: 'QR WhatsApp Outlet',
          subtitle: 'QR untuk chat ke nomor HP outlet',
          value: _tampilkanQrWa,
          onChanged: (v) => setState(() {
            _tampilkanQrWa = v;
            _isSaved = false;
          }),
        ),
        const SizedBox(height: 6),
        Text(
          'QR Lacak Order mengikuti saklar "Tampilkan QR di Struk Customer" '
          'di bagian Pengaturan Struk.',
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 11,
            color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
          ),
        ),
        _divider(),
        Text(
          'Pesan Promo (di atas QR)',
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _pesanPromoController,
          maxLines: 2,
          onChanged: (_) => _markUnsaved(),
          style: theme.textTheme.bodyLarge,
          decoration: InputDecoration(
            hintText: 'Contoh: Nikmati Layanan Antar Jemput Gratis Min. 5kg',
            hintStyle: theme.textTheme.bodyLarge?.copyWith(
              color: theme.textTheme.bodyLarge?.color?.withOpacity(0.35),
              fontSize: 13,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: theme.scaffoldBackgroundColor,
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Kosongkan bila tidak ingin menampilkan promo.',
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 11,
            color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
          ),
        ),
        _divider(),
        Text(
          'Kecepatan Cetak',
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: kPrimary,
          ),
        ),
        const SizedBox(height: 8),
        _sliderRow(
          icon: Icons.timer_outlined,
          title: 'Jeda antar potongan',
          subtitle: 'Kecil = lebih cepat. Naikkan bila hasil cetak acak/berantakan',
          valueLabel: '${_strukJedaMs.round()} ms',
          value: _strukJedaMs,
          min: 0,
          max: 2000,
          divisions: 40,
          onChanged: (v) => setState(() {
            _strukJedaMs = v;
            _isSaved = false;
          }),
        ),
        const SizedBox(height: 6),
        _sliderRow(
          icon: Icons.view_agenda_outlined,
          title: 'Tinggi potongan gambar',
          subtitle: 'Besar = lebih sedikit jeda, tapi printer murah bisa macet',
          valueLabel: '${_strukStripRows.round()} baris',
          value: _strukStripRows,
          min: 64,
          max: 320,
          divisions: 16,
          onChanged: (v) => setState(() {
            _strukStripRows = v;
            _isSaved = false;
          }),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _resetStrukGambar,
                icon: const Icon(Icons.restart_alt_rounded, size: 18),
                label: const Text('Bawaan'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kPrimary,
                  side: BorderSide(color: kPrimary.withOpacity(0.4)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _cetakContoh,
                icon: const Icon(Icons.print_rounded, size: 18),
                label: const Text('Simpan & Cetak Contoh'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _resetStrukGambar() {
    setState(() {
      _strukFontScale = PrinterSettings.defaultStrukFontScale;
      _strukStripRows = PrinterSettings.defaultStrukStripRows.toDouble();
      _strukJedaMs = PrinterSettings.defaultStrukJedaMs.toDouble();
      _isSaved = false;
    });
  }

  /// Simpan pengaturan lalu cetak struk contoh, supaya setelan font/jeda bisa
  /// langsung dicoba tanpa membuat order baru.
  Future<void> _cetakContoh() async {
    await _simpan();
    if (!mounted || !_isSaved) return;
    final now = DateTime.now();
    final sample = <String, dynamic>{
      'nama_laundry': OutletSettings.namaLaundry,
      'alamat': PrinterSettings.tampilkanAlamatOutlet
          ? OutletSettings.alamat
          : '',
      'no_hp_laundry': PrinterSettings.tampilkanNoHpOutlet
          ? OutletSettings.noHpLaundry
          : '',
      'no_order': 'LS-0000000-00',
      'pelanggan': 'CONTOH PELANGGAN',
      'no_hp': '081234567890',
      'waktu': DateFormat('dd/MM/yy HH.mm').format(now),
      'estimasi': DateFormat(
        'dd MMM yyyy, HH.mm',
      ).format(now.add(const Duration(days: 3))),
      'items': [
        {
          'layanan_nama': 'Cuci Lipat Regular',
          'layanan_tipe': 'kiloan',
          'berat_kg': 28.4,
          'harga_satuan': 10000,
          'durasi_jam': 72,
          'catatan': '',
        },
      ],
      'biaya_tambahan': <Map<String, dynamic>>[],
      'subtotal_sebelum_diskon': 284000,
      'diskon_nominal': 0,
      'diskon_catatan': '',
      'grand_total': 284000,
      'dp_amount': 0,
      'sisa_tagihan': 284000,
      'sudah_lunas': false,
      'admin': 'Admin',
      'rekening_list': PrinterSettings.rekeningList,
      'pesan_kaki': PrinterSettings.pesanKaki,
    };
    PrinterDialog.show(context, sample);
  }

  Widget _sliderRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required String valueLabel,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
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
            Text(
              valueLabel,
              style: TextStyle(
                color: kPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
        Slider(
          value: value.clamp(min, max).toDouble(),
          min: min,
          max: max,
          divisions: divisions,
          activeColor: kPrimary,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _divider() =>
      Divider(height: 20, thickness: 0.5, color: Colors.grey.withOpacity(0.2));

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

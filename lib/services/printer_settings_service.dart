import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

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
  static String footerPowered = '';
  static bool footerPoweredEnabled = true; //
  static const String defaultFooterPowered =
      'Powered By : Madeena Laundry x Rdh Project';

  // ── DIUBAH: hormati toggle. Kalau OFF, total tidak ada footer ──────
  static String get footerPoweredFinal {
    if (!footerPoweredEnabled) return '';
    return footerPowered.trim().isEmpty ? defaultFooterPowered : footerPowered;
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  PrinterSettingsService — Firestore read / write
// ════════════════════════════════════════════════════════════════════════════
class PrinterSettingsService {
  static DocumentReference<Map<String, dynamic>> _docRef(
    String storeId,
    String outletId,
  ) => FirebaseFirestore.instance
      .collection('stores')
      .doc(storeId)
      .collection('outlets')
      .doc(outletId)
      .collection('settings')
      .doc('printer');

  static Future<void> load(String storeId, String outletId) async {
    try {
      final snap = await _docRef(storeId, outletId).get();
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
      PrinterSettings.footerPowered = d['footer_powered']?.toString() ?? '';
      PrinterSettings.footerPoweredEnabled =
          d['footer_powered_enabled'] ?? true; //
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
    required String storeId,
    required String outletId,
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
    required String footerPowered,
    required bool footerPoweredEnabled, //
  }) async {
    await _docRef(storeId, outletId).set({
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
      'footer_powered': footerPowered,
      'footer_powered_enabled': footerPoweredEnabled, //
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<String?> uploadQr(
    dynamic imageFile,
    String namaBank,
    String storeId,
    String outletId,
  ) async {
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
          .child(storeId)
          .child(outletId)
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

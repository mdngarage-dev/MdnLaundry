import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:mdnlaundry_project/core/app_exports.dart';
import 'package:qr/qr.dart';
import 'package:image/image.dart' as imgLib;
import 'package:mdnlaundry_project/services/receipt_image_builder.dart';

class ThermalPrinterService {
  BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;

  Future<List<BluetoothDevice>> getPairedDevices() async {
    return await bluetooth.getBondedDevices();
  }

  Future<bool> isBluetoothOn() async {
    return await bluetooth.isOn ?? false;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helper: connect aman ke printer
  // Disconnect dulu kalau ada koneksi stale, baru connect baru.
  // Mencegah error "connect_error, read failed, socket might closed or timeout"
  // akibat socket sebelumnya tidak ditutup dengan benar (mis. print macet).
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _ensureConnected(BluetoothDevice device) async {
    try {
      final bool? isConnected = await bluetooth.isConnected;
      if (isConnected ?? false) {
        try {
          await bluetooth.disconnect();
          await Future.delayed(const Duration(milliseconds: 300));
        } catch (_) {}
      }
      await bluetooth.connect(device);
      await Future.delayed(const Duration(milliseconds: 300));
    } catch (e) {
      debugPrint('[ThermalPrinter] Gagal connect: $e');
      rethrow;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Generate QR PNG dari string — pure 1-bit, module-based sizing
  // modulePixels: jumlah px per modul (4 = aman 58mm, 5 = 80mm)
  // quiet: border putih dalam satuan modul
  //
  // Untuk data panjang (mis. string QRIS EMV ~150-200 char), error correction
  // diturunkan ke L agar jumlah modul tidak terlalu besar, sehingga sizePx
  // tetap wajar untuk printer thermal dan tidak menyebabkan buffer overflow.
  // ─────────────────────────────────────────────────────────────────────────
  Future<String?> _generateQrTempFile(
    String data, {
    int modulePixels = 4,
    int quiet = 2,
  }) async {
    try {
      final int errorLevel = data.length > 100
          ? QrErrorCorrectLevel.L
          : QrErrorCorrectLevel.M;

      final qrCode = QrCode.fromData(data: data, errorCorrectLevel: errorLevel);
      final qrImage = QrImage(qrCode);
      final int moduleCount = qrCode.moduleCount;
      final int totalModules = moduleCount + quiet * 2;
      final int sizePx = totalModules * modulePixels;

      final imgLib.Image image = imgLib.Image(width: sizePx, height: sizePx);
      imgLib.fill(image, color: imgLib.ColorRgb8(255, 255, 255));

      for (int row = 0; row < moduleCount; row++) {
        for (int col = 0; col < moduleCount; col++) {
          if (qrImage.isDark(row, col)) {
            final int x0 = (col + quiet) * modulePixels;
            final int y0 = (row + quiet) * modulePixels;
            for (int dy = 0; dy < modulePixels; dy++) {
              for (int dx = 0; dx < modulePixels; dx++) {
                final int px = x0 + dx;
                final int py = y0 + dy;
                if (px < sizePx && py < sizePx) {
                  image.setPixel(px, py, imgLib.ColorRgb8(0, 0, 0));
                }
              }
            }
          }
        }
      }

      // Threshold pure 1-bit — cegah abu-abu yang bikin printer overflow hitam
      final imgLib.Image bwImage = imgLib.grayscale(image);
      for (int y = 0; y < bwImage.height; y++) {
        for (int x = 0; x < bwImage.width; x++) {
          final pixel = bwImage.getPixel(x, y);
          final lum = imgLib.getLuminance(pixel);
          bwImage.setPixel(
            x,
            y,
            lum < 128
                ? imgLib.ColorRgb8(0, 0, 0)
                : imgLib.ColorRgb8(255, 255, 255),
          );
        }
      }

      final List<int> pngBytes = imgLib.encodePng(bwImage);
      final String tempPath =
          '${Directory.systemTemp.path}/qr_${DateTime.now().millisecondsSinceEpoch}.png';
      final File tempFile = File(tempPath);
      await tempFile.writeAsBytes(pngBytes, flush: true);

      if (await tempFile.exists() && await tempFile.length() > 0) {
        return tempPath;
      }
      return null;
    } catch (e) {
      debugPrint('[ThermalPrinter] Gagal generate QR: $e');
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Print QR dari string (generate lokal)
  // modulePixels 4 = 58mm, 5 = 80mm (untuk data pendek seperti no_order)
  // Delay dinaikkan dari 800ms -> 1500ms agar printer selesai render
  // sebelum command berikutnya dikirim.
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _printQrCode(String data, {int modulePixels = 4}) async {
    final String? path = await _generateQrTempFile(
      data,
      modulePixels: modulePixels,
    );
    if (path != null) {
      bluetooth.printImage(path);
      await Future.delayed(const Duration(milliseconds: 1500));
      try {
        await File(path).delete();
      } catch (_) {}
    } else {
      bluetooth.printCustom('[QR tidak tersedia]', 1, 1);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Print QR rekening
  // Prioritas 1: qr_string → generate lokal (paling reliable, pasti bisa scan)
  // Prioritas 2: qr_url   → download + resize + threshold 1-bit
  //
  // qr_string dari QRIS biasanya panjang (~150-200 char) sehingga modulnya
  // banyak. modulePixels diperkecil khusus untuk data panjang agar sizePx
  // tetap wajar untuk printer thermal dan tidak macet saat dicetak.
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _printQrRekening(
    String qrString,
    String qrUrl, {
    required bool is80mm,
  }) async {
    if (qrString.isNotEmpty) {
      if (qrString.length > 100) {
        await _printQrCodeSplit(qrString, modulePixels: is80mm ? 8 : 6);
      } else {
        await _printQrCode(qrString, modulePixels: is80mm ? 5 : 4);
      }
      return;
    }

    if (qrUrl.isNotEmpty) {
      try {
        final HttpClient client = HttpClient();
        client.connectionTimeout = const Duration(seconds: 10);
        final HttpClientRequest req = await client.getUrl(Uri.parse(qrUrl));
        req.headers.set('Accept', 'image/*');
        final HttpClientResponse resp = await req.close();

        if (resp.statusCode == 200) {
          final List<int> qrBytes = [];
          await for (final chunk in resp) {
            qrBytes.addAll(chunk);
          }
          client.close();

          if (qrBytes.isNotEmpty) {
            imgLib.Image? src = imgLib.decodeImage(Uint8List.fromList(qrBytes));
            if (src != null) {
              final int targetSize = is80mm ? 180 : 120;

              imgLib.Image resized = imgLib.copyResize(
                src,
                width: targetSize,
                height: targetSize,
                interpolation: imgLib.Interpolation.average,
              );

              resized = imgLib.grayscale(resized);
              for (int y = 0; y < resized.height; y++) {
                for (int x = 0; x < resized.width; x++) {
                  final pixel = resized.getPixel(x, y);
                  final lum = imgLib.getLuminance(pixel);
                  resized.setPixel(
                    x,
                    y,
                    lum < 160
                        ? imgLib.ColorRgb8(0, 0, 0)
                        : imgLib.ColorRgb8(255, 255, 255),
                  );
                }
              }

              final List<int> resizedBytes = imgLib.encodePng(resized);
              final String tempPath =
                  '${Directory.systemTemp.path}/qr_${DateTime.now().millisecondsSinceEpoch}.png';
              final File tempFile = File(tempPath);
              await tempFile.writeAsBytes(resizedBytes, flush: true);

              if (await tempFile.exists() && (await tempFile.length()) > 0) {
                bluetooth.printImage(tempPath);
                await Future.delayed(const Duration(milliseconds: 2500));
                await tempFile.delete();
              } else {
                bluetooth.printCustom('[QR gagal disimpan]', 1, 1);
              }
            } else {
              bluetooth.printCustom('[QR tidak dapat didekode]', 1, 1);
            }
          } else {
            client.close();
            bluetooth.printCustom('[QR kosong]', 1, 1);
          }
        } else {
          client.close();
          bluetooth.printCustom('[QR tidak tersedia]', 1, 1);
        }
      } catch (e, stackTrace) {
        debugPrint('[ThermalPrinter] Gagal cetak QR ($qrUrl): $e');
        debugPrint('$stackTrace');
        bluetooth.printCustom('[QR tidak tersedia]', 1, 1);
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STRUK PRODUKSI
  // QR tracking SELALU cetak — tidak dipengaruhi setting tampilkanQrStruk
  // modulePixels dinaikkan (5->8 / 4->6) agar QR fisik lebih besar, karena
  // noOrder adalah string pendek -> QR versi rendah -> modul sedikit.
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> printStrukProduksi(
    BluetoothDevice device,
    Map<String, dynamic> data,
  ) async {
    await _ensureConnected(device);

    final bool is80mm = PrinterSettings.ukuranKertas == 80;
    final int lineWidth = is80mm ? 48 : 32;
    final String divider = '-' * lineWidth;
    final String doubleLine = '=' * lineWidth;

    final String noOrder = data['no_order']?.toString() ?? '-';
    final String pelanggan = data['pelanggan']?.toString() ?? '-';
    final String estimasi = data['estimasi']?.toString() ?? '-';
    final List<Map<String, dynamic>> items = _toListMap(data['items']);

    bluetooth.printNewLine();
    bluetooth.printNewLine();

    bluetooth.printCustom('STRUK PRODUKSI', 3, 1);
    bluetooth.printCustom(doubleLine, 1, 1);

    // QR tracking — SELALU CETAK, tidak bisa dimatikan dari setting
    await _printQrCode(noOrder, modulePixels: is80mm ? 8 : 6);
    bluetooth.printNewLine();
    bluetooth.printCustom(noOrder, 1, 1);
    bluetooth.printCustom('Scan untuk cek status', 1, 1);
    bluetooth.printCustom(divider, 1, 1);

    bluetooth.printCustom('PELANGGAN :', 1, 0);
    bluetooth.printCustom(pelanggan, 3, 1);
    bluetooth.printCustom(divider, 1, 1);

    bluetooth.printCustom('INSTRUKSI CUCIAN :', 1, 0);
    bluetooth.printCustom(divider, 1, 1);

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final String nama = item['layanan_nama']?.toString() ?? '-';
      final String tipe = item['layanan_tipe']?.toString() ?? '';
      final double berat = _toDouble(item['berat_kg']);
      final String catatan = item['catatan']?.toString() ?? '';

      String satuan;
      switch (tipe) {
        case 'kiloan':
          satuan = 'kg';
          break;
        case 'meter':
          satuan = 'm2';
          break;
        default:
          satuan = 'pcs';
          break;
      }

      final String beratStr = berat % 1 == 0
          ? berat.toStringAsFixed(0)
          : berat.toStringAsFixed(1);

      bluetooth.printCustom('${i + 1}. $nama', 2, 0);
      bluetooth.printCustom('   $beratStr $satuan', 1, 0);

      if (catatan.isNotEmpty) {
        bluetooth.printCustom('   Catatan:', 1, 0);
        for (final baris in _wrapText(catatan, lineWidth - 4)) {
          bluetooth.printCustom('   $baris', 1, 0);
        }
      }

      if (i < items.length - 1) {
        bluetooth.printCustom('- ' * (lineWidth ~/ 2), 1, 1);
      }
    }

    bluetooth.printCustom(doubleLine, 1, 1);
    bluetooth.printCustom('EST. SELESAI :', 1, 0);
    bluetooth.printCustom(estimasi, 2, 1);

    bluetooth.printCustom(divider, 1, 1);
    for (final baris in _wrapText(
      PrinterSettings.footerPoweredFinal,
      lineWidth,
    )) {
      bluetooth.printCustom(baris, 1, 1);
    }

    bluetooth.printNewLine();
    bluetooth.printNewLine();
    bluetooth.printNewLine();
    bluetooth.printNewLine();
    bluetooth.printNewLine();
    bluetooth.paperCut();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STRUK CUSTOMER
  // QR tracking ikut setting tampilkanQrStruk
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> printStruk(
    BluetoothDevice device,
    Map<String, dynamic> data,
  ) async {
    await _ensureConnected(device);

    final bool is80mm = PrinterSettings.ukuranKertas == 80;
    final int lineWidth = is80mm ? 48 : 32;
    final String divider = '-' * lineWidth;
    final String doubleLine = '=' * lineWidth;

    final String namaOutlet =
        (data['nama_laundry']?.toString().isNotEmpty == true
        ? data['nama_laundry'].toString()
        : OutletSettings.namaLaundry.isNotEmpty
        ? OutletSettings.namaLaundry
        : 'Madeena Laundry');
    final String alamat = data['alamat']?.toString() ?? OutletSettings.alamat;
    final String noHpToko =
        data['no_hp_laundry']?.toString() ?? OutletSettings.noHpLaundry;
    final String logoPath = OutletSettings.logoPath;

    final String noOrder = data['no_order']?.toString() ?? '-';
    final String waktu = data['waktu']?.toString() ?? '-';
    final String pelanggan = data['pelanggan']?.toString() ?? '-';
    final String noHpPelanggan = data['no_hp']?.toString() ?? '-';
    final String admin = data['admin']?.toString() ?? '-';
    final String estimasi = data['estimasi']?.toString() ?? '-';

    final String pesanKaki = (data['pesan_kaki']?.toString().isNotEmpty == true
        ? data['pesan_kaki'].toString()
        : PrinterSettings.pesanKaki);

    final int grandTotal = _toInt(data['grand_total']);
    final int dpAmount = _toInt(data['dp_amount']);
    final int sisaTagihan = _toInt(data['sisa_tagihan']);
    final bool sudahLunas = data['sudah_lunas'] == true;

    final int diskonNominal = _toInt(data['diskon_nominal']);
    final String diskonCatatan = data['diskon_catatan']?.toString() ?? '';
    final int subtotalSebelumDiskon = _toInt(data['subtotal_sebelum_diskon']);

    final List<Map<String, dynamic>> items = _toListMap(data['items']);
    final List<Map<String, dynamic>> biayaTambahan = _toListMap(
      data['biaya_tambahan'],
    );
    final List<Map<String, dynamic>> rekeningList = _toListMap(
      data['rekening_list'],
    );

    final bool namaBesar = PrinterSettings.namaPelangganBesar;
    final bool tampilAlamat = PrinterSettings.tampilkanAlamatOutlet;
    final bool tampilNoHpOutlet = PrinterSettings.tampilkanNoHpOutlet;
    final bool sembunyiNoHpPelanggan = PrinterSettings.sembunyikanNoHpPelanggan;
    final int ukuranLabelPelanggan = PrinterSettings.ukuranLabelPelanggan;
    final bool tampilQr = PrinterSettings.tampilkanQrStruk;

    // ── Mode gambar (desain modern). Bila render gambar gagal SEBELUM ada
    //    yang terkirim ke printer, otomatis jatuh ke struk teks di bawah. ──
    if (PrinterSettings.strukGambar) {
      final bool berhasil = await _printStrukGambar(
        data: data,
        is80mm: is80mm,
        options: ReceiptOptions(
          namaOutlet: namaOutlet,
          alamat: tampilAlamat ? alamat : '',
          noHpOutlet: tampilNoHpOutlet ? noHpToko : '',
          logoPath: logoPath,
          pesanKaki: pesanKaki,
          pesanPromo: PrinterSettings.pesanPromo,
          footerPowered: PrinterSettings.footerPoweredFinal,
          namaPelangganBesar: namaBesar,
          sembunyikanNoHpPelanggan: sembunyiNoHpPelanggan,
          tampilkanQrTracking: tampilQr,
          tampilkanQrWa: PrinterSettings.tampilkanQrWa,
          noHpWa: noHpToko.isNotEmpty ? noHpToko : OutletSettings.noHpLaundry,
          fontScale: PrinterSettings.strukFontScale,
          stripRows: PrinterSettings.strukStripRows,
        ),
      );
      if (berhasil) return;
    }

    bluetooth.printNewLine();
    bluetooth.printNewLine();
    bluetooth.printNewLine();

    // Logo
    if (logoPath.isNotEmpty) {
      try {
        final File logoFile = File(logoPath);
        if (await logoFile.exists()) {
          bluetooth.printImage(logoPath);
        }
      } catch (e) {
        debugPrint('[ThermalPrinter] Gagal cetak logo: $e');
      }
    }

    // Header
    bluetooth.printCustom(namaOutlet, 3, 1);
    if (tampilAlamat && alamat.isNotEmpty) {
      for (final baris in _wrapText(alamat, lineWidth)) {
        bluetooth.printCustom(baris, 1, 1);
      }
    }
    if (tampilNoHpOutlet && noHpToko.isNotEmpty) {
      bluetooth.printCustom('Telp: $noHpToko', 1, 1);
    }

    bluetooth.printCustom(doubleLine, 1, 1);
    bluetooth.printCustom('STRUK CUSTOMER', 2, 1);
    bluetooth.printCustom(doubleLine, 1, 1);

    bluetooth.printCustom('No  : $noOrder', 1, 0);
    bluetooth.printCustom('Tgl : $waktu', 1, 0);
    bluetooth.printCustom(divider, 1, 1);

    // QR tracking customer — ikut setting
    if (tampilQr) {
      await _printQrCode(noOrder, modulePixels: is80mm ? 5 : 4);
      bluetooth.printCustom(noOrder, 1, 1);
      bluetooth.printCustom('Scan untuk cek status', 1, 1);
      bluetooth.printCustom(divider, 1, 1);
    }

    // Pelanggan
    if (namaBesar) {
      bluetooth.printCustom(pelanggan, 3, 1);
    } else {
      bluetooth.printCustom('Pelanggan:', ukuranLabelPelanggan, 0);
      bluetooth.printCustom(pelanggan, 1, 0);
    }
    if (!sembunyiNoHpPelanggan &&
        noHpPelanggan.isNotEmpty &&
        noHpPelanggan != '-') {
      bluetooth.printCustom('HP  : $noHpPelanggan', 1, 0);
    }
    bluetooth.printCustom(divider, 1, 1);

    // Layanan
    bluetooth.printCustom('LAYANAN', 1, 0);
    bluetooth.printCustom(divider, 1, 1);

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final String layananNama = item['layanan_nama']?.toString() ?? '-';
      final String tipe = item['layanan_tipe']?.toString() ?? '';
      final double berat = _toDouble(item['berat_kg']);
      final int hargaSatuan = _toInt(item['harga_satuan']);
      final int subtotal = (berat * hargaSatuan).round();
      final String catatan = item['catatan']?.toString() ?? '';

      String satuan;
      switch (tipe) {
        case 'kiloan':
          satuan = 'kg';
          break;
        case 'meter':
          satuan = 'm2';
          break;
        default:
          satuan = 'pcs';
          break;
      }

      final String beratStr = berat % 1 == 0
          ? berat.toStringAsFixed(0)
          : berat.toStringAsFixed(1);

      bluetooth.printCustom('${i + 1}. $layananNama', 1, 0);
      bluetooth.printCustom(
        '   $beratStr $satuan   ${_formatRupiah(hargaSatuan)}',
        1,
        0,
      );
      bluetooth.printCustom('   = ${_formatRupiah(subtotal)}', 1, 0);

      if (catatan.isNotEmpty) {
        bluetooth.printCustom('   Catatan:', 1, 0);
        for (final baris in _wrapText(catatan, lineWidth - 4)) {
          bluetooth.printCustom('   $baris', 1, 0);
        }
      }

      if (i < items.length - 1) {
        bluetooth.printCustom('- ' * (lineWidth ~/ 2), 1, 1);
      }
    }
    bluetooth.printCustom(divider, 1, 1);

    // Biaya tambahan
    if (biayaTambahan.isNotEmpty) {
      bluetooth.printCustom('BIAYA TAMBAHAN', 1, 0);
      bluetooth.printCustom(divider, 1, 1);
      int totalBiayaTambahan = 0;
      for (final b in biayaTambahan) {
        final String ket = b['keterangan']?.toString() ?? '-';
        final int nominal = _toInt(b['nominal']);
        final int rawQty = _toInt(b['qty']);
        final int qty = rawQty > 0 ? rawQty : 1;
        final int subtotal = nominal * qty;
        totalBiayaTambahan += subtotal;
        bluetooth.printCustom('  $ket (${qty}x)', 1, 0);
        bluetooth.printCustom('  = ${_formatRupiah(subtotal)}', 1, 0);
      }
      bluetooth.printCustom(divider, 1, 1);
      bluetooth.printCustom(
        'Total Tambahan: ${_formatRupiah(totalBiayaTambahan)}',
        1,
        0,
      );
      bluetooth.printCustom(divider, 1, 1);
    }

    // Total
    int totalLayanan = 0;
    for (final item in items) {
      totalLayanan +=
          (_toDouble(item['berat_kg']) * _toInt(item['harga_satuan'])).round();
    }
    bluetooth.printCustom('Layanan : ${_formatRupiah(totalLayanan)}', 1, 0);

    if (biayaTambahan.isNotEmpty) {
      final int totalBiaya = biayaTambahan.fold(0, (sum, b) {
        final int rawQty = _toInt(b['qty']);
        final int qty = rawQty > 0 ? rawQty : 1;
        return sum + _toInt(b['nominal']) * qty;
      });
      bluetooth.printCustom('Biaya Tmb: ${_formatRupiah(totalBiaya)}', 1, 0);
    }

    if (diskonNominal > 0) {
      bluetooth.printCustom(
        'Subtotal: ${_formatRupiah(subtotalSebelumDiskon)}',
        1,
        0,
      );
      final diskonLabel = diskonCatatan.isNotEmpty
          ? 'Diskon($diskonCatatan)'
          : 'Diskon';
      final diskonLine = '$diskonLabel: -${_formatRupiah(diskonNominal)}';
      if (diskonLine.length <= lineWidth) {
        bluetooth.printCustom(diskonLine, 1, 0);
      } else {
        bluetooth.printCustom('$diskonLabel:', 1, 0);
        bluetooth.printCustom('  -${_formatRupiah(diskonNominal)}', 1, 0);
      }
    }

    bluetooth.printCustom(doubleLine, 1, 1);
    bluetooth.printCustom('TOTAL   : ${_formatRupiah(grandTotal)}', 1, 0);
    bluetooth.printCustom(doubleLine, 1, 1);

    // Pembayaran
    if (sudahLunas) {
      bluetooth.printCustom('Dibayar : ${_formatRupiah(grandTotal)}', 1, 0);
      bluetooth.printCustom('Sisa    : Rp 0', 1, 0);
    } else {
      bluetooth.printCustom(
        'Dibayar : ${dpAmount > 0 ? _formatRupiah(dpAmount) : 'Rp 0'}',
        1,
        0,
      );
      bluetooth.printCustom('Sisa    : ${_formatRupiah(sisaTagihan)}', 1, 0);
    }
    bluetooth.printCustom(
      'Status  : ${sudahLunas ? 'LUNAS' : 'BELUM LUNAS'}',
      2,
      0,
    );
    bluetooth.printCustom(divider, 1, 1);

    bluetooth.printCustom('Est Selesai : $estimasi', 1, 0);
    bluetooth.printCustom(doubleLine, 1, 1);

    // Rekening pembayaran
    if (rekeningList.isNotEmpty) {
      bluetooth.printCustom('PEMBAYARAN VIA', 2, 1);
      bluetooth.printCustom(doubleLine, 1, 1);

      for (final rek in rekeningList) {
        final String namaBank = rek['nama_bank']?.toString() ?? '';
        final String noRek = rek['no_rekening']?.toString() ?? '';
        final String atasNama = rek['atas_nama']?.toString() ?? '';
        final String qrUrl = rek['qr_url']?.toString() ?? '';
        final String qrString = rek['qr_string']?.toString() ?? '';

        final bool adaQr = qrString.isNotEmpty || qrUrl.isNotEmpty;

        if (namaBank.isNotEmpty) bluetooth.printCustom(namaBank, 2, 1);
        if (noRek.isNotEmpty) bluetooth.printCustom(noRek, 1, 1);
        if (atasNama.isNotEmpty) bluetooth.printCustom('a.n $atasNama', 1, 1);

        if (adaQr) {
          await _printQrRekening(qrString, qrUrl, is80mm: is80mm);
          // buffer ekstra agar printer benar2 selesai sebelum command berikutnya
          await Future.delayed(const Duration(milliseconds: 500));
          // Teks "Scan untuk pembayaran" hanya muncul jika ada QR
          bluetooth.printCustom('Scan untuk pembayaran', 1, 1);
        }
        // Jika tidak ada QR (hanya no rekening) → tidak ada teks scan

        bluetooth.printCustom(divider, 1, 1);
      }
    }

    // Footer
    if (pesanKaki.isNotEmpty) {
      for (final baris in _wrapText(pesanKaki, lineWidth)) {
        bluetooth.printCustom(baris, 1, 1);
      }
    } else {
      bluetooth.printCustom('Terima kasih.', 1, 1);
    }
    bluetooth.printCustom('Dicetak oleh : $admin', 1, 0);

    bluetooth.printCustom(divider, 1, 1);
    for (final baris in _wrapText(
      PrinterSettings.footerPoweredFinal,
      lineWidth,
    )) {
      bluetooth.printCustom(baris, 1, 1);
    }

    bluetooth.printNewLine();
    bluetooth.printNewLine();
    bluetooth.printNewLine();
    bluetooth.printNewLine();
    bluetooth.paperCut();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STRUK CUSTOMER — MODE GAMBAR
  // Struk digambar jadi bitmap 1-bit lalu dikirim per potongan pendek lewat
  // jalur printImage yang sama dengan logo/QR (sudah terbukti jalan).
  // Return false  → render gagal / potongan pertama gagal terkirim
  //                 (belum ada yang tercetak, aman fallback ke teks).
  // Throw         → gagal di tengah jalan (koneksi putus), sama seperti
  //                 perilaku struk teks.
  // ─────────────────────────────────────────────────────────────────────────
  Future<bool> _printStrukGambar({
    required Map<String, dynamic> data,
    required bool is80mm,
    required ReceiptOptions options,
  }) async {
    final List<Uint8List> strips;
    try {
      strips = await ReceiptImageBuilder(is80mm: is80mm).build(data, options);
      if (strips.isEmpty) return false;
    } catch (e, st) {
      debugPrint('[ThermalPrinter] Render struk gambar gagal: $e');
      debugPrint('$st');
      return false;
    }

    for (int i = 0; i < strips.length; i++) {
      try {
        await bluetooth.printImageBytes(strips[i]);
      } catch (e) {
        debugPrint('[ThermalPrinter] Kirim potongan ${i + 1} gagal: $e');
        if (i == 0) return false; // belum ada yang tercetak → fallback teks
        rethrow;
      }
      // Jeda antar potongan bisa diatur di Pengaturan Printer.
      if (PrinterSettings.strukJedaMs > 0) {
        await Future.delayed(
          Duration(milliseconds: PrinterSettings.strukJedaMs),
        );
      }
    }

    bluetooth.printNewLine();
    bluetooth.printNewLine();
    bluetooth.printNewLine();
    bluetooth.printNewLine();
    bluetooth.paperCut();
    return true;
  }

  Future<void> _printQrCodeSplit(
    String data, {
    int modulePixels = 5,
    int quiet = 2,
  }) async {
    try {
      final int errorLevel = data.length > 100
          ? QrErrorCorrectLevel.L
          : QrErrorCorrectLevel.M;

      final qrCode = QrCode.fromData(data: data, errorCorrectLevel: errorLevel);
      final qrImage = QrImage(qrCode);
      final int moduleCount = qrCode.moduleCount;
      final int totalModules = moduleCount + quiet * 2;
      final int sizePx = totalModules * modulePixels;

      final imgLib.Image full = imgLib.Image(width: sizePx, height: sizePx);
      imgLib.fill(full, color: imgLib.ColorRgb8(255, 255, 255));

      for (int row = 0; row < moduleCount; row++) {
        for (int col = 0; col < moduleCount; col++) {
          if (qrImage.isDark(row, col)) {
            final int x0 = (col + quiet) * modulePixels;
            final int y0 = (row + quiet) * modulePixels;
            for (int dy = 0; dy < modulePixels; dy++) {
              for (int dx = 0; dx < modulePixels; dx++) {
                full.setPixel(x0 + dx, y0 + dy, imgLib.ColorRgb8(0, 0, 0));
              }
            }
          }
        }
      }

      // Split jadi 2 bagian horizontal (atas & bawah)
      final int halfHeight = sizePx ~/ 2;

      final imgLib.Image top = imgLib.copyCrop(
        full,
        x: 0,
        y: 0,
        width: sizePx,
        height: halfHeight,
      );
      final imgLib.Image bottom = imgLib.copyCrop(
        full,
        x: 0,
        y: halfHeight,
        width: sizePx,
        height: sizePx - halfHeight,
      );

      final String pathTop =
          '${Directory.systemTemp.path}/qr_top_${DateTime.now().millisecondsSinceEpoch}.png';
      final String pathBottom =
          '${Directory.systemTemp.path}/qr_bottom_${DateTime.now().millisecondsSinceEpoch}.png';

      await File(pathTop).writeAsBytes(imgLib.encodePng(top), flush: true);
      await File(
        pathBottom,
      ).writeAsBytes(imgLib.encodePng(bottom), flush: true);

      // Print bagian atas
      bluetooth.printImage(pathTop);
      await Future.delayed(const Duration(milliseconds: 1500));

      // Print bagian bawah
      bluetooth.printImage(pathBottom);
      await Future.delayed(const Duration(milliseconds: 1500));

      try {
        await File(pathTop).delete();
      } catch (_) {}
      try {
        await File(pathBottom).delete();
      } catch (_) {}
    } catch (e) {
      debugPrint('[ThermalPrinter] Gagal split QR: $e');
      bluetooth.printCustom('[QR tidak tersedia]', 1, 1);
    }
  }
  // ── Helpers ───────────────────────────────────────────────────────────────

  int _toInt(dynamic val) {
    if (val == null) return 0;
    if (val is int) return val;
    if (val is double) return val.round();
    if (val is num) return val.toInt();
    try {
      return int.parse(val.toString().replaceAll(RegExp(r'[^0-9]'), ''));
    } catch (_) {
      return 0;
    }
  }

  double _toDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is double) return val;
    if (val is num) return val.toDouble();
    try {
      return double.parse(val.toString().replaceAll(',', '.'));
    } catch (_) {
      return 0.0;
    }
  }

  List<Map<String, dynamic>> _toListMap(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return [];
  }

  String _formatRupiah(int val) {
    try {
      final s = val.toString();
      final buf = StringBuffer();
      int count = 0;
      for (int i = s.length - 1; i >= 0; i--) {
        if (count > 0 && count % 3 == 0) buf.write('.');
        buf.write(s[i]);
        count++;
      }
      return 'Rp ${buf.toString().split('').reversed.join('')}';
    } catch (_) {
      return 'Rp 0';
    }
  }

  List<String> _wrapText(String text, int maxWidth) {
    if (text.isEmpty) return ['-'];
    final List<String> lines = [];
    final words = text.split(' ');
    String current = '';
    for (final word in words) {
      final candidate = current.isEmpty ? word : '$current $word';
      if (candidate.length <= maxWidth) {
        current = candidate;
      } else {
        if (current.isNotEmpty) lines.add(current);
        current = word;
      }
    }
    if (current.isNotEmpty) lines.add(current);
    return lines.isEmpty ? ['-'] : lines;
  }
}

import 'dart:io';
import 'package:flutter/foundation.dart';
import '../screens/screens.dart';
import 'package:qr/qr.dart';
import 'package:image/image.dart' as imgLib;

class ThermalPrinterService {
  BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;

  Future<List<BluetoothDevice>> getPairedDevices() async {
    return await bluetooth.getBondedDevices();
  }

  Future<bool> isBluetoothOn() async {
    return await bluetooth.isOn ?? false;
  }

  /// Generate QR string → PNG temp file → return path-nya
  /// Caller wajib delete file setelah print
  Future<String?> _generateQrTempFile(String data, {int sizePx = 200}) async {
    try {
      final qrCode = QrCode.fromData(
        data: data,
        errorCorrectLevel: QrErrorCorrectLevel.M,
      );
      final qrImage = QrImage(qrCode);
      final int moduleCount = qrCode.moduleCount;

      final imgLib.Image image = imgLib.Image(width: sizePx, height: sizePx);
      imgLib.fill(image, color: imgLib.ColorRgb8(255, 255, 255));

      final double moduleSize = sizePx / moduleCount;
      for (int row = 0; row < moduleCount; row++) {
        for (int col = 0; col < moduleCount; col++) {
          if (qrImage.isDark(row, col)) {
            final int x1 = (col * moduleSize).floor();
            final int y1 = (row * moduleSize).floor();
            final int x2 = ((col + 1) * moduleSize).ceil();
            final int y2 = ((row + 1) * moduleSize).ceil();
            for (int y = y1; y < y2; y++) {
              for (int x = x1; x < x2; x++) {
                if (x < sizePx && y < sizePx) {
                  image.setPixel(x, y, imgLib.ColorRgb8(0, 0, 0));
                }
              }
            }
          }
        }
      }

      final List<int> pngBytes = imgLib.encodePng(image);
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

  /// Print QR langsung dari string, auto cleanup temp file
  Future<void> _printQrCode(String data, {int sizePx = 200}) async {
    final String? path = await _generateQrTempFile(data, sizePx: sizePx);
    if (path != null) {
      bluetooth.printImage(path);
      await Future.delayed(const Duration(milliseconds: 400));
      try {
        await File(path).delete();
      } catch (_) {}
    } else {
      bluetooth.printCustom('[QR tidak tersedia]', 1, 1);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Cetak Struk PRODUKSI (internal laundry)
  // Key yang dipakai dari data:
  //   no_order, pelanggan, estimasi,
  //   items → List<Map> (layanan_nama, layanan_tipe, berat_kg, catatan)
  // ─────────────────────────────────────────────────────────────
  Future<void> printStrukProduksi(
    BluetoothDevice device,
    Map<String, dynamic> data,
  ) async {
    bool? isConnected = await bluetooth.isConnected;
    if (!(isConnected ?? false)) {
      await bluetooth.connect(device);
    }

    final bool is80mm = PrinterSettings.ukuranKertas == 80;
    final int lineWidth = is80mm ? 48 : 32;
    final String divider = '-' * lineWidth;
    final String doubleLine = '=' * lineWidth;

    final String noOrder = data['no_order']?.toString() ?? '-';
    final String pelanggan = data['pelanggan']?.toString() ?? '-';
    final String estimasi = data['estimasi']?.toString() ?? '-';
    final List<Map<String, dynamic>> items = _toListMap(data['items']);

    // ── Jarak atas ────────────────────────────────────────────────
    bluetooth.printNewLine();
    bluetooth.printNewLine();

    // ── HEADER ────────────────────────────────────────────────────
    bluetooth.printCustom('STRUK PRODUKSI', 3, 1);
    bluetooth.printCustom(doubleLine, 1, 1);

    // ── QR GEDE + NO ORDER ────────────────────────────────────────
    if (PrinterSettings.tampilkanQrStruk) {
      await _printQrCode(noOrder, sizePx: is80mm ? 200 : 150);
      bluetooth.printNewLine();
      bluetooth.printCustom(noOrder, 1, 1);
      bluetooth.printCustom("Scan untuk cek status", 1, 1);
      bluetooth.printCustom(divider, 1, 1);
    }

    // ── PELANGGAN ─────────────────────────────────────────────────
    bluetooth.printCustom('PELANGGAN :', 1, 0);
    bluetooth.printCustom(pelanggan, 3, 1);
    bluetooth.printCustom(divider, 1, 1);

    // ── CATATAN PER ITEM ──────────────────────────────────────────
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

    // ── ESTIMASI SELESAI ──────────────────────────────────────────
    bluetooth.printCustom('EST. SELESAI :', 1, 0);
    bluetooth.printCustom(estimasi, 2, 1);

    // ── Jarak bawah ───────────────────────────────────────────────
    bluetooth.printNewLine();
    bluetooth.printNewLine();
    bluetooth.printNewLine();
    bluetooth.printNewLine();
    bluetooth.printNewLine();
    bluetooth.paperCut();
  }

  // ─────────────────────────────────────────────────────────────
  // Cetak Struk Order Laundry
  // Key yang diterima:
  //   nama_laundry, alamat, no_hp_laundry,
  //   no_order, waktu, pelanggan, no_hp,
  //   items           → List<Map<String,dynamic>>
  //   biaya_tambahan  → List<Map<String,dynamic>>  (opsional)
  //   grand_total, dp_amount, sisa_tagihan, sudah_lunas,
  //   estimasi, admin, tanggal_cetak
  // ─────────────────────────────────────────────────────────────
  Future<void> printStruk(
    BluetoothDevice device,
    Map<String, dynamic> data,
  ) async {
    bool? isConnected = await bluetooth.isConnected;
    if (!(isConnected ?? false)) {
      await bluetooth.connect(device);
    }

    final bool is80mm = PrinterSettings.ukuranKertas == 80;
    final int lineWidth = is80mm ? 48 : 32;
    final String divider = '-' * lineWidth;
    final String doubleLine = '=' * lineWidth;

    // ── Info outlet ───────────────────────────────────────────────────────
    final String namaOutlet =
        (data['nama_laundry']?.toString().isNotEmpty == true
        ? data['nama_laundry'].toString()
        : OutletSettings.namaMadeenalaundry.isNotEmpty
        ? OutletSettings.namaMadeenalaundry
        : "Madeena Laundry");
    final String alamat = data['alamat']?.toString() ?? OutletSettings.alamat;
    final String noHpToko =
        data['no_hp_laundry']?.toString() ?? OutletSettings.noHpMadeenalaundry;
    final String logoPath = OutletSettings.logoPath;

    // ── Data order ────────────────────────────────────────────────────────
    final String noOrder = data['no_order']?.toString() ?? "-";
    final String waktu = data['waktu']?.toString() ?? "-";
    final String pelanggan = data['pelanggan']?.toString() ?? "-";
    final String noHpPelanggan = data['no_hp']?.toString() ?? "-";
    final String admin = data['admin']?.toString() ?? "-";
    final String estimasi = data['estimasi']?.toString() ?? "-";

    // ── Pesan kaki ────────────────────────────────────────────────────────
    final String pesanKaki = (data['pesan_kaki']?.toString().isNotEmpty == true
        ? data['pesan_kaki'].toString()
        : PrinterSettings.pesanKaki);

    final int grandTotal = _toInt(data['grand_total']);
    final int dpAmount = _toInt(data['dp_amount']);
    final int sisaTagihan = _toInt(data['sisa_tagihan']);
    final bool sudahLunas = data['sudah_lunas'] == true;

    // ── Diskon ────────────────────────────────────────────────────────────
    final int diskonNominal = _toInt(data['diskon_nominal']);
    final String diskonCatatan = data['diskon_catatan']?.toString() ?? '';
    final int subtotalSebelumDiskon = _toInt(data['subtotal_sebelum_diskon']);

    // ── Items & biaya tambahan ────────────────────────────────────────────
    final List<Map<String, dynamic>> items = _toListMap(data['items']);
    final List<Map<String, dynamic>> biayaTambahan = _toListMap(
      data['biaya_tambahan'],
    );

    // ── Rekening list ─────────────────────────────────────────────────────
    final List<Map<String, dynamic>> rekeningList = _toListMap(
      data['rekening_list'],
    );

    // ── Baca semua PrinterSettings ────────────────────────────────────────
    final bool namaBesar = PrinterSettings.namaPelangganBesar;
    final bool tampilAlamat = PrinterSettings.tampilkanAlamatOutlet;
    final bool tampilNoHpOutlet = PrinterSettings.tampilkanNoHpOutlet;
    final bool sembunyiNoHpPelanggan = PrinterSettings.sembunyikanNoHpPelanggan;
    final int ukuranLabelPelanggan = PrinterSettings.ukuranLabelPelanggan;

    // ── Jarak atas ────────────────────────────────────────────────────────
    bluetooth.printNewLine();
    bluetooth.printNewLine();
    bluetooth.printNewLine();

    // ── Logo ──────────────────────────────────────────────────────────────
    if (logoPath.isNotEmpty) {
      try {
        final File logoFile = File(logoPath);
        if (await logoFile.exists()) {
          bluetooth.printImage(logoPath);
        }
      } catch (e, stackTrace) {
        debugPrint('[ThermalPrinter] Gagal cetak logo: $e');
        debugPrint('$stackTrace');
      }
    }

    // ── HEADER ────────────────────────────────────────────────────────────
    bluetooth.printCustom(namaOutlet, 3, 1);

    if (tampilAlamat && alamat.isNotEmpty) {
      for (final baris in _wrapText(alamat, lineWidth)) {
        bluetooth.printCustom(baris, 1, 1);
      }
    }

    if (tampilNoHpOutlet && noHpToko.isNotEmpty) {
      bluetooth.printCustom("Telp: $noHpToko", 1, 1);
    }

    bluetooth.printCustom(doubleLine, 1, 1);
    bluetooth.printCustom("STRUK CUSTOMER", 2, 1);
    bluetooth.printCustom(doubleLine, 1, 1);

    // ── INFO ORDER ────────────────────────────────────────────────────────
    bluetooth.printCustom("No  : $noOrder", 1, 0);
    bluetooth.printCustom("Tgl : $waktu", 1, 0);
    bluetooth.printCustom(divider, 1, 1);

    // ── QR nomor order ────────────────────────────────────────────────────
    await _printQrCode(noOrder, sizePx: is80mm ? 200 : 150);
    bluetooth.printCustom(noOrder, 1, 1);
    bluetooth.printCustom("Scan untuk cek status", 1, 1);
    bluetooth.printCustom(divider, 1, 1);

    // ── PELANGGAN ─────────────────────────────────────────────────────────
    if (namaBesar) {
      bluetooth.printCustom(pelanggan, 3, 1);
    } else {
      bluetooth.printCustom("Pelanggan:", ukuranLabelPelanggan, 0);
      bluetooth.printCustom(pelanggan, 1, 0);
    }

    if (!sembunyiNoHpPelanggan &&
        noHpPelanggan.isNotEmpty &&
        noHpPelanggan != '-') {
      bluetooth.printCustom("HP  : $noHpPelanggan", 1, 0);
    }

    bluetooth.printCustom(divider, 1, 1);

    // ── LAYANAN ───────────────────────────────────────────────────────────
    bluetooth.printCustom("LAYANAN", 1, 0);
    bluetooth.printCustom(divider, 1, 1);

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final String layananNama = item['layanan_nama']?.toString() ?? "-";
      final String tipe = item['layanan_tipe']?.toString() ?? "";
      final double berat = _toDouble(item['berat_kg']);
      final int hargaSatuan = _toInt(item['harga_satuan']);
      final int subtotal = (berat * hargaSatuan).round();
      final String catatan = item['catatan']?.toString() ?? "";

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

      bluetooth.printCustom("${i + 1}. $layananNama", 1, 0);
      bluetooth.printCustom(
        "   $beratStr $satuan   ${_formatRupiah(hargaSatuan)}",
        1,
        0,
      );
      bluetooth.printCustom("   = ${_formatRupiah(subtotal)}", 1, 0);

      if (catatan.isNotEmpty) {
        bluetooth.printCustom("   Catatan:", 1, 0);
        for (final baris in _wrapText(catatan, lineWidth - 4)) {
          bluetooth.printCustom("   $baris", 1, 0);
        }
      }

      if (i < items.length - 1) {
        bluetooth.printCustom("- " * (lineWidth ~/ 2), 1, 1);
      }
    }

    bluetooth.printCustom(divider, 1, 1);

    // ── BIAYA TAMBAHAN (jika ada) ─────────────────────────────────────────
    if (biayaTambahan.isNotEmpty) {
      bluetooth.printCustom("BIAYA TAMBAHAN", 1, 0);
      bluetooth.printCustom(divider, 1, 1);
      int totalBiayaTambahan = 0;
      for (final b in biayaTambahan) {
        final String ket = b['keterangan']?.toString() ?? "-";
        final int nominal = _toInt(b['nominal']);
        final int rawQty = _toInt(b['qty']);
        final int qty = rawQty > 0 ? rawQty : 1;
        final int subtotal = nominal * qty;
        totalBiayaTambahan += subtotal;
        bluetooth.printCustom("  $ket (${qty}x)", 1, 0);
        bluetooth.printCustom("  = ${_formatRupiah(subtotal)}", 1, 0);
      }
      bluetooth.printCustom(divider, 1, 1);
      bluetooth.printCustom(
        "Total Tambahan: ${_formatRupiah(totalBiayaTambahan)}",
        1,
        0,
      );
      bluetooth.printCustom(divider, 1, 1);
    }

    // ── TOTAL ─────────────────────────────────────────────────────────────
    int totalLayanan = 0;
    for (final item in items) {
      totalLayanan +=
          (_toDouble(item['berat_kg']) * _toInt(item['harga_satuan'])).round();
    }

    bluetooth.printCustom("Layanan : ${_formatRupiah(totalLayanan)}", 1, 0);

    if (biayaTambahan.isNotEmpty) {
      final int totalBiaya = biayaTambahan.fold(0, (sum, b) {
        final int rawQty = _toInt(b['qty']);
        final int qty = rawQty > 0 ? rawQty : 1;
        return sum + _toInt(b['nominal']) * qty;
      });
      bluetooth.printCustom("Biaya Tmb: ${_formatRupiah(totalBiaya)}", 1, 0);
    }

    if (diskonNominal > 0) {
      bluetooth.printCustom(
        "Subtotal: ${_formatRupiah(subtotalSebelumDiskon)}",
        1,
        0,
      );
      final diskonLabel = diskonCatatan.isNotEmpty
          ? "Diskon($diskonCatatan)"
          : "Diskon";
      final diskonLine = "$diskonLabel: -${_formatRupiah(diskonNominal)}";
      if (diskonLine.length <= lineWidth) {
        bluetooth.printCustom(diskonLine, 1, 0);
      } else {
        bluetooth.printCustom("$diskonLabel:", 1, 0);
        bluetooth.printCustom("  -${_formatRupiah(diskonNominal)}", 1, 0);
      }
    }

    bluetooth.printCustom(doubleLine, 1, 1);
    bluetooth.printCustom("TOTAL   : ${_formatRupiah(grandTotal)}", 1, 0);
    bluetooth.printCustom(doubleLine, 1, 1);

    // ── PEMBAYARAN ────────────────────────────────────────────────────────
    if (sudahLunas) {
      bluetooth.printCustom("Dibayar : ${_formatRupiah(grandTotal)}", 1, 0);
      bluetooth.printCustom("Sisa    : Rp 0", 1, 0);
    } else {
      bluetooth.printCustom(
        "Dibayar : ${dpAmount > 0 ? _formatRupiah(dpAmount) : 'Rp 0'}",
        1,
        0,
      );
      bluetooth.printCustom("Sisa    : ${_formatRupiah(sisaTagihan)}", 1, 0);
    }
    bluetooth.printCustom(
      "Status  : ${sudahLunas ? 'LUNAS' : 'BELUM LUNAS'}",
      2,
      0,
    );
    bluetooth.printCustom(divider, 1, 1);

    // ── ESTIMASI SELESAI ──────────────────────────────────────────────────
    bluetooth.printCustom("Est Selesai : $estimasi", 1, 0);
    bluetooth.printCustom(doubleLine, 1, 1);

    // ── REKENING PEMBAYARAN (jika ada) ────────────────────────────────────
    if (rekeningList.isNotEmpty) {
      bluetooth.printCustom("PEMBAYARAN VIA", 2, 1);
      bluetooth.printCustom(doubleLine, 1, 1);

      for (final rek in rekeningList) {
        final String namaBank = rek['nama_bank']?.toString() ?? '';
        final String noRek = rek['no_rekening']?.toString() ?? '';
        final String atasNama = rek['atas_nama']?.toString() ?? '';
        final String qrUrl = rek['qr_url']?.toString() ?? '';
        final String qrString = rek['qr_string']?.toString() ?? '';

        if (namaBank.isNotEmpty) {
          bluetooth.printCustom(namaBank, 2, 1);
        }
        if (noRek.isNotEmpty) {
          bluetooth.printCustom(noRek, 1, 1);
        }
        if (atasNama.isNotEmpty) {
          bluetooth.printCustom("a.n $atasNama", 1, 1);
        }

        // ── Cetak QR: prioritaskan qr_string, fallback ke qr_url ─────────
        if (qrString.isNotEmpty) {
          // Generate QR dari string — lebih reliable, semua printer support
          await _printQrCode(qrString, sizePx: is80mm ? 200 : 150);
        } else if (qrUrl.isNotEmpty) {
          // Fallback: download dari URL lalu cetak sebagai gambar
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
                final Directory tempDir = Directory.systemTemp;
                final String tempPath =
                    '${tempDir.path}/qr_${DateTime.now().millisecondsSinceEpoch}.png';
                final File tempFile = File(tempPath);
                await tempFile.writeAsBytes(qrBytes, flush: true);

                if (await tempFile.exists() && (await tempFile.length()) > 0) {
                  bluetooth.printImage(tempPath);
                  await Future.delayed(const Duration(milliseconds: 300));
                  await tempFile.delete();
                } else {
                  bluetooth.printCustom("[QR gagal disimpan]", 1, 1);
                }
              } else {
                bluetooth.printCustom("[QR kosong]", 1, 1);
              }
            } else {
              client.close();
              bluetooth.printCustom("[QR tidak tersedia]", 1, 1);
            }
          } catch (e, stackTrace) {
            debugPrint('[ThermalPrinter] Gagal cetak QR ($qrUrl): $e');
            debugPrint('$stackTrace');
            bluetooth.printCustom("[QR tidak tersedia]", 1, 1);
          }
        }

        bluetooth.printCustom(divider, 1, 1);
      }
    }

    // ── FOOTER ────────────────────────────────────────────────────────────
    if (pesanKaki.isNotEmpty) {
      for (final baris in _wrapText(pesanKaki, lineWidth)) {
        bluetooth.printCustom(baris, 1, 1);
      }
    } else {
      bluetooth.printCustom("Terima kasih.", 1, 1);
    }
    bluetooth.printCustom("Dicetak oleh : $admin", 1, 0);

    // ── Jarak bawah ───────────────────────────────────────────────────────
    bluetooth.printNewLine();
    bluetooth.printNewLine();
    bluetooth.printNewLine();
    bluetooth.printNewLine();
    bluetooth.paperCut();
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

  /// Format angka ke Rupiah: Rp 33.600
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
      return "Rp ${buf.toString().split('').reversed.join('')}";
    } catch (_) {
      return "Rp 0";
    }
  }

  /// Wrap teks panjang supaya muat di kertas
  List<String> _wrapText(String text, int maxWidth) {
    if (text.isEmpty) return ["-"];
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
    return lines.isEmpty ? ["-"] : lines;
  }
}

import 'dart:io';
import '../screens/screens.dart';

class ThermalPrinterService {
  BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;

  Future<List<BluetoothDevice>> getPairedDevices() async {
    return await bluetooth.getBondedDevices();
  }

  Future<bool> isBluetoothOn() async {
    return await bluetooth.isOn ?? false;
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
    final String pesanKaki = data['pesan_kaki']?.toString() ?? '';

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

    // ── Pengaturan printer ────────────────────────────────────────────────
    // namaPelangganBesar: size 3 (besar), bukan caps lock
    final bool namaBesar = PrinterSettings.namaPelangganBesar;

    // ── Logo ──────────────────────────────────────────────────────────────
    if (logoPath.isNotEmpty) {
      try {
        final File logoFile = File(logoPath);
        if (await logoFile.exists()) {
          final List<int> logoBytes = await logoFile.readAsBytes();
          bluetooth.printImage(logoBytes as dynamic);
        }
      } catch (_) {}
    }

    // ── HEADER ────────────────────────────────────────────────────────────
    bluetooth.printCustom(namaOutlet, 3, 1); // size 3, center
    if (alamat.isNotEmpty) {
      for (final baris in _wrapText(alamat, 32)) {
        bluetooth.printCustom(baris, 1, 1); // size 1, center
      }
    }
    if (noHpToko.isNotEmpty) {
      bluetooth.printCustom("Telp: $noHpToko", 1, 1);
    }
    bluetooth.printCustom("================================", 1, 1);
    bluetooth.printCustom("STRUK CUSTOMER", 2, 1); // size 2, center
    bluetooth.printCustom("================================", 1, 1);

    // ── INFO ORDER ────────────────────────────────────────────────────────
    bluetooth.printCustom("No  : $noOrder", 1, 0);
    bluetooth.printCustom("Tgl : $waktu", 1, 0);
    bluetooth.printCustom("Pelanggan:", 1, 0);

    // Nama pelanggan: size 3 jika namaBesar, size 1 jika normal
    if (namaBesar) {
      // Nama besar seperti di foto — size 3, bold
      bluetooth.printCustom(pelanggan, 3, 1); // size 3, center
    } else {
      bluetooth.printCustom(pelanggan, 1, 0); // size 1, left
    }

    if (noHpPelanggan.isNotEmpty && noHpPelanggan != '-') {
      bluetooth.printCustom("HP  : $noHpPelanggan", 1, 0);
    }
    bluetooth.printCustom("--------------------------------", 1, 1);

    // ── LAYANAN ───────────────────────────────────────────────────────────
    bluetooth.printCustom("LAYANAN", 2, 0); // size 2
    bluetooth.printCustom("--------------------------------", 1, 1);

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

      bluetooth.printCustom("${i + 1}. $layananNama", 2, 0); // size 2
      bluetooth.printCustom(
        "   $beratStr $satuan   ${_formatRupiah(hargaSatuan)}",
        1,
        0,
      );
      bluetooth.printCustom("   = ${_formatRupiah(subtotal)}", 1, 0);

      if (catatan.isNotEmpty) {
        bluetooth.printCustom("   Catatan:", 1, 0);
        for (final baris in _wrapText(catatan, 28)) {
          bluetooth.printCustom("   $baris", 1, 0);
        }
      }

      if (i < items.length - 1) {
        bluetooth.printCustom("- - - - - - - - - - - - - - - -", 1, 1);
      }
    }

    bluetooth.printCustom("--------------------------------", 1, 1);

    // ── BIAYA TAMBAHAN (jika ada) ─────────────────────────────────────────
    if (biayaTambahan.isNotEmpty) {
      bluetooth.printCustom("BIAYA TAMBAHAN", 2, 0);
      bluetooth.printCustom("--------------------------------", 1, 1);
      int totalBiayaTambahan = 0;
      for (final b in biayaTambahan) {
        final String ket = b['keterangan']?.toString() ?? "-";
        final int nominal = _toInt(b['nominal']);
        final int qty = _toInt(b['qty'] ?? 1);
        final int subtotal = nominal * qty;
        totalBiayaTambahan += subtotal;
        bluetooth.printCustom("  $ket (${qty}x)", 1, 0);
        bluetooth.printCustom("  = ${_formatRupiah(subtotal)}", 1, 0);
      }
      bluetooth.printCustom("--------------------------------", 1, 1);
      bluetooth.printCustom(
        "Total Tambahan: ${_formatRupiah(totalBiayaTambahan)}",
        1,
        0,
      );
      bluetooth.printCustom("--------------------------------", 1, 1);
    }

    // ── TOTAL ─────────────────────────────────────────────────────────────
    int totalLayanan = 0;
    for (final item in items) {
      totalLayanan +=
          (_toDouble(item['berat_kg']) * _toInt(item['harga_satuan'])).round();
    }

    bluetooth.printCustom("Layanan : ${_formatRupiah(totalLayanan)}", 1, 0);

    if (biayaTambahan.isNotEmpty) {
      final int totalBiaya = biayaTambahan.fold(
        0,
        (sum, b) => sum + _toInt(b['nominal']) * _toInt(b['qty'] ?? 1),
      );
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
      if (diskonLine.length <= 32) {
        bluetooth.printCustom(diskonLine, 1, 0);
      } else {
        bluetooth.printCustom("$diskonLabel:", 1, 0);
        bluetooth.printCustom("  -${_formatRupiah(diskonNominal)}", 1, 0);
      }
    }

    bluetooth.printCustom("================================", 1, 1);
    bluetooth.printCustom(
      "TOTAL   : ${_formatRupiah(grandTotal)}",
      2,
      0,
    ); // size 2
    bluetooth.printCustom("================================", 1, 1);

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
      2, // size 2 biar jelas
      0,
    );
    bluetooth.printCustom("--------------------------------", 1, 1);

    // ── ESTIMASI SELESAI ──────────────────────────────────────────────────
    bluetooth.printCustom("Est Selesai : $estimasi", 1, 0);
    bluetooth.printCustom("================================", 1, 1);

    // ── REKENING PEMBAYARAN (jika ada) ────────────────────────────────────
    if (rekeningList.isNotEmpty) {
      bluetooth.printCustom("PEMBAYARAN VIA", 2, 1); // size 2, center
      bluetooth.printCustom("================================", 1, 1);

      for (final rek in rekeningList) {
        final String namaBank = rek['nama_bank']?.toString() ?? '';
        final String noRek = rek['no_rekening']?.toString() ?? '';
        final String atasNama = rek['atas_nama']?.toString() ?? '';
        final String qrUrl = rek['qr_url']?.toString() ?? '';

        if (namaBank.isNotEmpty) {
          bluetooth.printCustom(namaBank, 2, 1); // size 2, center
        }
        if (noRek.isNotEmpty) {
          bluetooth.printCustom(noRek, 1, 1);
        }
        if (atasNama.isNotEmpty) {
          bluetooth.printCustom("a.n $atasNama", 1, 1);
        }

        // ── Cetak QR Code dari URL ─────────────────────────────────────
        if (qrUrl.isNotEmpty) {
          try {
            // Download gambar QR dari URL lalu print sebagai image bytes
            final HttpClient client = HttpClient();
            final HttpClientRequest req = await client.getUrl(Uri.parse(qrUrl));
            final HttpClientResponse resp = await req.close();
            final List<int> qrBytes = [];
            await for (final chunk in resp) {
              qrBytes.addAll(chunk);
            }
            client.close();

            if (qrBytes.isNotEmpty) {
              // Print sebagai image — printer thermal perlu raw bytes
              bluetooth.printImage(qrBytes as dynamic);
            }
          } catch (_) {
            // Jika gagal download QR, skip — tidak crash
            bluetooth.printCustom("[QR tidak tersedia]", 1, 1);
          }
        }

        bluetooth.printCustom("--------------------------------", 1, 1);
      }
    }

    // ── FOOTER ────────────────────────────────────────────────────────────
    if (pesanKaki.isNotEmpty) {
      for (final baris in _wrapText(pesanKaki, 32)) {
        bluetooth.printCustom(baris, 1, 1);
      }
    } else {
      bluetooth.printCustom("Terima kasih.", 1, 1);
    }
    bluetooth.printCustom("Dicetak oleh : $admin", 1, 0);
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

  /// Wrap teks panjang supaya muat di kertas 58mm (~32 char)
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

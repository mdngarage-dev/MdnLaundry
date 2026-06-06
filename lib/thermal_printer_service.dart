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
  // Key yang diterima (dari PrintScreen / _showCetakDialog):
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

    final int grandTotal = _toInt(data['grand_total']);
    final int dpAmount = _toInt(data['dp_amount']);
    final int sisaTagihan = _toInt(data['sisa_tagihan']);
    final bool sudahLunas = data['sudah_lunas'] == true;

    // ── Items ─────────────────────────────────────────────────────────────
    final List<Map<String, dynamic>> items = _toListMap(data['items']);

    // ── Biaya tambahan ────────────────────────────────────────────────────
    final List<Map<String, dynamic>> biayaTambahan = _toListMap(
      data['biaya_tambahan'],
    );

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
    bluetooth.printCustom(namaOutlet, 3, 1);
    if (alamat.isNotEmpty) {
      for (final baris in _wrapText(alamat, 32)) {
        bluetooth.printCustom(baris, 0, 1);
      }
    }
    if (noHpToko.isNotEmpty) {
      bluetooth.printCustom("Telp: $noHpToko", 0, 1);
    }
    bluetooth.printCustom("================================", 0, 1);
    bluetooth.printCustom("STRUK CUSTOMER", 1, 1);
    bluetooth.printCustom("================================", 0, 1);

    // ── INFO ORDER ────────────────────────────────────────────────────────
    bluetooth.printLeftRight("No :", noOrder, 1);
    bluetooth.printLeftRight("Tgl :", waktu, 1);
    bluetooth.printLeftRight("Pelanggan :", pelanggan, 1);
    bluetooth.printLeftRight(
      "HP :",
      noHpPelanggan.isNotEmpty ? noHpPelanggan : "-",
      1,
    );
    bluetooth.printCustom("--------------------------------", 0, 1);

    // ── LAYANAN ───────────────────────────────────────────────────────────
    bluetooth.printCustom("LAYANAN", 1, 0);
    bluetooth.printCustom("--------------------------------", 0, 1);

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final String layananNama = item['layanan_nama']?.toString() ?? "-";
      final String tipe = item['layanan_tipe']?.toString() ?? "";
      final double berat = _toDouble(item['berat_kg']);
      final int hargaSatuan = _toInt(item['harga_satuan']);
      final int subtotal = (berat * hargaSatuan).round();
      final String catatan = item['catatan']?.toString() ?? "";

      // Satuan label
      String satuan;
      switch (tipe) {
        case 'kiloan':
          satuan = 'kg';
          break;
        case 'meter':
          satuan = 'm²';
          break;
        default:
          satuan = 'pcs';
          break;
      }

      // Format berat/jumlah: hilangkan desimal jika bulat
      final String beratStr = berat % 1 == 0
          ? berat.toStringAsFixed(0)
          : berat.toStringAsFixed(1).replaceAll('.', ',');

      bluetooth.printCustom("${i + 1}. $layananNama", 1, 0);
      bluetooth.printCustom(
        "   $beratStr $satuan   ${_formatRupiah(hargaSatuan)}",
        0,
        0,
      );
      bluetooth.printCustom("   = ${_formatRupiah(subtotal)}", 0, 0);

      if (catatan.isNotEmpty) {
        bluetooth.printCustom("   Catatan:", 0, 0);
        for (final baris in _wrapText(catatan, 28)) {
          bluetooth.printCustom("   $baris", 0, 0);
        }
      }

      if (i < items.length - 1) {
        bluetooth.printCustom("- - - - - - - - - - - - - - - -", 0, 1);
      }
    }

    bluetooth.printCustom("--------------------------------", 0, 1);

    // ── BIAYA TAMBAHAN (jika ada) ─────────────────────────────────────────
    if (biayaTambahan.isNotEmpty) {
      bluetooth.printCustom("BIAYA TAMBAHAN", 1, 0);
      bluetooth.printCustom("--------------------------------", 0, 1);
      int totalBiayaTambahan = 0;
      for (final b in biayaTambahan) {
        final String ket = b['keterangan']?.toString() ?? "-";
        final int nominal = _toInt(b['nominal']);
        final int qty = _toInt(b['qty'] ?? 1);
        final int subtotal = nominal * qty;
        totalBiayaTambahan += subtotal;
        bluetooth.printLeftRight("  $ket ($qty×)", _formatRupiah(subtotal), 0);
      }
      bluetooth.printCustom("--------------------------------", 0, 1);
      bluetooth.printLeftRight(
        "Total Biaya Tambahan",
        _formatRupiah(totalBiayaTambahan),
        0,
      );
      bluetooth.printCustom("--------------------------------", 0, 1);
    }

    // ── TOTAL ─────────────────────────────────────────────────────────────
    // Hitung total layanan saja (tanpa biaya tambahan) untuk baris "Layanan:"
    int totalLayanan = 0;
    for (final item in items) {
      totalLayanan +=
          (_toDouble(item['berat_kg']) * _toInt(item['harga_satuan'])).round();
    }

    bluetooth.printLeftRight("Layanan :", _formatRupiah(totalLayanan), 0);
    bluetooth.printLeftRight("TOTAL :", _formatRupiah(grandTotal), 1);
    bluetooth.printCustom("--------------------------------", 0, 1);

    // ── PEMBAYARAN ────────────────────────────────────────────────────────
    bluetooth.printLeftRight(
      "Dibayar :",
      dpAmount > 0 ? _formatRupiah(dpAmount) : "Rp 0",
      0,
    );
    bluetooth.printLeftRight("Sisa :", _formatRupiah(sisaTagihan), 0);
    bluetooth.printLeftRight(
      "Status :",
      sudahLunas ? "LUNAS" : "BELUM LUNAS",
      1,
    );
    bluetooth.printCustom("--------------------------------", 0, 1);

    // ── ESTIMASI SELESAI ──────────────────────────────────────────────────
    bluetooth.printLeftRight("Est Selesai :", estimasi, 0);
    bluetooth.printCustom("================================", 0, 1);

    // ── FOOTER ────────────────────────────────────────────────────────────
    bluetooth.printCustom("Terima kasih.", 0, 0);
    bluetooth.printLeftRight("Dicetak oleh :", admin, 0);
    bluetooth.printNewLine();
    bluetooth.printNewLine();
    bluetooth.paperCut();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Parse dynamic ke int (support String, int, double)
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

  /// Parse dynamic ke double
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

  /// Cast List<dynamic> ke List<Map<String,dynamic>> dengan aman
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

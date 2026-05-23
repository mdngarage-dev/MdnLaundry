import 'dart:io';

// Sesuaikan path import dengan struktur project Anda
import '../screens/screens.dart'; // atau 'order.dart' jika OutletSettings ada di sana

class ThermalPrinterService {
  BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;

  Future<List<BluetoothDevice>> getPairedDevices() async {
    return await bluetooth.getBondedDevices();
  }

  Future<bool> isBluetoothOn() async {
    return await bluetooth.isOn ?? false;
  }

  // ─────────────────────────────────────────────────────────────
  // Cetak Struk — semua info klinik dari OutletSettings
  // ─────────────────────────────────────────────────────────────
  Future<void> printStruk(
    BluetoothDevice device,
    Map<String, dynamic> data,
  ) async {
    bool? isConnected = await bluetooth.isConnected;
    if (!isConnected!) {
      await bluetooth.connect(device);
    }

    // ── Ambil data klinik dari OutletSettings ──
    final String namaKlinik = OutletSettings.namaKlinik.isNotEmpty
        ? OutletSettings.namaKlinik
        : "KLINIK";
    final String alamat = OutletSettings.alamat;
    final String noHp = OutletSettings.noHpKlinik;
    final String logoPath = OutletSettings.logoPath;

    // ── Ambil data kunjungan ──
    final String nip = data['nip']?.toString() ?? "-";
    final String nama = data['nama']?.toString() ?? "-";
    // ✅ Fix layanan null — coba berbagai key yang mungkin dikirim
    final String layanan = (data['layan']?.toString().isNotEmpty == true
        ? data['layan'].toString()
        : data['layanan']?.toString().isNotEmpty == true
        ? data['layanan'].toString()
        : "Umum");
    final String keluhan = data['keluhan']?.toString() ?? "-";
    final String tindakan = data['tindakan']?.toString() ?? "-";
    final String berat = data['berat']?.toString() ?? "-";
    final String biaya = data['biaya']?.toString() ?? "0";
    final String tanggal = data['tanggalCetak']?.toString().isNotEmpty == true
        ? data['tanggalCetak'].toString()
        : data['terakhir']?.toString() ?? "-";
    final String visitKe = data['visitKe']?.toString() ?? "-";
    final String tglKembali = data['tgl_kembali']?.toString() ?? "";

    // ── Format biaya Rp xxx.xxx (tanpa package intl) ──
    String biayaFormatted = biaya;
    try {
      final clean = biaya.replaceAll(RegExp(r'[^0-9]'), '');
      if (clean.isNotEmpty) {
        final angka = int.parse(clean);
        final s = angka.toString();
        final buf = StringBuffer();
        int count = 0;
        for (int i = s.length - 1; i >= 0; i--) {
          if (count > 0 && count % 3 == 0) buf.write('.');
          buf.write(s[i]);
          count++;
        }
        biayaFormatted = "Rp ${buf.toString().split('').reversed.join('')}";
      }
    } catch (_) {
      biayaFormatted = biaya.isNotEmpty ? "Rp $biaya" : "Rp 0";
    }

    // ── LOGO (jika ada file logo yang disimpan) ──
    if (logoPath.isNotEmpty) {
      try {
        final File logoFile = File(logoPath);
        if (await logoFile.exists()) {
          final List<int> logoBytes = await logoFile.readAsBytes();
          bluetooth.printImage(logoBytes as dynamic);
        }
      } catch (_) {
        // Gagal cetak logo → lanjut tanpa logo
      }
    }

    // ── HEADER ──
    bluetooth.printCustom(namaKlinik.toUpperCase(), 3, 1); // Besar, Tengah
    if (alamat.isNotEmpty) {
      for (final baris in _wrapText(alamat, 32)) {
        bluetooth.printCustom(baris, 0, 1);
      }
    }
    if (noHp.isNotEmpty) {
      bluetooth.printCustom("Telp: $noHp", 0, 1);
    }
    bluetooth.printCustom("================================", 0, 1);

    // ── INFO PASIEN ──
    bluetooth.printLeftRight("Tanggal:", tanggal, 1);
    bluetooth.printLeftRight("NIP    :", nip, 1);
    bluetooth.printLeftRight("Nama   :", nama, 1);
    bluetooth.printLeftRight("Visit  :", "Ke-$visitKe", 1);
    bluetooth.printCustom("--------------------------------", 0, 1);

    // ── DETAIL KUNJUNGAN ──
    bluetooth.printCustom("  DETAIL KUNJUNGAN  ", 1, 1);
    bluetooth.printCustom("--------------------------------", 0, 1);
    bluetooth.printLeftRight("Layanan :", layanan, 1);
    bluetooth.printLeftRight("Berat   :", "$berat kg", 1);

    // Keluhan — wrap jika panjang
    bluetooth.printCustom("Keluhan :", 1, 0);
    for (final baris in _wrapText(keluhan, 30)) {
      bluetooth.printCustom("  $baris", 0, 0);
    }

    // Tindakan — wrap jika panjang
    bluetooth.printCustom("Tindakan:", 1, 0);
    for (final baris in _wrapText(tindakan, 30)) {
      bluetooth.printCustom("  $baris", 0, 0);
    }

    bluetooth.printCustom("================================", 0, 1);

    // ── BIAYA ──
    bluetooth.printCustom("  TOTAL BIAYA  ", 1, 1);
    bluetooth.printCustom(biayaFormatted, 3, 1); // Besar, Tengah
    bluetooth.printCustom("================================", 0, 1);

    // ── JADWAL KEMBALI KB (jika KIA) ──
    if (tglKembali.isNotEmpty && tglKembali != "-") {
      bluetooth.printCustom("** Jadwal Kembali KB **", 1, 1);
      bluetooth.printCustom(tglKembali, 2, 1);
      bluetooth.printCustom("================================", 0, 1);
    }

    // ── FOOTER ──
    bluetooth.printCustom("Semoga Lekas Sembuh", 1, 1);
    bluetooth.printCustom("Terima kasih telah berkunjung", 0, 1);
    bluetooth.printCustom("ke $namaKlinik", 0, 1);
    bluetooth.printNewLine();
    bluetooth.printNewLine();
    bluetooth.paperCut();
  }

  // ── Helper: wrap teks panjang ke beberapa baris ──
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

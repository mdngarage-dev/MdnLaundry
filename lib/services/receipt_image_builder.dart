import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as imgLib;
import 'package:qr/qr.dart';

/// Pengaturan tampilan yang dipakai renderer (diisi dari PrinterSettings /
/// OutletSettings oleh ThermalPrinterService, supaya file ini mandiri).
class ReceiptOptions {
  final String namaOutlet;
  final String alamat;
  final String noHpOutlet;
  final String logoPath;
  final String pesanKaki;
  final String pesanPromo;
  final String footerPowered;
  final bool namaPelangganBesar;
  final bool sembunyikanNoHpPelanggan;
  final bool tampilkanQrTracking;
  final bool tampilkanQrWa;

  /// Nomor yang dipakai untuk QR WhatsApp (terpisah dari nomor yang dicetak).
  final String noHpWa;

  /// Pengali ukuran font (1.0 = desain dasar).
  final double fontScale;

  /// Tinggi maksimum potongan gambar (baris) untuk kertas 58mm.
  final int stripRows;

  const ReceiptOptions({
    required this.namaOutlet,
    required this.alamat,
    required this.noHpOutlet,
    required this.logoPath,
    required this.pesanKaki,
    required this.pesanPromo,
    required this.footerPowered,
    required this.namaPelangganBesar,
    required this.sembunyikanNoHpPelanggan,
    required this.tampilkanQrTracking,
    required this.tampilkanQrWa,
    required this.noHpWa,
    required this.fontScale,
    required this.stripRows,
  });
}

/// Menggambar struk customer jadi gambar 1-bit lalu memotongnya menjadi
/// potongan (strip) pendek supaya aman dikirim lewat Bluetooth.
///
/// Lebar: 384 px (kertas 58mm) / 576 px (kertas 80mm).
class ReceiptImageBuilder {
  ReceiptImageBuilder({required this.is80mm});

  final bool is80mm;

  static const ui.Color _black = ui.Color(0xFF000000);
  static const ui.Color _white = ui.Color(0xFFFFFFFF);

  /// Piksel dengan luminance di bawah ini dicetak hitam.
  static const int _threshold = 175;

  double get _w => is80mm ? 576 : 384;
  double get _s => _w / 384; // faktor skala terhadap desain 58mm
  double get _pad => 8 * _s;
  double get _contentW => _w - _pad * 2;

  late ui.Canvas _c;
  double _y = 0;
  double _fs = 1.0; // pengali font dari pengaturan

  // gambar yang harus dimuat sebelum menggambar (async)
  ui.Image? _logo;
  final Map<int, ui.Image> _rekeningImages = {};

  // ─────────────────────────────────────────────────────────────────────────
  //  PUBLIK
  // ─────────────────────────────────────────────────────────────────────────
  Future<List<Uint8List>> build(
    Map<String, dynamic> data,
    ReceiptOptions opt,
  ) async {
    _fs = opt.fontScale.clamp(0.8, 2.2).toDouble();
    await _preload(data, opt);

    final recorder = ui.PictureRecorder();
    _c = ui.Canvas(recorder);
    _y = 10 * _s;

    _drawAll(data, opt);

    final int height = (_y + 14 * _s).ceil();
    final ui.Picture picture = recorder.endRecording();
    final ui.Image full = await picture.toImage(_w.toInt(), height);
    final ByteData? raw = await full.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    full.dispose();
    _logo?.dispose();
    for (final im in _rekeningImages.values) {
      im.dispose();
    }
    if (raw == null) throw StateError('Gagal membaca piksel struk');

    return _toStrips(raw, _w.toInt(), height, opt.stripRows);
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  PRELOAD (logo + QR rekening berupa gambar URL)
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _preload(Map<String, dynamic> data, ReceiptOptions opt) async {
    if (opt.logoPath.isNotEmpty) {
      try {
        final f = File(opt.logoPath);
        if (await f.exists()) {
          final bytes = await f.readAsBytes();
          final codec = await ui.instantiateImageCodec(
            bytes,
            targetWidth: (_w * 0.42).round(),
          );
          final frame = await codec.getNextFrame();
          _logo = frame.image;
        }
      } catch (e) {
        debugPrint('[Receipt] Logo gagal dimuat: $e');
      }
    }

    final rek = _listMap(data['rekening_list']);
    for (int i = 0; i < rek.length; i++) {
      final qrString = rek[i]['qr_string']?.toString() ?? '';
      final qrUrl = rek[i]['qr_url']?.toString() ?? '';
      if (qrString.isNotEmpty || qrUrl.isEmpty) continue;
      try {
        final client = HttpClient()
          ..connectionTimeout = const Duration(seconds: 10);
        final req = await client.getUrl(Uri.parse(qrUrl));
        req.headers.set('Accept', 'image/*');
        final resp = await req.close();
        if (resp.statusCode == 200) {
          final b = BytesBuilder(copy: false);
          await for (final chunk in resp) {
            b.add(chunk);
          }
          client.close();
          final codec = await ui.instantiateImageCodec(
            b.takeBytes(),
            targetWidth: (_w * 0.55).round(),
          );
          final frame = await codec.getNextFrame();
          _rekeningImages[i] = frame.image;
        } else {
          client.close();
        }
      } catch (e) {
        debugPrint('[Receipt] QR rekening #$i gagal diunduh: $e');
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  LAYOUT UTAMA
  // ─────────────────────────────────────────────────────────────────────────
  void _drawAll(Map<String, dynamic> data, ReceiptOptions opt) {
    final String noOrder = data['no_order']?.toString() ?? '-';
    final String waktu = data['waktu']?.toString() ?? '-';
    final String pelanggan = data['pelanggan']?.toString() ?? '-';
    final String noHpPelanggan = data['no_hp']?.toString() ?? '';
    final String estimasi = data['estimasi']?.toString() ?? '-';
    final String admin = data['admin']?.toString() ?? '';

    final int grandTotal = _toInt(data['grand_total']);
    final int dpAmount = _toInt(data['dp_amount']);
    final int sisaTagihan = _toInt(data['sisa_tagihan']);
    final bool sudahLunas = data['sudah_lunas'] == true;
    final int diskonNominal = _toInt(data['diskon_nominal']);
    final String diskonCatatan = data['diskon_catatan']?.toString() ?? '';
    final int subtotalSebelumDiskon = _toInt(data['subtotal_sebelum_diskon']);

    final items = _listMap(data['items']);
    final biaya = _listMap(data['biaya_tambahan']);
    final rekening = _listMap(data['rekening_list']);

    // ── Logo ────────────────────────────────────────────────────────────
    if (_logo != null) {
      final double maxH = 120 * _s;
      final double maxW = _contentW * 0.5;
      final double iw = _logo!.width.toDouble();
      final double ih = _logo!.height.toDouble();
      final double k = math.min(maxW / iw, maxH / ih);
      final double dw = iw * k;
      final double dh = ih * k;
      _c.drawImageRect(
        _logo!,
        ui.Rect.fromLTWH(0, 0, iw, ih),
        ui.Rect.fromLTWH((_w - dw) / 2, _y, dw, dh),
        ui.Paint()..filterQuality = ui.FilterQuality.high,
      );
      _y += dh + 8 * _s;
    }

    // ── Header outlet ──────────────────────────────────────────────────
    _centerText(
      opt.namaOutlet.toUpperCase(),
      23,
      weight: FontWeight.w900,
      maxLines: 2,
    );
    _y += 3 * _s;
    if (opt.alamat.isNotEmpty) {
      _centerText(opt.alamat, 13.5, weight: FontWeight.w600, maxLines: 3);
    }
    if (opt.noHpOutlet.isNotEmpty) {
      _y += 2 * _s;
      _phoneLine(opt.noHpOutlet);
    }
    _y += 4 * _s;

    // ── No nota ─────────────────────────────────────────────────────────
    _dashed();
    _rowText(
      'NO. NOTA',
      noOrder,
      size: 13.5,
      leftWeight: FontWeight.w800,
      rightWeight: FontWeight.w800,
      letterSpacing: 0.6,
    );
    _dashed();

    // ── Nama pelanggan ──────────────────────────────────────────────────
    _y += 6 * _s;
    if (opt.namaPelangganBesar) {
      _centerText(pelanggan, 34, weight: FontWeight.w900, maxLines: 2);
    } else {
      _centerText(pelanggan, 22, weight: FontWeight.w800, maxLines: 2);
    }
    if (!opt.sembunyikanNoHpPelanggan &&
        noHpPelanggan.isNotEmpty &&
        noHpPelanggan != '-') {
      _y += 1 * _s;
      _centerText(noHpPelanggan, 13.5, weight: FontWeight.w600);
    }
    _y += 6 * _s;

    // ── Tanggal & estimasi ──────────────────────────────────────────────
    _dashed();
    _rowText(
      'TANGGAL MASUK',
      waktu,
      size: 13.5,
      leftWeight: FontWeight.w800,
      rightWeight: FontWeight.w600,
      letterSpacing: 0.4,
    );
    _dashed();
    _rowText(
      'ESTIMASI SELESAI',
      estimasi,
      size: 13.5,
      leftWeight: FontWeight.w800,
      rightWeight: FontWeight.w600,
      letterSpacing: 0.4,
      subtitle: _estimasiSubtitle(items),
    );
    _y += 4 * _s;

    // ── Rincian layanan ─────────────────────────────────────────────────
    _solid();
    _rowText(
      'RINCIAN LAYANAN',
      'TOTAL',
      size: 13.5,
      leftWeight: FontWeight.w700,
      rightWeight: FontWeight.w700,
    );
    _solid();
    _y += 6 * _s;

    for (final item in items) {
      final String nama = item['layanan_nama']?.toString() ?? '-';
      final String tipe = item['layanan_tipe']?.toString() ?? '';
      final double qty = _toDouble(item['berat_kg']);
      final int harga = _toInt(item['harga_satuan']);
      final int subtotal = (qty * harga).round();
      final String catatan = item['catatan']?.toString() ?? '';
      final String satuan = tipe == 'kiloan'
          ? 'kg'
          : tipe == 'meter'
          ? 'm2'
          : 'pcs';

      _rowText(
        nama,
        _rp(subtotal),
        size: 15.5,
        leftWeight: FontWeight.w700,
        rightWeight: FontWeight.w600,
        subtitle: '${_qty(qty)} $satuan × ${_rp(harga)}',
      );
      if (catatan.isNotEmpty) {
        _leftText('Catatan: $catatan', 12, style: FontStyle.italic);
      }
      _y += 6 * _s;
    }

    if (biaya.isNotEmpty) {
      _leftText('Biaya tambahan', 13, weight: FontWeight.w800);
      _y += 2 * _s;
      for (final b in biaya) {
        final String ket = b['keterangan']?.toString() ?? '-';
        final int nominal = _toInt(b['nominal']);
        final int rawQty = _toInt(b['qty']);
        final int qty = rawQty > 0 ? rawQty : 1;
        _rowText(
          qty > 1 ? '$ket (${qty}x)' : ket,
          _rp(nominal * qty),
          size: 14.5,
          leftWeight: FontWeight.w600,
          rightWeight: FontWeight.w600,
        );
        _y += 3 * _s;
      }
    }

    if (diskonNominal > 0) {
      _y += 2 * _s;
      _rowText(
        'Subtotal',
        _rp(subtotalSebelumDiskon),
        size: 14,
        leftWeight: FontWeight.w600,
        rightWeight: FontWeight.w600,
      );
      _rowText(
        diskonCatatan.isNotEmpty ? 'Diskon ($diskonCatatan)' : 'Diskon',
        '- ${_rp(diskonNominal)}',
        size: 14,
        leftWeight: FontWeight.w700,
        rightWeight: FontWeight.w700,
      );
      _y += 2 * _s;
    }

    // ── Kotak total ─────────────────────────────────────────────────────
    _y += 4 * _s;
    final String statusBayar = sudahLunas
        ? 'Lunas'
        : (dpAmount > 0 ? 'DP ${_rp(dpAmount)}' : 'Belum dibayar');
    _totalBox(
      total: _rp(grandTotal),
      status: statusBayar,
      sisa: (!sudahLunas && dpAmount > 0) ? _rp(sisaTagihan) : null,
    );
    _y += 10 * _s;

    // ── Rekening pembayaran ─────────────────────────────────────────────
    if (rekening.isNotEmpty) {
      _dashed();
      _centerText(
        'PEMBAYARAN VIA',
        14,
        weight: FontWeight.w900,
        letterSpacing: 1.0,
      );
      _y += 4 * _s;
      for (int i = 0; i < rekening.length; i++) {
        final rek = rekening[i];
        final String namaBank = rek['nama_bank']?.toString() ?? '';
        final String noRek = rek['no_rekening']?.toString() ?? '';
        final String atasNama = rek['atas_nama']?.toString() ?? '';
        final String qrString = rek['qr_string']?.toString() ?? '';

        if (namaBank.isNotEmpty) {
          _centerText(namaBank, 17, weight: FontWeight.w900);
        }
        if (noRek.isNotEmpty) {
          _centerText(noRek, 15.5, weight: FontWeight.w700);
        }
        if (atasNama.isNotEmpty) {
          _centerText('a.n $atasNama', 13, weight: FontWeight.w600);
        }

        bool adaQr = false;
        if (qrString.isNotEmpty) {
          _y += 6 * _s;
          adaQr = _drawQrCentered(qrString, _w / 2, _contentW * 0.72);
        } else if (_rekeningImages.containsKey(i)) {
          _y += 6 * _s;
          _drawImageCentered(_rekeningImages[i]!, _contentW * 0.62);
          adaQr = true;
        }
        if (adaQr) {
          _y += 4 * _s;
          _centerText('Scan untuk pembayaran', 12, weight: FontWeight.w600);
        }
        if (i < rekening.length - 1) {
          _y += 4 * _s;
          _dashed(gap: 3);
        }
      }
      _y += 4 * _s;
    }

    // ── Pesan promo (opsional, di atas QR) ──────────────────────────────
    _dashed();
    final String promo = opt.pesanPromo.trim();
    if (promo.isNotEmpty) {
      for (final line in promo.split('\n')) {
        if (line.trim().isEmpty) continue;
        _centerText(line.trim(), 13.5, weight: FontWeight.w700, maxLines: 4);
      }
      _dashed();
    }

    // ── QR tracking + QR WhatsApp ───────────────────────────────────────
    final String? waLink = opt.tampilkanQrWa ? _waLink(opt.noHpWa) : null;
    final bool qrTrack = opt.tampilkanQrTracking && noOrder != '-';
    if (qrTrack || waLink != null) {
      _y += 4 * _s;
      _qrPair(
        trackData: qrTrack ? noOrder : null,
        waData: waLink,
      );
      _y += 6 * _s;
      _dashed();
    }

    // ── Penutup: pesan kaki dari pengaturan (default bila kosong) ────────
    _y += 6 * _s;
    final String pesanKaki = opt.pesanKaki.trim();
    if (pesanKaki.isEmpty) {
      _centerText(
        'Terima kasih. Sampai jumpa kembali.',
        13.5,
        weight: FontWeight.w700,
        maxLines: 3,
      );
    } else {
      for (final line in pesanKaki.split('\n')) {
        if (line.trim().isEmpty) continue;
        _centerText(line.trim(), 13.5, weight: FontWeight.w700, maxLines: 4);
      }
    }
    _y += 6 * _s;
    if (admin.isNotEmpty && admin != '-') {
      _centerText('Dicetak oleh : $admin', 11.5, weight: FontWeight.w500);
    }
    if (opt.footerPowered.trim().isNotEmpty) {
      _centerText(
        opt.footerPowered.trim(),
        11.5,
        weight: FontWeight.w500,
        maxLines: 2,
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  KOMPONEN GAMBAR
  // ─────────────────────────────────────────────────────────────────────────
  TextPainter _tp(
    String text,
    double size, {
    FontWeight weight = FontWeight.w500,
    FontStyle? style,
    TextAlign align = TextAlign.left,
    double? maxW,
    double letterSpacing = 0,
    int maxLines = 6,
    double minW = 0,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: _black,
          fontSize: size * _s * _fs,
          fontWeight: weight,
          fontStyle: style,
          letterSpacing: letterSpacing * _s,
          height: 1.18,
        ),
      ),
      textAlign: align,
      textDirection: TextDirection.ltr,
      maxLines: maxLines,
      ellipsis: '…',
    );
    tp.layout(minWidth: minW, maxWidth: maxW ?? _contentW);
    return tp;
  }

  /// Seperti [_tp] tapi font otomatis dikecilkan bila tidak muat dalam satu
  /// baris — dipakai untuk nominal supaya angka tidak pernah terpotong "…".
  TextPainter _tpFit(
    String text,
    double size, {
    FontWeight weight = FontWeight.w500,
    required double maxW,
  }) {
    double sz = size;
    TextPainter tp = _tp(text, sz, weight: weight, maxLines: 1, maxW: 100000);
    for (int i = 0; i < 8 && tp.width > maxW; i++) {
      sz *= 0.92;
      tp = _tp(text, sz, weight: weight, maxLines: 1, maxW: 100000);
    }
    return tp;
  }

  void _paint(TextPainter tp, double x, double y) => tp.paint(_c, ui.Offset(x, y));

  /// Teks rata tengah memenuhi lebar konten.
  void _centerText(
    String text,
    double size, {
    FontWeight weight = FontWeight.w500,
    double letterSpacing = 0,
    int maxLines = 4,
  }) {
    final tp = _tp(
      text,
      size,
      weight: weight,
      align: TextAlign.center,
      letterSpacing: letterSpacing,
      maxLines: maxLines,
      minW: _contentW,
    );
    _paint(tp, _pad, _y);
    _y += tp.height + 1 * _s;
  }

  /// Teks rata kiri.
  void _leftText(
    String text,
    double size, {
    FontWeight weight = FontWeight.w500,
    FontStyle? style,
  }) {
    final tp = _tp(text, size, weight: weight, style: style, maxLines: 4);
    _paint(tp, _pad, _y);
    _y += tp.height + 1 * _s;
  }

  /// Baris "kiri ........ kanan" + subjudul kecil di bawah kiri (opsional).
  void _rowText(
    String left,
    String right, {
    required double size,
    FontWeight leftWeight = FontWeight.w500,
    FontWeight rightWeight = FontWeight.w500,
    double letterSpacing = 0,
    String? subtitle,
  }) {
    final rtp = _tp(
      right,
      size,
      weight: rightWeight,
      letterSpacing: letterSpacing,
      maxLines: 2,
      maxW: _contentW * 0.62,
    );
    final double leftMax = _contentW - rtp.width - 10 * _s;
    final ltp = _tp(
      left,
      size,
      weight: leftWeight,
      letterSpacing: letterSpacing,
      maxLines: 3,
      maxW: leftMax < 40 * _s ? 40 * _s : leftMax,
    );
    _paint(ltp, _pad, _y);
    _paint(rtp, _w - _pad - rtp.width, _y);
    double h = math.max(ltp.height, rtp.height);

    if (subtitle != null && subtitle.isNotEmpty) {
      final stp = _tp(
        subtitle,
        size * 0.78,
        weight: FontWeight.w500,
        maxLines: 2,
        maxW: leftMax < 40 * _s ? 40 * _s : leftMax,
      );
      _paint(stp, _pad, _y + ltp.height);
      h = math.max(h, ltp.height + stp.height);
    }
    _y += h + 2 * _s;
  }

  void _phoneLine(String phone) {
    final tp = _tp(phone, 14.5, weight: FontWeight.w700);
    final double icon = 15 * _s * _fs;
    final double gap = 6 * _s;
    final double total = icon + gap + tp.width;
    final double x0 = (_w - total) / 2;
    _drawChatIcon(x0, _y + (tp.height - icon) / 2, icon);
    _paint(tp, x0 + icon + gap, _y);
    _y += tp.height + 1 * _s;
  }

  void _drawChatIcon(double x, double y, double size) {
    final stroke = ui.Paint()
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 1.7 * _s
      ..color = _black
      ..isAntiAlias = true;
    final double bh = size * 0.78;
    _c.drawRRect(
      ui.RRect.fromRectAndRadius(
        ui.Rect.fromLTWH(x, y, size, bh),
        ui.Radius.circular(2.5 * _s),
      ),
      stroke,
    );
    final tail = ui.Path()
      ..moveTo(x + size * 0.22, y + bh)
      ..lineTo(x + size * 0.18, y + size)
      ..lineTo(x + size * 0.48, y + bh);
    _c.drawPath(tail, stroke);
    final fill = ui.Paint()..color = _black;
    for (int i = 0; i < 3; i++) {
      _c.drawCircle(
        ui.Offset(x + size * (0.28 + i * 0.22), y + bh / 2),
        1.2 * _s,
        fill,
      );
    }
  }

  void _dashed({double gap = 5}) {
    _y += gap * _s;
    final p = ui.Paint()
      ..color = _black
      ..strokeWidth = 1.7 * _s
      ..isAntiAlias = false;
    double x = _pad;
    final double end = _w - _pad;
    while (x < end) {
      _c.drawLine(
        ui.Offset(x, _y),
        ui.Offset(math.min(x + 3.5 * _s, end), _y),
        p,
      );
      x += 6.5 * _s;
    }
    _y += gap * _s;
  }

  void _solid() {
    _y += 2 * _s;
    _c.drawLine(
      ui.Offset(_pad, _y),
      ui.Offset(_w - _pad, _y),
      ui.Paint()
        ..color = _black
        ..strokeWidth = 1.6 * _s
        ..isAntiAlias = false,
    );
    _y += 4 * _s;
  }

  /// Kotak TOTAL + status pembayaran (seperti pada contoh).
  void _totalBox({required String total, required String status, String? sisa}) {
    final double inset = 3 * _s;
    final double padX = 11 * _s;
    final double padY = 8 * _s;
    final double innerW = _contentW - inset * 2 - padX * 2;

    final lblTotal = _tp('TOTAL', 13.5, weight: FontWeight.w900, letterSpacing: 0.8);
    final valTotal = _tpFit(
      total,
      26,
      weight: FontWeight.w900,
      maxW: innerW - lblTotal.width - 8 * _s,
    );
    final lblBayar = _tp('PEMBAYARAN', 13.5, weight: FontWeight.w900, letterSpacing: 0.8);
    final valBayar = _tpFit(
      status,
      15,
      weight: FontWeight.w800,
      maxW: innerW - lblBayar.width - 8 * _s,
    );
    TextPainter? lblSisa;
    TextPainter? valSisa;
    if (sisa != null) {
      lblSisa = _tp('SISA', 13.5, weight: FontWeight.w900, letterSpacing: 0.8);
      valSisa = _tpFit(
        sisa,
        15,
        weight: FontWeight.w800,
        maxW: innerW - lblSisa.width - 8 * _s,
      );
    }

    final double row1 = math.max(lblTotal.height, valTotal.height);
    final double row2 = math.max(lblBayar.height, valBayar.height);
    final double row3 = (lblSisa != null && valSisa != null)
        ? math.max(lblSisa.height, valSisa.height)
        : 0;
    final double gap = 6 * _s;
    final double boxH =
        padY * 2 + row1 + gap + row2 + (row3 > 0 ? gap + row3 : 0);

    final double left = _pad + inset;
    final double right = _w - _pad - inset;
    final rect = ui.Rect.fromLTRB(left, _y, right, _y + boxH);
    _c.drawRRect(
      ui.RRect.fromRectAndRadius(rect, ui.Radius.circular(9 * _s)),
      ui.Paint()
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 2.6 * _s
        ..color = _black
        ..isAntiAlias = true,
    );

    double yy = _y + padY;
    void line(TextPainter l, TextPainter v, double h) {
      _paint(l, left + padX, yy + (h - l.height) / 2);
      _paint(v, right - padX - v.width, yy + (h - v.height) / 2);
      yy += h + gap;
    }

    line(lblTotal, valTotal, row1);
    line(lblBayar, valBayar, row2);
    if (lblSisa != null && valSisa != null) {
      line(lblSisa, valSisa, row3);
    }
    _y += boxH;
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  QR
  // ─────────────────────────────────────────────────────────────────────────
  /// Gambar QR dengan ukuran modul bulat (tajam). Return false bila tidak muat.
  bool _drawQrCentered(String data, double cx, double maxSize) {
    final qr = QrCode.fromData(
      data: data,
      errorCorrectLevel: data.length > 60
          ? QrErrorCorrectLevel.L
          : QrErrorCorrectLevel.M,
    );
    final img = QrImage(qr);
    final int n = qr.moduleCount;
    final int mod = (maxSize / n).floor();
    if (mod < 2) return false; // terlalu rapat untuk printer thermal
    final double size = (mod * n).toDouble();
    final double x0 = (cx - size / 2).roundToDouble();
    final double y0 = _y.roundToDouble();
    final paint = ui.Paint()
      ..color = _black
      ..isAntiAlias = false;
    for (int r = 0; r < n; r++) {
      for (int col = 0; col < n; col++) {
        if (img.isDark(r, col)) {
          _c.drawRect(
            ui.Rect.fromLTWH(x0 + col * mod, y0 + r * mod, mod.toDouble(), mod.toDouble()),
            paint,
          );
        }
      }
    }
    _y = y0 + size;
    return true;
  }

  void _drawImageCentered(ui.Image im, double maxSize) {
    final double iw = im.width.toDouble();
    final double ih = im.height.toDouble();
    final double k = math.min(maxSize / iw, maxSize / ih);
    final double dw = iw * k;
    final double dh = ih * k;
    _c.drawImageRect(
      im,
      ui.Rect.fromLTWH(0, 0, iw, ih),
      ui.Rect.fromLTWH((_w - dw) / 2, _y, dw, dh),
      ui.Paint()..filterQuality = ui.FilterQuality.high,
    );
    _y += dh;
  }

  /// Dua QR berdampingan: LACAK ORDER (kiri) & WHATSAPP OUTLET (kanan).
  /// Bila hanya satu, QR-nya ditaruh di tengah.
  void _qrPair({String? trackData, String? waData}) {
    final cols = <_QrCol>[
      if (trackData != null)
        _QrCol(trackData, 'LACAK ORDER', 'Pindai QR live tracking'),
      if (waData != null)
        _QrCol(waData, 'WHATSAPP OUTLET', 'Pindai untuk chat outlet.'),
    ];
    if (cols.isEmpty) return;

    final double slotW = _contentW / 2;
    final double qrMax = slotW - 22 * _s;
    final double top = _y;
    double bottom = top;

    for (int i = 0; i < cols.length; i++) {
      final double cx = cols.length == 1
          ? _w / 2
          : _pad + slotW * i + slotW / 2;
      _y = top;
      final bool ok = _drawQrCentered(cols[i].data, cx, qrMax);
      if (ok) {
        _y += 6 * _s;
      }
      final t1 = _tp(
        cols[i].title,
        12.5,
        weight: FontWeight.w900,
        align: TextAlign.center,
        maxW: slotW - 4 * _s,
        minW: slotW - 4 * _s,
        letterSpacing: 0.3,
        maxLines: 2,
      );
      _paint(t1, cx - (slotW - 4 * _s) / 2, _y);
      _y += t1.height;
      final t2 = _tp(
        cols[i].sub,
        10.5,
        weight: FontWeight.w500,
        align: TextAlign.center,
        maxW: slotW - 4 * _s,
        minW: slotW - 4 * _s,
        maxLines: 3,
      );
      _paint(t2, cx - (slotW - 4 * _s) / 2, _y);
      _y += t2.height;
      bottom = math.max(bottom, _y);
    }
    _y = bottom;
  }

  String? _waLink(String phone) {
    var d = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (d.isEmpty) return null;
    if (d.startsWith('0')) {
      d = '62${d.substring(1)}';
    } else if (d.startsWith('8')) {
      d = '62$d';
    }
    if (d.length < 8) return null;
    return 'https://wa.me/$d';
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  PIKSEL -> STRIP PNG 1-BIT
  // ─────────────────────────────────────────────────────────────────────────
  List<Uint8List> _toStrips(ByteData raw, int width, int height, int stripRows) {
    // 1) threshold ke hitam/putih
    final Uint8List px = raw.buffer.asUint8List(raw.offsetInBytes, raw.lengthInBytes);
    final Uint8List bw = Uint8List(width * height); // 1 = hitam
    final List<bool> blank = List<bool>.filled(height, true);
    for (int y = 0; y < height; y++) {
      final int rowStart = y * width;
      for (int x = 0; x < width; x++) {
        final int i = (rowStart + x) * 4;
        final int a = px[i + 3];
        // komposit ke latar putih
        final int r = (px[i] * a + 255 * (255 - a)) ~/ 255;
        final int g = (px[i + 1] * a + 255 * (255 - a)) ~/ 255;
        final int b = (px[i + 2] * a + 255 * (255 - a)) ~/ 255;
        final int lum = (r * 299 + g * 587 + b * 114) ~/ 1000;
        if (lum < _threshold) {
          bw[rowStart + x] = 1;
          blank[y] = false;
        }
      }
    }

    // 2) tentukan titik potong; utamakan baris kosong supaya teks tidak terbelah
    // kertas 80mm = baris lebih lebar (72 byte/baris vs 48) → potongan dikecilkan
    final int maxRows = math.max(48, is80mm ? (stripRows * 0.7).round() : stripRows);
    final int minRows = (maxRows * 0.55).round();
    final List<int> cuts = <int>[0];
    int start = 0;
    while (height - start > maxRows) {
      int cut = start + maxRows;
      for (int y = start + maxRows; y >= start + minRows; y--) {
        if (blank[y]) {
          cut = y;
          break;
        }
      }
      cuts.add(cut);
      start = cut;
    }
    cuts.add(height);

    // 3) encode tiap strip jadi PNG
    final List<Uint8List> out = <Uint8List>[];
    for (int k = 0; k < cuts.length - 1; k++) {
      final int y0 = cuts[k];
      final int y1 = cuts[k + 1];
      final int h = y1 - y0;
      if (h <= 0) continue;
      final imgLib.Image strip = imgLib.Image(width: width, height: h);
      for (int y = 0; y < h; y++) {
        final int rowStart = (y0 + y) * width;
        for (int x = 0; x < width; x++) {
          final int v = bw[rowStart + x] == 1 ? 0 : 255;
          strip.setPixelRgb(x, y, v, v, v);
        }
      }
      out.add(Uint8List.fromList(imgLib.encodePng(strip)));
    }
    return out;
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  HELPERS DATA
  // ─────────────────────────────────────────────────────────────────────────
  String _estimasiSubtitle(List<Map<String, dynamic>> items) {
    if (items.isEmpty) return '';
    Map<String, dynamic> pick = items.first;
    int best = _toInt(pick['durasi_jam']);
    for (final it in items) {
      final int d = _toInt(it['durasi_jam']);
      if (d > best) {
        best = d;
        pick = it;
      }
    }
    final String nama = pick['layanan_nama']?.toString() ?? '';
    if (nama.isEmpty) return '';
    if (best <= 0) return nama;
    final String durasi = best % 24 == 0 ? '${best ~/ 24} hari' : '$best jam';
    return '$nama · $durasi';
  }

  String _rp(int v) {
    final bool neg = v < 0;
    final String s = v.abs().toString();
    final StringBuffer b = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
      b.write(s[i]);
    }
    return '${neg ? '-' : ''}Rp ${b.toString()}';
  }

  String _qty(double v) {
    String s = v.toStringAsFixed(2);
    if (s.contains('.')) {
      s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
    }
    return s.replaceAll('.', ',');
  }

  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.round();
    return int.tryParse(v.toString().replaceAll(RegExp(r'[^0-9\-]'), '')) ?? 0;
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().replaceAll(',', '.')) ?? 0;
  }

  List<Map<String, dynamic>> _listMap(dynamic raw) {
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
}

class _QrCol {
  final String data;
  final String title;
  final String sub;
  const _QrCol(this.data, this.title, this.sub);
}

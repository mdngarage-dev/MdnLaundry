import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:excel/excel.dart' as xls;
import 'package:mdnlaundry_project/screens/main_screens.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart' as html;

// ─────────────────────────────────────────────────────────────────────────────
// CONSTANTS
// ─────────────────────────────────────────────────────────────────────────────
final defaultBgColor = xls.ExcelColor.fromHexString('#FFFFFF'); // #FFFFFF
final defaultFontColor = xls.ExcelColor.fromHexString('#111827'); // #111827

// ─────────────────────────────────────────────────────────────────────────────
// MODEL
// ─────────────────────────────────────────────────────────────────────────────
class Layanan {
  final String id;
  final String nama;
  final String tipe; // 'satuan' | 'kiloan' | 'meter'
  final double harga;
  final int durasiJam; // selalu disimpan dalam jam

  const Layanan({
    required this.id,
    required this.nama,
    required this.tipe,
    required this.harga,
    required this.durasiJam,
  });

  factory Layanan.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Layanan(
      id: doc.id,
      nama: d['nama'] ?? '',
      tipe: d['tipe'] ?? 'kiloan',
      harga: (d['harga'] ?? 0).toDouble(),
      durasiJam: d['durasi_jam'] ?? 24,
    );
  }

  Map<String, dynamic> toMap() => {
    'nama': nama,
    'tipe': tipe,
    'harga': harga,
    'durasi_jam': durasiJam,
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// MAIN SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class LayananScreen extends StatefulWidget {
  final bool autoOpenForm;
  final String storeId;
  final String outletId;
  const LayananScreen({
    super.key,
    this.autoOpenForm = false,
    required this.storeId,
    required this.outletId,
  });

  @override
  State<LayananScreen> createState() => _LayananScreenState();
}

class _LayananScreenState extends State<LayananScreen> {
  final _firestore = FirebaseFirestore.instance;
  String _filterTipe = 'semua';
  bool _isExporting = false;

  // ── helper warna & label tipe ─────────────────────────────────────────────
  Color _tipeColor(String tipe, BuildContext context) {
    switch (tipe) {
      case 'kiloan':
        return Colors.blue;
      case 'satuan':
        return Colors.green;
      case 'meter':
        return Colors.orange;
      default:
        return Theme.of(context).primaryColor;
    }
  }

  IconData _tipeIcon(String tipe) {
    switch (tipe) {
      case 'kiloan':
        return Icons.scale_outlined;
      case 'satuan':
        return Icons.tag_outlined;
      case 'meter':
        return Icons.straighten_outlined;
      default:
        return Icons.local_laundry_service_outlined;
    }
  }

  String _tipeLabel(String tipe) {
    switch (tipe) {
      case 'kiloan':
        return 'Kiloan';
      case 'satuan':
        return 'Satuan';
      case 'meter':
        return 'Meter';
      default:
        return 'Semua';
    }
  }

  String _formatHarga(double h) {
    if (h >= 1000000) return 'Rp ${(h / 1000000).toStringAsFixed(1)}jt';
    if (h >= 1000) return 'Rp ${(h / 1000).toStringAsFixed(0)}k';
    return 'Rp ${h.toStringAsFixed(0)}';
  }

  String _formatDurasi(int jam) {
    if (jam >= 24 && jam % 24 == 0) {
      final hari = jam ~/ 24;
      return '$hari Hari';
    }
    return '$jam Jam';
  }

  @override
  void initState() {
    super.initState();
    if (widget.autoOpenForm) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openForm());
    }
  }

  // ════════════════════════════════════════════════════════════
  // EXPORT EXCEL
  // ════════════════════════════════════════════════════════════
  Future<void> _exportToExcel(BuildContext context) async {
    setState(() => _isExporting = true);
    try {
      final snap = await _firestore
          .collection('stores')
          .doc(widget.storeId)
          .collection('outlets')
          .doc(widget.outletId)
          .collection('layanan')
          .orderBy('nama')
          .get();

      final allLayanan = snap.docs
          .map((d) => Layanan.fromFirestore(d))
          .toList();

      final workbook = xls.Excel.createExcel();
      final defaultSheetName = workbook.getDefaultSheet();

      _writeLayananSheet(workbook, 'Daftar Layanan', allLayanan);

      if (workbook.sheets.containsKey(defaultSheetName) &&
          workbook.sheets.length > 1) {
        workbook.delete(defaultSheetName!);
      }

      final bytes = workbook.encode();
      if (bytes == null) throw Exception('Gagal encode file excel');

      final tanggalStr = DateFormat('ddMMyy_HHmm').format(DateTime.now());
      final fileName = 'Daftar_Layanan_$tanggalStr.xlsx';

      if (kIsWeb) {
        final blob = html.Blob([
          bytes,
        ], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: url)
          ..setAttribute('download', fileName)
          ..click();
        html.Url.revokeObjectUrl(url);
      } else {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(bytes);

        if (!mounted) return;
        await Share.shareXFiles([XFile(file.path)], text: 'Daftar Layanan');
      }
    } catch (e, stack) {
      debugPrint('ERROR export excel layanan: $e\n$stack');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal membuat laporan: $e')));
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _writeLayananSheet(
    xls.Excel workbook,
    String sheetName,
    List<Layanan> data,
  ) {
    final sheet = workbook[sheetName];

    final headerFill = xls.ExcelColor.fromHexString('#0D9488');
    final subFill = xls.ExcelColor.fromHexString('#CCFBF1');
    final tableHeaderFill = xls.ExcelColor.fromHexString('#115E59');
    final altRowFill = xls.ExcelColor.fromHexString('#F3F4F6');
    final white = xls.ExcelColor.fromHexString('#FFFFFF');
    final darkText = xls.ExcelColor.fromHexString('#111827');

    const totalCols = 5;

    sheet.merge(
      xls.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
      xls.CellIndex.indexByColumnRow(columnIndex: totalCols - 1, rowIndex: 0),
    );
    _setCellLayanan(
      sheet,
      0,
      0,
      'DAFTAR LAYANAN',
      bold: true,
      fontSize: 16,
      bgColor: headerFill,
      fontColor: white,
      align: xls.HorizontalAlign.Center,
    );

    sheet.merge(
      xls.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1),
      xls.CellIndex.indexByColumnRow(columnIndex: totalCols - 1, rowIndex: 1),
    );
    _setCellLayanan(
      sheet,
      0,
      1,
      'Dicetak: ${DateFormat('d MMM yyyy, HH:mm', 'id').format(DateTime.now())}',
      bold: false,
      fontSize: 11,
      bgColor: subFill,
      fontColor: darkText,
      align: xls.HorizontalAlign.Center,
    );

    // ── Ringkasan ──
    final countKiloan = data.where((l) => l.tipe == 'kiloan').length;
    final countSatuan = data.where((l) => l.tipe == 'satuan').length;
    final countMeter = data.where((l) => l.tipe == 'meter').length;

    int row = 3;
    _setCellLayanan(
      sheet,
      0,
      row,
      'RINGKASAN',
      bold: true,
      fontSize: 12,
      fontColor: darkText,
    );
    row++;
    final summaryRows = <List<String>>[
      ['Total Layanan', data.length.toString()],
      ['Kiloan', countKiloan.toString()],
      ['Satuan', countSatuan.toString()],
      ['Meter', countMeter.toString()],
    ];
    for (final r in summaryRows) {
      _setCellLayanan(sheet, 0, row, r[0], fontColor: darkText);
      _setCellLayanan(sheet, 1, row, r[1], bold: true, fontColor: darkText);
      row++;
    }
    row++;

    // ── Header tabel ──
    final headers = [
      'No',
      'Nama Layanan',
      'Tipe',
      'Harga',
      'Durasi Pengerjaan',
    ];
    for (int c = 0; c < headers.length; c++) {
      _setCellLayanan(
        sheet,
        c,
        row,
        headers[c],
        bold: true,
        fontColor: white,
        bgColor: tableHeaderFill,
        align: xls.HorizontalAlign.Center,
      );
    }
    row++;

    // ── Data rows (diurutkan per tipe biar rapi) ──
    final sorted = [...data]
      ..sort((a, b) {
        final order = {'kiloan': 0, 'satuan': 1, 'meter': 2};
        final cmp = (order[a.tipe] ?? 9).compareTo(order[b.tipe] ?? 9);
        return cmp != 0 ? cmp : a.nama.compareTo(b.nama);
      });

    int no = 1;
    for (final l in sorted) {
      final rowFill = (no % 2 == 0) ? altRowFill : white;
      final values = [
        no.toString(),
        l.nama,
        _tipeLabel(l.tipe),
        _formatHargaFull(l.harga),
        _formatDurasi(l.durasiJam),
      ];
      for (int c = 0; c < values.length; c++) {
        _setCellLayanan(
          sheet,
          c,
          row,
          values[c],
          fontColor: darkText,
          bgColor: rowFill,
        );
      }
      row++;
      no++;
    }

    final widths = [5.0, 28.0, 14.0, 16.0, 18.0];
    for (int c = 0; c < widths.length; c++) {
      sheet.setColumnWidth(c, widths[c]);
    }
  }

  String _formatHargaFull(double h) => NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  ).format(h);

  void _setCellLayanan(
    xls.Sheet sheet,
    int col,
    int row,
    String value, {
    bool bold = false,
    int fontSize = 10,
    xls.ExcelColor? bgColor,
    xls.ExcelColor? fontColor,
    xls.HorizontalAlign align = xls.HorizontalAlign.Left,
  }) {
    final effectiveBgColor = bgColor ?? xls.ExcelColor.fromHexString('#FFFFFF');
    final effectiveFontColor =
        fontColor ?? xls.ExcelColor.fromHexString('#111827');
    final cell = sheet.cell(
      xls.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
    );
    cell.value = xls.TextCellValue(value);
    cell.cellStyle = xls.CellStyle(
      bold: bold,
      fontSize: fontSize,
      backgroundColorHex: effectiveBgColor,
      fontColorHex: effectiveFontColor,
      horizontalAlign: align,
      verticalAlign: xls.VerticalAlign.Center,
    );
  }

  // ── hapus layanan ─────────────────────────────────────────────────────────
  Future<void> _deleteLayanan(Layanan layanan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text(
          'Hapus Layanan',
          style: TextStyle(
            color: Theme.of(ctx).textTheme.bodyLarge?.color,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Yakin ingin menghapus layanan "${layanan.nama}"?',
          style: TextStyle(color: Theme.of(ctx).textTheme.bodyMedium?.color),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Batal',
              style: TextStyle(color: Theme.of(ctx).primaryColor),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Hapus',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _firestore
          .collection('stores')
          .doc(widget.storeId)
          .collection('outlets')
          .doc(widget.outletId)
          .collection('layanan')
          .doc(layanan.id)
          .delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Layanan "${layanan.nama}" dihapus'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  // ── buka bottom sheet tambah / edit ──────────────────────────────────────
  void _openForm({Layanan? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => LayananFormSheet(
        existing: existing,
        onSave: (nama, tipe, harga, durasiJam) async {
          final data = {
            'nama': nama,
            'tipe': tipe,
            'harga': harga,
            'durasi_jam': durasiJam,
          };

          final layananRef = _firestore
              .collection('stores')
              .doc(widget.storeId)
              .collection('outlets')
              .doc(widget.outletId)
              .collection('layanan');

          if (existing == null) {
            await layananRef.add(data);
          } else {
            await layananRef.doc(existing.id).update(data);
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  existing == null
                      ? 'Layanan "$nama" berhasil ditambahkan'
                      : 'Layanan "$nama" berhasil diperbarui',
                ),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          }
        },
      ),
    );
  }

  // ── summary card ──────────────────────────────────────────────────────────
  Widget _buildSummaryCard({
    required BuildContext context,
    required String label,
    required int count,
    required Color color,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? color : Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? color : color.withOpacity(0.3),
              width: isSelected ? 0 : 1.5,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withOpacity(0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : [],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: isSelected ? Colors.white : color, size: 22),
              const SizedBox(height: 4),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? Colors.white.withOpacity(0.9)
                      : Theme.of(context).textTheme.bodyMedium?.color,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Daftar Layanan',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor:
            Theme.of(context).appBarTheme.backgroundColor ??
            Theme.of(context).primaryColor,
        elevation: 2,
        iconTheme: const IconThemeData(color: Colors.white),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
        ),
        actions: [
          IconButton(
            icon: _isExporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.download_rounded, color: Colors.white),
            tooltip: 'Download Daftar Layanan Excel',
            onPressed: _isExporting ? null : () => _exportToExcel(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        backgroundColor: Theme.of(context).primaryColor,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Tambah Layanan',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('stores')
            .doc(widget.storeId)
            .collection('outlets')
            .doc(widget.outletId)
            .collection('layanan')
            .orderBy('nama')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final allDocs = snapshot.data?.docs ?? [];
          final allLayanan = allDocs
              .map((d) => Layanan.fromFirestore(d))
              .toList();

          final countSatuan = allLayanan
              .where((l) => l.tipe == 'satuan')
              .length;
          final countKiloan = allLayanan
              .where((l) => l.tipe == 'kiloan')
              .length;
          final countMeter = allLayanan.where((l) => l.tipe == 'meter').length;
          final countSemua = allLayanan.length;

          final filtered = _filterTipe == 'semua'
              ? allLayanan
              : allLayanan.where((l) => l.tipe == _filterTipe).toList();

          return Column(
            children: [
              // ── Summary Cards ───────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    _buildSummaryCard(
                      context: context,
                      label: 'Semua',
                      count: countSemua,
                      color: Theme.of(context).primaryColor,
                      icon: Icons.grid_view_rounded,
                      isSelected: _filterTipe == 'semua',
                      onTap: () => setState(() => _filterTipe = 'semua'),
                    ),
                    _buildSummaryCard(
                      context: context,
                      label: 'Kiloan',
                      count: countKiloan,
                      color: Colors.blue,
                      icon: Icons.scale_outlined,
                      isSelected: _filterTipe == 'kiloan',
                      onTap: () => setState(() => _filterTipe = 'kiloan'),
                    ),
                    _buildSummaryCard(
                      context: context,
                      label: 'Satuan',
                      count: countSatuan,
                      color: Colors.green,
                      icon: Icons.tag_outlined,
                      isSelected: _filterTipe == 'satuan',
                      onTap: () => setState(() => _filterTipe = 'satuan'),
                    ),
                    _buildSummaryCard(
                      context: context,
                      label: 'Meter',
                      count: countMeter,
                      color: Colors.orange,
                      icon: Icons.straighten_outlined,
                      isSelected: _filterTipe == 'meter',
                      onTap: () => setState(() => _filterTipe = 'meter'),
                    ),
                  ],
                ),
              ),

              // ── List Layanan ────────────────────────────────────────────
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.local_laundry_service_outlined,
                              size: 64,
                              color: Theme.of(
                                context,
                              ).hintColor.withOpacity(0.4),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Belum ada layanan',
                              style: TextStyle(
                                color: Theme.of(context).hintColor,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                        itemCount: filtered.length,
                        itemBuilder: (ctx, i) {
                          final l = filtered[i];
                          final color = _tipeColor(l.tipe, ctx);
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: Theme.of(ctx).cardColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Theme.of(
                                  ctx,
                                ).dividerColor.withOpacity(0.4),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(
                                    Theme.of(ctx).brightness == Brightness.dark
                                        ? 0.25
                                        : 0.04,
                                  ),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              leading: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  _tipeIcon(l.tipe),
                                  color: color,
                                  size: 22,
                                ),
                              ),
                              title: Text(
                                l.nama,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: Theme.of(
                                    ctx,
                                  ).textTheme.bodyLarge?.color,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: color.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          _tipeLabel(l.tipe),
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: color,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Icon(
                                        Icons.access_time_outlined,
                                        size: 13,
                                        color: Theme.of(ctx).hintColor,
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        _formatDurasi(l.durasiJam),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(ctx).hintColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${_formatHarga(l.harga)} / ${_tipeLabel(l.tipe).toLowerCase()}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(ctx).primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Tombol Edit
                                  IconButton(
                                    icon: Icon(
                                      Icons.edit_outlined,
                                      color: Theme.of(ctx).primaryColor,
                                      size: 20,
                                    ),
                                    tooltip: 'Edit',
                                    onPressed: () => _openForm(existing: l),
                                  ),
                                  // Tombol Hapus
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.redAccent,
                                      size: 20,
                                    ),
                                    tooltip: 'Hapus',
                                    onPressed: () => _deleteLayanan(l),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BOTTOM SHEET FORM (Tambah / Edit)
// ─────────────────────────────────────────────────────────────────────────────
class LayananFormSheet extends StatefulWidget {
  final Layanan? existing;
  final Future<void> Function(
    String nama,
    String tipe,
    double harga,
    int durasiJam,
  )
  onSave;

  const LayananFormSheet({this.existing, required this.onSave});

  @override
  State<LayananFormSheet> createState() => LayananFormSheetState();
}

class LayananFormSheetState extends State<LayananFormSheet> {
  final _namaCtrl = TextEditingController();
  final _hargaCtrl = TextEditingController();
  final _durasiCtrl = TextEditingController();

  String _tipe = 'kiloan';
  String _satuanDurasi = 'hari'; // 'jam' | 'hari'
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    if (widget.existing != null) {
      final e = widget.existing!;
      _namaCtrl.text = e.nama;
      _hargaCtrl.text = e.harga.toStringAsFixed(0);
      _tipe = e.tipe;

      // Konversi balik jam → tampilan
      if (e.durasiJam >= 24 && e.durasiJam % 24 == 0) {
        _satuanDurasi = 'hari';
        _durasiCtrl.text = (e.durasiJam ~/ 24).toString();
      } else {
        _satuanDurasi = 'jam';
        _durasiCtrl.text = e.durasiJam.toString();
      }
    } else {
      _durasiCtrl.text = '1';
    }
  }

  @override
  void dispose() {
    _namaCtrl.dispose();
    _hargaCtrl.dispose();
    _durasiCtrl.dispose();
    super.dispose();
  }

  int get _durasiDalamJam {
    final val = int.tryParse(_durasiCtrl.text) ?? 1;
    return _satuanDurasi == 'hari' ? val * 24 : val;
  }

  String get _durasiPreview {
    final val = int.tryParse(_durasiCtrl.text) ?? 0;
    if (val == 0) return '';
    final jam = _satuanDurasi == 'hari' ? val * 24 : val;
    return 'Akan tersimpan sebagai $jam jam';
  }

  Future<void> _submit() async {
    final nama = _namaCtrl.text.trim();
    final harga = double.tryParse(_hargaCtrl.text.replaceAll('.', '')) ?? 0;
    final durasi = int.tryParse(_durasiCtrl.text) ?? 0;

    if (nama.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama layanan tidak boleh kosong')),
      );
      return;
    }
    if (harga <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Harga harus lebih dari 0')));
      return;
    }
    if (durasi <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Durasi harus lebih dari 0')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await widget.onSave(nama, _tipe, harga, _durasiDalamJam);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal menyimpan: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildTipeChip(
    String value,
    String label,
    IconData icon,
    Color color,
  ) {
    final selected = _tipe == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tipe = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? color : color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? color : color.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: selected ? Colors.white : color, size: 20),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Judul
            Text(
              isEdit ? 'Edit Layanan' : 'Tambah Layanan',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            const SizedBox(height: 20),

            // ── Nama Layanan ──────────────────────────────────────────────
            _buildLabel(context, 'Nama Layanan'),
            const SizedBox(height: 8),
            TextField(
              controller: _namaCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: _inputDecoration(context, 'cth. Cuci Setrika'),
            ),
            const SizedBox(height: 16),

            // ── Tipe Layanan ──────────────────────────────────────────────
            _buildLabel(context, 'Tipe Layanan'),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildTipeChip(
                  'kiloan',
                  'Kiloan',
                  Icons.scale_outlined,
                  Colors.blue,
                ),
                _buildTipeChip(
                  'satuan',
                  'Satuan',
                  Icons.tag_outlined,
                  Colors.green,
                ),
                _buildTipeChip(
                  'meter',
                  'Meter',
                  Icons.straighten_outlined,
                  Colors.orange,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Harga ─────────────────────────────────────────────────────
            _buildLabel(context, 'Harga'),
            const SizedBox(height: 8),
            TextField(
              controller: _hargaCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: _inputDecoration(
                context,
                'cth. 7000',
                prefix: const Text('Rp  '),
              ),
            ),
            const SizedBox(height: 16),

            // ── Durasi Pengerjaan ─────────────────────────────────────────
            _buildLabel(context, 'Durasi Pengerjaan'),
            const SizedBox(height: 8),
            Row(
              children: [
                // Input angka
                Expanded(
                  child: TextField(
                    controller: _durasiCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => setState(() {}),
                    decoration: _inputDecoration(context, '1'),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 8),
                // Toggle Jam / Hari
                _buildDurasiToggle(context, 'jam', 'Jam'),
                const SizedBox(width: 6),
                _buildDurasiToggle(context, 'hari', 'Hari'),
              ],
            ),
            if (_durasiPreview.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                _durasiPreview,
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ],
            const SizedBox(height: 24),

            // ── Tombol Simpan ─────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        isEdit ? 'Simpan Perubahan' : 'Tambah Layanan',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildDurasiToggle(BuildContext context, String value, String label) {
    final selected = _satuanDurasi == value;
    return GestureDetector(
      onTap: () => setState(() => _satuanDurasi = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).primaryColor
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? Theme.of(context).primaryColor
                : Theme.of(context).dividerColor.withOpacity(0.5),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: selected
                ? Colors.white
                : Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(BuildContext context, String label) {
    return RichText(
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
          color: Theme.of(context).textTheme.bodyLarge?.color,
        ),
        children: const [
          TextSpan(
            text: ' *',
            style: TextStyle(color: Colors.redAccent),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(
    BuildContext context,
    String hint, {
    Widget? prefix,
  }) {
    return InputDecoration(
      hintText: hint,
      prefix: prefix,
      hintStyle: TextStyle(color: Theme.of(context).hintColor.withOpacity(0.6)),
      filled: true,
      fillColor: Theme.of(context).cardColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Theme.of(context).dividerColor.withOpacity(0.4),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Theme.of(context).dividerColor.withOpacity(0.4),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Theme.of(context).primaryColor,
          width: 1.8,
        ),
      ),
    );
  }
}

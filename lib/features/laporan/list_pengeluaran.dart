import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mdnlaundry_project/core/app_exports.dart';
import 'dart:io';
import 'package:excel/excel.dart' as xls;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart' as html;

class ListPengeluaranPage extends StatefulWidget {
  final String storeId;
  final String outletId;
  final bool isGabungan;

  const ListPengeluaranPage({
    super.key,
    required this.storeId,
    required this.outletId,
    this.isGabungan = false,
  });

  @override
  State<ListPengeluaranPage> createState() => _ListPengeluaranPageState();
}

class _ListPengeluaranPageState extends State<ListPengeluaranPage> {
  // ── Periode ──
  String _selectedPeriode = "Bulan Ini";
  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _endDate = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );

  // ── Data ──
  bool _isLoading = true;
  bool _isExporting = false;
  List<Map<String, dynamic>> _allData = [];
  List<Map<String, dynamic>> _filtered = [];
  String _searchQuery = "";
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Fetch Firestore ──
  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      Query<Map<String, dynamic>> query = FirebaseFirestore.instance
          .collection('pengeluaran')
          .where('store_id', isEqualTo: widget.storeId);
      if (!widget.isGabungan) {
        query = query.where('outlet_id', isEqualTo: widget.outletId);
      }
      final snap = await query.get();

      List<Map<String, dynamic>> list = [];

      for (var doc in snap.docs) {
        final data = doc.data();
        DateTime? tgl;

        final raw = data['tanggal'];
        if (raw is Timestamp) {
          tgl = raw.toDate();
        } else if (raw is String && raw.isNotEmpty) {
          try {
            tgl = DateFormat("dd/MM/yyyy HH:mm").parse(raw);
          } catch (_) {
            try {
              tgl = DateTime.parse(raw);
            } catch (_) {}
          }
        }

        if (tgl == null) continue;

        list.add({
          'id': doc.id,
          'keterangan': data['keterangan'] ?? "-",
          'nominal': (data['nominal'] ?? 0).toDouble(),
          'kategori': data['kategori'] ?? "Lain-Lain",
          'tanggal': tgl,
          'store_id': widget.storeId,
          'outlet_id': (data['outlet_id'] ?? '').toString().trim(),
        });
      }

      // Urutkan terbaru dulu
      list.sort(
        (a, b) =>
            (b['tanggal'] as DateTime).compareTo(a['tanggal'] as DateTime),
      );

      setState(() {
        _allData = list;
        _isLoading = false;
      });
      _applyFilter();
    } catch (e) {
      debugPrint("ERROR fetch pengeluaran: $e");
      setState(() => _isLoading = false);
    }
  }

  // ── Filter berdasarkan periode & search ──
  void _applyFilter() {
    final DateTime start = DateTime(
      _startDate.year,
      _startDate.month,
      _startDate.day,
    );
    final DateTime end = DateTime(_endDate.year, _endDate.month, _endDate.day);

    setState(() {
      _filtered = _allData.where((item) {
        final DateTime tgl = item['tanggal'] as DateTime;
        final DateTime tglHari = DateTime(tgl.year, tgl.month, tgl.day);

        bool inRange = !tglHari.isBefore(start) && !tglHari.isAfter(end);
        bool matchSearch =
            _searchQuery.isEmpty ||
            (item['keterangan'] as String).toLowerCase().contains(
              _searchQuery.toLowerCase(),
            );
        return inRange && matchSearch;
      }).toList();
    });
  }

  // ── Set periode preset ──
  void _setPeriode(String label) {
    final now = DateTime.now();
    DateTime s, e;

    switch (label) {
      case "Hari Ini":
        s = DateTime(now.year, now.month, now.day);
        e = s;
        break;
      case "Kemarin":
        final yesterday = now.subtract(const Duration(days: 1));
        s = DateTime(yesterday.year, yesterday.month, yesterday.day);
        e = s;
        break;
      case "Minggu Ini":
        final weekday = now.weekday;
        s = now.subtract(Duration(days: weekday - 1));
        s = DateTime(s.year, s.month, s.day);
        e = DateTime(now.year, now.month, now.day);
        break;
      case "Bulan Ini":
        s = DateTime(now.year, now.month, 1);
        e = DateTime(now.year, now.month, now.day);
        break;
      case "Bulan Lalu":
        final lastMonth = DateTime(now.year, now.month - 1, 1);
        s = lastMonth;
        e = DateTime(now.year, now.month, 0); // hari terakhir bulan lalu
        break;
      case "30 Hari Terakhir":
        s = now.subtract(const Duration(days: 29));
        s = DateTime(s.year, s.month, s.day);
        e = DateTime(now.year, now.month, now.day);
        break;
      default:
        s = DateTime(now.year, now.month, 1);
        e = DateTime(now.year, now.month, now.day);
    }

    setState(() {
      _selectedPeriode = label;
      _startDate = s;
      _endDate = e;
    });
    _applyFilter();
  }

  // ── Show bottom sheet periode ──
  void _showPeriodePicker() {
    final options = [
      "Hari Ini",
      "Kemarin",
      "Minggu Ini",
      "Bulan Ini",
      "Bulan Lalu",
      "30 Hari Terakhir",
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
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
              const SizedBox(height: 20),
              Text(
                "Pilih Periode",
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Filter pengeluaran berdasarkan rentang tanggal",
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: options.map((opt) {
                  final bool isSelected = _selectedPeriode == opt;
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      _setPeriode(opt);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? kPrimary.withOpacity(0.1)
                            : Theme.of(context).scaffoldBackgroundColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? kPrimary
                              : Theme.of(context).dividerColor,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isSelected) ...[
                            Icon(
                              Icons.check_circle_rounded,
                              color: kPrimary,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            opt,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isSelected
                                  ? kPrimary
                                  : Theme.of(
                                      context,
                                    ).textTheme.bodyLarge?.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              // Custom date button
              GestureDetector(
                onTap: () async {
                  Navigator.pop(context);
                  final DateTimeRange? range =
                      await CalendarHelper.showFullDatePicker(context);
                  if (range != null) {
                    setState(() {
                      _selectedPeriode = "Custom";
                      _startDate = range.start;
                      _endDate = range.end;
                    });
                    _applyFilter();
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(color: kPrimary, width: 1.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.calendar_month_rounded,
                        color: kPrimary,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Pilih Tanggal Custom",
                        style: TextStyle(
                          color: kPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Delete ──
  Future<void> _deletePengeluaran(String docId, int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Hapus Pengeluaran"),
        content: const Text("Yakin ingin menghapus data pengeluaran ini?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Batal", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Hapus"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('pengeluaran')
          .doc(docId)
          .delete();

      setState(() {
        _allData.removeWhere((e) => e['id'] == docId);
        _filtered.removeAt(index);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ Pengeluaran berhasil dihapus"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("❌ Gagal menghapus: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ── Edit ──
  void _editPengeluaran(Map<String, dynamic> item) {
    final TextEditingController ketCtrl = TextEditingController(
      text: item['keterangan'],
    );
    final TextEditingController nomCtrl = TextEditingController(
      text: item['nominal'].toInt().toString(),
    );
    String selectedKategori = item['kategori'] ?? "Lain-Lain";

    final kategoriList = ["Restock", "Gaji", "Operasional", "Lain-Lain"];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                    const SizedBox(height: 20),
                    Text(
                      "Edit Pengeluaran",
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: ketCtrl,
                      decoration: InputDecoration(
                        labelText: "Keterangan",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nomCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: "Nominal",
                        prefixText: "Rp ",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedKategori,
                      decoration: InputDecoration(
                        labelText: "Kategori",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      items: kategoriList
                          .map(
                            (k) => DropdownMenuItem(value: k, child: Text(k)),
                          )
                          .toList(),
                      onChanged: (val) =>
                          setModalState(() => selectedKategori = val!),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () async {
                          try {
                            await FirebaseFirestore.instance
                                .collection('pengeluaran')
                                .doc(item['id'])
                                .update({
                                  'keterangan': ketCtrl.text,
                                  'nominal':
                                      double.tryParse(
                                        nomCtrl.text.replaceAll(
                                          RegExp(r'[^0-9]'),
                                          '',
                                        ),
                                      ) ??
                                      0,
                                  'kategori': selectedKategori,
                                });
                            Navigator.pop(ctx);
                            _fetchData();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("✅ Pengeluaran diperbarui"),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("❌ Gagal update: $e"),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                        child: const Text(
                          "Simpan Pengeluaran",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ════════════════════════════════════════════════════════════
  // EXPORT EXCEL
  // ════════════════════════════════════════════════════════════
  Future<void> _exportToExcel() async {
    setState(() => _isExporting = true);
    try {
      // Pakai data yang sudah difilter periode (ikut search juga, sesuai tampilan)
      final dataExport = List<Map<String, dynamic>>.from(_filtered);

      final workbook = xls.Excel.createExcel();
      final defaultSheetName = workbook.getDefaultSheet();

      if (widget.isGabungan) {
        final Map<String, List<Map<String, dynamic>>> perOutlet = {};
        for (final o in dataExport) {
          final outletId = (o['outlet_id'] as String).isEmpty
              ? 'Tanpa Outlet'
              : o['outlet_id'] as String;
          perOutlet.putIfAbsent(outletId, () => []).add(o);
        }

        _writePengeluaranSheet(
          workbook,
          'Gabungan',
          dataExport,
          'LAPORAN PENGELUARAN GABUNGAN SEMUA OUTLET',
        );

        int idx = 1;
        for (final entry in perOutlet.entries) {
          String sheetLabel = entry.key.length > 25
              ? entry.key.substring(0, 25)
              : entry.key;
          sheetLabel = 'Outlet ${idx++} - $sheetLabel'
              .replaceAll(RegExp(r'[\\/?*\[\]:]'), '')
              .trim();
          if (sheetLabel.length > 31) {
            sheetLabel = sheetLabel.substring(0, 31);
          }
          _writePengeluaranSheet(
            workbook,
            sheetLabel,
            entry.value,
            'LAPORAN PENGELUARAN OUTLET: ${entry.key}',
          );
        }
      } else {
        _writePengeluaranSheet(
          workbook,
          'Pengeluaran',
          dataExport,
          'LAPORAN PENGELUARAN',
        );
      }

      if (workbook.sheets.containsKey(defaultSheetName) &&
          workbook.sheets.length > 1) {
        workbook.delete(defaultSheetName!);
      }

      final bytes = workbook.encode();
      if (bytes == null) throw Exception('Gagal encode file excel');

      final periodeStr =
          '${DateFormat('ddMMyy').format(_startDate)}-${DateFormat('ddMMyy').format(_endDate)}';
      final fileName =
          'Laporan_Pengeluaran_${widget.isGabungan ? "Gabungan" : "Outlet"}_$periodeStr.xlsx';

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
        await Share.shareXFiles([
          XFile(file.path),
        ], text: 'Laporan Pengeluaran ${_formatPeriodeLabel()}');
      }
    } catch (e, stack) {
      debugPrint('ERROR export excel pengeluaran: $e\n$stack');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal membuat laporan: $e')));
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _writePengeluaranSheet(
    xls.Excel workbook,
    String sheetName,
    List<Map<String, dynamic>> data,
    String title,
  ) {
    final sheet = workbook[sheetName];

    final headerFill = xls.ExcelColor.fromHexString('#DC2626');
    final subFill = xls.ExcelColor.fromHexString('#FEE2E2');
    final tableHeaderFill = xls.ExcelColor.fromHexString('#991B1B');
    final altRowFill = xls.ExcelColor.fromHexString('#F3F4F6');
    final white = xls.ExcelColor.fromHexString('#FFFFFF');
    final darkText = xls.ExcelColor.fromHexString('#111827');

    const totalCols = 4;

    sheet.merge(
      xls.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
      xls.CellIndex.indexByColumnRow(columnIndex: totalCols - 1, rowIndex: 0),
    );
    _setCellPengeluaran(
      sheet,
      0,
      0,
      title,
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
    _setCellPengeluaran(
      sheet,
      0,
      1,
      'Periode: ${DateFormat('d MMM yyyy', 'id').format(_startDate)} - ${DateFormat('d MMM yyyy', 'id').format(_endDate)}',
      bold: false,
      fontSize: 11,
      bgColor: subFill,
      fontColor: darkText,
      align: xls.HorizontalAlign.Center,
    );

    // ── Ringkasan ──
    double total = 0;
    final Map<String, double> totalPerKategori = {};
    for (final d in data) {
      final nominal = d['nominal'] as double;
      final kat = (d['kategori'] as String?) ?? 'Lain-Lain';
      total += nominal;
      totalPerKategori[kat] = (totalPerKategori[kat] ?? 0) + nominal;
    }

    int row = 3;
    _setCellPengeluaran(
      sheet,
      0,
      row,
      'RINGKASAN',
      bold: true,
      fontSize: 12,
      fontColor: darkText,
    );
    row++;
    _setCellPengeluaran(sheet, 0, row, 'Total Transaksi', fontColor: darkText);
    _setCellPengeluaran(
      sheet,
      1,
      row,
      data.length.toString(),
      bold: true,
      fontColor: darkText,
    );
    row++;
    _setCellPengeluaran(
      sheet,
      0,
      row,
      'Total Pengeluaran',
      fontColor: darkText,
    );
    _setCellPengeluaran(
      sheet,
      1,
      row,
      _formatRp(total),
      bold: true,
      fontColor: darkText,
    );
    row++;
    for (final entry in totalPerKategori.entries) {
      _setCellPengeluaran(
        sheet,
        0,
        row,
        '  - ${entry.key}',
        fontColor: darkText,
      );
      _setCellPengeluaran(
        sheet,
        1,
        row,
        _formatRp(entry.value),
        fontColor: darkText,
      );
      row++;
    }
    row++;

    // ── Header tabel ──
    final headers = ['No', 'Tanggal', 'Keterangan', 'Kategori', 'Nominal'];
    for (int c = 0; c < headers.length; c++) {
      _setCellPengeluaran(
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

    // ── Data rows ──
    int no = 1;
    for (final d in data) {
      final rowFill = (no % 2 == 0) ? altRowFill : white;
      final values = [
        no.toString(),
        _formatTanggal(d['tanggal'] as DateTime),
        d['keterangan'] as String,
        (d['kategori'] as String?) ?? 'Lain-Lain',
        _formatRp(d['nominal'] as double),
      ];
      for (int c = 0; c < values.length; c++) {
        _setCellPengeluaran(
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

    final widths = [5.0, 16.0, 30.0, 16.0, 18.0];
    for (int c = 0; c < widths.length; c++) {
      sheet.setColumnWidth(c, widths[c]);
    }
  }

  void _setCellPengeluaran(
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
    final cell = sheet.cell(
      xls.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
    );
    cell.value = xls.TextCellValue(value);
    cell.cellStyle = xls.CellStyle(
      bold: bold,
      fontSize: fontSize,
      backgroundColorHex: bgColor ?? xls.ExcelColor.fromHexString('#FFFFFF'),
      fontColorHex: fontColor ?? xls.ExcelColor.fromHexString('#111827'),
      horizontalAlign: align,
      verticalAlign: xls.VerticalAlign.Center,
    );
  }

  // ── Format ──
  String _formatRp(double val) => NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  ).format(val);

  String _formatTanggal(DateTime tgl) =>
      DateFormat('d MMM yyyy', 'id').format(tgl);

  String _formatPeriodeLabel() {
    if (_selectedPeriode == "Custom") {
      return "${_formatTanggal(_startDate)} - ${_formatTanggal(_endDate)}";
    }
    return _selectedPeriode;
  }

  double get _totalFiltered =>
      _filtered.fold(0, (sum, e) => sum + (e['nominal'] as double));

  // ── Warna kategori ──
  Color _kategoriColor(String kat) {
    switch (kat) {
      case "Restock":
        return const Color(0xff0284C7);
      case "Gaji":
        return const Color(0xff7C3AED);
      case "Operasional":
        return const Color(0xffD97706);
      default:
        return const Color(0xff64748B);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = Theme.of(context).cardColor;
    final bodyLarge = Theme.of(context).textTheme.bodyLarge;
    final bodySmall = Theme.of(context).textTheme.bodySmall;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(context),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FormPengeluaranPage(
                storeId: widget.storeId,
                outletId: widget.outletId,
              ),
            ),
          );
          _fetchData();
        },
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          "Tambah Pengeluaran",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : GlobalRefresh(
              onRefresh: _fetchData,
              child: Column(
                children: [
                  // ── Filter bar ──
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Column(
                      children: [
                        // Dropdown periode — 1 baris
                        GestureDetector(
                          onTap: _showPeriodePicker,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: kPrimary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: kPrimary, width: 1.2),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.calendar_month_rounded,
                                  color: kPrimary,
                                  size: 18,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _formatPeriodeLabel(),
                                    style: TextStyle(
                                      color: kPrimary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: kPrimary,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Search bar
                        TextField(
                          controller: _searchCtrl,
                          onChanged: (val) {
                            _searchQuery = val;
                            _applyFilter();
                          },
                          decoration: InputDecoration(
                            hintText: "Cari pengeluaran...",
                            prefixIcon: const Icon(Icons.search_rounded),
                            filled: true,
                            fillColor: cardColor,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 16,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Theme.of(context).dividerColor,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Theme.of(context).dividerColor,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Total & jumlah transaksi
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "Total ",
                              style: bodySmall?.copyWith(fontSize: 13),
                            ),
                            Text(
                              _formatRp(_totalFiltered),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              "${_filtered.length} transaksi",
                              style: bodySmall?.copyWith(fontSize: 13),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),

                  // ── List ──
                  Expanded(
                    child: _filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.receipt_long_outlined,
                                  size: 56,
                                  color: Colors.grey.shade300,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  "Tidak ada pengeluaran",
                                  style: bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Tarik ke bawah untuk refresh",
                                  style: bodySmall,
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                            itemCount: _filtered.length,
                            itemBuilder: (ctx, i) {
                              final item = _filtered[i];
                              final String ket = item['keterangan'];
                              final double nominal = item['nominal'];
                              final String kat =
                                  item['kategori'] ?? "Lain-Lain";
                              final DateTime tgl = item['tanggal'];

                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  color: cardColor,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: Theme.of(context).dividerColor,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.04),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Row(
                                    children: [
                                      // Icon uang
                                      Container(
                                        width: 52,
                                        height: 52,
                                        decoration: BoxDecoration(
                                          color: const Color(0xffDBEAFE),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: const Center(
                                          child: Text(
                                            "💸",
                                            style: TextStyle(fontSize: 24),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      // Info
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              ket,
                                              style: bodyLarge?.copyWith(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 5),
                                            Row(
                                              children: [
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 3,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: _kategoriColor(
                                                      kat,
                                                    ).withOpacity(0.1),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          20,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    kat,
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: _kategoriColor(
                                                        kat,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Icon(
                                                  Icons.calendar_today_outlined,
                                                  size: 11,
                                                  color: Theme.of(
                                                    context,
                                                  ).textTheme.bodySmall?.color,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  _formatTanggal(tgl),
                                                  style: bodySmall?.copyWith(
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Nominal + aksi
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            _formatRp(nominal),
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.red,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              // Edit
                                              GestureDetector(
                                                onTap: () =>
                                                    _editPengeluaran(item),
                                                child: Container(
                                                  padding: const EdgeInsets.all(
                                                    6,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: const Color(
                                                      0xffDBEAFE,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                  child: const Icon(
                                                    Icons.edit_outlined,
                                                    size: 16,
                                                    color: Color(0xff0284C7),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              // Hapus
                                              GestureDetector(
                                                onTap: () => _deletePengeluaran(
                                                  item['id'],
                                                  i,
                                                ),
                                                child: Container(
                                                  padding: const EdgeInsets.all(
                                                    6,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: const Color(
                                                      0xffFEE2E2,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                  child: const Icon(
                                                    Icons
                                                        .delete_outline_rounded,
                                                    size: 16,
                                                    color: Color(0xffDC2626),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
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
            ),
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
          title: const Text(
            "Pengeluaran",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          backgroundColor: kPrimary,
          foregroundColor: Colors.white,
          elevation: 2,
          centerTitle: true,
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
              onPressed: _isExporting ? null : _exportToExcel,
              tooltip: 'Download Laporan Excel',
            ),
          ],
          leading: Navigator.canPop(context)
              ? IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                )
              : null,
        ),
      ),
    );
  }
}

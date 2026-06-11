import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'screens.dart';

// ════════════════════════════════════════════════════════════════════════════
//  ORDER SCREEN  –  List + Chip Filter
// ════════════════════════════════════════════════════════════════════════════
class OrderScreen extends StatefulWidget {
  final String? initialStatus;
  final bool initialBelumBayar;
  final bool initialDeadline;

  const OrderScreen({
    super.key,
    this.initialStatus,
    this.initialBelumBayar = false,
    this.initialDeadline = false,
  });

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  late String? _filterStatus;
  late bool _filterBelumBayar;
  bool _filterBulanIni = true;
  bool _filterDeadline = false;
  DateTime? _filterBulanCustom;

  late final Stream<QuerySnapshot> _orderStream;

  @override
  void initState() {
    super.initState();
    _filterStatus = widget.initialStatus;
    _filterBelumBayar = widget.initialBelumBayar;
    _filterDeadline = widget.initialDeadline;
    _filterBulanIni =
        !widget.initialDeadline &&
        !widget.initialBelumBayar &&
        widget.initialStatus == null;
    _orderStream = FirebaseFirestore.instance
        .collection('order')
        .orderBy('waktu_order', descending: true)
        .snapshots();
  }

  static const _chips = [
    _ChipData(label: 'Antrian', status: 'antrian'),
    _ChipData(label: 'Proses', status: 'proses'),
    _ChipData(label: 'Selesai', status: 'selesai'),
  ];

  // ── Filter logic ──────────────────────────────────────────────────────────
  bool _passesClientFilter(Map<String, dynamic> data) {
    if (_filterStatus != null) {
      final status = data['status']?.toString().toLowerCase() ?? '';
      if (status != _filterStatus!.toLowerCase()) return false;
    }

    if (_filterBelumBayar) {
      final statusBayar = data['status_bayar']?.toString().toLowerCase() ?? '';
      if (statusBayar == 'lunas') return false;
    }

    // Filter Deadline — hanya order yang masih perlu diproses & estimasi mepet/lewat
    if (_filterDeadline) {
      final statusOrder = data['status']?.toString().toLowerCase() ?? '';
      // Exclude semua status yang sudah selesai diproses
      const statusSudahSelesai = {'selesai', 'siap ambil', 'siap antar'};
      if (statusSudahSelesai.contains(statusOrder)) return false;

      final estimasi = data['estimasi_selesai'];
      if (estimasi == null) return false;

      // Hanya tampil jika estimasi sudah lewat atau <= 3 hari lagi
      // Handle tipe Timestamp maupun String dari Firestore
      DateTime? dlDate;
      if (estimasi is Timestamp) {
        dlDate = estimasi.toDate();
      } else if (estimasi is String && estimasi.isNotEmpty) {
        try {
          final parts = estimasi.split('-');
          if (parts.length == 3) {
            if (parts[0].length == 4) {
              dlDate = DateTime(
                int.parse(parts[0]),
                int.parse(parts[1]),
                int.parse(parts[2]),
              );
            } else {
              dlDate = DateTime(
                int.parse(parts[2]),
                int.parse(parts[1]),
                int.parse(parts[0]),
              );
            }
          }
        } catch (_) {}
      }
      if (dlDate != null) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final dlDay = DateTime(dlDate.year, dlDate.month, dlDate.day);
        final diff = dlDay.difference(today).inDays;
        if (diff > 1) return false;
      }
    }

    // Filter bulan berjalan — hanya aktif saat chip "Semua/Bulan Ini" dipilih
    if (_filterStatus == null &&
        !_filterBelumBayar &&
        !_filterDeadline &&
        _filterBulanIni) {
      final waktu = data['waktu_order'];
      if (waktu is Timestamp) {
        final tgl = waktu.toDate();
        final target = _filterBulanCustom ?? DateTime.now();
        if (tgl.year != target.year || tgl.month != target.month) return false;
      }
    }

    return true;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'antrian':
        return const Color(0xFF4F6FE8);
      case 'proses':
        return const Color(0xFFF59E0B);
      case 'siap ambil':
        return const Color(0xFF0D9488);
      case 'siap antar':
        return const Color(0xFF7C3AED);
      case 'selesai':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _statusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'antrian':
        return Icons.hourglass_empty_rounded;
      case 'proses':
        return Icons.local_laundry_service_outlined;
      case 'siap ambil':
        return Icons.inventory_2_outlined;
      case 'siap antar':
        return Icons.local_shipping_outlined;
      case 'selesai':
        return Icons.check_circle_outline_rounded;
      default:
        return Icons.circle_outlined;
    }
  }

  Future<void> _showBulanPicker() async {
    int selectedYear = (_filterBulanCustom ?? DateTime.now()).year;
    int selectedMonth = (_filterBulanCustom ?? DateTime.now()).month;
    final now = DateTime.now();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(
                    Icons.calendar_month_outlined,
                    color: kPrimary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Pilih Bulan & Tahun',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Pilih Tahun
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: kPrimary.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Tahun',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => setS(() => selectedYear--),
                          icon: Icon(
                            Icons.chevron_left_rounded,
                            color: kPrimary,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: kPrimary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$selectedYear',
                            style: TextStyle(
                              color: kPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: selectedYear < now.year
                              ? () => setS(() => selectedYear++)
                              : null,
                          icon: Icon(
                            Icons.chevron_right_rounded,
                            color: selectedYear < now.year
                                ? kPrimary
                                : Colors.grey.shade300,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Grid 12 bulan
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  childAspectRatio: 1.6,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemCount: 12,
                itemBuilder: (_, i) {
                  final m = i + 1;
                  final isSelected = m == selectedMonth;
                  final isCurrentMonth =
                      m == now.month && selectedYear == now.year;
                  final isFuture = DateTime(
                    selectedYear,
                    m,
                  ).isAfter(DateTime(now.year, now.month));
                  return GestureDetector(
                    onTap: isFuture
                        ? null
                        : () => setS(() => selectedMonth = m),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? kPrimary
                            : isCurrentMonth
                            ? kPrimary.withOpacity(0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? kPrimary
                              : isFuture
                              ? Colors.grey.withOpacity(0.1)
                              : isCurrentMonth
                              ? kPrimary.withOpacity(0.4)
                              : Colors.grey.withOpacity(0.2),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          DateFormat('MMM', 'id_ID').format(DateTime(2000, m)),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSelected
                                ? Colors.white
                                : isFuture
                                ? Colors.grey.shade300
                                : Theme.of(context).textTheme.bodyMedium?.color,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  // Tombol Reset ke Bulan Ini
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() => _filterBulanCustom = null);
                        Navigator.pop(ctx);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey,
                        side: BorderSide(color: Colors.grey.shade300),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Bulan Ini'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _filterBulanCustom = DateTime(
                            selectedYear,
                            selectedMonth,
                          );
                        });
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Pilih',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(context),
      body: Column(
        children: [
          // ── Filter chips ────────────────────────────────────────────────
          Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Chip: Bulan Ini / Semua
                  _filterChip(
                    context,
                    label:
                        _filterStatus == null &&
                            !_filterBelumBayar &&
                            !_filterDeadline
                        ? (_filterBulanCustom != null
                              ? DateFormat(
                                  'MMM yyyy',
                                  'id_ID',
                                ).format(_filterBulanCustom!)
                              : 'Bulan Ini')
                        : 'Semua',
                    selected:
                        _filterStatus == null &&
                        !_filterBelumBayar &&
                        !_filterDeadline,
                    onTap: () {
                      if (_filterStatus == null &&
                          !_filterBelumBayar &&
                          !_filterDeadline) {
                        // Sudah aktif → buka picker
                        _showBulanPicker();
                      } else {
                        // Belum aktif → aktifkan dulu
                        setState(() {
                          _filterStatus = null;
                          _filterBelumBayar = false;
                          _filterDeadline = false;
                          _filterBulanIni = true;
                        });
                      }
                    },
                    primary: primary,
                    isDark: isDark,
                  ),
                  const SizedBox(width: 8),

                  // Chips: Antrian, Proses, Selesai
                  ..._chips.map(
                    (c) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _filterChip(
                        context,
                        label: c.label,
                        selected: _filterStatus == c.status,
                        onTap: () => setState(() {
                          _filterStatus = _filterStatus == c.status
                              ? null
                              : c.status;
                          _filterDeadline = false;
                          _filterBulanIni = false;
                          _filterBulanCustom = null;
                        }),
                        primary: primary,
                        isDark: isDark,
                      ),
                    ),
                  ),

                  // Chip: Belum Bayar
                  _filterChipIcon(
                    context,
                    label: 'Belum Bayar',
                    icon: Icons.payment_outlined,
                    selected: _filterBelumBayar,
                    onTap: () {
                      setState(() {
                        _filterBelumBayar = !_filterBelumBayar;
                        _filterDeadline = false;
                        _filterBulanIni = false;
                      });
                    },
                    activeColor: Colors.orange.shade700,
                    isDark: isDark,
                  ),
                  const SizedBox(width: 8),

                  // Chip: Deadline
                  _filterChipIcon(
                    context,
                    label: 'Deadline',
                    icon: Icons.timer_outlined,
                    selected: _filterDeadline,
                    onTap: () {
                      setState(() {
                        _filterDeadline = !_filterDeadline;
                        _filterBelumBayar = false;
                        _filterBulanIni = false;
                      });
                    },
                    activeColor: Colors.red.shade600,
                    isDark: isDark,
                  ),
                ],
              ),
            ),
          ),

          // ── Divider ─────────────────────────────────────────────────────
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Colors.grey.withOpacity(0.18),
                  Colors.transparent,
                ],
              ),
            ),
          ),

          // ── Summary row ─────────────────────────────────────────────────
          StreamBuilder<QuerySnapshot>(
            stream: _orderStream,
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();

              final docs = snapshot.data!.docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return _passesClientFilter(data);
              }).toList();

              int totalNominal = 0;
              for (final doc in docs) {
                final data = doc.data() as Map<String, dynamic>;
                final harga = data['harga_total'] ?? data['harga_satuan'];
                if (harga != null) {
                  try {
                    totalNominal += harga is num
                        ? harga.toInt()
                        : int.parse(harga.toString());
                  } catch (_) {}
                }
              }

              // Label sesuai filter aktif
              String filterLabel;
              if (_filterBelumBayar) {
                filterLabel = 'Belum Bayar';
              } else if (_filterDeadline) {
                filterLabel = 'Deadline';
              } else if (_filterStatus != null) {
                filterLabel =
                    _filterStatus![0].toUpperCase() +
                    _filterStatus!.substring(1);
              } else {
                filterLabel = _filterBulanCustom != null
                    ? DateFormat(
                        'MMM yyyy',
                        'id_ID',
                      ).format(_filterBulanCustom!)
                    : 'Bulan Ini';
              }

              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                color: Theme.of(context).scaffoldBackgroundColor,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: '${docs.length} transaksi ',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          TextSpan(
                            text: filterLabel,
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      NumberFormat.currency(
                        locale: 'id_ID',
                        symbol: 'Rp ',
                        decimalDigits: 0,
                      ).format(totalNominal),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // ── List ─────────────────────────────────────────────────────────
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _orderStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF0D9488)),
                  );
                }
                if (snapshot.hasError) {
                  debugPrint('Firestore error: ${snapshot.error}');
                  return _emptyState(
                    icon: Icons.wifi_off_rounded,
                    title: 'Gagal memuat data',
                    subtitle: 'Periksa koneksi internet Anda',
                  );
                }

                final allDocs = snapshot.data?.docs ?? [];
                final docs = allDocs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return _passesClientFilter(data);
                }).toList();

                if (docs.isEmpty) {
                  return _emptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'Belum ada order',
                    subtitle: 'Tarik ke bawah untuk muat ulang',
                  );
                }

                return GlobalRefresh(
                  onRefresh: () async => setState(() {}),
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                    itemCount: docs.length,
                    itemBuilder: (context, i) {
                      final doc = docs[i];
                      final data = doc.data() as Map<String, dynamic>;

                      final status = data['status']?.toString() ?? '-';
                      final noPelanggan =
                          data['nomor_pelanggan']?.toString() ?? '-';
                      final layananNama =
                          data['layanan_nama']?.toString() ?? '-';
                      final waktuOrder = data['waktu_order'];
                      String tanggalOrder = '-';
                      if (waktuOrder is Timestamp) {
                        tanggalOrder = DateFormat(
                          'dd-MM-yyyy',
                        ).format(waktuOrder.toDate());
                      }

                      final harga = data['harga_total'] ?? data['harga_satuan'];
                      final jenis = data['jenis_pakaian']?.toString() ?? '';
                      final hargaFmt = harga != null
                          ? _formatRupiah(harga)
                          : '-';
                      final sColor = _statusColor(status);
                      final sIcon = _statusIcon(status);

                      final statusBayar =
                          data['status_bayar']?.toString().toLowerCase() ?? '';
                      final belumLunas = statusBayar != 'lunas';

                      final namaPelanggan =
                          data['nama_pelanggan']?.toString() ?? '';
                      final noHpPelanggan = data['no_hp']?.toString() ?? '';

                      // ── Deadline logic ─────────────────────────────────
                      // Tidak tampil jika sudah selesai diproses
                      const statusTidakPerluDeadline = {
                        'selesai',
                        'siap ambil',
                        'siap antar',
                      };
                      final tidakPerluDeadline = statusTidakPerluDeadline
                          .contains(status.toLowerCase());
                      final estimasiRaw = data['estimasi_selesai'];
                      String? deadlineLabel;
                      Color deadlineColor = Colors.red.shade600;

                      if (!tidakPerluDeadline && estimasiRaw != null) {
                        // Handle tipe Timestamp maupun String dari Firestore
                        DateTime? dlDate;
                        if (estimasiRaw is Timestamp) {
                          dlDate = estimasiRaw.toDate();
                        } else if (estimasiRaw is String &&
                            estimasiRaw.isNotEmpty) {
                          try {
                            final parts = estimasiRaw.split('-');
                            if (parts.length == 3) {
                              if (parts[0].length == 4) {
                                dlDate = DateTime(
                                  int.parse(parts[0]),
                                  int.parse(parts[1]),
                                  int.parse(parts[2]),
                                );
                              } else {
                                dlDate = DateTime(
                                  int.parse(parts[2]),
                                  int.parse(parts[1]),
                                  int.parse(parts[0]),
                                );
                              }
                            }
                          } catch (_) {}
                        }

                        if (dlDate != null) {
                          final now = DateTime.now();
                          final today = DateTime(now.year, now.month, now.day);
                          final dlDay = DateTime(
                            dlDate.year,
                            dlDate.month,
                            dlDate.day,
                          );
                          final diff = dlDay.difference(today).inDays;

                          if (diff < 0) {
                            deadlineLabel = 'Lewat ${-diff}h';
                            deadlineColor = Colors.red.shade700;
                          } else if (diff == 0) {
                            deadlineLabel = 'Hari Ini';
                            deadlineColor = Colors.red.shade600;
                          } else if (diff == 1) {
                            deadlineLabel = 'Besok';
                            deadlineColor = Colors.orange.shade700;
                          } else {
                            deadlineLabel = DateFormat('dd/MM').format(dlDate);
                            deadlineColor = Colors.blue.shade600;
                          }
                        }
                      }
                      // ──────────────────────────────────────────────────

                      return GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                OrderDetailScreen(docId: doc.id, data: data),
                          ),
                        ),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Left color bar
                                Container(
                                  width: 5,
                                  decoration: BoxDecoration(
                                    color: sColor,
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(16),
                                      bottomLeft: Radius.circular(16),
                                    ),
                                  ),
                                ),

                                // Status icon
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 14,
                                  ),
                                  child: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: sColor.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(sIcon, color: sColor, size: 20),
                                  ),
                                ),

                                // Main content (left side)
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      0,
                                      12,
                                      0,
                                      12,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          noPelanggan,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyLarge
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          layananNama +
                                              (jenis.isNotEmpty
                                                  ? ' · $jenis'
                                                  : ''),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(fontSize: 12),
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.person_outline_rounded,
                                              size: 12,
                                              color: Colors.grey.shade500,
                                            ),
                                            const SizedBox(width: 3),
                                            Expanded(
                                              child: Text(
                                                namaPelanggan.isNotEmpty
                                                    ? namaPelanggan
                                                    : '-',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall
                                                    ?.copyWith(fontSize: 11),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                // Right column
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    0,
                                    12,
                                    12,
                                    12,
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      // Baris atas: harga (jika belum lunas) + tanggal
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (belumLunas) ...[
                                            Text(
                                              hargaFmt,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color:
                                                        Colors.orange.shade700,
                                                  ),
                                            ),
                                            const SizedBox(width: 6),
                                          ],
                                          Text(
                                            tanggalOrder,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(fontSize: 11),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),

                                      // Baris badge:
                                      // status → belum bayar → deadline → harga (jika lunas)
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _miniChip(context, status, sColor),
                                          if (belumLunas) ...[
                                            const SizedBox(width: 4),
                                            _miniChip(
                                              context,
                                              'Belum Bayar',
                                              Colors.orange.shade700,
                                            ),
                                          ],
                                          if (deadlineLabel != null) ...[
                                            const SizedBox(width: 4),
                                            _miniChipIcon(
                                              context,
                                              label: deadlineLabel,
                                              icon: Icons.timer_outlined,
                                              color: deadlineColor,
                                            ),
                                          ],
                                          // Tampilkan harga jika sudah lunas
                                          // dan tidak ada badge deadline
                                          if (!belumLunas &&
                                              deadlineLabel == null) ...[
                                            const SizedBox(width: 4),
                                            Text(
                                              hargaFmt,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 11,
                                                  ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 2),

                                      // Baris HP + chevron
                                      if (noHpPelanggan.isNotEmpty)
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.phone_outlined,
                                              size: 10,
                                              color: Colors.grey.shade500,
                                            ),
                                            const SizedBox(width: 2),
                                            Text(
                                              noHpPelanggan,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(fontSize: 10),
                                            ),
                                            const SizedBox(width: 4),
                                            Icon(
                                              Icons.chevron_right_rounded,
                                              color: Colors.grey.shade400,
                                              size: 18,
                                            ),
                                          ],
                                        )
                                      else
                                        Icon(
                                          Icons.chevron_right_rounded,
                                          color: Colors.grey.shade400,
                                          size: 18,
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Widgets ───────────────────────────────────────────────────────────────

  Widget _filterChip(
    BuildContext context, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
    required Color primary,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? primary
              : (isDark ? Colors.white10 : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? primary : Colors.transparent),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? Colors.white
                : Theme.of(context).textTheme.bodySmall?.color,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _filterChipIcon(
    BuildContext context, {
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
    required Color activeColor,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? activeColor
              : (isDark ? Colors.white10 : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? activeColor : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: selected
                  ? Colors.white
                  : Theme.of(context).textTheme.bodySmall?.color,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: selected
                    ? Colors.white
                    : Theme.of(context).textTheme.bodySmall?.color,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniChip(BuildContext context, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.25), width: 0.8),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.18),
            blurRadius: 4,
            offset: const Offset(0, 1.5),
          ),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _miniChipIcon(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.25), width: 0.8),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.18),
            blurRadius: 4,
            offset: const Offset(0, 1.5),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 9, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 14),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
        ],
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
          title: Text(
            'Daftar Order',
            style:
                Theme.of(context).appBarTheme.titleTextStyle?.copyWith(
                  fontWeight: FontWeight.bold,
                ) ??
                const TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor:
              Theme.of(context).appBarTheme.backgroundColor ?? kPrimary,
          elevation: 2,
          centerTitle: true,
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  Helper classes & functions
// ════════════════════════════════════════════════════════════════════════════

class _ChipData {
  final String label;
  final String status;
  const _ChipData({required this.label, required this.status});
}

String _formatRupiah(dynamic val) {
  try {
    final n = val is num ? val.toInt() : int.parse(val.toString());
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(n);
  } catch (_) {
    return 'Rp $val';
  }
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'screens.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final bool _isLoading = false;

  late AnimationController _heartController;
  late Animation<double> _heartAnim;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _heartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    _heartAnim = Tween<double>(begin: 1.0, end: 1.35).animate(
      CurvedAnimation(parent: _heartController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _heartController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<File?> _loadLocalProfileImage() async {
    if (kIsWeb) return null;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/profile_pic_local.png');
      return await file.exists() ? file : null;
    } catch (e) {
      debugPrint("Gagal memuat gambar profil: $e");
      return null;
    }
  }

  // ─── BUILD ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.dark,
              statusBarBrightness: Brightness.light,
            ),
      child: PopScope(
        canPop: false,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── BLUE HERO SECTION — full width, no horizontal padding ──────
                _buildHeroSection(user, isDark),

                // ── SCROLLABLE content ─────────────────────────────────────────
                Expanded(
                  child: GlobalRefresh(
                    onRefresh: () async => setState(() {}),
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 25),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 16),
                          _buildOrderStatsGrid(),
                          const SizedBox(height: 8),
                          _buildRecentOrdersSection(),
                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── HERO SECTION: Header + Pendapatan (full-width biru) ─────────────────
  Widget _buildHeroSection(User? user, bool isDark) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    final tanggalStr = DateFormat('dd MMM yyyy').format(now);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('order')
          .where(
            'waktu_order',
            isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart),
          )
          .where('waktu_order', isLessThan: Timestamp.fromDate(todayEnd))
          .snapshots(),
      builder: (context, snapshot) {
        int totalPendapatan = 0;
        int jumlahOrder = 0;

        if (snapshot.hasData) {
          for (final doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            jumlahOrder++;
            final harga = data['harga_total'];
            if (harga != null) {
              try {
                totalPendapatan += harga is num
                    ? harga.toInt()
                    : int.parse(harga.toString());
              } catch (_) {}
            }
          }
        }

        return Container(
          width: double.infinity,
          // Tidak pakai borderRadius di atas — biar mentok ke status bar
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF1A2744), const Color(0xFF0D1B3E)]
                  : [kPrimary, const Color(0xFF2563EB)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            // Hanya radius di bawah
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(28),
              bottomRight: Radius.circular(28),
            ),
            boxShadow: [
              BoxShadow(
                color: kPrimary.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Baris header: sapaan + lonceng + avatar ─────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Halo, ${(user?.displayName ?? 'User').split('|')[0].trim()}!",
                            style: const TextStyle(
                              fontSize: 22,
                              fontFamily: 'BubbbleGum',
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            "Selamat datang di ${OutletSettings.namaMadeenalaundry}",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.75),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        // Lonceng notifikasi
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const NotifikasiScreen(),
                            ),
                          ).then((_) => setState(() {})),
                          child: FutureBuilder<int>(
                            future: NotifStorage.jumlahBelumDibaca(),
                            builder: (context, snap) {
                              final jumlah = snap.data ?? 0;
                              return Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      jumlah > 0
                                          ? Icons.notifications_rounded
                                          : Icons.notifications_none_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                  if (jumlah > 0)
                                    Positioned(
                                      top: -4,
                                      right: -4,
                                      child: Container(
                                        width: 17,
                                        height: 17,
                                        decoration: BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: kPrimary,
                                            width: 1.5,
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            jumlah > 9
                                                ? '9+'
                                                : jumlah.toString(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 8,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Avatar
                        GestureDetector(
                          onTap: () => Navigator.pushNamed(
                            context,
                            '/profile',
                          ).then((_) => setState(() {})),
                          child: FutureBuilder<File?>(
                            future: _loadLocalProfileImage(),
                            builder: (context, snap) {
                              final file = snap.data;
                              return Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.5),
                                    width: 2,
                                  ),
                                ),
                                child: CircleAvatar(
                                  radius: 20,
                                  backgroundColor: Colors.white.withOpacity(
                                    0.2,
                                  ),
                                  backgroundImage: file != null
                                      ? FileImage(file)
                                      : null,
                                  child: file == null
                                      ? const Icon(
                                          Icons.person,
                                          color: Colors.white,
                                          size: 20,
                                        )
                                      : null,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // ── Card pendapatan (kaca / frosted glass style) ─────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.25),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Label + tanggal
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Pendapatan Hari Ini',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              tanggalStr,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Nominal
                      snapshot.connectionState == ConnectionState.waiting
                          ? const SizedBox(
                              height: 36,
                              child: Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                            )
                          : Text(
                              NumberFormat.currency(
                                locale: 'id_ID',
                                symbol: 'Rp ',
                                decimalDigits: 0,
                              ).format(totalPendapatan),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.5,
                              ),
                            ),
                      const SizedBox(height: 8),

                      // Badge jumlah order
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(width: 5),
                            Text(
                              snapshot.connectionState ==
                                      ConnectionState.waiting
                                  ? 'Memuat...'
                                  : '$jumlahOrder order hari ini',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── ORDER STATS GRID 3x2 ───────────────────────────────────────────────
  Widget _buildOrderStatsGrid() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('order').snapshots(),
      builder: (context, snapshot) {
        int antrian = 0;
        int proses = 0;
        int siapAmbil = 0;
        int siapAntar = 0;
        int deadline = 0;
        int terlambat = 0;

        if (snapshot.hasData) {
          final now = DateTime.now();
          for (final doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final status = (data['status']?.toString() ?? '').toLowerCase();
            final estimasiStr = data['estimasi_selesai']?.toString() ?? '';

            // Hitung terlambat & deadline berdasarkan estimasi_selesai
            DateTime? estimasi;
            if (estimasiStr.isNotEmpty) {
              try {
                // Format "08-06-2026"
                final parts = estimasiStr.split('-');
                if (parts.length == 3) {
                  estimasi = DateTime(
                    int.parse(parts[2]),
                    int.parse(parts[1]),
                    int.parse(parts[0]),
                  );
                }
              } catch (_) {}
            }

            switch (status) {
              case 'antrian':
                antrian++;
                break;
              case 'proses':
                proses++;
                // Cek deadline: estimasi hari ini atau besok
                if (estimasi != null) {
                  final hariIni = DateTime(now.year, now.month, now.day);
                  final estiMurni = DateTime(
                    estimasi.year,
                    estimasi.month,
                    estimasi.day,
                  );
                  final selisih = estiMurni.difference(hariIni).inDays;
                  if (selisih <= 1 && selisih >= 0) deadline++;
                  if (estiMurni.isBefore(hariIni)) terlambat++;
                }
                break;
              case 'siap ambil':
                siapAmbil++;
                break;
              case 'siap antar':
                siapAntar++;
                break;
            }
          }
        }

        final cards = [
          _OrderStatItem(
            label: 'Antrian',
            count: antrian,
            icon: Icons.timer_outlined,
            bgColor: const Color(0xFFE8EEFF),
            iconColor: const Color(0xFF4F6FE8),
          ),
          _OrderStatItem(
            label: 'Proses',
            count: proses,
            icon: Icons.local_laundry_service_outlined,
            bgColor: const Color(0xFFFFF3E0),
            iconColor: const Color(0xFFF59E0B),
          ),
          _OrderStatItem(
            label: 'Siap Ambil',
            count: siapAmbil,
            icon: Icons.inventory_2_outlined,
            bgColor: const Color(0xFFE6FAF5),
            iconColor: const Color(0xFF0D9488),
          ),
          _OrderStatItem(
            label: 'Siap Antar',
            count: siapAntar,
            icon: Icons.local_shipping_outlined,
            bgColor: const Color(0xFFEDE9FE),
            iconColor: const Color(0xFF7C3AED),
          ),
          _OrderStatItem(
            label: 'Deadline',
            count: deadline,
            icon: Icons.alarm_outlined,
            bgColor: const Color(0xFFFFF0E6),
            iconColor: const Color(0xFFEA580C),
          ),
          _OrderStatItem(
            label: 'Terlambat',
            count: terlambat,
            icon: Icons.error_outline_rounded,
            bgColor: const Color(0xFFFFE8E8),
            iconColor: const Color(0xFFDC2626),
          ),
        ];

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: cards.map((item) {
            final w = (MediaQuery.of(context).size.width - 50 - 20) / 3;
            return SizedBox(width: w, child: _buildOrderStatCard(item));
          }).toList(),
        );
      },
    );
  }

  Widget _buildOrderStatCard(_OrderStatItem item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAlert =
        (item.label == 'Deadline' || item.label == 'Terlambat') &&
        item.count > 0;

    String? navStatus;
    switch (item.label) {
      case 'Antrian':
        navStatus = 'antrian';
        break;
      case 'Proses':
        navStatus = 'proses';
        break;
      case 'Siap Ambil':
        navStatus = 'siap ambil';
        break;
      case 'Siap Antar':
        navStatus = 'siap antar';
        break;
      case 'Deadline':
        navStatus = 'proses';
        break;
      case 'Terlambat':
        navStatus = 'proses';
        break;
    }

    return GestureDetector(
      onTap: () => _goToOrder(status: navStatus),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min, // ← kunci: tinggi mengikuti konten
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isDark ? item.iconColor.withOpacity(0.2) : item.bgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(item.icon, color: item.iconColor, size: 18),
            ),
            const SizedBox(height: 6),
            Text(
              item.count.toString(),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isAlert
                    ? item.iconColor
                    : Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              item.label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── RECENT ORDERS SECTION ───────────────────────────────────────────────
  Widget _buildRecentOrdersSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('order')
          .orderBy('waktu_order', descending: true)
          .limit(10)
          .snapshots(),
      builder: (context, snapshot) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Order Terbaru",
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                if (snapshot.hasData)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: kPrimary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "${snapshot.data!.docs.length} order",
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: kPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            if (snapshot.connectionState == ConnectionState.waiting)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(color: Color(0xFF0D9488)),
                ),
              )
            else if (snapshot.hasError)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  "Gagal memuat data",
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              )
            else if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 32),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.receipt_long_outlined,
                      size: 48,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "Belum ada order",
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              )
            else
              ...snapshot.data!.docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final noPelanggan = data['nomor_pelanggan']?.toString() ?? "-";
                final layananNama = data['layanan_nama']?.toString() ?? "-";
                final status = data['status']?.toString() ?? "-";
                final estimasi = data['estimasi_selesai']?.toString() ?? "-";

                Color statusColor;
                IconData statusIcon;
                switch (status.toLowerCase()) {
                  case 'antrian':
                    statusColor = const Color(0xFF4F6FE8);
                    statusIcon = Icons.timer_outlined;
                    break;
                  case 'proses':
                    statusColor = const Color(0xFFF59E0B);
                    statusIcon = Icons.local_laundry_service_outlined;
                    break;
                  case 'siap ambil':
                    statusColor = const Color(0xFF0D9488);
                    statusIcon = Icons.inventory_2_outlined;
                    break;
                  case 'siap antar':
                    statusColor = const Color(0xFF7C3AED);
                    statusIcon = Icons.local_shipping_outlined;
                    break;
                  default:
                    statusColor = const Color(0xFF10B981);
                    statusIcon = Icons.check_circle_outline_outlined;
                }

                return GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          OrderDetailScreen(docId: doc.id, data: data),
                    ),
                  ),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(statusIcon, color: statusColor, size: 20),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                noPelanggan,
                                style: Theme.of(context).textTheme.bodyLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                              ),
                              const SizedBox(height: 2),
                              // ── Nama pelanggan ──────────────────
                              Row(
                                children: [
                                  Icon(
                                    Icons.person_outline_rounded,
                                    size: 11,
                                    color: Colors.grey.shade500,
                                  ),
                                  const SizedBox(width: 3),
                                  Expanded(
                                    child: Text(
                                      data['nama_pelanggan']
                                                  ?.toString()
                                                  .isNotEmpty ==
                                              true
                                          ? data['nama_pelanggan'].toString()
                                          : '-',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              // ── Badge status + nama layanan ─────
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: statusColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      status,
                                      style: TextStyle(
                                        color: statusColor,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      layananNama,
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
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            estimasi,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );
  }

  // ─── HEADER ──────────────────────────────────────────────────────────────
  Widget _buildHeader(User? user) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Halo, ${(user?.displayName ?? 'User').split('|')[0].trim()}!",
                style: TextStyle(
                  fontSize: 24,
                  fontFamily: 'BubbbleGum',
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              Text(
                "Selamat Datang!\nDi sistem management ${OutletSettings.namaMadeenalaundry}",
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontSize: 13,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
            ],
          ),
        ),
        Row(
          children: [
            // Lonceng notifikasi
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotifikasiScreen()),
              ).then((_) => setState(() {})),
              child: FutureBuilder<int>(
                future: NotifStorage.jumlahBelumDibaca(),
                builder: (context, snapshot) {
                  final jumlahNotif = snapshot.data ?? 0;
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(13),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          jumlahNotif > 0
                              ? Icons.notifications_rounded
                              : Icons.notifications_none_rounded,
                          color: kPrimary,
                          size: 22,
                        ),
                      ),
                      if (jumlahNotif > 0)
                        Positioned(
                          top: -4,
                          right: -4,
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Theme.of(
                                  context,
                                ).scaffoldBackgroundColor,
                                width: 1.5,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                jumlahNotif > 9 ? '9+' : jumlahNotif.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            // Avatar profil
            GestureDetector(
              onTap: () => Navigator.pushNamed(
                context,
                '/profile',
              ).then((_) => setState(() {})),
              child: FutureBuilder<File?>(
                future: _loadLocalProfileImage(),
                builder: (context, snapshot) {
                  final localImageFile = snapshot.data;
                  return CircleAvatar(
                    radius: 22,
                    backgroundColor: kPrimary,
                    backgroundImage: localImageFile != null
                        ? FileImage(localImageFile)
                        : null,
                    child: localImageFile == null
                        ? const Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 22,
                          )
                        : null,
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _goToOrder({String? status, bool belumBayar = false}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            OrderScreen(initialStatus: status, initialBelumBayar: belumBayar),
      ),
    );
  }
}

// ─── Helper model untuk stats card ────────────────────────────────────────
class _OrderStatItem {
  final String label;
  final int count;
  final IconData icon;
  final Color bgColor;
  final Color iconColor;

  const _OrderStatItem({
    required this.label,
    required this.count,
    required this.icon,
    required this.bgColor,
    required this.iconColor,
  });
}

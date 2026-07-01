import 'dart:io';
import 'package:mdnlaundry_project/screens/outlet/outlet_service.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:mdnlaundry_project/screens/scanner_screen.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'main_screens.dart';
import 'package:mdnlaundry_project/screens/settings/outlet/admin_activation.dart';

class HomeScreen extends StatefulWidget {
  final String storeId;
  final String outletId;
  final String outletName;
  final VoidCallback? onSwitchOutlet;
  final bool isOwner;

  const HomeScreen({
    super.key,
    required this.storeId,
    required this.outletId,
    this.outletName = '',
    this.onSwitchOutlet,
    this.isOwner = false,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final bool _isLoading = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _currentOutletId = '';
  String _currentOutletName = '';
  bool _pendingAdminCheckDone = false;

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

    // ── Cek admin pending khusus untuk Owner ──
    if (widget.isOwner) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkPendingAdmin();
      });
    }
  }

  @override
  void dispose() {
    _heartController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
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
          body: Column(
            children: [
              _buildHeroSection(user, isDark),
              Expanded(
                child: GlobalRefresh(
                  onRefresh: () async => setState(() {}),
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        _buildOrderStatsGrid(),
                        const SizedBox(height: 8),
                        _buildSearchBar(),
                        const SizedBox(height: 12),
                        _searchQuery.isEmpty
                            ? _buildRecentOrdersSection()
                            : _buildSearchResult(_searchQuery),
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
    );
  }

  // ── Urutan pipeline status laundry ─────────────────────────────
  static const List<Map<String, dynamic>> _statusPipeline = [
    {
      'key': 'antrian',
      'label': 'Antrian',
      'desc': 'Order masuk dan menunggu diproses',
      'icon': Icons.timer_outlined,
      'color': Color(0xFF4F6FE8),
    },
    {
      'key': 'proses',
      'label': 'Sedang Diproses',
      'desc': 'Laundry sedang dalam pengerjaan',
      'icon': Icons.local_laundry_service_outlined,
      'color': Color(0xFFF59E0B),
    },
    {
      'key': 'siap ambil',
      'label': 'Siap Diambil',
      'desc': 'Laundry selesai dan siap diambil',
      'icon': Icons.inventory_2_outlined,
      'color': Color(0xFF0D9488),
    },
    {
      'key': 'selesai',
      'label': 'Selesai',
      'desc': 'Order telah selesai dan diambil pelanggan',
      'icon': Icons.check_circle_outline_rounded,
      'color': Color(0xFF10B981),
    },
  ];

  Widget _buildSearchResult(String query) {
    final q = query.toLowerCase();

    return StreamBuilder<QuerySnapshot>(
      stream: OutletService.getOrdersStream(
        storeId: widget.storeId,
        outletId: widget.outletId,
        // statusFilter tidak diisi → ambil semua status
      ),

      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(color: Color(0xFF0D9488)),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildSearchEmpty();
        }

        final filtered = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final noOrder = (data['nomor_pelanggan']?.toString() ?? '')
              .toLowerCase();
          final nama = (data['nama_pelanggan']?.toString() ?? '').toLowerCase();
          return noOrder.contains(q) || nama.contains(q);
        }).toList();

        if (filtered.isEmpty) return _buildSearchEmpty();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Label ────────────────────────────────────────────────
            Row(
              children: [
                Text(
                  'Hasil Pencarian',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: kPrimary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${filtered.length} ditemukan',
                    style: TextStyle(
                      fontSize: 11,
                      color: kPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Cards ────────────────────────────────────────────────
            ...filtered.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return _buildOrderTimelineCard(doc.id, data, q);
            }),
          ],
        );
      },
    );
  }

  Widget _buildOrderTimelineCard(
    String docId,
    Map<String, dynamic> data,
    String query,
  ) {
    final noOrder = data['nomor_pelanggan']?.toString() ?? '-';
    final nama = data['nama_pelanggan']?.toString() ?? '-';
    final noHp = data['no_hp']?.toString() ?? '';
    final status = (data['status']?.toString() ?? '').toLowerCase();
    final estimasi = data['estimasi_selesai']?.toString() ?? '-';
    final isExact = noOrder.toLowerCase() == query;

    // Waktu order
    final waktuOrder = data['waktu_order'];
    String tanggalMasuk = '-';
    if (waktuOrder != null) {
      try {
        final dt = waktuOrder is Timestamp
            ? waktuOrder.toDate()
            : DateTime.tryParse(waktuOrder.toString());
        if (dt != null)
          tanggalMasuk = DateFormat('dd MMM yyyy, HH:mm').format(dt);
      } catch (_) {}
    }

    // Cari index status saat ini di pipeline
    final currentIndex = _statusPipeline.indexWhere(
      (s) => (s['key'] as String) == status,
    );
    // Kalau 'lunas' atau status lain → anggap selesai (index terakhir)
    final activeIndex = currentIndex == -1
        ? _statusPipeline.length - 1
        : currentIndex;

    // Warna & icon status aktif
    final activeColor = currentIndex == -1
        ? const Color(0xFF10B981)
        : _statusPipeline[activeIndex]['color'] as Color;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: isExact ? Border.all(color: kPrimary, width: 1.5) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Header card ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                // Icon status
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: activeColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    currentIndex == -1
                        ? Icons.check_circle_outline_rounded
                        : _statusPipeline[activeIndex]['icon'] as IconData,
                    color: activeColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        noOrder,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
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
                              nama,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(
                                context,
                              ).textTheme.bodySmall?.copyWith(fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Badge status aktif
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: activeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    currentIndex == -1
                        ? 'Selesai'
                        : (_statusPipeline[activeIndex]['label'] as String),
                    style: TextStyle(
                      color: activeColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),
          Divider(height: 1, color: Colors.grey.withOpacity(0.12)),
          const SizedBox(height: 4),

          // ── TIMELINE ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 16, 4),
            child: Column(
              children: List.generate(_statusPipeline.length, (i) {
                final step = _statusPipeline[i];
                final isDone = i <= activeIndex;
                final isActive = i == activeIndex;
                final stepColor = isDone
                    ? (step['color'] as Color)
                    : Colors.grey.shade300;
                final isLast = i == _statusPipeline.length - 1;

                // Timestamp: masuk → tanggalMasuk, aktif → sekarang, lain → '-'
                String timeLabel = '';
                if (i == 0)
                  timeLabel = tanggalMasuk;
                else if (isActive) {
                  timeLabel = DateFormat('dd MMM yyyy').format(DateTime.now());
                }

                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Kolom kiri: garis + dot ─────────────────
                      SizedBox(
                        width: 24,
                        child: Column(
                          children: [
                            // Dot
                            Container(
                              width: isActive ? 14 : 10,
                              height: isActive ? 14 : 10,
                              margin: EdgeInsets.only(top: isActive ? 1 : 3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isDone
                                    ? stepColor
                                    : Colors.grey.shade300,
                                boxShadow: isActive
                                    ? [
                                        BoxShadow(
                                          color: stepColor.withOpacity(0.4),
                                          blurRadius: 6,
                                          spreadRadius: 1,
                                        ),
                                      ]
                                    : null,
                              ),
                            ),
                            // Garis ke bawah
                            if (!isLast)
                              Expanded(
                                child: Container(
                                  width: 2,
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: i < activeIndex
                                        ? stepColor.withOpacity(0.4)
                                        : Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),

                      // ── Konten kanan ────────────────────────────
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(bottom: isLast ? 16 : 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                step['label'] as String,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isActive
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: isDone
                                      ? Theme.of(
                                          context,
                                        ).textTheme.bodyLarge?.color
                                      : Colors.grey.shade400,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                // Step aktif tampilkan estimasi kalau ada
                                isActive &&
                                        estimasi.isNotEmpty &&
                                        estimasi != '-'
                                    ? 'Est. selesai: $estimasi'
                                    : (step['desc'] as String),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDone
                                      ? Colors.grey.shade500
                                      : Colors.grey.shade300,
                                ),
                              ),
                              if (timeLabel.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  timeLabel,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isDone
                                        ? stepColor
                                        : Colors.grey.shade300,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),

          // ── Footer: tombol lihat detail ─────────────────────────
          InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => OrderDetailScreen(
                  docId: docId,
                  data: data,
                  storeId: widget.storeId,
                  outletId: widget.outletId,
                ),
              ),
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(18),
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                color: kPrimary.withOpacity(0.05),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Lihat Detail Order',
                    style: TextStyle(
                      fontSize: 12,
                      color: kPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 11,
                    color: kPrimary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchEmpty() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 10),
          Text(
            'Order tidak ditemukan',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            'Coba cari dengan no. order atau nama lain',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey.shade400,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        Expanded(
          child: Container(
            height: 46,
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Cari no. order atau nama pelanggan...',
                hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: Colors.grey.shade400,
                ),
                // Tombol clear muncul jika ada teks
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: Colors.grey.shade400,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),

        // ── Tombol QR scanner ─────────────────────────────────────
        GestureDetector(
          onTap: () async {
            final String? result = await Navigator.push<String>(
              context,
              MaterialPageRoute(builder: (_) => const QRScannerScreen()),
            );
            if (result != null && result.isNotEmpty) {
              _searchController.text = result;
              setState(() => _searchQuery = result.trim());
            }
          },
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [kPrimary, const Color(0xFF2563EB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: kPrimary.withOpacity(0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(
              Icons.qr_code_scanner_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
      ],
    );
  }

  // ─── HERO SECTION ────────────────────────────────────────────────────────
  Widget _buildHeroSection(User? user, bool isDark) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    final tanggalStr = DateFormat('dd MMM yyyy').format(now);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('order')
          .where('store_id', isEqualTo: widget.storeId)
          .where('outlet_id', isEqualTo: widget.outletId) // ← tambah ini
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
          // ── Rounded hanya di sudut bawah ─────────────────────────────
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF1A2744), const Color(0xFF0D1B3E)]
                  : [kPrimary, const Color(0xFF2563EB)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(30),
              bottomRight: Radius.circular(30),
            ),
            boxShadow: [
              BoxShadow(
                color: kPrimary.withOpacity(0.35),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              22,
              MediaQuery.of(context).padding.top + 14,
              22,
              22, // sedikit lebih besar di bawah agar round terlihat
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Baris header ─────────────────────────────────────────
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
                            "Selamat datang di ${OutletSettings.namaLaundry}",
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
                              builder: (_) => NotifikasiScreen(
                                storeId: widget.storeId,
                                outletId: widget.outletId,
                              ),
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

                const SizedBox(height: 14),

                // ── Card pendapatan ───────────────────────────────────────
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
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

                          // Tombol pindah outlet
                          // Tombol pindah outlet — hanya Owner yang bisa ganti outlet
                          if (widget.isOwner)
                            GestureDetector(
                              onTap: () => widget.onSwitchOutlet?.call(),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.4),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.store_outlined,
                                      color: Colors.white,
                                      size: 12,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      widget.outletName.isNotEmpty
                                          ? widget.outletName
                                          : 'Pilih Outlet',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 3),
                                    const Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      color: Colors.white,
                                      size: 14,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
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

  // ─── ORDER STATS GRID 3x2 ────────────────────────────────────────────────
  Widget _buildOrderStatsGrid() {
    return StreamBuilder<QuerySnapshot>(
      stream: OutletService.getOrdersStream(
        storeId: widget.storeId,
        outletId: widget.outletId,
      ),
      builder: (context, snapshot) {
        int antrian = 0;
        int proses = 0;
        int siapAmbil = 0;

        int deadline = 0;
        int terlambat = 0;

        if (snapshot.hasData) {
          final now = DateTime.now();
          for (final doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final status = (data['status']?.toString() ?? '').toLowerCase();

            switch (status) {
              case 'antrian':
                antrian++;
                break;
              case 'proses':
                proses++;
                break;
              case 'siap ambil':
              case 'siap antar':
                siapAmbil++;
                break;
            }

            const selesaiStatus = {'selesai', 'siap ambil', 'siap antar'};
            if (!selesaiStatus.contains(status)) {
              final estimasi = data['estimasi_selesai'];
              DateTime? dlDate;
              if (estimasi is Timestamp) {
                dlDate = estimasi.toDate();
              } else if (estimasi is String && estimasi.isNotEmpty) {
                try {
                  final parts = estimasi.split('-');
                  if (parts.length == 3) {
                    dlDate = parts[0].length == 4
                        ? DateTime(
                            int.parse(parts[0]),
                            int.parse(parts[1]),
                            int.parse(parts[2]),
                          )
                        : DateTime(
                            int.parse(parts[2]),
                            int.parse(parts[1]),
                            int.parse(parts[0]),
                          );
                  }
                } catch (_) {}
              }
              if (dlDate != null) {
                final now = DateTime.now();
                final today = DateTime(now.year, now.month, now.day);
                final diff = DateTime(
                  dlDate.year,
                  dlDate.month,
                  dlDate.day,
                ).difference(today).inDays;
                if (diff < 0) {
                  terlambat++;
                } else if (diff <= 1) {
                  deadline++;
                }
              }
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
            label: 'Rak Monitoring',
            count: siapAmbil,
            icon: Icons.shelves,
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
            final w = (MediaQuery.of(context).size.width - 28 - 20) / 3;
            return SizedBox(width: w, child: _buildOrderStatCard(item));
          }).toList(),
        );
      },
    );
  }

  // ── Helper: klasifikasi deadline / terlambat berdasarkan datetime penuh ──
  // Mutually exclusive: sebuah order hanya akan masuk ke salah satu,
  // deadline ATAU terlambat, tidak pernah keduanya.
  void _hitungDeadlineTerlambat(
    DateTime? deadlineDateTime,
    DateTime now,
    void Function() onDeadline,
    void Function() onTerlambat,
  ) {
    if (deadlineDateTime == null) return;

    if (deadlineDateTime.isBefore(now)) {
      // Sudah lewat jam deadline → terlambat
      onTerlambat();
    } else if (deadlineDateTime.difference(now) <= const Duration(hours: 3)) {
      // Sisa waktu ≤ 3 jam → baru dihitung "Deadline"
      onDeadline();
    }
    // Kalau sisa waktu masih > 3 jam, tidak dihitung di kedua kategori,
    // cukup tampil di Antrian/Proses seperti biasa.
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
      case 'Rak Monitoring':
        navStatus = 'rak monitoring';
        break;
      case 'Deadline':
      case 'Terlambat':
        navStatus = null;
        break;
    }

    return GestureDetector(
      onTap: () {
        if (item.label == 'Rak Monitoring') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RakMonitoringScreen(
                storeId: widget.storeId,
                outletId: widget.outletId,
              ),
            ),
          );
          return;
        }
        if (item.label == 'Deadline' || item.label == 'Terlambat') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OrderScreen(
                storeId: widget.storeId,
                outletId: widget.outletId,
                initialDeadline: true,
              ),
            ),
          );
          return;
        }
        _goToOrder(status: navStatus);
      },
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
          mainAxisSize: MainAxisSize.min,
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

  // ─── RECENT ORDERS: bulan ini, terbaru di atas ───────────────────────────
  Widget _buildRecentOrdersSection() {
    final now = DateTime.now();
    // Awal & akhir bulan ini
    final bulanStart = DateTime(now.year, now.month, 1);
    final bulanEnd = DateTime(now.year, now.month + 1, 1);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('order')
          .where('store_id', isEqualTo: widget.storeId)
          .where('outlet_id', isEqualTo: widget.outletId) // ← tambah ini
          .where(
            'waktu_order',
            isGreaterThanOrEqualTo: Timestamp.fromDate(bulanStart),
          )
          .where('waktu_order', isLessThan: Timestamp.fromDate(bulanEnd))
          .snapshots(),
      builder: (context, snapshot) {
        final bulanLabel = DateFormat('MMMM yyyy', 'id_ID').format(now);

        // ── Sort client-side: terbaru di atas ──────────────────────────
        final docs = snapshot.hasData
            ? [...snapshot.data!.docs]
            : <QueryDocumentSnapshot>[];
        docs.sort((a, b) {
          final dataA = a.data() as Map<String, dynamic>;
          final dataB = b.data() as Map<String, dynamic>;
          final tA = dataA['waktu_order'];
          final tB = dataB['waktu_order'];
          if (tA == null && tB == null) return 0;
          if (tA == null) return 1;
          if (tB == null) return -1;
          final tsA = tA is Timestamp
              ? tA.toDate()
              : DateTime.tryParse(tA.toString()) ?? DateTime(0);
          final tsB = tB is Timestamp
              ? tB.toDate()
              : DateTime.tryParse(tB.toString()) ?? DateTime(0);
          return tsB.compareTo(tsA); // descending
        });

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // ── "Order Terbaru" + badge bulan sejajar dalam satu Row ─
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      "Order Terbaru",
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        bulanLabel,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
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
                      "${docs.length} order",
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
                  "Gagal memuat data ${snapshot.error}",
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              )
            else if (docs.isEmpty)
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
                      "Belum ada order bulan ini",
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              )
            else
              ...docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final noPelanggan = data['nomor_pelanggan']?.toString() ?? "-";
                final layananNama = data['layanan_nama']?.toString() ?? "-";
                final status = data['status']?.toString() ?? "-";
                final waktuOrder = data['waktu_order'];
                String tanggalInput = "-";
                if (waktuOrder != null) {
                  try {
                    final dt = waktuOrder is Timestamp
                        ? waktuOrder.toDate()
                        : DateTime.tryParse(waktuOrder.toString());
                    if (dt != null) {
                      tanggalInput = DateFormat('dd-MM-yyyy').format(dt);
                    }
                  } catch (_) {}
                }

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
                    statusIcon = Icons.shelves;
                    break;
                  default:
                    statusColor = const Color(0xFF10B981);
                    statusIcon = Icons.check_circle_outline_outlined;
                }

                return GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OrderDetailScreen(
                        docId: doc.id,
                        data: data,
                        storeId: widget.storeId,
                        outletId: widget.outletId,
                      ),
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
                      crossAxisAlignment: CrossAxisAlignment.start,
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

                              // ── TAMBAHAN: nominal di bawah badge ──────────────────
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.payments_outlined,
                                    size: 11,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    () {
                                      final harga = data['harga_total'];
                                      if (harga == null) return '-';
                                      try {
                                        final n = harga is num
                                            ? harga.toInt()
                                            : int.parse(harga.toString());
                                        return NumberFormat.currency(
                                          locale: 'id_ID',
                                          symbol: 'Rp ',
                                          decimalDigits: 0,
                                        ).format(n);
                                      } catch (_) {
                                        return '-';
                                      }
                                    }(),
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                        ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          mainAxisSize:
                              MainAxisSize.min, // ← kunci: min biar ga stretch
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
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
                                tanggalInput,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            QrImageView(
                              data: noPelanggan,
                              version: QrVersions.auto,
                              size: 48,
                              backgroundColor: Colors.transparent,
                              errorCorrectionLevel: QrErrorCorrectLevel.L,
                              eyeStyle: QrEyeStyle(
                                eyeShape: QrEyeShape.square,
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.white
                                    : Colors.black,
                              ),
                              dataModuleStyle: QrDataModuleStyle(
                                dataModuleShape: QrDataModuleShape.square,
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.white
                                    : Colors.black,
                              ),
                            ),
                          ],
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

  // ════════════════════════════════════════════════════════════
  // CEK ADMIN MENUNGGU AKTIVASI (khusus Owner)
  // ════════════════════════════════════════════════════════════
  Future<void> _checkPendingAdmin() async {
    if (_pendingAdminCheckDone) return;
    _pendingAdminCheckDone = true;

    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('store_id', isEqualTo: widget.storeId)
          .where('role', isEqualTo: 'Admin')
          .get();

      final pendingAdmins = snap.docs.where((doc) {
        final data = doc.data();
        return (data['is_activated'] ?? false) == false;
      }).toList();

      if (pendingAdmins.isNotEmpty && mounted) {
        _showPendingAdminDialog(pendingAdmins.length);
      }
    } catch (e) {
      debugPrint('ERROR cek pending admin: $e');
    }
  }

  void _showPendingAdminDialog(int count) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_add_alt_1_rounded,
                  color: Colors.orange,
                  size: 30,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Ada Admin Menunggu Aktivasi',
                textAlign: TextAlign.center,
                style: Theme.of(ctx).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                count == 1
                    ? '1 admin baru mendaftar dan menunggu persetujuan kamu.'
                    : '$count admin baru mendaftar dan menunggu persetujuan kamu.',
                textAlign: TextAlign.center,
                style: Theme.of(
                  ctx,
                ).textTheme.bodySmall?.copyWith(fontSize: 13),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Nanti'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                AdminActivationScreen(storeId: widget.storeId),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Lihat Sekarang',
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

  void _goToOrder({String? status, bool belumBayar = false}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderScreen(
          storeId: widget.storeId,
          outletId: widget.outletId,
          initialStatus: status,
          initialBelumBayar: belumBayar,
        ),
      ),
    );
  }
}

// ─── Helper model ─────────────────────────────────────────────────────────
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

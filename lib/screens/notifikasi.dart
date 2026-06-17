import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'screens.dart';

// ─── Model notifikasi (sync dari Firestore) ──────────────────────────────────
class NotifItem {
  final String id;
  final String judul;
  final String isi;
  final DateTime waktu;
  bool sudahDibaca;

  NotifItem({
    required this.id,
    required this.judul,
    required this.isi,
    required this.waktu,
    this.sudahDibaca = false,
  });

  factory NotifItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NotifItem(
      id: doc.id,
      judul: data['judul'] ?? '',
      isi: data['isi'] ?? '',
      waktu: (data['waktu'] as Timestamp?)?.toDate() ?? DateTime.now(),
      sudahDibaca: data['sudahDibaca'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'id': id,
    'judul': judul,
    'isi': isi,
    'waktu': Timestamp.fromDate(waktu),
    'sudahDibaca': sudahDibaca,
  };

  // Untuk backward compat dengan SharedPreferences (jika ada)
  factory NotifItem.fromJson(Map<String, dynamic> json) => NotifItem(
    id: json['id'] ?? '',
    judul: json['judul'] ?? '',
    isi: json['isi'] ?? '',
    waktu: DateTime.tryParse(json['waktu'] ?? '') ?? DateTime.now(),
    sudahDibaca: json['sudahDibaca'] ?? false,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'judul': judul,
    'isi': isi,
    'waktu': waktu.toIso8601String(),
    'sudahDibaca': sudahDibaca,
  };
}

// ─── Firestore NotifStorage ──────────────────────────────────────────────────
class NotifStorage {
  static const _collectionName = 'notif_history';
  static const _maxItem = 50;

  static CollectionReference get _notifCollection =>
      FirebaseFirestore.instance.collection(_collectionName);

  static String? get _currentUserId => FirebaseAuth.instance.currentUser?.uid;

  /// Simpan notif baru ke Firestore
  static Future<void> simpan(NotifItem item) async {
    try {
      final userId = _currentUserId;
      if (userId == null) {
        debugPrint('⚠ User belum login, notif tidak disimpan');
        return;
      }

      // Simpan ke sub-collection user-specific untuk isolasi data
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection(_collectionName)
          .doc(item.id)
          .set(item.toFirestore());

      debugPrint('✅ Notif tersimpan di Firestore: ${item.judul}');
    } catch (e) {
      debugPrint('⚠ Error simpan notif: $e');
    }
  }

  /// Ambil semua notif dari Firestore (sync antar device)
  static Future<List<NotifItem>> ambilSemua() async {
    try {
      final userId = _currentUserId;
      if (userId == null) {
        debugPrint('⚠ User belum login, notif kosong');
        return [];
      }

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection(_collectionName)
          .orderBy('waktu', descending: true)
          .limit(_maxItem)
          .get();

      return snapshot.docs.map((doc) => NotifItem.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('⚠ Error ambil notif: $e');
      return [];
    }
  }

  /// Stream notif untuk real-time update
  static Stream<List<NotifItem>> streamNotif() {
    final userId = _currentUserId;
    if (userId == null) return Stream.value([]);

    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection(_collectionName)
        .orderBy('waktu', descending: true)
        .limit(_maxItem)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => NotifItem.fromFirestore(doc)).toList(),
        );
  }

  /// Hapus satu notif berdasarkan id
  static Future<void> hapus(String id) async {
    try {
      final userId = _currentUserId;
      if (userId == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection(_collectionName)
          .doc(id)
          .delete();

      debugPrint('✅ Notif dihapus: $id');
    } catch (e) {
      debugPrint('⚠ Error hapus notif: $e');
    }
  }

  /// Hapus semua notif
  static Future<void> hapusSemua() async {
    try {
      final userId = _currentUserId;
      if (userId == null) return;

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection(_collectionName)
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      debugPrint('✅ Semua notif dihapus');
    } catch (e) {
      debugPrint('⚠ Error hapus semua notif: $e');
    }
  }

  /// Tandai semua sudah dibaca
  static Future<void> tandaiSemuaDibaca() async {
    try {
      final userId = _currentUserId;
      if (userId == null) return;

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection(_collectionName)
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {'sudahDibaca': true});
      }
      await batch.commit();

      debugPrint('✅ Semua notif ditandai dibaca');
    } catch (e) {
      debugPrint('⚠ Error tandai dibaca: $e');
    }
  }

  /// Hitung jumlah notif belum dibaca
  static Future<int> jumlahBelumDibaca() async {
    try {
      final userId = _currentUserId;
      if (userId == null) return 0;

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection(_collectionName)
          .where('sudahDibaca', isEqualTo: false)
          .get();

      return snapshot.size;
    } catch (e) {
      debugPrint('⚠ Error hitung belum dibaca: $e');
      return 0;
    }
  }

  /// Stream jumlah notif belum dibaca (real-time)
  static Stream<int> streamJumlahBelumDibaca() {
    final userId = _currentUserId;
    if (userId == null) return Stream.value(0);

    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection(_collectionName)
        .where('sudahDibaca', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.size);
  }
}

// ─── Screen ──────────────────────────────────────────────────────────────────
class NotifikasiScreen extends StatefulWidget {
  const NotifikasiScreen({super.key});

  @override
  State<NotifikasiScreen> createState() => _NotifikasiScreenState();
}

class _NotifikasiScreenState extends State<NotifikasiScreen> {
  bool _isLoading = true;
  List<NotifItem> _listNotif = [];

  @override
  void initState() {
    super.initState();
    _loadNotif();
  }

  Future<void> _loadNotif() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final list = await NotifStorage.ambilSemua();

    // Tandai semua dibaca saat screen dibuka
    await NotifStorage.tandaiSemuaDibaca();

    if (!mounted) return;
    setState(() {
      _listNotif = list;
      _isLoading = false;
    });
  }

  Future<void> _hapusItem(NotifItem item) async {
    await NotifStorage.hapus(item.id);
    if (!mounted) return;
    setState(() => _listNotif.removeWhere((n) => n.id == item.id));
  }

  Future<void> _hapusSemua() async {
    final konfirmasi = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Semua Notifikasi?'),
        content: const Text('Semua riwayat notifikasi akan dihapus permanen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (konfirmasi != true) return;
    await NotifStorage.hapusSemua();
    if (!mounted) return;
    setState(() => _listNotif.clear());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(context),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kPrimary))
          : GlobalRefresh(
              onRefresh: _loadNotif,
              child: _listNotif.isEmpty
                  ? _buildEmptyState()
                  : ListView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      children: [
                        _buildInfoBanner(),
                        const SizedBox(height: 12),
                        ..._listNotif.map(
                          (item) => _buildSwipeableCard(context, item),
                        ),
                        const SizedBox(height: 80),
                      ],
                    ),
            ),
    );
  }

  // ── Banner info ─────────────────────────────────────────────────────────────
  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: kPrimary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kPrimary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.swipe_left_rounded, color: kPrimary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Geser ke kiri untuk menghapus notifikasi.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: kPrimary, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  // ── Card dengan swipe to delete ─────────────────────────────────────────────
  Widget _buildSwipeableCard(BuildContext context, NotifItem item) {
    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _hapusItem(item),
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(18),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_rounded, color: Colors.white, size: 26),
            SizedBox(height: 4),
            Text(
              'Hapus',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      child: GestureDetector(
        onTap: () => _bukaDetailNotif(item),
        child: _buildNotifCard(context, item),
      ),
    );
  }

  // ── Card notifikasi ─────────────────────────────────────────────────────────
  Widget _buildNotifCard(BuildContext context, NotifItem item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isUnread = !item.sudahDibaca;

    // Format waktu relatif
    final now = DateTime.now();
    final selisih = now.difference(item.waktu);
    String waktuLabel;
    if (selisih.inMinutes < 1) {
      waktuLabel = 'Baru saja';
    } else if (selisih.inMinutes < 60) {
      waktuLabel = '${selisih.inMinutes} menit lalu';
    } else if (selisih.inHours < 24) {
      waktuLabel = '${selisih.inHours} jam lalu';
    } else if (selisih.inDays == 1) {
      waktuLabel = 'Kemarin';
    } else {
      waktuLabel = DateFormat('dd MMM yyyy', 'id_ID').format(item.waktu);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isUnread
            ? kPrimary.withOpacity(isDark ? 0.12 : 0.05)
            : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isUnread
              ? kPrimary.withOpacity(0.3)
              : Colors.grey.withOpacity(0.15),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.15 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Icon notif ──────────────────────────────────────────────────
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: kPrimary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                Icons.local_laundry_service_rounded,
                color: kPrimary,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),

            // ── Konten ──────────────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Judul + dot unread
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.judul,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                fontWeight: isUnread
                                    ? FontWeight.bold
                                    : FontWeight.w600,
                                fontSize: 14,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isUnread)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: kPrimary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Isi notif
                  Text(
                    item.isi,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(fontSize: 13, height: 1.4),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),

                  // Waktu
                  Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 12,
                        color: Theme.of(
                          context,
                        ).textTheme.bodySmall?.color?.withOpacity(0.6),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        waktuLabel,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          color: Theme.of(
                            context,
                          ).textTheme.bodySmall?.color?.withOpacity(0.6),
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
  }

  // ── Empty state ─────────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      children: [
        const SizedBox(height: 80),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: kPrimary.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.notifications_none_rounded,
                  size: 52,
                  color: kPrimary.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Belum Ada Notifikasi',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Notifikasi estimasi laundry selesai\nakan muncul di sini.',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 32),
              OutlinedButton.icon(
                onPressed: _loadNotif,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Refresh'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kPrimary,
                  side: BorderSide(color: kPrimary.withOpacity(0.4)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── AppBar ──────────────────────────────────────────────────────────────────
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
            'Notifikasi',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          backgroundColor: kPrimary,
          foregroundColor: Colors.white,
          elevation: 2,
          centerTitle: true,
          leading: Navigator.canPop(context)
              ? IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                )
              : null,
          actions: [
            if (_listNotif.isNotEmpty)
              IconButton(
                onPressed: _hapusSemua,
                icon: const Icon(
                  Icons.delete_sweep_rounded,
                  color: Colors.white,
                ),
                tooltip: 'Hapus Semua',
              ),
          ],
        ),
      ),
    );
  }

  void _bukaDetailNotif(NotifItem item) {
    final judul = item.judul.toLowerCase();

    Widget screen;
    if (judul.contains('terlambat') || judul.contains('deadline')) {
      screen = const OrderScreen(initialDeadline: true);
    } else if (judul.contains('estimasi') || judul.contains('selesai')) {
      screen = const OrderScreen(initialStatus: 'proses');
    } else {
      screen = const OrderScreen();
    }

    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }
}

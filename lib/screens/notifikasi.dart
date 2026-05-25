// ─── notifikasi.dart ────────────────────────────────────────────────────────
// Halaman notifikasi pasien KB/KIA yang akan jatuh tempo dalam 3 hari ke depan.
// - Terintegrasi langsung dengan Firestore collection 'rekam_medis' & 'pasien'
// - Notif hilang otomatis jika sudah lewat > 1 hari dari tgl_kembali
// - Tombol "Ingatkan" kirim pesan WhatsApp dengan isi dinamis (X hari lagi / hari ini / terlambat)
// - Empty state jika tidak ada pasien yang jatuh tempo

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'screens.dart'; // kPrimary & konstanta lain sudah ada di sini

class NotifikasiScreen extends StatefulWidget {
  const NotifikasiScreen({super.key});

  @override
  State<NotifikasiScreen> createState() => _NotifikasiScreenState();
}

class _NotifikasiScreenState extends State<NotifikasiScreen> {
  bool _isLoading = true;
  List<_PasienJatuhTempo> _listPasien = [];

  @override
  void initState() {
    super.initState();
    _loadNotifikasi();
  }

  /// Ambil semua rekam_medis yang punya tgl_kembali,
  /// filter yang jatuh tempo dalam -1 s/d +3 hari dari sekarang,
  /// lalu join nama & nomor HP dari collection 'pasien'.
  Future<void> _loadNotifikasi() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final firestore = FirebaseFirestore.instance;
      final now = DateTime.now();
      final hariIni = DateTime(now.year, now.month, now.day);

      // Batas filter: kemarin (batas bawah, hari H-1 masih tampil)
      // dan 3 hari ke depan (batas atas)
      final batasAwal = hariIni.subtract(const Duration(days: 1));
      final batasAkhir = hariIni.add(const Duration(days: 3));

      // Ambil rekam medis dengan tgl_kembali yang tidak kosong
      // Karena Firestore tidak bisa filter string date langsung,
      // kita ambil semua yang punya tgl_kembali lalu filter di client
      final snap = await firestore
          .collection('rekam_medis')
          .where('tgl_kembali', isNotEqualTo: '')
          .orderBy('tgl_kembali')
          .get();

      // Dedup: per NIP hanya ambil rekam medis terbaru
      final Map<String, QueryDocumentSnapshot> latestPerNip = {};
      for (final doc in snap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final nip = data['nomer_induk_pasien']?.toString() ?? '';
        if (nip.isEmpty) continue;
        final tglStr = data['tgl_kembali']?.toString().trim() ?? '';
        if (tglStr.isEmpty) continue;

        // Parse tgl_kembali format "dd-MM-yyyy"
        DateTime? tglKembali;
        try {
          tglKembali = DateFormat('dd-MM-yyyy').parse(tglStr);
        } catch (_) {
          try {
            tglKembali = DateFormat('dd-MMM-yyyy', 'id_ID').parse(tglStr);
          } catch (_) {
            continue;
          }
        }

        // Filter: hanya tampilkan yang dalam rentang batasAwal ~ batasAkhir
        if (tglKembali.isBefore(batasAwal) || tglKembali.isAfter(batasAkhir)) {
          continue;
        }

        // Simpan hanya rekam medis paling baru per NIP
        if (!latestPerNip.containsKey(nip)) {
          latestPerNip[nip] = doc;
        } else {
          // Bandingkan waktu_kunjungan untuk ambil yang terbaru
          final existing =
              (latestPerNip[nip]!.data()
                      as Map<String, dynamic>)['waktu_kunjungan']
                  ?.toString() ??
              '';
          final current = data['waktu_kunjungan']?.toString() ?? '';
          if (current.compareTo(existing) > 0) {
            latestPerNip[nip] = doc;
          }
        }
      }

      // Untuk setiap NIP, ambil nama & HP dari collection 'pasien'
      final List<_PasienJatuhTempo> hasil = [];
      for (final entry in latestPerNip.entries) {
        final nip = entry.key;
        final rekamData = entry.value.data() as Map<String, dynamic>;

        final tglStr = rekamData['tgl_kembali'].toString().trim();
        DateTime tglKembali;
        try {
          tglKembali = DateFormat('dd-MM-yyyy').parse(tglStr);
        } catch (_) {
          tglKembali = DateFormat('dd-MMM-yyyy', 'id_ID').parse(tglStr);
        }

        // Ambil data pasien
        String nama = nip;
        String hp = '';
        try {
          final pasienSnap = await firestore
              .collection('pasien')
              .where('nomer_induk_pasien', isEqualTo: nip)
              .limit(1)
              .get();
          if (pasienSnap.docs.isNotEmpty) {
            final pData = pasienSnap.docs.first.data();
            nama = pData['nama_lengkap']?.toString() ?? nip;
            hp = pData['nomer_hp']?.toString() ?? '';
          }
        } catch (_) {}

        final selisihHari = tglKembali
            .difference(DateTime(now.year, now.month, now.day))
            .inDays;

        hasil.add(
          _PasienJatuhTempo(
            nip: nip,
            nama: nama,
            hp: hp,
            tglKembali: tglKembali,
            selisihHari: selisihHari,
            layanan: rekamData['layanan']?.toString() ?? 'KIA',
          ),
        );
      }

      // Urutkan: paling dekat jatuh tempo duluan
      hasil.sort((a, b) => a.selisihHari.compareTo(b.selisihHari));

      if (!mounted) return;
      setState(() {
        _listPasien = hasil;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loadNotifikasi: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  /// Kirim pesan WhatsApp pengingat jadwal KB
  Future<void> _kirimWA(BuildContext context, _PasienJatuhTempo pasien) async {
    if (pasien.hp.isEmpty) {
      _showSnack(context, 'Nomor HP pasien tidak tersedia', Colors.orange);
      return;
    }

    final tglFormatted = DateFormat(
      'dd MMMM yyyy',
      'id_ID',
    ).format(pasien.tglKembali);
    String infoWaktu;
    if (pasien.selisihHari > 0) {
      infoWaktu = '*${pasien.selisihHari} hari lagi*';
    } else if (pasien.selisihHari == 0) {
      infoWaktu = '*hari ini*';
    } else {
      infoWaktu = '*${pasien.selisihHari.abs()} hari yang lalu (terlambat!)*';
    }

    final pesan =
        '''Halo Bunda *${pasien.nama}*,

Kami dari ${OutletSettings.namaKlinik} mengingatkan bahwa jadwal kontrol KB Anda sudah $infoWaktu.

📅 *Jadwal Kembali:* $tglFormatted

Mohon segera kunjungi ${OutletSettings.namaKlinik} untuk pemeriksaan lanjutan demi menjaga kesehatan Anda.

Terima kasih 🙏''';

    // Bersihkan nomor HP: hapus +62 atau 0 di awal, tambahkan 62
    String hp = pasien.hp.replaceAll(RegExp(r'\s+|-'), '');
    if (hp.startsWith('0')) {
      hp = '62${hp.substring(1)}';
    } else if (hp.startsWith('+')) {
      hp = hp.substring(1);
    }

    final encodedPesan = Uri.encodeComponent(pesan);
    final waUrl = 'https://wa.me/$hp?text=$encodedPesan';

    try {
      final uri = Uri.parse(waUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (!context.mounted) return;
        _showSnack(context, 'Tidak dapat membuka WhatsApp', Colors.red);
      }
    } catch (e) {
      if (!context.mounted) return;
      _showSnack(context, 'Gagal membuka WhatsApp: $e', Colors.red);
    }
  }

  void _showSnack(BuildContext context, String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(context),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kPrimary))
          : RefreshIndicator(
              color: kPrimary,
              onRefresh: _loadNotifikasi,
              child: _listPasien.isEmpty
                  ? _buildEmptyState()
                  : ListView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      children: [
                        _buildInfoBanner(),
                        const SizedBox(height: 12),
                        ..._listPasien.map((p) => _buildNotifCard(context, p)),
                        const SizedBox(height: 80),
                      ],
                    ),
            ),
    );
  }

  /// Banner info kecil di atas list
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
          Icon(Icons.info_outline_rounded, color: kPrimary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Menampilkan pasien KB/KIA yang jatuh tempo dalam 3 hari ke depan.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: kPrimary, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  /// Card tiap pasien jatuh tempo
  Widget _buildNotifCard(BuildContext context, _PasienJatuhTempo pasien) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Tentukan warna & label status
    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    if (pasien.selisihHari < 0) {
      statusColor = Colors.red;
      statusLabel = 'Terlambat ${pasien.selisihHari.abs()} hari';
      statusIcon = Icons.warning_amber_rounded;
    } else if (pasien.selisihHari == 0) {
      statusColor = Colors.orange;
      statusLabel = 'Jatuh Tempo Hari Ini';
      statusIcon = Icons.today_rounded;
    } else if (pasien.selisihHari == 1) {
      statusColor = Colors.amber[700]!;
      statusLabel = 'Besok Jatuh Tempo';
      statusIcon = Icons.schedule_rounded;
    } else {
      statusColor = kPrimary;
      statusLabel = '${pasien.selisihHari} Hari Lagi';
      statusIcon = Icons.event_available_rounded;
    }

    final tglFormatted = DateFormat(
      'dd MMM yyyy',
      'id_ID',
    ).format(pasien.tglKembali);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: statusColor.withOpacity(0.3), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(isDark ? 0.08 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Baris atas: avatar + nama + badge status ──────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar inisial
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Center(
                    child: Text(
                      pasien.nama.isNotEmpty
                          ? pasien.nama[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pasien.nama,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        pasien.nip,
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                // Badge status
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, color: statusColor, size: 13),
                      const SizedBox(width: 4),
                      Text(
                        statusLabel,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // ── Info detail ───────────────────────────────────────────────
            Row(
              children: [
                _infoChip(
                  Icons.favorite_outline_rounded,
                  pasien.layanan,
                  Colors.pink,
                ),
                const SizedBox(width: 8),
                _infoChip(
                  Icons.calendar_today_rounded,
                  tglFormatted,
                  statusColor,
                ),
                const SizedBox(width: 8),
                if (pasien.hp.isNotEmpty)
                  _infoChip(
                    Icons.phone_android_rounded,
                    pasien.hp,
                    Colors.green,
                  ),
              ],
            ),

            const SizedBox(height: 14),

            // ── Tombol Ingatkan ───────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: pasien.hp.isEmpty
                    ? null
                    : () => _kirimWA(context, pasien),
                icon: const Icon(Icons.send_rounded, size: 17),
                label: Text(
                  pasien.hp.isEmpty
                      ? 'Nomor HP Tidak Ada'
                      : 'Ingatkan via WhatsApp',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: pasien.hp.isEmpty
                      ? Colors.grey[300]
                      : const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey[300],
                  disabledForegroundColor: Colors.grey[600],
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label, Color color) {
    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Empty state ketika tidak ada pasien KB yang jatuh tempo
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
                'Semua Terkontrol! 🎉',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Belum ada pasien KB/KIA yang\njatuh tempo dalam 3 hari ke depan.',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 32),
              OutlinedButton.icon(
                onPressed: _loadNotifikasi,
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
            "Notifikasi Pasien",
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
        ),
      ),
    );
  }
}

// ─── Model data lokal ────────────────────────────────────────────────────────
class _PasienJatuhTempo {
  final String nip;
  final String nama;
  final String hp;
  final DateTime tglKembali;
  final int selisihHari; // negatif = sudah lewat
  final String layanan;

  const _PasienJatuhTempo({
    required this.nip,
    required this.nama,
    required this.hp,
    required this.tglKembali,
    required this.selisihHari,
    required this.layanan,
  });
}

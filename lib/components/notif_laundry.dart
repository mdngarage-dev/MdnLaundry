import 'package:flutter/material.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import '../screens/notifikasi.dart';
import '../screens/main_screens.dart';

// ─── Navigator key global (tetap sama) ───────────────────────────────────────
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// ─── Konstanta OneSignal ──────────────────────────────────────────────────────
const _oneSignalAppId = '54e65963-bfc8-40ad-aef9-cb1d7303590e';

// ─── Tag identifikasi untuk targeting notif per outlet/toko ──────────────────
// Tag yang sebenarnya (store_id, role, current_outlet_id) di-SET dari
// HomeWrapper — setelah data user (storeId, role, currentOutletId) berhasil
// dimuat dari Firestore. Di sini TIDAK di-set apapun karena saat OneSignal
// init, user belum tentu sudah login / datanya belum tersedia.

// ─── Service utama ────────────────────────────────────────────────────────────
class NotifLaundryService {
  // Singleton — pastikan hanya ada 1 instance
  static final NotifLaundryService _instance = NotifLaundryService._internal();
  factory NotifLaundryService() => _instance;
  NotifLaundryService._internal();

  Future<void> inisialisasiNotifikasi() async {
    debugPrint("▶ Inisialisasi notifikasi OneSignal Laundry...");

    try {
      // ── 1. Inisialisasi OneSignal ─────────────────────────────────────────
      OneSignal.initialize(_oneSignalAppId);

      // ── 2. Minta izin notifikasi ──────────────────────────────────────────
      await OneSignal.Notifications.requestPermission(true);

      // ── 3. Log Player ID untuk debug ──────────────────────────────────────
      final playerId = OneSignal.User.pushSubscription.id;
      debugPrint("📱 OneSignal Player ID: $playerId");

      // ── 4. Handler saat notif diterima (foreground) ───────────────────────
      OneSignal.Notifications.addForegroundWillDisplayListener((event) async {
        debugPrint("📨 OneSignal Foreground: ${event.notification.title}");

        // Simpan ke history
        try {
          await _simpanKeHistory(
            id: event.notification.notificationId,
            judul: event.notification.title ?? 'Notifikasi Laundry',
            isi: event.notification.body ?? '',
          );
        } catch (e) {
          debugPrint("⚠ Simpan error: $e");
        }

        // Tampilkan notif di foreground (default OneSignal tidak tampil)
        event.preventDefault();
        event.notification.display();
      });

      // ── 5. Handler saat user tap notif ────────────────────────────────────
      OneSignal.Notifications.addClickListener((event) {
        debugPrint("🔔 Tap notif: ${event.notification.title}");
        _navigateToNotifikasi();
      });

      // ── 6. Handler notif background/terminated ────────────────────────────
      // OneSignal otomatis tampilkan notif saat background/terminated
      // Kita hanya perlu simpan ke history saat app dibuka lagi
      OneSignal.Notifications.addClickListener((event) async {
        try {
          await _simpanKeHistory(
            id: event.notification.notificationId,
            judul: event.notification.title ?? 'Notifikasi Laundry',
            isi: event.notification.body ?? '',
          );
        } catch (e) {
          debugPrint("⚠ Simpan background error: $e");
        }
      });

      debugPrint("✅ OneSignal berhasil diinisialisasi");
    } catch (e, stack) {
      debugPrint("⚠ OneSignal error: $e\n$stack");
    }
  }

  // ── Set tag untuk targeting notif (dipanggil dari HomeWrapper) ─────────────
  // Dipanggil setiap kali storeId / role / currentOutletId berubah atau
  // berhasil dimuat (saat login, saat ganti outlet, dsb).
  Future<void> setUserTags({
    required String storeId,
    required String role, // 'Owner' atau 'Admin'
    required String currentOutletId,
  }) async {
    try {
      await OneSignal.User.addTags({
        'store_id': storeId,
        'role': role,
        'current_outlet_id': currentOutletId,
      });
      debugPrint(
        '✅ OneSignal tags diset: store_id=$storeId, role=$role, current_outlet_id=$currentOutletId',
      );
    } catch (e) {
      debugPrint('⚠ Gagal set OneSignal tags: $e');
    }
  }

  // ── Hapus semua tag targeting (dipanggil saat logout) ───────────────────────
  Future<void> clearUserTags() async {
    try {
      await OneSignal.User.removeTags([
        'store_id',
        'role',
        'current_outlet_id',
      ]);
      debugPrint('✅ OneSignal tags dihapus');
    } catch (e) {
      debugPrint('⚠ Gagal hapus OneSignal tags: $e');
    }
  }

  // ── Simpan notif ke SharedPreferences ──────────────────────────────────────
  Future<void> _simpanKeHistory({
    required String id,
    required String judul,
    required String isi,
  }) async {
    final item = NotifItem(
      id: id,
      judul: judul,
      isi: isi,
      waktu: DateTime.now(),
      sudahDibaca: false,
    );
    await NotifStorage.simpan(item);
    debugPrint('✅ Notif tersimpan: ${item.judul}');
  }

  // ── Navigasi ke halaman notifikasi ─────────────────────────────────────────
  void _navigateToNotifikasi() {
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const NotifikasiScreen()),
      (route) => route.isFirst,
    );
  }
}

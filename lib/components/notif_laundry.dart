import 'package:flutter/material.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mdnlaundry_project/screens/notifikasi.dart';
import 'package:mdnlaundry_project/screens/main_screens.dart';

// ─── Navigator key global ─────────────────────────────────────────────────────
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// ─── Konstanta OneSignal ──────────────────────────────────────────────────────
const _oneSignalAppId = '54e65963-bfc8-40ad-aef9-cb1d7303590e';

// ─── Service utama ────────────────────────────────────────────────────────────
class NotifLaundryService {
  static final NotifLaundryService _instance = NotifLaundryService._internal();
  factory NotifLaundryService() => _instance;
  NotifLaundryService._internal();

  // Track apakah OneSignal sudah siap
  bool _isInitialized = false;

  Future<void> inisialisasiNotifikasi() async {
    debugPrint("▶ Inisialisasi notifikasi OneSignal Laundry...");

    try {
      // ── 1. Inisialisasi OneSignal ─────────────────────────────────────────
      OneSignal.initialize(_oneSignalAppId);

      // ── 2. Minta izin notifikasi ──────────────────────────────────────────
      await OneSignal.Notifications.requestPermission(true);

      // ── 3. Tunggu sampai subscription aktif ──────────────────────────────
      // Ini penting! Kalau langsung set tags sebelum subscription ready,
      // tags bisa parsial atau tidak tersimpan sama sekali
      await _waitForSubscription();

      // ── 4. Log Player ID untuk debug ──────────────────────────────────────
      final playerId = OneSignal.User.pushSubscription.id;
      debugPrint("📱 OneSignal Player ID: $playerId");

      _isInitialized = true;

      // ── 5. Handler saat notif diterima (foreground) ───────────────────────
      OneSignal.Notifications.addForegroundWillDisplayListener((event) async {
        debugPrint("📨 OneSignal Foreground: ${event.notification.title}");

        try {
          await _simpanKeHistory(
            id: event.notification.notificationId,
            judul: event.notification.title ?? 'Notifikasi Laundry',
            isi: event.notification.body ?? '',
          );
        } catch (e) {
          debugPrint("⚠ Simpan error: $e");
        }

        event.preventDefault();
        event.notification.display();
      });

      // ── 6. Handler saat user tap notif ────────────────────────────────────
      OneSignal.Notifications.addClickListener((event) async {
        debugPrint("🔔 Tap notif: ${event.notification.title}");

        try {
          await _simpanKeHistory(
            id: event.notification.notificationId,
            judul: event.notification.title ?? 'Notifikasi Laundry',
            isi: event.notification.body ?? '',
          );
        } catch (e) {
          debugPrint("⚠ Simpan saat tap notif error: $e");
        }

        await _navigateToNotifikasi();
      });

      debugPrint("✅ OneSignal berhasil diinisialisasi");
    } catch (e, stack) {
      debugPrint("⚠ OneSignal error: $e\n$stack");
    }
  }

  // ── Tunggu sampai OneSignal subscription aktif ──────────────────────────────
  Future<void> _waitForSubscription({int maxRetries = 10}) async {
    for (int i = 0; i < maxRetries; i++) {
      final id = OneSignal.User.pushSubscription.id;
      if (id != null && id.isNotEmpty) {
        debugPrint("✅ OneSignal subscription aktif: $id");
        return;
      }
      debugPrint("⏳ Menunggu OneSignal subscription... (${i + 1}/$maxRetries)");
      await Future.delayed(const Duration(milliseconds: 500));
    }
    debugPrint("⚠ OneSignal subscription timeout, lanjut tanpa menunggu");
  }

  // ── Set tag untuk targeting notif ──────────────────────────────────────────
  // PENTING: Selalu set KETIGA tag sekaligus (store_id, role, current_outlet_id)
  // Jangan set satu per satu karena bisa menyebabkan state tidak konsisten
  Future<void> setUserTags({
    required String storeId,
    required String role,
    required String currentOutletId,
  }) async {
    // Validasi — jangan set tags kosong
    if (storeId.isEmpty || role.isEmpty || currentOutletId.isEmpty) {
      debugPrint(
        '⚠ setUserTags diabaikan: ada field kosong '
        '(storeId=$storeId, role=$role, outletId=$currentOutletId)',
      );
      return;
    }

    // Jika OneSignal belum initialized, tunggu dulu
    if (!_isInitialized) {
      debugPrint('⏳ OneSignal belum siap, tunggu 1 detik...');
      await Future.delayed(const Duration(seconds: 1));
    }

    // Retry mechanism: coba set tags sampai 3x
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        // Set semua 3 tags sekaligus dalam 1 call
        await OneSignal.User.addTags({
          'store_id': storeId,
          'role': role,
          'current_outlet_id': currentOutletId,
        });

        // Verify tags benar-benar tersimpan
        await Future.delayed(const Duration(milliseconds: 300));
        final savedTags = await OneSignal.User.getTags();

        final savedStoreId = savedTags['store_id'] ?? '';
        final savedRole = savedTags['role'] ?? '';
        final savedOutletId = savedTags['current_outlet_id'] ?? '';

        if (savedStoreId == storeId &&
            savedRole == role &&
            savedOutletId == currentOutletId) {
          debugPrint('✅ OneSignal tags berhasil di-set & verified:');
          debugPrint('   store_id=$storeId');
          debugPrint('   role=$role');
          debugPrint('   current_outlet_id=$currentOutletId');
          return; // Sukses, keluar dari loop
        } else {
          debugPrint('⚠ Tags tidak match setelah set (attempt $attempt):');
          debugPrint(
            '   Expected: store=$storeId, role=$role, outlet=$currentOutletId',
          );
          debugPrint(
            '   Got:      store=$savedStoreId, role=$savedRole, outlet=$savedOutletId',
          );

          if (attempt < 3) {
            await Future.delayed(const Duration(milliseconds: 500));
          }
        }
      } catch (e) {
        debugPrint('⚠ Gagal set OneSignal tags (attempt $attempt): $e');
        if (attempt < 3) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }
    }

    debugPrint('❌ Gagal set OneSignal tags setelah 3 attempt');
  }

  // ── Verify & refresh tags (dipanggil setiap kali app resume) ───────────────
  Future<void> verifyAndRefreshTags({
    required String storeId,
    required String role,
    required String currentOutletId,
  }) async {
    if (storeId.isEmpty || role.isEmpty || currentOutletId.isEmpty) return;

    try {
      final currentTags = await OneSignal.User.getTags();

      final currentStoreId = currentTags['store_id'] ?? '';
      final currentRole = currentTags['role'] ?? '';
      final currentOutlet = currentTags['current_outlet_id'] ?? '';

      final isSync =
          currentStoreId == storeId &&
          currentRole == role &&
          currentOutlet == currentOutletId;

      if (!isSync) {
        debugPrint('⚠ OneSignal tags tidak sinkron, re-set...');
        debugPrint(
          '  Expected: store=$storeId, role=$role, outlet=$currentOutletId',
        );
        debugPrint(
          '  Current:  store=$currentStoreId, role=$currentRole, outlet=$currentOutlet',
        );
        await setUserTags(
          storeId: storeId,
          role: role,
          currentOutletId: currentOutletId,
        );
      } else {
        debugPrint('✅ OneSignal tags sudah sinkron');
      }
    } catch (e) {
      debugPrint('⚠ Gagal verify tags, langsung re-set: $e');
      await setUserTags(
        storeId: storeId,
        role: role,
        currentOutletId: currentOutletId,
      );
    }
  }

  // ── Hapus semua tag targeting (saat logout) ─────────────────────────────────
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

  // ── Simpan notif ke history ─────────────────────────────────────────────────
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
  Future<void> _navigateToNotifikasi() async {
    String storeId = '';
    String outletId = '';

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        final data = doc.data() ?? {};
        storeId = data['store_id'] ?? '';
        outletId = data['current_outlet_id'] ?? '';
      }
    } catch (e) {
      debugPrint('⚠ Gagal fetch storeId/outletId untuk notif: $e');
    }

    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => NotifikasiScreen(storeId: storeId, outletId: outletId),
      ),
      (route) => route.isFirst,
    );
  }
}

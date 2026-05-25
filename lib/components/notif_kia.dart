// ─── notif_kia.dart (FIXED) ──────────────────────────────────────────────────
// Fix 1: try-catch menyeluruh agar emulator tidak crash / blank putih
// Fix 2: onMessageOpenedApp → navigasi ke NotifikasiScreen
// Fix 3: getInitialMessage → handle klik notif saat app dari killed state
// ─────────────────────────────────────────────────────────────────────────────

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:overlay_support/overlay_support.dart';
import 'package:flutter/material.dart';
import '../screens/screens.dart';

// Navigator key global — daftarkan ini di MaterialApp (lihat main.dart di bawah)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class NotifKiaService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final AudioPlayer _audioPlayer = AudioPlayer();

  Future<void> inisialisasiNotifikasi() async {
    debugPrint("▶ Inisialisasi notifikasi FCM...");

    try {
      // ── 1. Minta izin ─────────────────────────────────────────────────────
      NotificationSettings settings = await _fcm
          .requestPermission(alert: true, badge: true, sound: true)
          .timeout(
            const Duration(seconds: 5), // Emulator kadang hang di sini
            onTimeout: () {
              debugPrint("⚠ requestPermission timeout — skip FCM");
              // Return dummy settings agar tidak crash
              return const NotificationSettings(
                authorizationStatus: AuthorizationStatus.denied,
                alert: AppleNotificationSetting.disabled,
                announcement: AppleNotificationSetting.disabled,
                badge: AppleNotificationSetting.disabled,
                carPlay: AppleNotificationSetting.disabled,
                lockScreen: AppleNotificationSetting.disabled,
                notificationCenter: AppleNotificationSetting.disabled,
                showPreviews: AppleShowPreviewSetting.never,
                sound: AppleNotificationSetting.disabled,
                criticalAlert: AppleNotificationSetting.disabled,
                providesAppNotificationSettings:
                    AppleNotificationSetting.disabled,
                timeSensitive: AppleNotificationSetting.disabled,
              );
            },
          );

      debugPrint("✅ Status izin: ${settings.authorizationStatus}");

      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus != AuthorizationStatus.provisional) {
        debugPrint("⚠ Izin notifikasi ditolak — FCM tidak aktif");
        return;
      }

      // ── 2. Token (opsional, untuk debug) ──────────────────────────────────
      try {
        String? token = await _fcm.getToken().timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            debugPrint("⚠ getToken timeout");
            return null;
          },
        );
        debugPrint("📱 FCM Token: $token");
      } catch (e) {
        debugPrint("⚠ getToken error (emulator?): $e");
      }

      // ── 3. Subscribe topik ────────────────────────────────────────────────
      try {
        await _fcm
            .subscribeToTopic('admin_klinik')
            .timeout(const Duration(seconds: 5));
        debugPrint("✅ Subscribe topik: admin_klinik");
      } catch (e) {
        debugPrint("⚠ subscribeToTopic error: $e");
      }

      // ── 4. Foreground: app terbuka, notif masuk ───────────────────────────
      FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
        debugPrint("📨 FCM Foreground: ${message.notification?.title}");

        // Putar suara notif
        try {
          await _audioPlayer.play(AssetSource('sounds/notif.mp3'));
        } catch (e) {
          debugPrint("⚠ Gagal putar suara: $e");
        }

        // Tampilkan overlay banner
        try {
          showOverlayNotification(
            (context) => GestureDetector(
              // ✅ Klik banner → ke NotifikasiScreen
              onTap: () {
                OverlaySupportEntry.of(context)?.dismiss();
                navigatorKey.currentState?.push(
                  MaterialPageRoute(builder: (_) => const NotifikasiScreen()),
                );
              },
              child: Card(
                margin: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                color: const Color(0xFF1E1E2E),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: SafeArea(
                  child: ListTile(
                    leading: const Icon(
                      Icons.notifications_active,
                      color: Colors.tealAccent,
                    ),
                    title: Text(
                      message.notification?.title ?? "Notifikasi",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      message.notification?.body ?? "",
                      style: const TextStyle(color: Colors.white70),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: Colors.white38,
                    ),
                  ),
                ),
              ),
            ),
            duration: const Duration(seconds: 7),
          );
        } catch (e) {
          debugPrint("⚠ Overlay error: $e");
        }
      });

      // ── 5. Background: user klik notif saat app di background ────────────
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint("📨 onMessageOpenedApp: ${message.notification?.title}");
        _navigateToNotifikasi();
      });

      // ── 6. Terminated: user klik notif saat app mati (killed) ────────────
      try {
        RemoteMessage? initialMessage = await _fcm.getInitialMessage().timeout(
          const Duration(seconds: 3),
          onTimeout: () => null,
        );
        if (initialMessage != null) {
          debugPrint(
            "📨 getInitialMessage: ${initialMessage.notification?.title}",
          );
          // Delay sedikit agar navigator sudah siap
          Future.delayed(const Duration(milliseconds: 800), () {
            _navigateToNotifikasi();
          });
        }
      } catch (e) {
        debugPrint("⚠ getInitialMessage error: $e");
      }
    } catch (e, stack) {
      // ✅ Catch-all: apapun errornya, app tetap jalan normal
      debugPrint("⚠ FCM inisialisasi error (diabaikan): $e");
      debugPrint("$stack");
    }
  }

  /// Navigasi ke NotifikasiScreen via navigatorKey global
  void _navigateToNotifikasi() {
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const NotifikasiScreen()),
      (route) => route.isFirst, // tetap bisa back ke HomeWrapper
    );
  }
}

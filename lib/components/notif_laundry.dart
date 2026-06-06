import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:overlay_support/overlay_support.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:uuid/uuid.dart';
import '../screens/screens.dart';
import '../screens/notifikasi.dart'; // import NotifStorage
import 'package:permission_handler/permission_handler.dart';

// ─── Navigator key global ────────────────────────────────────────────────────
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// ─── Local notifications plugin ──────────────────────────────────────────────
final FlutterLocalNotificationsPlugin flutterLocalNotif =
    FlutterLocalNotificationsPlugin();

// ─── Channel Android ─────────────────────────────────────────────────────────
const _androidChannel = AndroidNotificationChannel(
  'laundry_reminder',
  'Notifikasi Laundry',
  description: 'Pengingat estimasi selesai laundry',
  importance: Importance.max,
);

// ─── Helper: simpan notif ke SharedPreferences ───────────────────────────────
Future<void> _simpanKeHistory(RemoteMessage message) async {
  const uuid = Uuid();
  final item = NotifItem(
    id: message.messageId ?? uuid.v4(),
    judul: message.notification?.title ?? 'Notifikasi Laundry',
    isi: message.notification?.body ?? '',
    waktu: DateTime.now(),
    sudahDibaca: false,
  );
  await NotifStorage.simpan(item);
}

// ─── Helper: tampilkan local notif ───────────────────────────────────────────
Future<void> _showLocalNotif(RemoteMessage message) async {
  final androidDetails = AndroidNotificationDetails(
    _androidChannel.id,
    _androidChannel.name,
    channelDescription: _androidChannel.description,
    importance: Importance.max,
    priority: Priority.high,
    channelShowBadge: true,
  );

  await flutterLocalNotif.show(
    message.hashCode,
    message.notification?.title ?? 'Notifikasi',
    message.notification?.body ?? '',
    NotificationDetails(android: androidDetails),
    payload: '/notifikasi',
  );
}

// ─── Background handler — WAJIB top-level function ───────────────────────────
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await _simpanKeHistory(message);
  await _showLocalNotif(message);
}

// ─── Service utama ───────────────────────────────────────────────────────────
class NotifKiaService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final AudioPlayer _audioPlayer = AudioPlayer();

  static const String _topic = 'admin_Madeena_Laundry';

  Future<void> inisialisasiNotifikasi() async {
    debugPrint("▶ Inisialisasi notifikasi FCM Laundry...");

    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: false,
          badge: false,
          sound: false,
        );

    try {
      // ── 1. Minta izin notifikasi (Android 13+) ────────────────────────────
      if (await Permission.notification.isDenied) {
        final result = await Permission.notification.request();
        debugPrint("📋 Permission result: $result");
        if (result.isDenied || result.isPermanentlyDenied) {
          debugPrint("⚠ Izin notifikasi ditolak — buka settings");
          await openAppSettings();
          return;
        }
      }

      // ── 2. Setup flutter_local_notifications ──────────────────────────────
      const initSettings = InitializationSettings(
        android: AndroidInitializationSettings(
          '@android:drawable/ic_dialog_info',
        ),
        iOS: DarwinInitializationSettings(),
      );

      await flutterLocalNotif.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (details) {
          debugPrint('🔔 Tap notif: ${details.payload}');
          if (details.payload == '/notifikasi') {
            _navigateToNotifikasi();
          }
        },
      );

      await flutterLocalNotif
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(_androidChannel);

      // ── 3. Minta izin FCM ─────────────────────────────────────────────────
      final settings = await _fcm
          .requestPermission(alert: true, badge: true, sound: true)
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              debugPrint("⚠ requestPermission timeout — skip FCM");
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

      // ── 4. Token debug ────────────────────────────────────────────────────
      try {
        final token = await _fcm.getToken().timeout(
          const Duration(seconds: 5),
          onTimeout: () => null,
        );
        debugPrint("📱 FCM Token: $token");
      } catch (e) {
        debugPrint("⚠ getToken error: $e");
      }

      // ── 5. Subscribe topic ────────────────────────────────────────────────
      try {
        await _fcm.subscribeToTopic(_topic).timeout(const Duration(seconds: 5));
        debugPrint("✅ Subscribe topic: $_topic");
      } catch (e) {
        debugPrint("⚠ subscribeToTopic error: $e");
      }

      // ── 6. FOREGROUND ─────────────────────────────────────────────────────
      FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
        debugPrint("📨 FCM Foreground: ${message.notification?.title}");

        try {
          await _simpanKeHistory(message);
        } catch (e) {
          debugPrint("⚠ Simpan history error: $e");
        }

        try {
          await _audioPlayer.play(AssetSource('sounds/notif.mp3'));
        } catch (e) {
          debugPrint("⚠ Gagal putar suara: $e");
        }

        try {
          await _showLocalNotif(message);
        } catch (e) {
          debugPrint("⚠ Local notif error: $e");
        }

        try {
          showOverlayNotification(
            (context) => GestureDetector(
              onTap: () {
                OverlaySupportEntry.of(context)?.dismiss();
                _navigateToNotifikasi();
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
                      Icons.local_laundry_service_rounded,
                      color: Colors.tealAccent,
                    ),
                    title: Text(
                      message.notification?.title ?? 'Notifikasi Laundry',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      message.notification?.body ?? '',
                      style: const TextStyle(color: Colors.white70),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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

      // ── 7. BACKGROUND: tap notif dari status bar ──────────────────────────
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint("📨 onMessageOpenedApp: ${message.notification?.title}");
        _navigateToNotifikasi();
      });

      // ── 8. TERMINATED: app mati, user tap notif ───────────────────────────
      try {
        final initialMessage = await _fcm.getInitialMessage().timeout(
          const Duration(seconds: 3),
          onTimeout: () => null,
        );
        if (initialMessage != null) {
          debugPrint(
            "📨 getInitialMessage: ${initialMessage.notification?.title}",
          );
          await _simpanKeHistory(initialMessage);
          Future.delayed(const Duration(milliseconds: 800), () {
            _navigateToNotifikasi();
          });
        }
      } catch (e) {
        debugPrint("⚠ getInitialMessage error: $e");
      }
    } catch (e, stack) {
      debugPrint("⚠ FCM inisialisasi error: $e\n$stack");
    }
  }

  void _navigateToNotifikasi() {
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const NotifikasiScreen()),
      (route) => route.isFirst,
    );
  }
}

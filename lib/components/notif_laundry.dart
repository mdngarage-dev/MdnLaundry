import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:overlay_support/overlay_support.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:uuid/uuid.dart';
import '../screens/screens.dart';
import '../screens/notifikasi.dart';
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

// ─── Ambil judul & isi dari data-only FCM message ────────────────────────────
String _getJudul(RemoteMessage message) =>
    message.data['judul'] ??
    message.notification?.title ??
    'Notifikasi Laundry';

String _getIsi(RemoteMessage message) =>
    message.data['isi'] ?? message.notification?.body ?? '';

// ─── Simpan notif ke SharedPreferences ───────────────────────────────────────
Future<void> _simpanKeHistory(RemoteMessage message) async {
  const uuid = Uuid();
  final item = NotifItem(
    // Gunakan messageId jika ada, fallback ke uuid
    id: message.messageId ?? uuid.v4(),
    judul: _getJudul(message),
    isi: _getIsi(message),
    waktu: DateTime.now(),
    sudahDibaca: false,
  );
  await NotifStorage.simpan(item);
  debugPrint('✅ Notif tersimpan: ${item.judul}');
}

// ─── Tampilkan local notification ────────────────────────────────────────────
Future<void> _showLocalNotif(RemoteMessage message) async {
  final judul = _getJudul(message);
  final isi = _getIsi(message);

  final androidDetails = AndroidNotificationDetails(
    _androidChannel.id,
    _androidChannel.name,
    channelDescription: _androidChannel.description,
    importance: Importance.max,
    priority: Priority.high,
    channelShowBadge: true,
    // Gunakan icon dari app (bukan icon default Android)
    icon: '@mipmap/ic_launcher',
  );

  await flutterLocalNotif.show(
    message.hashCode,
    judul,
    isi,
    NotificationDetails(android: androidDetails),
    payload: '/notifikasi',
  );
}

// ─── Background handler — WAJIB top-level function ───────────────────────────
// Dipanggil saat app background/terminated dan data-only FCM masuk
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // Simpan ke history
  await _simpanKeHistory(message);
  // Tampilkan notif manual (karena data-only tidak auto-display)
  await _showLocalNotif(message);
}

// ─── Service utama ────────────────────────────────────────────────────────────
class NotifLaundryService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final AudioPlayer _audioPlayer = AudioPlayer();

  static const String _topic = 'admin_Madeena_Laundry';

  Future<void> inisialisasiNotifikasi() async {
    debugPrint("▶ Inisialisasi notifikasi FCM Laundry...");

    // Data-only message tidak perlu suppress foreground presentation
    // tapi tetap set false agar tidak dobel jika suatu saat ada notification payload
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: false,
          badge: false,
          sound: false,
        );

    try {
      // ── 1. Izin notifikasi Android 13+ ───────────────────────────────────
      if (await Permission.notification.isDenied) {
        final result = await Permission.notification.request();
        if (result.isDenied || result.isPermanentlyDenied) {
          await openAppSettings();
          return;
        }
      }

      // ── 2. Setup flutter_local_notifications ──────────────────────────────
      const initSettings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      );

      await flutterLocalNotif.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (details) {
          debugPrint('🔔 Tap notif lokal: ${details.payload}');
          if (details.payload == '/notifikasi') {
            _navigateToNotifikasi();
          }
        },
      );

      // Buat channel Android
      await flutterLocalNotif
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(_androidChannel);

      // ── 3. Izin FCM ───────────────────────────────────────────────────────
      final settings = await _fcm
          .requestPermission(alert: true, badge: true, sound: true)
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () {
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

      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus != AuthorizationStatus.provisional) {
        debugPrint("⚠ Izin ditolak");
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
        debugPrint("✅ Subscribe: $_topic");
      } catch (e) {
        debugPrint("⚠ subscribeToTopic error: $e");
      }

      // ── 6. FOREGROUND: app terbuka ────────────────────────────────────────
      FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
        debugPrint("📨 FCM Foreground: ${_getJudul(message)}");

        // Simpan ke history dulu
        try {
          await _simpanKeHistory(message);
        } catch (e) {
          debugPrint("⚠ Simpan error: $e");
        }

        // Suara notif
        try {
          await _audioPlayer.play(AssetSource('sounds/notif.mp3'));
        } catch (e) {
          debugPrint("⚠ Suara error: $e");
        }

        // Local notif di status bar (data-only tidak auto-display)
        try {
          await _showLocalNotif(message);
        } catch (e) {
          debugPrint("⚠ Local notif error: $e");
        }

        // Overlay banner in-app
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
                      _getJudul(message),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      _getIsi(message),
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

      // ── 7. BACKGROUND: user tap notif dari status bar ─────────────────────
      // Notif sudah disimpan di background handler saat masuk
      // Handler ini hanya untuk navigasi saat user tap
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint("📨 onMessageOpenedApp: ${_getJudul(message)}");
        _navigateToNotifikasi();
      });

      // ── 8. TERMINATED: app mati, user tap notif ───────────────────────────
      try {
        final initialMessage = await _fcm.getInitialMessage().timeout(
          const Duration(seconds: 3),
          onTimeout: () => null,
        );
        if (initialMessage != null) {
          debugPrint("📨 getInitialMessage: ${_getJudul(initialMessage)}");
          // Edge case: kalau belum tersimpan di background handler
          await _simpanKeHistory(initialMessage);
          Future.delayed(
            const Duration(milliseconds: 800),
            _navigateToNotifikasi,
          );
        }
      } catch (e) {
        debugPrint("⚠ getInitialMessage error: $e");
      }
    } catch (e, stack) {
      debugPrint("⚠ FCM error: $e\n$stack");
    }
  }

  void _navigateToNotifikasi() {
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const NotifikasiScreen()),
      (route) => route.isFirst,
    );
  }
}

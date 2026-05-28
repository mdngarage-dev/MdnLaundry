import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'screens/screens.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:mdncare_project/components/notif_kia.dart';
import 'package:overlay_support/overlay_support.dart';
import 'package:mdncare_project/screens/auth_wrapper.dart'; // ← import AuthWrapper
import 'package:firebase_messaging/firebase_messaging.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);
  await AppConfig.init();

  // ── Firebase init ────────────────────────────────────────────────────────
  try {
    if (kIsWeb) {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: "AIzaSyBBXW0pR2cthN56U1EQoKzv87McImw1F2A",
          authDomain: "madeena-care.firebaseapp.com",
          projectId: "madeena-care",
          storageBucket: "madeena-care.firebasestorage.app",
          messagingSenderId: "630469794839",
          appId: "1:630469794839:web:37f989c2062dcbc249d052",
          measurementId: "G-BLQYXXV9K4",
        ),
      );
    } else {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
    }
  } catch (e) {
    debugPrint("Inisialisasi Error di Main: $e");
  }

  try {
    debugPrint('[FIREBASE] apps: ${Firebase.apps.length}');
    debugPrint(
      '[FIREBASE] currentUser langsung: ${FirebaseAuth.instance.currentUser?.uid}',
    );

    // Coba paksa refresh
    final u = FirebaseAuth.instance.currentUser;
    if (u != null) {
      final token = await u.getIdToken(true);
      debugPrint('[FIREBASE] token refresh OK: ${token?.substring(0, 20)}...');
    } else {
      debugPrint('[FIREBASE] currentUser null di main — coba tunggu...');
      // Tunggu 5 detik dan cek lagi
      await Future.delayed(const Duration(seconds: 5));
      debugPrint(
        '[FIREBASE] currentUser setelah 5 detik: ${FirebaseAuth.instance.currentUser?.uid}',
      );
    }
  } catch (e) {
    debugPrint('[FIREBASE] Error: $e');
  }

  NotifKiaService().inisialisasiNotifikasi(); // tanpa await
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MadeenaCareApp(),
    ),
  );
}

class MadeenaCareApp extends StatelessWidget {
  const MadeenaCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return OverlaySupport.global(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Madeena Care',

        navigatorKey: navigatorKey,

        themeMode: themeProvider.themeMode,
        theme: lightTheme(),
        darkTheme: darkTheme(),

        // ✅ DIGANTI: dari StreamBuilder langsung → AuthWrapper
        // AuthWrapper menangani race condition Firebase Auth restore
        home: const AuthWrapper(),

        routes: {
          '/signup': (context) => const SignUpScreen(),
          '/login': (context) => const SignInScreen(),
          '/home': (context) => const HomeWrapper(),
          '/profile': (context) => const ProfileScreen(),
          '/notifikasi': (context) => const NotifikasiScreen(),
        },
      ),
    );
  }
}

// ─── main.dart (FIXED) ───────────────────────────────────────────────────────
// Fix 1: FCM inisialisasi TIDAK lagi await sebelum runApp
//         → runApp() jalan duluan, FCM init di background
// Fix 2: navigatorKey didaftarkan ke MaterialApp
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'screens/screens.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:mdncare_project/components/notif_kia.dart';
import 'package:overlay_support/overlay_support.dart'; // ← pastikan ini ada

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
    debugPrint("Firebase init error: $e");
  }

  await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);

  // ✅ FIX UTAMA: FCM init TIDAK di-await sebelum runApp
  // Ini supaya blank putih hilang — FCM init jalan di background
  // setelah app sudah muncul
  NotifKiaService().inisialisasiNotifikasi(); // tanpa await

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

    // ✅ Bungkus dengan OverlaySupport agar overlay notif bisa tampil
    return OverlaySupport.global(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Madeena Care',

        // ✅ navigatorKey didaftarkan di sini
        navigatorKey: navigatorKey,

        themeMode: themeProvider.themeMode,
        theme: lightTheme(),
        darkTheme: darkTheme(),

        home: StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasData && snapshot.data != null) {
              final user = snapshot.data!;
              // ✅ Cek emailVerified — kalau belum, paksa sign out & ke GetStarted
              if (!user.emailVerified) {
                // Sign out async tapi tidak perlu await di sini
                FirebaseAuth.instance.signOut();
                return const GetStartedScreen();
              }
              return const HomeWrapper();
            }
            return const GetStartedScreen();
          },
        ),

        routes: {
          '/signup': (context) => const SignUpScreen(),
          '/login': (context) => const SignInScreen(),
          '/home': (context) => const HomeWrapper(),
          '/profile': (context) => const ProfileScreen(),
          '/notifikasi': (context) =>
              const NotifikasiScreen(), // ✅ tambah route
        },
      ),
    );
  }
}

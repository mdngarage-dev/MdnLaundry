import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:mdnlaundry_project/screens/main_screens.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:mdnlaundry_project/components/notif_laundry.dart';
import 'package:overlay_support/overlay_support.dart';
import 'package:mdnlaundry_project/auth_wrapper.dart'; // ← import AuthWrapper

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);
  await AppConfig.init();

  // ── Firebase init ────────────────────────────────────────────────────────
  try {
    if (kIsWeb) {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: "AIzaSyAUs_7vHagR7rc24kkGtxoKpTLbSd9-X4w",
          authDomain: "laundry-ku-id.firebaseapp.com",
          projectId: "laundry-ku-id",
          storageBucket: "laundry-ku-id.firebasestorage.app",
          messagingSenderId: "518877666392",
          appId: "1:518877666392:web:d4885be99c724e5783fe2d",
          measurementId: "G-0W7K571RTN",
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
      final token = await u
          .getIdToken(true)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              debugPrint('getIdToken timeout, pakai token lama');
              return u.getIdToken(false); // fallback tanpa refresh
            },
          );
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

  await NotifLaundryService().inisialisasiNotifikasi();

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MadeenalaundryApp(),
    ),
  );
}

class MadeenalaundryApp extends StatelessWidget {
  const MadeenalaundryApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return OverlaySupport.global(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Madeena Laundry',
        navigatorKey: navigatorKey,
        themeMode: themeProvider.themeMode,
        theme: lightTheme(seed: themeProvider.seedColorLight).copyWith(
          textTheme: lightTheme().textTheme.apply(fontFamily: 'Pastrami'),
          listTileTheme: const ListTileThemeData(tileColor: Colors.transparent),
        ),
        darkTheme: darkTheme(seed: themeProvider.seedColorDark).copyWith(
          textTheme: darkTheme().textTheme.apply(fontFamily: 'Pastrami'),
          listTileTheme: const ListTileThemeData(tileColor: Colors.transparent),
        ),
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

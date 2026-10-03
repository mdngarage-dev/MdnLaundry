import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mdnlaundry_project/features/developer/developer_dashboard.dart';
import 'package:mdnlaundry_project/core/app_exports.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:mdnlaundry_project/services/notif_laundry_service.dart';
import 'package:overlay_support/overlay_support.dart';
import 'package:mdnlaundry_project/features/auth/auth_wrapper.dart';
import 'package:mdnlaundry_project/core/config/firebase_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);
  await AppConfig.init();

  // ── Firebase init ────────────────────────────────────────────────────────
  try {
    if (kIsWeb) {
      await Firebase.initializeApp(options: FirebaseConfig.web);
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

  await GoogleSignIn.instance.initialize(
    serverClientId:
        '212303177176-tp68m9346djupd0i4tg7jtgdqc2i5k56.apps.googleusercontent.com', // dari Firebase Console
  );
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
          '/developer-dashboard': (context) => const DeveloperDashboard(),
          '/getstarted': (context) => const GetStartedScreen(),
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'screens/screens.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);
  await AppConfig.init();

  try {
    if (kIsWeb) {
      // Untuk Web/Chrome, Options WAJIB diisi manual
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
      // Untuk Android (HP), dia otomatis baca file google-services.json
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
    }
  } catch (e) {
    debugPrint("Firebase init error: $e");
  }

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
    // Menguping perubahan tema secara real-time
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Madeena Care',
      themeMode: themeProvider.themeMode, //
      theme: lightTheme(),
      darkTheme: darkTheme(),

      home: StreamBuilder<User?>(
        //
        stream: FirebaseAuth.instance.authStateChanges(), //
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            //
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()), //
            );
          }
          if (snapshot.hasData && snapshot.data != null) {
            //
            return const HomeWrapper(); //
          }
          return const GetStartedScreen(); //
        },
      ),
      routes: {
        '/signup': (context) => const SignUpScreen(), //
        '/login': (context) => const SignInScreen(), //
        '/home': (context) => const HomeWrapper(),
        '/profile': (context) => const ProfileScreen(), //
      },
    );
  }
}

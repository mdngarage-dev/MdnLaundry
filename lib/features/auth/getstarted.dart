import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mdnlaundry_project/core/app_exports.dart';

class GetStartedScreen extends StatelessWidget {
  const GetStartedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                // Memaksa tinggi konten minimal sepanjang layar yang tersedia
                constraints: BoxConstraints(minHeight: constraints.maxHeight),

                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28.0,
                    vertical: 24.0,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment
                        .spaceBetween, // Menjaga jarak atas dan bawah
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // ── BAGIAN ATAS (Gambar & Teks) ─────────────────────────
                      Column(
                        children: [
                          const SizedBox(height: 20),
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight: 250,
                              maxWidth: MediaQuery.of(context).size.width * 0.6,
                            ),
                            child: Image.asset(
                              'assets/images/getstarted.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(height: 32),
                          Text(
                            "Let's get started",
                            style: TextStyle(
                              fontFamily: 'BubbbleGum',
                              color: Theme.of(
                                context,
                              ).textTheme.bodyLarge?.color,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "Solusi management laundry dalam genggaman anda.",
                            style: TextStyle(
                              fontFamily: 'Pastrami',
                              color: Theme.of(
                                context,
                              ).textTheme.bodyMedium?.color,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),

                      // ── BAGIAN BAWAH (Tombol-Tombol) ────────────────────────
                      Column(
                        children: [
                          const SizedBox(
                            height: 40,
                          ), // Jarak minimum jika layar pendek
                          SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: ElevatedButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const SignUpScreen(),
                                ),
                              ),
                              style: primaryButtonStyle(),
                              child: const Text('Create Account'),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: ElevatedButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const SignInScreen(),
                                ),
                              ),
                              style: secondaryButtonStyle(),
                              child: const Text('Login to Account'),
                            ),
                          ),
                          const SizedBox(
                            height: 12,
                          ), // Padding tambahan dasar bawah
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// AUTO-LOGOUT HELPER
// ═══════════════════════════════════════════════════════════════════════════

/// Durasi tidak aktif sebelum auto-logout (24 jam)
const Duration _kAutoLogoutDuration = Duration(hours: 24);

/// Key SharedPreferences untuk timestamp terakhir aktif
const String _kLastActiveKey = 'last_active_timestamp';

/// Panggil setiap kali login/register berhasil
Future<void> saveLastActiveTime() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt(_kLastActiveKey, DateTime.now().millisecondsSinceEpoch);
}

/// Jika lebih dari 24 jam tidak aktif → logout otomatis → kembali ke GetStartedScreen.
Future<void> checkAutoLogout(BuildContext context) async {
  // 1. Pastikan user memang sedang login di Firebase
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  final prefs = await SharedPreferences.getInstance();
  final lastActiveMs = prefs.getInt(_kLastActiveKey);

  final now = DateTime.now();

  if (lastActiveMs == null) {
    // Jika tidak ada timestamp lama (misal: baru update app),
    // jangan langsung di-logout, tapi amankan dengan simpan waktu sekarang.
    await prefs.setInt(_kLastActiveKey, now.millisecondsSinceEpoch);
    return;
  }

  final lastActive = DateTime.fromMillisecondsSinceEpoch(lastActiveMs);
  final elapsed = now.difference(lastActive);

  // Cek apakah sudah lewat 24 jam
  if (elapsed >= _kAutoLogoutDuration) {
    // Paksa logout karena sudah lewat 24 jam tidak aktif
    await FirebaseAuth.instance.signOut();

    await prefs.remove('saved_email');
    await prefs.remove('saved_password');
    await prefs.setBool('remember_me', false);
    await prefs.remove(_kLastActiveKey);

    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const GetStartedScreen()),
        (route) => false,
      );
    }
  } else {
    // PENTING: Jika aplikasi hanya ditutup lalu dibuka lagi (masih di bawah 24 jam),
    // Perbarui waktu aktifnya agar durasi 24 jam dihitung dari aktivitas terakhir!
    await prefs.setInt(_kLastActiveKey, now.millisecondsSinceEpoch);
  }
}

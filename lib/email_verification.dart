import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mdnlaundry_project/screens/main_screens.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String role; // 'Owner' | 'Admin'

  const EmailVerificationScreen({super.key, required this.role});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  Timer? _pollingTimer;
  bool _isResending = false;
  int _resendCooldown = 60;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _startPolling();
    _startCooldown();
  }

  // ─── Polling cek emailVerified tiap 4 detik ───────────────────────────────
  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return;

        await user.reload();
        final refreshed = FirebaseAuth.instance.currentUser;

        if (refreshed?.emailVerified == true && mounted) {
          _pollingTimer?.cancel();

          if (widget.role == 'Owner') {
            // Owner langsung masuk app
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const HomeWrapper()),
              (route) => false,
            );
          } else {
            // Admin → layar tunggu aktivasi Owner
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (_) => const WaitingActivationScreen(),
              ),
              (route) => false,
            );
          }
        }
      } catch (e) {
        debugPrint("Polling emailVerified: $e");
      }
    });
  }

  void _startCooldown() {
    _resendCooldown = 60;
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _resendCooldown--);
      if (_resendCooldown <= 0) t.cancel();
    });
  }

  Future<void> _resendEmail() async {
    if (_resendCooldown > 0) return;
    setState(() => _isResending = true);
    try {
      await FirebaseAuth.instance.currentUser?.sendEmailVerification().timeout(
        const Duration(seconds: 10),
      );
      if (mounted) {
        _showSnackBar("Email verifikasi dikirim ulang!", isError: false);
        _startCooldown();
      }
    } catch (e) {
      _showSnackBar("Gagal kirim ulang: $e", isError: true);
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  Future<void> _cancelAndLogout() async {
    _pollingTimer?.cancel();
    _cooldownTimer?.cancel();
    await FirebaseAuth.instance.signOut();
    if (mounted) Navigator.pushReplacementNamed(context, '/login');
  }

  void _showSnackBar(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Ilustrasi
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  color: kPrimary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.mark_email_unread_outlined,
                  size: 58,
                  color: kPrimary,
                ),
              ),
              const SizedBox(height: 32),

              Text(
                "Cek Email Kamu",
                style: TextStyle(
                  fontFamily: 'BubbbleGum',
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
              const SizedBox(height: 12),

              Text(
                "Link verifikasi telah dikirim ke:",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
              const SizedBox(height: 6),

              // Email badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: kPrimary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  email,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: kPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Text(
                "Buka email & klik link verifikasi.\nHalaman ini otomatis lanjut setelah terverifikasi.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 32),

              // Indikator polling
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: kPrimary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      "Menunggu verifikasi...",
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Tombol kirim ulang
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: (_isResending || _resendCooldown > 0)
                      ? null
                      : _resendEmail,
                  style: primaryButtonStyle(),
                  icon: _isResending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.send_outlined, size: 18),
                  label: Text(
                    _resendCooldown > 0
                        ? "Kirim Ulang (${_resendCooldown}s)"
                        : "Kirim Ulang Email",
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              TextButton(
                onPressed: _cancelAndLogout,
                child: Text(
                  "Gunakan akun lain / Batal",
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).hintColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Layar tunggu aktivasi Owner untuk Admin
// ─────────────────────────────────────────────────────────────────────────────
class WaitingActivationScreen extends StatefulWidget {
  const WaitingActivationScreen({super.key});

  @override
  State<WaitingActivationScreen> createState() =>
      _WaitingActivationScreenState();
}

class _WaitingActivationScreenState extends State<WaitingActivationScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  void _startPolling() {
    _timer = Timer.periodic(const Duration(seconds: 5), (_) async {
      try {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid == null) return;

        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();

        if (doc.data()?['is_activated'] == true && mounted) {
          _timer?.cancel();
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const HomeWrapper()),
            (route) => false,
          );
        }
      } catch (e) {
        debugPrint("Polling aktivasi: $e");
      }
    });
  }

  Future<void> _logout() async {
    _timer?.cancel();
    await FirebaseAuth.instance.signOut();
    if (mounted) Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.hourglass_top_rounded,
                  size: 56,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(height: 32),

              Text(
                "Menunggu Aktivasi",
                style: TextStyle(
                  fontFamily: 'BubbbleGum',
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
              const SizedBox(height: 12),

              Text(
                "Akun kamu sudah terdaftar & terverifikasi.\nMinta Owner untuk mengaktifkan akun kamu di menu manajemen Admin.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: kPrimary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  user?.email ?? '',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: kPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.orange,
                      ),
                    ),
                    SizedBox(width: 10),
                    Text(
                      "Menunggu persetujuan Owner...",
                      style: TextStyle(fontSize: 13, color: Colors.orange),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              TextButton(
                onPressed: _logout,
                child: Text(
                  "Keluar / Gunakan akun lain",
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).hintColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

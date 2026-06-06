import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mdnlaundry_project/screens/screens.dart';
import 'dart:math';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  Widget _child = const _SplashScreen();

  @override
  void initState() {
    super.initState();
    _initAuth();
  }

  Future<void> _initAuth() async {
    debugPrint('[AUTH] Mulai _initAuth');

    // Jalankan auth dan splash timer BERSAMAAN
    final results = await Future.wait([
      _doAuth(), // logic auth
      Future.delayed(const Duration(seconds: 3)), // minimum splash 3 detik
    ]);

    final destination = results[0] as Widget;
    if (mounted) setState(() => _child = destination);
  }

  // Pindahkan semua logic auth ke fungsi terpisah
  Future<Widget> _doAuth() async {
    User? user;
    try {
      user = await FirebaseAuth.instance
          .authStateChanges()
          .firstWhere((u) => u != null)
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      user = null;
    }

    if (user != null) return const HomeWrapper();

    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('saved_email') ?? '';
    final savedPassword = prefs.getString('saved_password') ?? '';

    if (savedEmail.isNotEmpty && savedPassword.isNotEmpty) {
      try {
        final cred = await FirebaseAuth.instance
            .signInWithEmailAndPassword(
              email: savedEmail,
              password: savedPassword,
            )
            .timeout(const Duration(seconds: 10));
        if (cred.user != null) return const HomeWrapper();
      } catch (e) {
        debugPrint('[AUTH] Email re-login gagal: $e');
      }
    }

    try {
      // 1. Ganti GoogleSignIn() menjadi GoogleSignIn.standard()
      final googleSignIn = GoogleSignIn.standard();

      final googleUser = await googleSignIn.signInSilently().timeout(
        const Duration(seconds: 10),
      );

      if (googleUser != null) {
        final googleAuth = await googleUser.authentication;

        // 2. Pastikan properti token diakses dari objek yang tepat
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        await FirebaseAuth.instance.signInWithCredential(credential);
        return const HomeWrapper();
      }
    } catch (e) {
      // Jangan lupa handle error-nya di sini jika diperlukan
      print('Error saat sign in silently: $e');
    }

    return const GetStartedScreen();
  }

  @override
  Widget build(BuildContext context) => _child;
}

// ─── SPLASH SCREEN ──────────────────────────────────────────────────────────

class _SplashScreen extends StatefulWidget {
  const _SplashScreen();

  @override
  State<_SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<_SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _particleCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _fadeCtrl;
  late Animation<double> _pulseAnim;
  late Animation<double> _fadeAnim;

  final List<_Particle> _particles = [];
  bool _showLogo = false;
  bool _showText = false;

  @override
  void initState() {
    super.initState();

    final rng = Random();
    for (int i = 0; i < 35; i++) {
      final angle = rng.nextDouble() * pi * 2;
      final dist = 80.0 + rng.nextDouble() * 180;
      _particles.add(
        _Particle(
          startX: cos(angle) * dist,
          startY: sin(angle) * dist,
          endX: (rng.nextDouble() - 0.5) * 50,
          endY: (rng.nextDouble() - 0.5) * 50,
          size: 4 + rng.nextDouble() * 8,
          color: [
            const Color(0xFF5B8DB8), // biru steel (warna outline logo)
            const Color(0xFFADD8E6), // biru muda terang
            const Color(0xFF89B4D4), // biru medium
            const Color(0xFFBFD9EC), // biru sangat muda
            const Color(0xFF7BA7C7), // biru slate
          ][rng.nextInt(5)],
          delay: rng.nextDouble() * 0.4,
          isCircle: rng.nextBool(),
        ),
      );
    }

    _particleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _pulseAnim = Tween<double>(
      begin: 1.0,
      end: 1.14,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    _runSequence();
  }

  Future<void> _runSequence() async {
    debugPrint('[SPLASH] _runSequence START');
    if (mounted) {
      setState(() {
        _showLogo = false;
        _showText = false;
      });
    }

    debugPrint('[SPLASH] sebelum particleCtrl');
    _particleCtrl.reset();
    await _particleCtrl.animateTo(0.5, curve: Curves.easeIn);
    debugPrint('[SPLASH] setelah animateTo 0.5');
    if (!mounted) return;

    debugPrint('[SPLASH] set showLogo true');
    setState(() => _showLogo = true);
    debugPrint('[SPLASH] _showLogo = true');
    await _particleCtrl.animateTo(1.0, curve: Curves.easeOut);
    debugPrint('[SPLASH] setelah animateTo 1.0');
    if (!mounted) return;

    // 4. Teks fade in
    _fadeCtrl.reset();
    _fadeCtrl.forward();
    setState(() => _showText = true);

    // 5. Denyut 3x
    for (int i = 0; i < 3; i++) {
      if (!mounted) return;
      _pulseCtrl.reset();
      await _pulseCtrl.forward();
      if (!mounted) return;
      await _pulseCtrl.reverse();
      await Future.delayed(const Duration(milliseconds: 100));
    }

    // 6. Tahan sebentar lalu STOP — TIDAK looping lagi
    await Future.delayed(const Duration(milliseconds: 700));
    // Selesai. AuthWrapper yang akan ganti layar.
  }

  @override
  void dispose() {
    _particleCtrl.dispose();
    _pulseCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFF6F5),
      body: AnimatedBuilder(
        animation: Listenable.merge([_particleCtrl, _pulseAnim, _fadeAnim]),
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              // ── Partikel background ───────────────────────────────────
              CustomPaint(
                size: Size.infinite,
                painter: _ParticlePainter(
                  particles: _particles,
                  progress: _particleCtrl.value,
                  showLogo: _showLogo,
                ),
              ),

              // ── Konten tengah ─────────────────────────────────────────
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo dengan pulse
                  AnimatedOpacity(
                    opacity: _showLogo ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 400),
                    child: AnimatedBuilder(
                      animation: _pulseAnim,
                      builder: (context, child) => Transform.scale(
                        scale: _pulseAnim.value == 0.0 ? 1.0 : _pulseAnim.value,
                        child: child,
                      ),
                      child: Image.asset(
                        'assets/icon.png',
                        width: 110,
                        height: 110,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Nama app
                  FadeTransition(
                    opacity: _fadeAnim,
                    child: const Text(
                      'Madeena Laundry',
                      style: TextStyle(
                        fontFamily: 'BubbbleGum',
                        fontSize: 30,
                        color: Color(0xFF5B9BD5),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),

                  const SizedBox(height: 6),

                  // Tagline
                  FadeTransition(
                    opacity: _fadeAnim,
                    child: const Text(
                      'Sistem management laundry Digital',
                      style: TextStyle(
                        fontFamily: 'Pastrami',
                        fontSize: 13,
                        color: Color(0xFF5B9BD5),
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Bouncing dots
                  FadeTransition(
                    opacity: _fadeAnim,
                    child: const _BouncingDots(),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── PARTICLE MODEL ──────────────────────────────────────────────────────────

class _Particle {
  final double startX, startY, endX, endY, size, delay;
  final Color color;
  final bool isCircle;

  _Particle({
    required this.startX,
    required this.startY,
    required this.endX,
    required this.endY,
    required this.size,
    required this.color,
    required this.delay,
    required this.isCircle,
  });
}

// ─── PARTICLE PAINTER ────────────────────────────────────────────────────────

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;
  final bool showLogo;

  _ParticlePainter({
    required this.particles,
    required this.progress,
    required this.showLogo,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    for (final p in particles) {
      final t = ((progress - p.delay) / 0.6).clamp(0.0, 1.0);
      final et = Curves.easeInOut.transform(t);
      final alpha = showLogo ? (1.0 - et).clamp(0.0, 1.0) : et.clamp(0.0, 1.0);

      if (alpha <= 0.01) continue;

      final px = cx + p.startX * (1 - et) + p.endX * et;
      final py = cy + p.startY * (1 - et) + p.endY * et;

      final paint = Paint()
        ..color = p.color.withOpacity(alpha * 0.85)
        ..style = PaintingStyle.fill;

      if (p.isCircle) {
        canvas.drawCircle(Offset(px, py), p.size / 2, paint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(px, py),
              width: p.size,
              height: p.size,
            ),
            const Radius.circular(2),
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => true;
}

// ─── BOUNCING DOTS ───────────────────────────────────────────────────────────

class _BouncingDots extends StatefulWidget {
  const _BouncingDots();

  @override
  State<_BouncingDots> createState() => _BouncingDotsState();
}

class _BouncingDotsState extends State<_BouncingDots>
    with TickerProviderStateMixin {
  final List<AnimationController> _ctrls = [];

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < 3; i++) {
      final c = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 500),
      );
      _ctrls.add(c);
      Future.delayed(Duration(milliseconds: i * 150), () {
        if (mounted) c.repeat(reverse: true);
      });
    }
  }

  @override
  void dispose() {
    for (final c in _ctrls) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _ctrls[i],
          builder: (_, _) => Transform.translate(
            offset: Offset(0, -8 * _ctrls[i].value),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: Color(0xFF5B9BD5).withOpacity(0.6 + i * 0.13),
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      }),
    );
  }
}

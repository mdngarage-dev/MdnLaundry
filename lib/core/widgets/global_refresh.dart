import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';

class GlobalRefresh extends StatefulWidget {
  final Future<void> Function() onRefresh;
  final Widget child;

  const GlobalRefresh({
    super.key,
    required this.onRefresh,
    required this.child,
  });

  @override
  State<GlobalRefresh> createState() => _GlobalRefreshState();
}

class _GlobalRefreshState extends State<GlobalRefresh>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<_BubbleData> _bubbles;
  final math.Random _rng = math.Random(42);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    // Pre-generate bubble seeds — posisi & ukuran acak tapi stabil
    _bubbles = List.generate(22, (i) => _BubbleData(_rng));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color baseColor = Theme.of(context).primaryColor;

    return CustomRefreshIndicator(
      onRefresh: widget.onRefresh,
      offsetToArmed: 88.0,
      builder: (context, child, controller) {
        final bool isRefreshing =
            controller.state.name == 'refreshing' ||
            controller.state.name == 'loading';

        if (isRefreshing && !_controller.isAnimating) {
          _controller.repeat();
        } else if (!isRefreshing && _controller.isAnimating) {
          _controller.stop();
          _controller.value = 0.0;
        }

        return AnimatedBuilder(
          animation: Listenable.merge([controller, _controller]),
          builder: (context, _) {
            final double pull = controller.value.clamp(0.0, 1.0);
            final double barH = 88.0 * pull;

            return Stack(
              children: [
                // ── Area busa sabun ──────────────────────────────────────
                if (pull > 0 || isRefreshing)
                  SizedBox(
                    height: barH,
                    width: double.infinity,
                    child: ClipRect(
                      child: CustomPaint(
                        painter: _SoapFoamPainter(
                          animProgress: _controller.value,
                          pullProgress: pull,
                          isRefreshing: isRefreshing,
                          bubbles: _bubbles,
                          baseColor: baseColor,
                        ),
                      ),
                    ),
                  ),

                // ── Konten bergeser ke bawah ─────────────────────────────
                Transform.translate(offset: Offset(0.0, barH), child: child),
              ],
            );
          },
        );
      },
      child: widget.child,
    );
  }
}

// ── Data seed tiap gelembung ─────────────────────────────────────────────────
class _BubbleData {
  final double xFrac; // posisi X relatif (0..1)
  final double sizeFrac; // radius relatif (0..1)
  final double phase; // fase animasi (0..1)
  final double speed; // kecepatan naik relatif
  final double wobble; // amplitudo goyang kiri-kanan

  _BubbleData(math.Random rng)
    : xFrac = rng.nextDouble(),
      sizeFrac = 0.3 + rng.nextDouble() * 0.7,
      phase = rng.nextDouble(),
      speed = 0.5 + rng.nextDouble() * 0.8,
      wobble = rng.nextDouble() * 0.04;
}

// ── Painter: busa sabun + air terjun tipis ───────────────────────────────────
class _SoapFoamPainter extends CustomPainter {
  final double animProgress;
  final double pullProgress;
  final bool isRefreshing;
  final List<_BubbleData> bubbles;
  final Color baseColor;

  const _SoapFoamPainter({
    required this.animProgress,
    required this.pullProgress,
    required this.isRefreshing,
    required this.bubbles,
    required this.baseColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // 1. ── Lapisan busa dasar (gradient area bawah) ──────────────────────
    final Rect foamRect = Rect.fromLTWH(0, h * 0.55, w, h * 0.45);
    final Paint foamPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          baseColor.withOpacity(0.0),
          baseColor.withOpacity(0.13 * pullProgress),
        ],
      ).createShader(foamRect);
    canvas.drawRect(foamRect, foamPaint);

    // 2. ── Garis air terjun tipis dari atas ──────────────────────────────
    _drawWaterfallStreaks(canvas, size);

    // 3. ── Gelembung-gelembung ────────────────────────────────────────────
    for (final b in bubbles) {
      _drawBubble(canvas, size, b);
    }

    // 4. ── Gelombang busa di tepi bawah bar ──────────────────────────────
    _drawFoamEdge(canvas, size);
  }

  void _drawWaterfallStreaks(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final Paint streakPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    final double t = isRefreshing ? animProgress : pullProgress;

    for (int i = 0; i < 8; i++) {
      final double xNorm = (i / 8.0 + 0.06);
      final double x = xNorm * w;
      final double offset = ((t * 1.5 + i * 0.13) % 1.0);
      final double yStart = -8 + offset * (h + 16);
      final double yEnd = yStart + h * 0.18;

      final double alpha = (math.sin(offset * math.pi)).clamp(0.0, 1.0);

      streakPaint.shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          baseColor.withOpacity(0.0),
          baseColor.withOpacity(0.28 * pullProgress * alpha),
          baseColor.withOpacity(0.0),
        ],
      ).createShader(Rect.fromLTWH(x - 1, yStart, 2, yEnd - yStart));

      canvas.drawLine(Offset(x, yStart), Offset(x, yEnd), streakPaint);
    }
  }

  void _drawBubble(Canvas canvas, Size size, _BubbleData b) {
    final double w = size.width;
    final double h = size.height;

    // Hitung posisi: saat pull, gelembung muncul dari bawah & naik
    // Saat isRefreshing, gelembung terus bergerak naik & melayang
    final double t = isRefreshing
        ? (animProgress * b.speed + b.phase) % 1.0
        : b.phase * pullProgress;

    // Y: mulai dari bawah bar (h), bergerak ke atas
    final double yProgress = isRefreshing ? (1.0 - t) : (1.0 - t * 0.6);
    final double y = yProgress * h + h * 0.05;

    // X: goyang pelan kiri-kanan
    final double xBase = b.xFrac * w;
    final double xWobble =
        math.sin(t * math.pi * 4 + b.phase * 6) * b.wobble * w;
    final double x = (xBase + xWobble).clamp(0, w);

    // Ukuran: kecil di atas, besar di bawah
    final double radiusBase = 4.0 + b.sizeFrac * 9.0;
    final double radius = radiusBase * (isRefreshing ? 1.0 : pullProgress);
    if (radius < 1.5) return;

    // Opacity: muncul dan menghilang di ujung
    double alpha = 1.0;
    if (isRefreshing) {
      alpha = math.sin(t * math.pi).clamp(0.0, 1.0);
    } else {
      alpha = pullProgress;
    }

    final Offset center = Offset(x, y);

    // ─ Body gelembung: transparan dengan rim ─
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = baseColor.withOpacity(0.07 * alpha)
        ..style = PaintingStyle.fill,
    );

    // ─ Lingkaran luar (rim) ─
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = baseColor.withOpacity(0.35 * alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );

    // ─ Highlight (pantulan cahaya) — titik putih kecil ─
    canvas.drawCircle(
      Offset(x - radius * 0.28, y - radius * 0.3),
      radius * 0.22,
      Paint()..color = Colors.white.withOpacity(0.55 * alpha),
    );

    // ─ Rim bawah (refleksi) ─
    final Path rimArc = Path()
      ..addArc(
        Rect.fromCircle(center: center, radius: radius * 0.82),
        math.pi * 0.55,
        math.pi * 0.65,
      );
    canvas.drawPath(
      rimArc,
      Paint()
        ..color = baseColor.withOpacity(0.22 * alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7,
    );
  }

  void _drawFoamEdge(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double t = isRefreshing ? animProgress : pullProgress * 0.5;

    final Path foamPath = Path();
    foamPath.moveTo(0, h);

    // Gelombang busa tidak teratur di tepi bawah
    const int steps = 60;
    for (int i = 0; i <= steps; i++) {
      final double x = i / steps * w;
      final double wave1 = math.sin(x / w * math.pi * 5 + t * math.pi * 2) * 4;
      final double wave2 =
          math.sin(x / w * math.pi * 8 - t * math.pi * 3) * 2.5;
      final double y = h - 5 + wave1 + wave2;
      if (i == 0) {
        foamPath.moveTo(x, y);
      } else {
        foamPath.lineTo(x, y);
      }
    }
    foamPath.lineTo(w, h);
    foamPath.lineTo(0, h);
    foamPath.close();

    canvas.drawPath(
      foamPath,
      Paint()
        ..color = baseColor.withOpacity(0.18 * pullProgress)
        ..style = PaintingStyle.fill,
    );

    // Titik-titik busa mini di tepi
    final Paint dotPaint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < 18; i++) {
      final double xd = (i / 18.0 + t * 0.1) % 1.0 * w;
      final double dotR = 1.5 + (i % 3) * 1.0;
      final double yd =
          h - dotR - 2 + math.sin(xd / w * math.pi * 7 + t * math.pi * 2) * 3;
      dotPaint.color = baseColor.withOpacity(0.30 * pullProgress);
      canvas.drawCircle(Offset(xd, yd), dotR, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_SoapFoamPainter old) =>
      old.animProgress != animProgress ||
      old.pullProgress != pullProgress ||
      old.isRefreshing != isRefreshing;
}

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

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color ekgColor = Theme.of(context).primaryColor;

    return CustomRefreshIndicator(
      onRefresh: widget.onRefresh,
      offsetToArmed: 80.0,
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
            final double pullValue = controller.value.clamp(0.0, 1.0);

            return Stack(
              children: [
                // ── Bar EKG ──────────────────────────────────────────────
                if (isRefreshing || pullValue > 0)
                  SizedBox(
                    height: 80 * pullValue,
                    width: double.infinity,
                    child: ClipRect(
                      child: CustomPaint(
                        painter: _EkgPainter(
                          progress: _controller.value,
                          pullProgress: pullValue,
                          isRefreshing: isRefreshing,
                          color: ekgColor,
                        ),
                      ),
                    ),
                  ),

                // ── Konten bergeser ke bawah ──────────────────────────────
                Transform.translate(
                  offset: Offset(0.0, 80.0 * pullValue),
                  child: child,
                ),
              ],
            );
          },
        );
      },
      child: widget.child,
    );
  }
}

class _EkgPainter extends CustomPainter {
  final double progress;
  final double pullProgress;
  final bool isRefreshing;
  final Color color;

  const _EkgPainter({
    required this.progress,
    required this.pullProgress,
    required this.isRefreshing,
    required this.color,
  });

  // Gelombang EKG P-QRS-T — dikalibrasi agar hati tepat di tengah bar (h/2)
  double _ekgY(double x, double w, double h, double phase) {
    final double t = ((x / w) + phase) % 1.0;
    final double cy = (t % 0.25) / 0.25; // posisi dalam satu siklus 0..1

    final double mid = h / 2;
    const double amp = 22.0; // amplitudo maksimal spike R

    if (cy < 0.08) {
      // P-wave: gelombang kecil ke atas
      return mid - math.sin(cy / 0.08 * math.pi) * 5;
    } else if (cy < 0.14) {
      // Q: turun sedikit
      return mid + math.sin((cy - 0.08) / 0.06 * math.pi) * 5;
    } else if (cy < 0.20) {
      // R: spike ke atas (puncak EKG)
      return mid - math.sin((cy - 0.14) / 0.06 * math.pi) * amp;
    } else if (cy < 0.26) {
      // S: turun balik
      return mid + math.sin((cy - 0.20) / 0.06 * math.pi) * 8;
    } else if (cy < 0.40) {
      // T-wave: naik lembut
      return mid - math.sin((cy - 0.26) / 0.14 * math.pi) * 9;
    }
    return mid; // garis datar
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double mid = h / 2;

    // 1. Baseline tipis
    canvas.drawLine(
      Offset(0, mid),
      Offset(w, mid),
      Paint()
        ..color = color.withOpacity(0.12)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke,
    );

    // 2. Posisi hati
    final double phase = isRefreshing ? progress * 0.85 : pullProgress * 0.25;
    final double heartX = isRefreshing ? (progress * w) : (pullProgress * w);
    final double trailLen = w * 0.42;
    final double startX = (heartX - trailLen).clamp(0.0, w);

    // 3. Gambar trail EKG dengan gradasi opacity
    final Paint ekgPaint = Paint()
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (double x = startX; x <= heartX; x += 1.5) {
      final double alpha = ((x - startX) / trailLen).clamp(0.0, 1.0);
      final double y = _ekgY(x, w, h, phase);
      final double prevY = _ekgY(x - 1.5, w, h, phase);
      ekgPaint.color = color.withOpacity(alpha * 0.9);
      canvas.drawLine(Offset(x - 1.5, prevY), Offset(x, y), ekgPaint);
    }

    // 4. Hati di ujung garis — posisi Y ikut gelombang EKG
    if (heartX >= 0 && heartX <= w + 10) {
      final double heartY = _ekgY(heartX.clamp(0, w), w, h, phase);

      // Pulse scale detak
      final double pulse = isRefreshing
          ? 1.0 + math.sin(progress * math.pi * 8).abs() * 0.25
          : 0.7 + pullProgress * 0.5;

      final double sz = 11.0 * pulse;

      // Glow
      canvas.drawCircle(
        Offset(heartX, heartY),
        sz,
        Paint()
          ..color = color.withOpacity(0.15)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );

      // Hati
      final Paint heartFill = Paint()..color = color;
      canvas.save();
      canvas.translate(heartX, heartY);
      canvas.scale(sz / 10, sz / 10);

      final Path hp = Path();
      hp.moveTo(0, 3.2);
      hp.cubicTo(-0.8, 1.2, -5, 1.0, -5, 4.0);
      hp.cubicTo(-5, 6.5, -2.5, 8.5, 0, 10.5);
      hp.cubicTo(2.5, 8.5, 5, 6.5, 5, 4.0);
      hp.cubicTo(5, 1.0, 0.8, 1.2, 0, 3.2);
      hp.close();
      canvas.drawPath(hp, heartFill);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_EkgPainter old) =>
      old.progress != progress ||
      old.pullProgress != pullProgress ||
      old.isRefreshing != isRefreshing;
}

// Helper math (tidak import dart:math agar tidak konflik)
class Math {
  static double sin(double x) {
    // Taylor approximation cukup akurat untuk animasi
    x = x % (2 * 3.14159265358979);
    if (x < 0) x += 2 * 3.14159265358979;
    double result = x;
    double term = x;
    for (int i = 1; i <= 7; i++) {
      term *= -x * x / ((2 * i) * (2 * i + 1));
      result += term;
    }
    return result;
  }
}

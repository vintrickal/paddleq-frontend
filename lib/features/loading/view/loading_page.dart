import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:paddleq/core/theme/paddle_colors.dart';
import 'package:paddleq/core/theme/paddle_text.dart';

/// Loading screen mapped from `Loading.html`.
///
/// Plays a paddle-rally animation (two paddles swinging, ball arcing between
/// them, striped progress bar shimmering) for [duration]. When the bar fills,
/// [onComplete] fires so the caller can navigate onward.
class LoadingPage extends StatefulWidget {
  const LoadingPage({
    super.key,
    required this.onComplete,
    this.duration = const Duration(milliseconds: 2600),
  });

  final VoidCallback onComplete;
  final Duration duration;

  @override
  State<LoadingPage> createState() => _LoadingPageState();
}

class _LoadingPageState extends State<LoadingPage> with TickerProviderStateMixin {
  late final AnimationController _rally; // 1.2s, repeats
  late final AnimationController _bar;   // [duration], one-shot
  late final AnimationController _dot;   // 1.4s, repeats
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _rally = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
    _dot = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
    _bar = AnimationController(vsync: this, duration: widget.duration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && !_completed) {
          _completed = true;
          widget.onComplete();
        }
      })
      ..forward();
  }

  @override
  void dispose() {
    _rally.dispose();
    _bar.dispose();
    _dot.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PaddleColors.paper,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _CourtBackdrop(),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Brand(dot: _dot),
                    const SizedBox(height: 36),
                    SizedBox(
                      height: 200,
                      child: _RallyScene(rally: _rally),
                    ),
                    const SizedBox(height: 36),
                    _ProgressBar(progress: _bar),
                    const SizedBox(height: 12),
                    _Label(dot: _dot),
                    const SizedBox(height: 4),
                    Text(
                      'warming up the courts',
                      style: PaddleText.script(size: 18, color: PaddleColors.inkSoft),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── court backdrop ─────────────────────────────────────────────────────────

class _CourtBackdrop extends StatelessWidget {
  const _CourtBackdrop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 0.7,
          colors: [Color(0x0F2D7749), PaddleColors.paper],
          stops: [0, 0.6],
        ),
        color: PaddleColors.paper,
      ),
      child: LayoutBuilder(builder: (context, c) {
        return Stack(
          children: [
            // outer court rectangle: inset 12% / 18%
            Positioned(
              left: c.maxWidth * 0.18,
              right: c.maxWidth * 0.18,
              top: c.maxHeight * 0.12,
              bottom: c.maxHeight * 0.12,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0x1F2D7749), width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            // inner court rectangle: inset 22% / 32%
            Positioned(
              left: c.maxWidth * 0.32,
              right: c.maxWidth * 0.32,
              top: c.maxHeight * 0.22,
              bottom: c.maxHeight * 0.22,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0x2E2D7749), width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            // dashed net
            Positioned(
              left: c.maxWidth * 0.08,
              right: c.maxWidth * 0.08,
              top: c.maxHeight * 0.5,
              child: CustomPaint(
                size: const Size(double.infinity, 2),
                painter: _DashedLinePainter(
                  color: const Color(0x402D7749),
                  dash: 8,
                  gap: 6,
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  _DashedLinePainter({required this.color, required this.dash, required this.gap});
  final Color color;
  final double dash;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.square;
    var x = 0.0;
    final y = size.height / 2;
    while (x < size.width) {
      canvas.drawLine(Offset(x, y), Offset(math.min(x + dash, size.width), y), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter old) =>
      old.color != color || old.dash != dash || old.gap != gap;
}

// ─── brand wordmark with hopping dot ────────────────────────────────────────

class _Brand extends StatelessWidget {
  const _Brand({required this.dot});
  final Animation<double> dot;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final fontSize = (width * 0.08).clamp(36.0, 64.0);
    final dotSize = fontSize * 0.5;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          'PADDLE',
          style: GoogleFonts.fasterOne(
            fontSize: fontSize,
            color: PaddleColors.ink,
            height: 1,
            letterSpacing: 1,
          ),
        ),
        SizedBox(width: fontSize * 0.06),
        AnimatedBuilder(
          animation: dot,
          builder: (context, _) {
            final hop = -6 * math.sin(dot.value * math.pi);
            return Padding(
              padding: EdgeInsets.only(bottom: fontSize * 0.05),
              child: Transform.translate(
                offset: Offset(0, hop),
                child: Container(
                  width: dotSize,
                  height: dotSize,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFD4ED3A),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x14000000),
                        offset: Offset(-3, -3),
                        spreadRadius: -1,
                        blurRadius: 0,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

// ─── rally scene (two paddles + arcing ball) ────────────────────────────────

class _RallyScene extends StatelessWidget {
  const _RallyScene({required this.rally});
  final Animation<double> rally;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: rally,
      builder: (context, _) {
        final t = rally.value; // 0..1

        // ball X: linear back-and-forth between 14% and 86% (cosine).
        final ballX = 0.5 - 0.36 * math.cos(t * 2 * math.pi);
        // ball Y bounces twice per cycle (alternates 30% ↔ 60%).
        final yPhase = (t * 2) % 1.0;
        final yProgress = yPhase < 0.5 ? yPhase * 2 : (1 - yPhase) * 2;
        final ballY = 0.30 + 0.30 * yProgress;

        // paddle swing angles
        final leftAngle = _paddleLeftAngle(t);
        final rightAngle = _paddleRightAngle(t);

        return LayoutBuilder(builder: (context, c) {
          final w = c.maxWidth;
          final h = c.maxHeight;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              // left paddle
              Positioned(
                left: w * 0.08,
                top: h * 0.5,
                child: Transform.translate(
                  offset: const Offset(0, -78),
                  child: Transform.rotate(
                    angle: leftAngle,
                    alignment: const Alignment(0, 0.9),
                    child: const _Paddle(faceColor: PaddleColors.paddleGreen),
                  ),
                ),
              ),
              // right paddle (mirrored)
              Positioned(
                right: w * 0.08,
                top: h * 0.5,
                child: Transform.translate(
                  offset: const Offset(0, -78),
                  child: Transform(
                    transform: Matrix4.identity()..scale(-1.0, 1.0),
                    alignment: const Alignment(0, 0.9),
                    child: Transform.rotate(
                      angle: rightAngle,
                      alignment: const Alignment(0, 0.9),
                      child: const _Paddle(faceColor: Color(0xFFC24A1E)),
                    ),
                  ),
                ),
              ),
              // ball shadow on the floor
              Positioned(
                left: w * ballX - 15,
                bottom: 12,
                child: Opacity(
                  opacity: 0.18 + 0.14 * yProgress,
                  child: Transform.scale(
                    scale: 0.7 + 0.4 * yProgress,
                    child: Container(
                      width: 30,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
              ),
              // ball
              Positioned(
                left: w * ballX - 14,
                top: h * ballY - 14,
                child: const _Ball(),
              ),
              // motion trail at center
              Positioned(
                left: w * 0.5 - 30,
                top: h * 0.5 - 1,
                child: Transform.scale(
                  scaleX: t < 0.5 ? 1 : -1,
                  child: Container(
                    width: 60,
                    height: 2,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Color(0x662D7749),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        });
      },
    );
  }

  /// Approximation of CSS keyframes:
  /// 0%,15% rotate(-32) → 25% rotate(8) → 50%,100% rotate(-18)
  double _paddleLeftAngle(double t) {
    double deg;
    if (t <= 0.15) {
      deg = -32;
    } else if (t <= 0.25) {
      deg = _lerp(-32, 8, (t - 0.15) / 0.10);
    } else if (t <= 0.50) {
      deg = _lerp(8, -18, (t - 0.25) / 0.25);
    } else {
      deg = -18;
    }
    return deg * math.pi / 180;
  }

  /// 0%,50% rotate(18) → 65% rotate(32) → 75% rotate(-8) → 100% rotate(18)
  double _paddleRightAngle(double t) {
    double deg;
    if (t <= 0.50) {
      deg = 18;
    } else if (t <= 0.65) {
      deg = _lerp(18, 32, (t - 0.50) / 0.15);
    } else if (t <= 0.75) {
      deg = _lerp(32, -8, (t - 0.65) / 0.10);
    } else {
      deg = _lerp(-8, 18, (t - 0.75) / 0.25);
    }
    return deg * math.pi / 180;
  }

  static double _lerp(double a, double b, double p) => a + (b - a) * p.clamp(0, 1);
}

class _Paddle extends StatelessWidget {
  const _Paddle({required this.faceColor});
  final Color faceColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 78,
      height: 96,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            width: 78,
            height: 78,
            child: Container(
              decoration: BoxDecoration(
                color: faceColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(38),
                  topRight: Radius.circular(38),
                  bottomLeft: Radius.circular(36),
                  bottomRight: Radius.circular(36),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    offset: const Offset(0, -6),
                    spreadRadius: 0,
                    blurRadius: 0,
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    offset: const Offset(0, 6),
                    blurRadius: 12,
                    spreadRadius: -4,
                  ),
                ],
              ),
            ),
          ),
          // grip handle
          Positioned(
            left: 32,
            bottom: 0,
            width: 14,
            height: 28,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF2C1D12),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                  bottomLeft: Radius.circular(5),
                  bottomRight: Radius.circular(5),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    offset: const Offset(-2, 0),
                    spreadRadius: 0,
                    blurRadius: 0,
                  ),
                ],
              ),
            ),
          ),
          // grip texture
          Positioned(
            left: 32,
            bottom: 4,
            width: 14,
            height: 18,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFC47B4A), Color(0xFF8A4F29)],
                  stops: [0.5, 0.5],
                  tileMode: TileMode.repeated,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Ball extends StatelessWidget {
  const _Ball();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: Alignment(-0.3, -0.4),
          radius: 0.8,
          colors: [Color(0xFFF7FF7A), Color(0xFFD4ED3A), Color(0xFFB6CF28)],
          stops: [0, 0.5, 1],
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x4D000000),
            offset: Offset(0, 6),
            blurRadius: 14,
            spreadRadius: -4,
          ),
        ],
      ),
      child: CustomPaint(
        painter: _BallHolesPainter(),
      ),
    );
  }
}

class _BallHolesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0x2E000000);
    final s = size.width;
    void hole(double x, double y, [double r = 1.5]) {
      canvas.drawCircle(Offset(s * x, s * y), r, paint);
    }
    hole(0.32, 0.30);
    hole(0.60, 0.26);
    hole(0.78, 0.43);
    hole(0.40, 0.62);
    hole(0.68, 0.65);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── striped progress bar ───────────────────────────────────────────────────

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.progress});
  final Animation<double> progress;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: progress,
      builder: (context, _) {
        return Container(
          height: 10,
          decoration: BoxDecoration(
            color: const Color(0x14000000),
            borderRadius: BorderRadius.circular(99),
          ),
          clipBehavior: Clip.antiAlias,
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: progress.value.clamp(0, 1),
              child: const _StripedFill(),
            ),
          ),
        );
      },
    );
  }
}

class _StripedFill extends StatefulWidget {
  const _StripedFill();

  @override
  State<_StripedFill> createState() => _StripedFillState();
}

class _StripedFillState extends State<_StripedFill> with SingleTickerProviderStateMixin {
  late final AnimationController _shimmer;

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat();
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmer,
      builder: (context, _) {
        return CustomPaint(
          painter: _StripedFillPainter(shimmer: _shimmer.value),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _StripedFillPainter extends CustomPainter {
  _StripedFillPainter({required this.shimmer});
  final double shimmer;

  @override
  void paint(Canvas canvas, Size size) {
    final stripePaint = Paint();
    final dark = Paint()..color = PaddleColors.paddleGreenDark;
    canvas.drawRect(Offset.zero & size, dark);

    // 45° green stripes, 10px wide, 20px period
    stripePaint.color = PaddleColors.paddleGreen;
    final stripeWidth = 10.0;
    final period = 20.0;
    final maxX = size.width + size.height + period;
    for (var x = -size.height; x < maxX; x += period) {
      final path = Path()
        ..moveTo(x, 0)
        ..lineTo(x + stripeWidth, 0)
        ..lineTo(x + stripeWidth + size.height, size.height)
        ..lineTo(x + size.height, size.height)
        ..close();
      canvas.drawPath(path, stripePaint);
    }

    // shimmer pass
    final shimmerX = size.width * (shimmer * 2 - 1);
    final shimmerRect = Rect.fromLTWH(shimmerX - 30, 0, 60, size.height);
    final shimmerPaint = Paint()
      ..shader = const LinearGradient(
        colors: [
          Colors.transparent,
          Color(0x66FFFFFF),
          Colors.transparent,
        ],
      ).createShader(shimmerRect);
    canvas.drawRect(shimmerRect, shimmerPaint);
  }

  @override
  bool shouldRepaint(covariant _StripedFillPainter old) => old.shimmer != shimmer;
}

// ─── label "QUEUEING UP..." ─────────────────────────────────────────────────

class _Label extends StatelessWidget {
  const _Label({required this.dot});
  final Animation<double> dot;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: dot,
      builder: (context, _) {
        // 4-step dot cycle to mirror the CSS `dots` keyframes.
        final step = (dot.value * 4).floor().clamp(0, 3);
        final dots = '.' * step;
        return Text(
          'COURT SETTING UP$dots',
          style: GoogleFonts.delaGothicOne(
            fontSize: 12,
            color: PaddleColors.inkSoft,
            letterSpacing: 2,
            height: 1,
          ),
        );
      },
    );
  }
}

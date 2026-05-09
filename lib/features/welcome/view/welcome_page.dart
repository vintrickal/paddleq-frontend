import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:paddleq/core/api/api_exception.dart';
import 'package:paddleq/core/api/paddleq_api.dart';
import 'package:paddleq/core/models/session_dtos.dart';
import 'package:paddleq/core/theme/paddle_colors.dart';
import 'package:paddleq/core/theme/paddle_text.dart';
import 'package:paddleq/features/court/view/court_page.dart';
import 'package:paddleq/features/home/view/home_page.dart';

/// Splash / welcome animation mapped from `Welcome.html`.
///
/// Sequence (animation peaks at 3700ms, then holds until [totalMs] before
/// the 480ms exit fires — gives the user a moment to enjoy the finished
/// scene before routing away):
///   • 200–760ms — three rounded "court" rings scale-in
///   • 700–1600ms — dashed net line draws across
///   • 200–820ms — paddle / ball / scribble confetti bursts from the edges
///   • 250–1400ms — PADDLE letters rise into place + ball dot
///   • 1100ms — eyebrow tagline fades up
///   • 1300ms — script sub-line fades up
///   • 1500–3700ms — pulse bar fills
///   • 1600ms+ — ball dot starts hopping on a loop
///   • [totalMs] — page fades / scales out and routes to Home
class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  /// Time the wordmark, sub and pulse bar take to reach their final state.
  static const animationMs = 3700;

  /// Total time the welcome screen stays on-screen before exiting.
  /// `animationMs..totalMs` is a hold window so the user gets to see the
  /// finished composition (and the ball-hop loop) in full.
  static const totalMs = 5500;
  static const exitMs = 480;

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> with TickerProviderStateMixin {
  late final AnimationController _master;
  late final AnimationController _hop;
  late final List<_Flier> _fliers;
  late final Future<SessionResponse?> _activeSessionFuture;
  bool _routed = false;
  bool _exiting = false;

  @override
  void initState() {
    super.initState();
    _master = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: WelcomePage.animationMs),
    )..forward();

    _hop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    Future.delayed(const Duration(milliseconds: 1600), () {
      if (mounted) _hop.repeat(reverse: true);
    });

    _fliers = _buildFliers();

    // Run the active-session probe in parallel with the splash so refreshing
    // the browser drops the host straight back into their session instead of
    // leaving them stuck on Home (where Setup court would 409).
    _activeSessionFuture = _resolveActiveSession();

    Future.delayed(
      const Duration(milliseconds: WelcomePage.totalMs),
      _goHome,
    );
  }

  @override
  void dispose() {
    _master.dispose();
    _hop.dispose();
    super.dispose();
  }

  /// Returns the active session if there is one, `null` for a 404 (no
  /// session) and any other failure (network down, server error, etc.).
  /// Errors during a splash screen would be jarring — silently fall back
  /// to the normal Home flow instead.
  Future<SessionResponse?> _resolveActiveSession() async {
    try {
      return await context.read<PaddleqApi>().getActiveSession();
    } on ApiException {
      return null;
    }
  }

  Future<void> _goHome() async {
    if (_routed) return;
    _routed = true;
    if (!mounted) return;
    setState(() => _exiting = true);

    // Cap the wait so SKIP isn't blocked by a slow API. Worst case the
    // user lands on Home and tries again — better than staring at a
    // frozen splash for 30 s.
    final session = await _activeSessionFuture.timeout(
      const Duration(seconds: 2),
      onTimeout: () => null,
    );

    await Future.delayed(const Duration(milliseconds: WelcomePage.exitMs));
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => session != null
            ? CourtPage(session: session)
            : const HomePage(),
        transitionDuration: const Duration(milliseconds: 280),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  List<_Flier> _buildFliers() {
    final rng = math.Random(42);
    Color pick() => _confettiColors[rng.nextInt(_confettiColors.length)];

    final list = <_Flier>[];
    for (var i = 0; i < 12; i++) {
      list.add(_Flier(
        kind: _FlierKind.paddle,
        seedX: rng.nextDouble(),
        seedY: rng.nextDouble(),
        targetX: rng.nextDouble(),
        targetY: rng.nextDouble(),
        side: rng.nextInt(4),
        rotStart: rng.nextDouble() * 360 - 180,
        rotEnd: (rng.nextDouble() * 360 + 180) * (rng.nextBool() ? 1 : -1),
        scale: 0.6 + rng.nextDouble() * 0.6,
        delayMs: 300 + i * 80,
        durMs: (1400 + rng.nextDouble() * 800).round(),
        color: pick(),
      ));
    }
    for (var i = 0; i < 16; i++) {
      list.add(_Flier(
        kind: _FlierKind.ball,
        seedX: rng.nextDouble(),
        seedY: rng.nextDouble(),
        targetX: rng.nextDouble(),
        targetY: rng.nextDouble(),
        side: rng.nextInt(4),
        rotStart: rng.nextDouble() * 360 - 180,
        rotEnd: (rng.nextDouble() * 360 + 180) * (rng.nextBool() ? 1 : -1),
        scale: 0.6 + rng.nextDouble() * 0.6,
        delayMs: 200 + i * 60,
        durMs: (1400 + rng.nextDouble() * 800).round(),
        color: pick(),
      ));
    }
    for (var i = 0; i < 8; i++) {
      list.add(_Flier(
        kind: _FlierKind.scribble,
        seedX: rng.nextDouble(),
        seedY: rng.nextDouble(),
        targetX: rng.nextDouble(),
        targetY: rng.nextDouble(),
        side: rng.nextInt(4),
        rotStart: rng.nextDouble() * 60 - 30,
        rotEnd: rng.nextDouble() * 60 - 30,
        scale: 0.6 + rng.nextDouble() * 0.6,
        delayMs: 400 + i * 100,
        durMs: (1400 + rng.nextDouble() * 800).round(),
        color: pick(),
      ));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PaddleColors.paper,
      body: AnimatedBuilder(
        animation: _master,
        builder: (context, _) {
          return Stack(
            fit: StackFit.expand,
            children: [
              const _PaperBackground(),
              _RingsLayer(progressMs: _master.value * WelcomePage.animationMs),
              _NetLayer(progressMs: _master.value * WelcomePage.animationMs),
              _ConfettiLayer(
                fliers: _fliers,
                progressMs: _master.value * WelcomePage.animationMs,
              ),
              Center(
                child: AnimatedScale(
                  scale: _exiting ? 1.04 : 1,
                  duration: const Duration(milliseconds: WelcomePage.exitMs),
                  curve: const Cubic(.5, 0, .7, .2),
                  child: AnimatedOpacity(
                    opacity: _exiting ? 0 : 1,
                    duration: const Duration(milliseconds: WelcomePage.exitMs),
                    curve: const Cubic(.5, 0, .7, .2),
                    child: _CenterStage(
                      progressMs: _master.value * WelcomePage.animationMs,
                      hop: _hop,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 22,
                right: 22,
                child: AnimatedOpacity(
                  opacity: _exiting ? 0 : _fade(_master.value * WelcomePage.animationMs, 800, 1200),
                  duration: const Duration(milliseconds: 200),
                  child: _SkipButton(onTap: _goHome),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Helpers ────────────────────────────────────────────────────────────────

const _confettiColors = <Color>[
  Color(0xFF2D7749),
  Color(0xFFC24A1E),
  Color(0xFF1D72B8),
  Color(0xFF7A3FB7),
  Color(0xFFC7891B),
];

double _clamp01(double v) => v.clamp(0.0, 1.0);

/// Linear 0-1 progress for an animation that starts at [startMs] and runs
/// for [durMs] (no easing).
double _linear(double t, double startMs, double durMs) =>
    _clamp01((t - startMs) / durMs);

/// Same as [_linear] but applies a cubic-bezier-like ease-out approximation.
double _easeOut(double t, double startMs, double durMs) {
  final p = _linear(t, startMs, durMs);
  return 1 - math.pow(1 - p, 3).toDouble();
}

/// Fade-up alpha — 0 → 1 starting at [startMs] over [durMs] (used for the
/// `fadeUp` keyframe in the CSS).
double _fade(double t, double startMs, double durMs) =>
    _easeOut(t, startMs, durMs);

// ─── Background paper + radial wash ─────────────────────────────────────────

class _PaperBackground extends StatelessWidget {
  const _PaperBackground();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.2),
          radius: 0.9,
          colors: [
            Color(0x1A2D7749),
            PaddleColors.paper,
          ],
          stops: [0, 0.7],
        ),
        color: PaddleColors.paper,
      ),
    );
  }
}

// ─── Court rings ────────────────────────────────────────────────────────────

class _RingsLayer extends StatelessWidget {
  const _RingsLayer({required this.progressMs});
  final double progressMs;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final vmin = math.min(constraints.maxWidth, constraints.maxHeight);
      return Stack(
        alignment: Alignment.center,
        children: [
          _ring(vmin * 0.86, 0.4, 200),
          _ring(vmin * 0.60, 0.7, 380),
          _ring(vmin * 0.38, 1.0, 560),
        ],
      );
    });
  }

  Widget _ring(double size, double maxOpacity, double startMs) {
    final p = _easeOut(progressMs, startMs, 1200);
    final scale = 0.6 + 0.4 * p;
    final rotation = (-6 + 6 * p) * math.pi / 180;
    return Opacity(
      opacity: maxOpacity * p,
      child: Transform.rotate(
        angle: rotation,
        child: Transform.scale(
          scale: scale,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0x2E2D7749), width: 2),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Net (dashed line) ──────────────────────────────────────────────────────

class _NetLayer extends StatelessWidget {
  const _NetLayer({required this.progressMs});
  final double progressMs;

  @override
  Widget build(BuildContext context) {
    final p = _easeOut(progressMs, 700, 900);
    return LayoutBuilder(builder: (context, constraints) {
      return Positioned.fill(
        child: Stack(
          children: [
            Positioned(
              left: constraints.maxWidth * 0.08,
              right: constraints.maxWidth * 0.08,
              top: constraints.maxHeight * 0.52,
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: p,
                  child: Opacity(
                    opacity: p,
                    child: CustomPaint(
                      size: const Size(double.infinity, 2),
                      painter: _DashedLinePainter(
                        color: const Color(0x472D7749),
                        dash: 8,
                        gap: 6,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });
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

// ─── Center stage (tagline / wordmark / sub / pulse bar) ────────────────────

class _CenterStage extends StatelessWidget {
  const _CenterStage({required this.progressMs, required this.hop});

  final double progressMs;
  final Animation<double> hop;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _TaglinePill(progressMs: progressMs),
          const SizedBox(height: 18),
          _Wordmark(progressMs: progressMs, hop: hop),
          const SizedBox(height: 18),
          _SubLine(progressMs: progressMs),
          const SizedBox(height: 26),
          _PulseBar(progressMs: progressMs),
        ],
      ),
    );
  }
}

class _TaglinePill extends StatelessWidget {
  const _TaglinePill({required this.progressMs});
  final double progressMs;

  @override
  Widget build(BuildContext context) {
    final p = _fade(progressMs, 1100, 600);
    final size = MediaQuery.sizeOf(context).width;
    final fontSize = (size * 0.016).clamp(13.0, 18.0);
    return Opacity(
      opacity: p,
      child: Transform.translate(
        offset: Offset(0, 8 * (1 - p)),
        child: Text(
          'PICKLEBALL · QUEUE · PLAY',
          style: GoogleFonts.delaGothicOne(
            fontSize: fontSize,
            color: PaddleColors.paddleGreen,
            letterSpacing: 4,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class _Wordmark extends StatefulWidget {
  const _Wordmark({required this.progressMs, required this.hop});
  final double progressMs;
  final Animation<double> hop;

  @override
  State<_Wordmark> createState() => _WordmarkState();
}

class _WordmarkState extends State<_Wordmark> {
  static const _chars = ['P', 'A', 'D', 'D', 'L', 'E'];
  static const _delays = [250.0, 320.0, 390.0, 460.0, 530.0, 600.0];
  static const _dotDelay = 700.0;
  static const _charDur = 700.0;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context).width;
    final fontSize = (size * 0.14).clamp(56.0, 168.0);
    final dotSize = fontSize * 0.7;

    return SizedBox(
      height: fontSize * 1.05,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < _chars.length; i++)
            _RisingChar(
              char: _chars[i],
              fontSize: fontSize,
              progress: _easeOut(widget.progressMs, _delays[i], _charDur),
            ),
          _BallDot(
            size: dotSize,
            entryProgress: _easeOut(widget.progressMs, _dotDelay, _charDur),
            hop: widget.hop,
          ),
        ],
      ),
    );
  }
}

class _RisingChar extends StatelessWidget {
  const _RisingChar({required this.char, required this.fontSize, required this.progress});

  final String char;
  final double fontSize;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: SizedBox(
        height: fontSize * 1.05,
        child: Transform.translate(
          offset: Offset(0, fontSize * 1.1 * (1 - progress)),
          child: Opacity(
            opacity: progress,
            child: Text(
              char,
              style: GoogleFonts.fasterOne(
                fontSize: fontSize,
                color: PaddleColors.ink,
                height: 1,
                letterSpacing: 2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BallDot extends StatelessWidget {
  const _BallDot({required this.size, required this.entryProgress, required this.hop});

  final double size;
  final double entryProgress;
  final Animation<double> hop;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: hop,
      builder: (context, _) {
        final hopOffset = -12 * math.sin(hop.value * math.pi);
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: size * 0.06),
          child: Transform.translate(
            offset: Offset(0, size * 0.18 + (1 - entryProgress) * size * 1.1 + hopOffset * entryProgress),
            child: Opacity(
              opacity: entryProgress,
              child: Container(
                width: size,
                height: size,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    center: Alignment(-0.3, -0.4),
                    radius: 0.8,
                    colors: [
                      Color(0xFFF7FF7A),
                      Color(0xFFD4ED3A),
                      Color(0xFFB6CF28),
                    ],
                    stops: [0, 0.5, 1],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x4D000000),
                      offset: Offset(0, 4),
                      blurRadius: 10,
                      spreadRadius: -2,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SubLine extends StatelessWidget {
  const _SubLine({required this.progressMs});
  final double progressMs;

  @override
  Widget build(BuildContext context) {
    final p = _fade(progressMs, 1300, 600);
    final width = MediaQuery.sizeOf(context).width;
    final fontSize = (width * 0.024).clamp(18.0, 26.0);
    return Opacity(
      opacity: p,
      child: Transform.translate(
        offset: Offset(0, 8 * (1 - p)),
        child: Text(
          'queue up. play more.',
          style: PaddleText.script(size: fontSize, color: PaddleColors.inkSoft),
        ),
      ),
    );
  }
}

class _PulseBar extends StatelessWidget {
  const _PulseBar({required this.progressMs});
  final double progressMs;

  @override
  Widget build(BuildContext context) {
    final fade = _fade(progressMs, 1500, 400);
    final fillP = _linear(progressMs, 1500, 2200);
    final fill = _bezierEase(fillP, .5, .05, .4, 1);
    final width = MediaQuery.sizeOf(context).width;
    final barWidth = (width * 0.30).clamp(180.0, 280.0);

    return Opacity(
      opacity: fade,
      child: Container(
        width: barWidth,
        height: 4,
        decoration: BoxDecoration(
          color: const Color(0x14000000),
          borderRadius: BorderRadius.circular(99),
        ),
        clipBehavior: Clip.antiAlias,
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: fill,
            child: Container(
              decoration: BoxDecoration(
                color: PaddleColors.paddleGreen,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Approximate cubic-bezier(x1,y1,x2,y2) sampling; close enough for a 4px bar.
double _bezierEase(double t, double x1, double y1, double x2, double y2) {
  final c = 3.0 * y1;
  final b = 3.0 * (y2 - y1) - c;
  final a = 1.0 - c - b;
  return ((a * t + b) * t + c) * t;
}

// ─── Skip button ────────────────────────────────────────────────────────────

class _SkipButton extends StatelessWidget {
  const _SkipButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xD9FFFFFF),
      shape: StadiumBorder(side: BorderSide(color: Colors.black.withValues(alpha: 0.12), width: 1.5)),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text(
            'SKIP →',
            style: GoogleFonts.delaGothicOne(
              fontSize: 11,
              color: PaddleColors.ink,
              letterSpacing: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Confetti ───────────────────────────────────────────────────────────────

enum _FlierKind { paddle, ball, scribble }

class _Flier {
  _Flier({
    required this.kind,
    required this.seedX,
    required this.seedY,
    required this.targetX,
    required this.targetY,
    required this.side,
    required this.rotStart,
    required this.rotEnd,
    required this.scale,
    required this.delayMs,
    required this.durMs,
    required this.color,
  });

  final _FlierKind kind;
  final double seedX, seedY; // 0-1 along edge
  final double targetX, targetY; // 0-1 around center spread
  final int side; // 0=left, 1=right, 2=top, 3=bottom
  final double rotStart, rotEnd;
  final double scale;
  final int delayMs;
  final int durMs;
  final Color color;
}

class _ConfettiLayer extends StatelessWidget {
  const _ConfettiLayer({required this.fliers, required this.progressMs});

  final List<_Flier> fliers;
  final double progressMs;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      final h = constraints.maxHeight;
      return Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          for (final f in fliers) _buildFlier(f, w, h),
        ],
      );
    });
  }

  Widget _buildFlier(_Flier f, double w, double h) {
    final t = _easeOut(progressMs, f.delayMs.toDouble(), f.durMs.toDouble());

    final cx = w * 0.5;
    final cy = h * 0.5;

    // start position outside the viewport on one of four sides
    late final double sx, sy;
    switch (f.side) {
      case 0:
        sx = -120;
        sy = h * f.seedY;
      case 1:
        sx = w + 120;
        sy = h * f.seedY;
      case 2:
        sx = w * f.seedX;
        sy = -120;
      default:
        sx = w * f.seedX;
        sy = h + 120;
    }
    final ex = cx + (f.targetX - 0.5) * w * 0.7;
    final ey = cy + (f.targetY - 0.5) * h * 0.7;

    final x = sx + (ex - sx) * t;
    final y = sy + (ey - sy) * t;

    // opacity: fade in 0-15%, hold to 70%, fade out
    double opacity;
    if (t < 0.15) {
      opacity = t / 0.15;
    } else if (t < 0.7) {
      opacity = 1;
    } else {
      opacity = 1 - (t - 0.7) / 0.3;
    }
    if (t >= 1) opacity = 0;

    final rot = (f.rotStart + (f.rotEnd - f.rotStart) * t) * math.pi / 180;
    final scale = f.scale * (1 - 0.4 * t);

    return Positioned(
      left: x,
      top: y,
      child: IgnorePointer(
        child: Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Transform.rotate(
            angle: rot,
            child: Transform.scale(
              scale: scale,
              child: _flierShape(f),
            ),
          ),
        ),
      ),
    );
  }

  Widget _flierShape(_Flier f) {
    switch (f.kind) {
      case _FlierKind.paddle:
        return _MiniPaddle(color: f.color);
      case _FlierKind.ball:
        return const _MiniBall();
      case _FlierKind.scribble:
        return Container(
          width: 36,
          height: 12,
          decoration: BoxDecoration(
            color: f.color,
            borderRadius: BorderRadius.circular(6),
          ),
        );
    }
  }
}

class _MiniPaddle extends StatelessWidget {
  const _MiniPaddle({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 50,
      height: 60,
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 48,
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                  bottomLeft: Radius.circular(11),
                  bottomRight: Radius.circular(11),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    offset: const Offset(0, -4),
                    spreadRadius: 0,
                    blurRadius: 0,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 16,
            child: Center(
              child: Container(
                width: 11,
                decoration: BoxDecoration(
                  color: const Color(0xFF2C1D12),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniBall extends StatelessWidget {
  const _MiniBall();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: Alignment(-0.3, -0.4),
          radius: 0.8,
          colors: [
            Color(0xFFF7FF7A),
            Color(0xFFD4ED3A),
            Color(0xFFB6CF28),
          ],
          stops: [0, 0.5, 1],
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x4D000000),
            offset: Offset(0, 4),
            blurRadius: 10,
            spreadRadius: -2,
          ),
        ],
      ),
    );
  }
}

import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Stroke icons reproduced from the Claude Design handoff SVGs.
///
/// All icons paint with the current [IconTheme] color (or the [color]
/// override) and respect the supplied [size]. Stroke widths scale with size.
class PaddleIcon extends StatelessWidget {
  const PaddleIcon._(
    this._kind, {
    this.size = 16,
    this.color,
    this.strokeWidth,
    this.rotateTurns = 0,
    super.key,
  });

  final _Kind _kind;
  final double size;
  final Color? color;
  final double? strokeWidth;
  final double rotateTurns;

  const PaddleIcon.check({double size = 12, Color color = Colors.white, Key? key})
      : this._(_Kind.check, size: size, color: color, key: key);
  const PaddleIcon.arrowRight({double size = 22, Color color = Colors.white, Key? key})
      : this._(_Kind.arrowRight, size: size, color: color, key: key);
  const PaddleIcon.settings({double size = 16, Color? color, Key? key})
      : this._(_Kind.settings, size: size, color: color, key: key);
  const PaddleIcon.chevronRight({double size = 14, Color? color, Key? key})
      : this._(_Kind.chevron, size: size, color: color, key: key);
  const PaddleIcon.chevronLeft({double size = 14, Color? color, Key? key})
      : this._(_Kind.chevron, size: size, color: color, rotateTurns: 0.5, key: key);
  const PaddleIcon.back({double size = 14, Color? color, Key? key})
      : this._(_Kind.back, size: size, color: color, key: key);
  const PaddleIcon.plus({double size = 14, Color? color, Key? key})
      : this._(_Kind.plus, size: size, color: color, key: key);
  const PaddleIcon.x({double size = 13, Color? color, Key? key})
      : this._(_Kind.x, size: size, color: color, key: key);
  const PaddleIcon.qr({double size = 16, Color? color, Key? key})
      : this._(_Kind.qr, size: size, color: color, key: key);
  const PaddleIcon.user({double size = 16, Color? color, Key? key})
      : this._(_Kind.user, size: size, color: color, key: key);
  const PaddleIcon.edit({double size = 13, Color? color, Key? key})
      : this._(_Kind.edit, size: size, color: color, key: key);
  const PaddleIcon.trophy({double size = 14, Color? color, Key? key})
      : this._(_Kind.trophy, size: size, color: color, key: key);
  const PaddleIcon.clock({double size = 12, Color? color, Key? key})
      : this._(_Kind.clock, size: size, color: color, key: key);
  const PaddleIcon.refresh({double size = 14, Color? color, Key? key})
      : this._(_Kind.refresh, size: size, color: color, key: key);

  @override
  Widget build(BuildContext context) {
    final resolved = color ?? IconTheme.of(context).color ?? Colors.black;
    Widget canvas = CustomPaint(
      size: Size.square(size),
      painter: _IconPainter(kind: _kind, color: resolved, strokeWidth: strokeWidth),
    );
    if (rotateTurns != 0) {
      canvas = RotatedBox(quarterTurns: (rotateTurns * 4).round(), child: canvas);
    }
    return SizedBox(width: size, height: size, child: canvas);
  }
}

enum _Kind { check, arrowRight, settings, chevron, back, plus, x, qr, user, edit, trophy, clock, refresh }

class _IconPainter extends CustomPainter {
  _IconPainter({required this.kind, required this.color, this.strokeWidth});

  final _Kind kind;
  final Color color;
  final double? strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final stroke = Paint()
      ..color = color
      ..strokeWidth = strokeWidth ?? (s * 0.14).clamp(1.2, 3.0)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final fill = Paint()..color = color..style = PaintingStyle.fill;

    double v(double pct, double vb) => pct * s / vb;

    switch (kind) {
      case _Kind.check:
        final p = Path()
          ..moveTo(v(2, 12), v(6.5, 12))
          ..lineTo(v(4.8, 12), v(9, 12))
          ..lineTo(v(10, 12), v(3.5, 12));
        canvas.drawPath(p, stroke);
      case _Kind.arrowRight:
        canvas.drawLine(Offset(v(3, 22), v(11, 22)), Offset(v(18, 22), v(11, 22)), stroke);
        final p = Path()
          ..moveTo(v(12, 22), v(5, 22))
          ..lineTo(v(18, 22), v(11, 22))
          ..lineTo(v(12, 22), v(17, 22));
        canvas.drawPath(p, stroke);
      case _Kind.settings:
        final c = Offset(s / 2, s / 2);
        canvas.drawCircle(c, s * 0.18, stroke);
        for (final deg in [0, 90, 180, 270]) {
          final r = deg * math.pi / 180;
          final p1 = Offset(c.dx + s * 0.32 * math.cos(r), c.dy + s * 0.32 * math.sin(r));
          final p2 = Offset(c.dx + s * 0.5 * math.cos(r), c.dy + s * 0.5 * math.sin(r));
          canvas.drawLine(p1, p2, stroke);
        }
      case _Kind.chevron:
        final p = Path()
          ..moveTo(v(2, 10), v(1, 14))
          ..lineTo(v(8, 10), v(7, 14))
          ..lineTo(v(2, 10), v(13, 14));
        canvas.drawPath(p, stroke);
      case _Kind.back:
        final p = Path()
          ..moveTo(v(9, 14), v(2, 14))
          ..lineTo(v(4, 14), v(7, 14))
          ..lineTo(v(9, 14), v(12, 14));
        canvas.drawPath(p, stroke);
      case _Kind.plus:
        canvas.drawLine(Offset(s / 2, v(2, 14)), Offset(s / 2, v(12, 14)), stroke);
        canvas.drawLine(Offset(v(2, 14), s / 2), Offset(v(12, 14), s / 2), stroke);
      case _Kind.x:
        canvas.drawLine(Offset(v(3, 14), v(3, 14)), Offset(v(11, 14), v(11, 14)), stroke);
        canvas.drawLine(Offset(v(11, 14), v(3, 14)), Offset(v(3, 14), v(11, 14)), stroke);
      case _Kind.qr:
        Rect at(double x, double y, double w, double h) =>
            Rect.fromLTWH(v(x, 16), v(y, 16), v(w, 16), v(h, 16));
        final r = stroke..strokeWidth = (strokeWidth ?? s * 0.09);
        canvas.drawRect(at(2, 2, 4, 4), r);
        canvas.drawRect(at(10, 2, 4, 4), r);
        canvas.drawRect(at(2, 10, 4, 4), r);
        canvas.drawRect(at(10, 10, 2, 2), fill);
        canvas.drawRect(at(13, 13, 1.5, 1.5), fill);
      case _Kind.user:
        canvas.drawCircle(Offset(s / 2, v(5.5, 16)), v(2.5, 16), stroke);
        final body = Path()
          ..moveTo(v(3, 16), v(14, 16))
          ..cubicTo(v(3, 16), v(11.5, 16), v(5.2, 16), v(9.5, 16), v(8, 16), v(9.5, 16))
          ..cubicTo(v(10.8, 16), v(9.5, 16), v(13, 16), v(11.5, 16), v(13, 16), v(14, 16));
        canvas.drawPath(body, stroke);
      case _Kind.edit:
        final p = Path()
          ..moveTo(v(2, 14), v(12, 14))
          ..lineTo(v(4, 14), v(11.5, 14))
          ..lineTo(v(11, 14), v(4.5, 14))
          ..lineTo(v(9.5, 14), v(3, 14))
          ..lineTo(v(2.5, 14), v(10, 14))
          ..close();
        canvas.drawPath(p, stroke);
      case _Kind.trophy:
        final cup = Path()
          ..moveTo(v(3, 14), v(2, 14))
          ..lineTo(v(11, 14), v(2, 14))
          ..lineTo(v(11, 14), v(5, 14))
          ..arcToPoint(
            Offset(v(3, 14), v(5, 14)),
            radius: Radius.circular(v(4, 14)),
            clockwise: false,
          )
          ..close();
        canvas.drawPath(cup, stroke);
        canvas.drawRect(
          Rect.fromLTWH(v(5, 14), v(9, 14), v(4, 14), v(3, 14)),
          stroke,
        );
      case _Kind.clock:
        canvas.drawCircle(Offset(s / 2, s / 2), s * 0.42, stroke);
        canvas.drawLine(Offset(s / 2, s / 2), Offset(s / 2, s / 2 - s * 0.3), stroke);
        canvas.drawLine(Offset(s / 2, s / 2), Offset(s / 2 + s * 0.22, s / 2 + s * 0.05), stroke);
      case _Kind.refresh:
        final c = Offset(s / 2, s / 2);
        final r = s * 0.35;
        canvas.drawArc(Rect.fromCircle(center: c, radius: r), -1.0, 4.7, false, stroke);
        final tip = Offset(c.dx + r, c.dy - r * 0.2);
        final p = Path()
          ..moveTo(tip.dx - r * 0.35, tip.dy - r * 0.15)
          ..lineTo(tip.dx, tip.dy)
          ..lineTo(tip.dx - r * 0.1, tip.dy + r * 0.4);
        canvas.drawPath(p, stroke);
    }
  }

  @override
  bool shouldRepaint(covariant _IconPainter old) =>
      old.kind != kind || old.color != color || old.strokeWidth != strokeWidth;
}

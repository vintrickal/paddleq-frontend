import 'package:flutter/material.dart';
import 'package:paddleq/core/theme/paddle_colors.dart';

/// Word with the soft green pill drawn behind its baseline — the design's
/// `em::after` pseudo element.
class HighlightText extends StatelessWidget {
  const HighlightText({super.key, required this.text, required this.style, this.barOpacity = 0.10, this.barHeight = 7});

  final String text;
  final TextStyle style;

  /// Opacity of the green bar (mobile uses 0.10, desktop uses 0.18).
  final double barOpacity;

  /// Bar height — mobile 7, desktop 10.
  final double barHeight;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: -2,
          right: -2,
          bottom: -3,
          child: Container(
            height: barHeight,
            decoration: BoxDecoration(
              color: PaddleColors.paddleGreen.withValues(alpha: barOpacity),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        Text(text, style: style.copyWith(color: PaddleColors.paddleGreen)),
      ],
    );
  }
}

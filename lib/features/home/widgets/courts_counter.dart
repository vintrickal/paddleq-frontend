import 'package:flutter/material.dart';
import 'package:paddleq/core/theme/paddle_colors.dart';
import 'package:paddleq/core/theme/paddle_text.dart';

/// Courts counter — minus / value / plus.
///
/// The value tile briefly scales up when [bumping] flips to true (driven by
/// the cubit). [variant] selects between the compact mobile look and the
/// roomier desktop look.
class CourtsCounter extends StatelessWidget {
  const CourtsCounter({
    super.key,
    required this.value,
    required this.maxValue,
    required this.onIncrement,
    required this.onDecrement,
    required this.bumping,
    this.variant = CounterVariant.mobile,
  });

  final int value;
  final int maxValue;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final bool bumping;
  final CounterVariant variant;

  @override
  Widget build(BuildContext context) {
    final isDesktop = variant == CounterVariant.desktop;
    final btnSize = isDesktop ? 44.0 : 36.0;
    final tileH = isDesktop ? 56.0 : 36.0;
    final tileW = isDesktop ? 72.0 : 48.0;
    final fontSize = isDesktop ? 28.0 : 18.0;

    final canDec = value > 1;
    final canInc = value < maxValue;

    return Container(
      decoration: BoxDecoration(
        color: PaddleColors.tile,
        borderRadius: BorderRadius.circular(isDesktop ? 14 : 10),
        border: Border.all(
          color: isDesktop ? PaddleColors.lineMid : PaddleColors.line,
          width: isDesktop ? 1.5 : 1,
        ),
      ),
      padding: EdgeInsets.all(isDesktop ? 6 : 0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _RoundButton(
            size: btnSize,
            label: '−',
            onTap: canDec ? onDecrement : null,
            transparent: isDesktop,
          ),
          SizedBox(width: isDesktop ? 16 : 8),
          _ValueTile(
            value: value,
            width: tileW,
            height: tileH,
            fontSize: fontSize,
            bumping: bumping,
          ),
          SizedBox(width: isDesktop ? 16 : 8),
          _RoundButton(
            size: btnSize,
            label: '+',
            onTap: canInc ? onIncrement : null,
            transparent: isDesktop,
          ),
        ],
      ),
    );
  }
}

enum CounterVariant { mobile, desktop }

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.size,
    required this.label,
    required this.onTap,
    this.transparent = false,
  });

  final double size;
  final String label;
  final VoidCallback? onTap;
  final bool transparent;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    final radius = BorderRadius.circular(transparent ? 10 : 10);
    return Material(
      color: transparent ? Colors.transparent : PaddleColors.tile,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: transparent ? null : Border.all(color: PaddleColors.line),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: PaddleText.display(
              size: size * 0.5,
              color: disabled ? const Color(0x33000000) : PaddleColors.ink,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

class _ValueTile extends StatelessWidget {
  const _ValueTile({
    required this.value,
    required this.width,
    required this.height,
    required this.fontSize,
    required this.bumping,
  });

  final int value;
  final double width;
  final double height;
  final double fontSize;
  final bool bumping;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      scale: bumping ? 1.10 : 1.0,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: PaddleColors.ink,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          '$value',
          style: PaddleText.display(size: fontSize, color: Colors.white, height: 1),
        ),
      ),
    );
  }
}

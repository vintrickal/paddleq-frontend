import 'package:flutter/material.dart';
import 'package:paddleq/core/theme/paddle_colors.dart';
import 'package:paddleq/core/theme/paddle_text.dart';
import 'package:paddleq/core/widgets/paddle_icons.dart';

/// Tall green primary action with hard "lift" shadow + soft drop.
///
/// Compresses on press (translateY 2) — driven by an internal pressed state.
class SetupCta extends StatefulWidget {
  const SetupCta({
    super.key,
    required this.label,
    required this.onPressed,
    this.height = 60,
    this.fontSize = 16,
  });

  final String label;
  final VoidCallback onPressed;
  final double height;
  final double fontSize;

  @override
  State<SetupCta> createState() => _SetupCtaState();
}

class _SetupCtaState extends State<SetupCta> {
  bool _pressed = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(14);
    final bg = _hovered ? PaddleColors.paddleGreenDark : PaddleColors.paddleGreen;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0, _pressed ? 2 : 0, 0),
          height: widget.height,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: radius,
            boxShadow: [
              // Hard "lift" — solid darker green underneath
              BoxShadow(
                color: PaddleColors.paddleGreenDark,
                offset: Offset(0, _pressed ? 2 : 4),
                blurRadius: 0,
              ),
              // Soft drop
              BoxShadow(
                color: const Color(0x382D7749),
                offset: Offset(0, _pressed ? 4 : 8),
                blurRadius: 18,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.label,
                style: PaddleText.display(
                  size: widget.fontSize,
                  color: Colors.white,
                  height: 1,
                ).copyWith(letterSpacing: widget.fontSize * 0.04),
              ),
              const SizedBox(width: 12),
              const PaddleIcon.arrowRight(),
            ],
          ),
        ),
      ),
    );
  }
}

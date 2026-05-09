import 'package:flutter/material.dart';
import 'package:paddleq/core/theme/paddle_colors.dart';

/// Constrains a mobile-first screen to a phone-width column on desktop.
///
/// On viewports wider than [breakpoint], the child is rendered inside a
/// 390px-wide rounded "phone" against the paper background. On narrower
/// viewports the child fills the available space.
class PhoneFrame extends StatelessWidget {
  const PhoneFrame({
    super.key,
    required this.child,
    this.maxWidth = 430,
    this.breakpoint = 768,
  });

  final Widget child;
  final double maxWidth;
  final double breakpoint;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isDesktop = size.width >= breakpoint;

    if (!isDesktop) return child;

    return ColoredBox(
      color: PaddleColors.paper,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxWidth,
            maxHeight: 880,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(38),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: PaddleColors.paper,
                borderRadius: BorderRadius.circular(38),
                border: Border.all(color: PaddleColors.lineMid, width: 1),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 40,
                    offset: Offset(0, 24),
                  ),
                ],
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

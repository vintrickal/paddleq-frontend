import 'package:flutter/material.dart';
import 'package:paddleq/core/theme/paddle_colors.dart';
import 'package:paddleq/core/theme/paddle_text.dart';
import 'package:paddleq/core/widgets/paddle_icons.dart';

/// "Court is ready" full-screen overlay with the green check + Adjust / Add players.
class ConfirmDialog extends StatelessWidget {
  const ConfirmDialog({
    super.key,
    required this.courts,
    required this.modeLabel,
    required this.totalPlayers,
    required this.onAdjust,
    required this.onAddPlayers,
  });

  final int courts;
  final String modeLabel;
  final int totalPlayers;
  final VoidCallback onAdjust;
  final VoidCallback onAddPlayers;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 200),
      builder: (_, t, child) => Opacity(opacity: t, child: child),
      child: ColoredBox(
        color: PaddleColors.overlay,
        child: BackdropBlurFallback(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.92, end: 1),
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutBack,
                builder: (_, scale, child) =>
                    Transform.scale(scale: scale, child: child),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Container(
                    decoration: BoxDecoration(
                      color: PaddleColors.tile,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x40000000),
                          blurRadius: 80,
                          offset: Offset(0, 30),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.fromLTRB(22, 28, 22, 22),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: PaddleColors.paddleGreen,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: PaddleColors.paddleGreen.withValues(alpha: 0.15),
                                blurRadius: 0,
                                spreadRadius: 6,
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: const PaddleIcon.check(size: 26),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Court is ready',
                          style: PaddleText.display(size: 20, height: 1.1),
                        ),
                        const SizedBox(height: 6),
                        Text.rich(
                          TextSpan(
                            style: PaddleText.body(
                              size: 13,
                              color: PaddleColors.inkSoft,
                              height: 1.5,
                            ),
                            children: [
                              TextSpan(text: '$courts ${courts == 1 ? 'court' : 'courts'} for '),
                              TextSpan(text: modeLabel.toLowerCase()),
                              const TextSpan(text: '.\n'),
                              const TextSpan(text: 'Add players next to start the queue.'),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 14),
                        _Pill(count: totalPlayers),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: _OutlineButton(
                                label: 'Adjust',
                                onPressed: onAdjust,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _PrimaryButton(
                                label: 'Add players',
                                onPressed: onAddPlayers,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.count});
  final int count;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: PaddleColors.paddleGreenSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PaddleIcon.check(size: 9, color: PaddleColors.paddleGreenDark),
          const SizedBox(width: 6),
          Text(
            '$count player slots open',
            style: PaddleText.body(
              size: 12,
              color: PaddleColors.paddleGreenDark,
              weight: FontWeight.w700,
            ).copyWith(letterSpacing: 12 * 0.04),
          ),
        ],
      ),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  const _OutlineButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Material(
        color: const Color(0x0D000000),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onPressed,
          child: Center(
            child: Text(label, style: PaddleText.display(size: 13, height: 1)),
          ),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Material(
        color: PaddleColors.paddleGreen,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onPressed,
          child: Center(
            child: Text(
              label,
              style: PaddleText.display(size: 13, color: Colors.white, height: 1),
            ),
          ),
        ),
      ),
    );
  }
}

/// Wraps child in a [BackdropFilter] when supported; falls back gracefully.
class BackdropBlurFallback extends StatelessWidget {
  const BackdropBlurFallback({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => child;
}

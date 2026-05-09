import 'package:flutter/material.dart';
import 'package:paddleq/core/theme/paddle_colors.dart';
import 'package:paddleq/core/theme/paddle_text.dart';
import 'package:paddleq/core/widgets/paddle_icons.dart';

/// Singles / Doubles selection tile.
///
/// Two visual variants:
///  * [orientation] = [Axis.vertical] — stacked (mobile Home Mobile.html)
///  * [orientation] = [Axis.horizontal] — wide row (desktop Home.html)
class ModeTile extends StatelessWidget {
  const ModeTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.assetPath,
    required this.selected,
    required this.onTap,
    this.orientation = Axis.vertical,
  });

  final String title;
  final String subtitle;
  final String assetPath;
  final bool selected;
  final VoidCallback onTap;
  final Axis orientation;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);
    return Semantics(
      button: true,
      selected: selected,
      label: '$title, $subtitle',
      child: Material(
        color: selected ? PaddleColors.paddleGreenSoft : PaddleColors.tile,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            height: orientation == Axis.vertical ? 130 : null,
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: selected ? PaddleColors.paddleGreen : PaddleColors.line,
                width: 1.5,
              ),
              boxShadow: selected
                  ? const [
                      BoxShadow(
                        color: PaddleColors.paddleGreenSoftStrong,
                        blurRadius: 0,
                        spreadRadius: 3,
                      ),
                    ]
                  : null,
            ),
            padding: orientation == Axis.vertical
                ? const EdgeInsets.fromLTRB(14, 16, 14, 14)
                : const EdgeInsets.all(22),
            child: orientation == Axis.vertical
                ? _verticalLayout()
                : _horizontalLayout(),
          ),
        ),
      ),
    );
  }

  Widget _verticalLayout() {
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _IconBadge(assetPath: assetPath),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: PaddleText.display(size: 18, height: 1)),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: PaddleText.body(size: 11, color: PaddleColors.inkSoft, height: 1.2),
                ),
              ],
            ),
          ],
        ),
        Positioned(top: 0, right: 0, child: _CheckBadge(selected: selected)),
      ],
    );
  }

  Widget _horizontalLayout() {
    return Row(
      children: [
        _IconBadge(assetPath: assetPath, size: 56),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: PaddleText.display(size: 20, height: 1)),
              const SizedBox(height: 6),
              Text(subtitle,
                  style: PaddleText.body(size: 12, color: PaddleColors.inkSoft, height: 1.2)),
            ],
          ),
        ),
        _CheckBadge(selected: selected, size: 22),
      ],
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.assetPath, this.size = 44});
  final String assetPath;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: PaddleColors.tile,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PaddleColors.line),
      ),
      padding: EdgeInsets.all(size * 0.15),
      child: Image.asset(assetPath, fit: BoxFit.contain),
    );
  }
}

class _CheckBadge extends StatelessWidget {
  const _CheckBadge({required this.selected, this.size = 20});
  final bool selected;
  final double size;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? PaddleColors.paddleGreen : PaddleColors.tile,
        border: Border.all(
          color: selected ? PaddleColors.paddleGreen : PaddleColors.lineMid,
          width: 1.5,
        ),
      ),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 160),
        opacity: selected ? 1 : 0,
        child: Center(child: PaddleIcon.check(size: size * 0.6)),
      ),
    );
  }
}

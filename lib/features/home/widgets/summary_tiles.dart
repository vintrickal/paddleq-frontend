import 'package:flutter/material.dart';
import 'package:paddleq/core/theme/paddle_colors.dart';
import 'package:paddleq/core/theme/paddle_text.dart';

/// Three-up tile row: Courts / Per court / Players.
class SummaryTiles extends StatelessWidget {
  const SummaryTiles({
    super.key,
    required this.courts,
    required this.perCourt,
    required this.totalPlayers,
    this.variant = SummaryVariant.mobile,
  });

  final int courts;
  final int perCourt;
  final int totalPlayers;
  final SummaryVariant variant;

  @override
  Widget build(BuildContext context) {
    final isDesktop = variant == SummaryVariant.desktop;
    final gap = isDesktop ? 14.0 : 8.0;
    return Row(
      children: [
        Expanded(
          child: _Tile(
            num: courts,
            label: courts == 1 ? 'Court' : 'Courts',
            variant: variant,
          ),
        ),
        SizedBox(width: gap),
        Expanded(child: _Tile(num: perCourt, label: 'Per court', variant: variant)),
        SizedBox(width: gap),
        Expanded(child: _Tile(num: totalPlayers, label: isDesktop ? 'Players needed' : 'Players', variant: variant)),
      ],
    );
  }
}

enum SummaryVariant { mobile, desktop }

class _Tile extends StatelessWidget {
  const _Tile({required this.num, required this.label, required this.variant});

  final int num;
  final String label;
  final SummaryVariant variant;

  @override
  Widget build(BuildContext context) {
    final isDesktop = variant == SummaryVariant.desktop;
    return Container(
      decoration: BoxDecoration(
        color: PaddleColors.tile,
        borderRadius: BorderRadius.circular(isDesktop ? 14 : 12),
        border: Border.all(color: PaddleColors.line),
      ),
      padding: isDesktop
          ? const EdgeInsets.fromLTRB(18, 16, 18, 16)
          : const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$num',
              style: PaddleText.display(size: isDesktop ? 28 : 20, height: 1)),
          SizedBox(height: isDesktop ? 6 : 4),
          Text(
            label,
            style: PaddleText.label(
              size: isDesktop ? 11 : 10,
              tracking: isDesktop ? 0.12 : 0.10,
              weight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

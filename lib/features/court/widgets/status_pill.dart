import 'package:flutter/material.dart';
import 'package:paddleq/core/theme/paddle_colors.dart';
import 'package:paddleq/core/theme/paddle_text.dart';
import 'package:paddleq/features/court/cubit/court_cubit.dart';

/// Tiny dot + status label used in the player list rows.
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.status});
  final PlayerStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      PlayerStatus.active => PaddleColors.active,
      PlayerStatus.waiting => PaddleColors.warn,
      PlayerStatus.resting => PaddleColors.rest,
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          status.label,
          style: PaddleText.body(
            size: 11,
            color: color,
            weight: FontWeight.w700,
          ).copyWith(letterSpacing: 11 * 0.06),
        ),
      ],
    );
  }
}

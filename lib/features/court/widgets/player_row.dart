import 'package:flutter/material.dart';
import 'package:paddleq/core/theme/paddle_colors.dart';
import 'package:paddleq/core/theme/paddle_text.dart';
import 'package:paddleq/core/widgets/paddle_icons.dart';
import 'package:paddleq/features/court/cubit/court_cubit.dart';
import 'package:paddleq/features/court/widgets/avatar.dart';
import 'package:paddleq/features/court/widgets/player_info_dialog.dart';
import 'package:paddleq/features/court/widgets/status_pill.dart';

/// Single row in the player list: avatar / name + skill / status / [court chip] / chevron.
///
/// Tapping the row opens [showPlayerInfoDialog] for the player's profile +
/// REST action, unless an explicit [onTap] is provided to override.
class PlayerRow extends StatelessWidget {
  const PlayerRow({super.key, required this.player, this.onTap});

  final Player player;

  /// Override the default "open profile" tap behavior. Pass `null` to
  /// keep the default; pass a callback for non-profile tap targets.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isResting = player.status == PlayerStatus.resting;
    final radius = BorderRadius.circular(14);
    return Opacity(
      opacity: isResting ? 0.55 : 1,
      child: Material(
        color: PaddleColors.tile,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap ?? () => showPlayerInfoDialog(context, player),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: PaddleColors.line),
            ),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(
              children: [
                Avatar(name: player.name),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Flexible(
                            child: Text(
                              player.name,
                              style: PaddleText.body(
                                  size: 14,
                                  weight: FontWeight.w700,
                                  height: 1.2),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '(${player.skill})',
                            style: PaddleText.script(
                                size: 14, color: PaddleColors.inkFaint),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          StatusPill(status: player.status),
                          GamesPlayedPill(count: player.gamesPlayed),
                        ],
                      ),
                    ],
                  ),
                ),
                if (player.court != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0x0D000000),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'C${player.court}',
                      style: PaddleText.display(
                          size: 10, color: PaddleColors.inkSoft, height: 1),
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                const PaddleIcon.chevronRight(
                    color: PaddleColors.inkFaint, size: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shape-twin of [StatusPill], coloured paddle-blue, showing how many
/// matches the player has played this session.
class GamesPlayedPill extends StatelessWidget {
  const GamesPlayedPill({super.key, required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final label = count == 1 ? '1 game' : '$count games';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: PaddleColors.paddleBlue,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: PaddleText.body(
            size: 11,
            color: PaddleColors.paddleBlue,
            weight: FontWeight.w700,
          ).copyWith(letterSpacing: 11 * 0.06),
        ),
      ],
    );
  }
}

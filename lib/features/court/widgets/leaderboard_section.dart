import 'package:flutter/material.dart';
import 'package:paddleq/core/models/match_dtos.dart';
import 'package:paddleq/core/theme/paddle_colors.dart';
import 'package:paddleq/core/theme/paddle_text.dart';
import 'package:paddleq/features/court/widgets/avatar.dart';

/// "Leaderboard" section — players in the active session ranked by the
/// backend (wins → win-rate → games-played). Entries arrive pre-sorted
/// with their `rank` already filled in.
///
/// Top three ranks get a tinted medal pill (gold / silver / bronze); the
/// rest get a neutral chip. Each row shows the player's name, skill,
/// W/L record, and win-rate as a percentage.
class LeaderboardSection extends StatelessWidget {
  const LeaderboardSection({super.key, required this.entries});
  final List<LeaderboardEntryResponse> entries;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: PaddleColors.tile,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PaddleColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _Header(count: entries.length),
          if (entries.isEmpty)
            const _EmptyState()
          else
            for (var i = 0; i < entries.length; i++) ...[
              if (i > 0)
                const Divider(height: 1, color: PaddleColors.line),
              _LeaderboardRow(entry: entries[i]),
            ],
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Row(
        children: [
          Text(
            'Leaderboard',
            style: PaddleText.display(size: 16, height: 1),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0x0F000000),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$count',
              style: PaddleText.body(
                size: 11,
                weight: FontWeight.w700,
                color: PaddleColors.inkSoft,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      child: Text(
        'Nobody on the board yet — the leaderboard fills as matches finish.',
        style: PaddleText.body(
          size: 12,
          color: PaddleColors.inkFaint,
          height: 1.4,
        ),
      ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({required this.entry});
  final LeaderboardEntryResponse entry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: [
          _RankChip(rank: entry.rank),
          const SizedBox(width: 10),
          Avatar(name: entry.playerName, size: 32),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: Text(
                        entry.playerName,
                        style: PaddleText.body(
                          size: 13,
                          weight: FontWeight.w700,
                          height: 1.2,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '(${entry.skillLevel.toStringAsFixed(1)})',
                      style: PaddleText.script(
                        size: 13,
                        color: PaddleColors.inkFaint,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${entry.wins}W · ${entry.losses}L · '
                  '${(entry.winRate * 100).toStringAsFixed(0)}% win rate',
                  style: PaddleText.body(
                    size: 11,
                    color: PaddleColors.inkSoft,
                    weight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${entry.gamesPlayed}',
                style: PaddleText.display(size: 16, height: 1),
              ),
              const SizedBox(height: 2),
              Text(
                'GAMES',
                style: PaddleText.label(
                  size: 9,
                  tracking: 0.14,
                  weight: FontWeight.w900,
                  color: PaddleColors.inkFaint,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RankChip extends StatelessWidget {
  const _RankChip({required this.rank});
  final int rank;

  @override
  Widget build(BuildContext context) {
    final medal = _medalFor(rank);
    final color = medal?.color ?? const Color(0xFF6B7280);
    final bg = medal?.bg ?? const Color(0x0F000000);
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: medal == null ? null : Border.all(color: color, width: 1.5),
      ),
      child: Text(
        '$rank',
        style: PaddleText.display(
          size: 12,
          color: color,
          height: 1,
        ),
      ),
    );
  }
}

class _Medal {
  const _Medal(this.color, this.bg);
  final Color color;
  final Color bg;
}

_Medal? _medalFor(int rank) {
  switch (rank) {
    case 1:
      return const _Medal(Color(0xFFB08400), Color(0x33C7891B)); // gold
    case 2:
      return const _Medal(Color(0xFF6B7280), Color(0x336B7280)); // silver
    case 3:
      return const _Medal(Color(0xFF8B5A2B), Color(0x338B5A2B)); // bronze
    default:
      return null;
  }
}

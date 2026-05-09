import 'package:flutter/material.dart';
import 'package:paddleq/core/models/match_dtos.dart';
import 'package:paddleq/core/theme/paddle_colors.dart';
import 'package:paddleq/core/theme/paddle_text.dart';
import 'package:paddleq/core/widgets/paddle_icons.dart';
import 'package:paddleq/features/court/widgets/avatar.dart';

/// "Match history" section — completed matches in this session, newest
/// first. Pulled from `GET /api/matches/history` via [CourtCubit.loadQueue]
/// and stored as [CourtState.matchHistory].
///
/// Each row shows the court the match was played on, the winning team
/// highlighted with a trophy, the losing team dimmed, and the players on
/// each side as initial-avatars + name. Empty state explains that no
/// matches have completed yet.
class MatchHistorySection extends StatelessWidget {
  const MatchHistorySection({super.key, required this.matches});
  final List<MatchResponse> matches;

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
          _Header(count: matches.length),
          if (matches.isEmpty)
            const _EmptyState()
          else
            for (var i = 0; i < matches.length; i++) ...[
              if (i > 0) const Divider(height: 1, color: PaddleColors.line),
              _HistoryRow(match: matches[i]),
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
            'Match history',
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
        'No completed matches yet — the first finished game will show up here.',
        style: PaddleText.body(
          size: 12,
          color: PaddleColors.inkFaint,
          height: 1.4,
        ),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.match});
  final MatchResponse match;

  @override
  Widget build(BuildContext context) {
    final winning = match.winningTeam;
    final team1 = match.playersOnTeam(1).toList();
    final team2 = match.playersOnTeam(2).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0x0D000000),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  match.courtNumber == null
                      ? 'COURT —'
                      : 'COURT ${match.courtNumber}',
                  style: PaddleText.display(
                    size: 10,
                    color: PaddleColors.inkSoft,
                    height: 1,
                  ).copyWith(letterSpacing: 1),
                ),
              ),
              // const SizedBox(width: 8),
              // if (match.completedAt != null)
              //   Text(
              //     _relativeTime(match.completedAt!),
              //     style: PaddleText.body(
              //       size: 11,
              //       color: PaddleColors.inkFaint,
              //       height: 1,
              //     ),
              //   ),
            ],
          ),
          const SizedBox(height: 8),
          Stack(
            alignment: Alignment.center,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: _TeamBlock(
                      label: 'TEAM 1',
                      members: team1,
                      isWinner: winning == 1,
                    ),
                  ),
                  Expanded(
                    child: _TeamBlock(
                      label: 'TEAM 2',
                      members: team2,
                      isWinner: winning == 2,
                    ),
                  ),
                ],
              ),
            ],
          )
        ],
      ),
    );
  }
}

class _TeamBlock extends StatelessWidget {
  const _TeamBlock({
    required this.label,
    required this.members,
    required this.isWinner,
  });

  final String label;
  final List<MatchPlayerInfo> members;
  final bool isWinner;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isWinner ? 1 : 0.55,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (isWinner)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: PaddleIcon.trophy(
                    color: PaddleColors.paddleGreen,
                    size: 12,
                  ),
                ),
              Text(
                label,
                style: PaddleText.body(
                  size: 10,
                  weight: FontWeight.w900,
                  color: isWinner
                      ? PaddleColors.paddleGreenDark
                      : PaddleColors.inkSoft,
                  height: 1,
                ).copyWith(letterSpacing: 0.8),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final p in members) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Avatar(name: p.playerName, size: 22, tinted: true),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      p.playerName,
                      style: PaddleText.body(
                        size: 12,
                        weight: FontWeight.w700,
                        height: 1.1,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _relativeTime(DateTime utc) {
  final diff = DateTime.now().toUtc().difference(utc.toUtc());
  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) {
    final m = diff.inMinutes;
    return '${m}m ago';
  }
  if (diff.inHours < 24) {
    final h = diff.inHours;
    return '${h}h ago';
  }
  final d = diff.inDays;
  return '${d}d ago';
}

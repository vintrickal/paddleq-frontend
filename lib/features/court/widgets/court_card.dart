import 'package:flutter/material.dart';
import 'package:paddleq/core/models/match_dtos.dart';
import 'package:paddleq/core/theme/paddle_colors.dart';
import 'package:paddleq/core/theme/paddle_text.dart';
import 'package:paddleq/core/widgets/paddle_icons.dart';
import 'package:paddleq/features/court/widgets/avatar.dart';
import 'package:paddleq/features/court/widgets/court_name_label.dart';

/// Active match panel for one court: TEAM 1 vs TEAM 2 + winner buttons.
/// Empty state: "QUEUE PLAYERS" CTA.
///
/// Team grouping comes straight from the [MatchResponse.players] payload
/// returned by `POST /api/matches/next` (each [MatchPlayerInfo] has a
/// `team` of 1 or 2). The backend's matchmaker assigns teams (e.g.
/// highest+lowest skill on team 1, middle two on team 2 for mixed-skill
/// doubles), so we render exactly what the server picked rather than
/// re-splitting a flat player list ourselves.
class CourtCard extends StatelessWidget {
  const CourtCard({
    super.key,
    required this.idx,
    required this.match,
    required this.onWinner,
    required this.onQueue,
  });

  final int idx;

  /// Currently in-progress match on this court, or null if the court is
  /// empty (no match formed yet).
  final MatchResponse? match;
  final ValueChanged<int> onWinner;
  final VoidCallback onQueue;

  @override
  Widget build(BuildContext context) {
    final m = match;
    if (m == null) return _EmptyCourt(idx: idx, onQueue: onQueue);

    final team1 = m.playersOnTeam(1).toList();
    final team2 = m.playersOnTeam(2).toList();

    return Container(
      decoration: BoxDecoration(
        color: PaddleColors.tile,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: PaddleColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CourtHead(idx: idx, startedAt: m.startedAt),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _Team(label: 'TEAM 1', members: team1)),
                  Container(
                    width: 24,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      border: Border(left: BorderSide(color: PaddleColors.line)),
                    ),
                    child: Text(
                      'VS',
                      style: PaddleText.display(size: 12, color: PaddleColors.inkFaint, height: 1),
                    ),
                  ),
                  Expanded(child: _Team(label: 'TEAM 2', members: team2)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: PaddleColors.line)),
            ),
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(child: _WinnerButton(team: 1, onTap: () => onWinner(1))),
                const SizedBox(width: 8),
                Expanded(child: _WinnerButton(team: 2, onTap: () => onWinner(2))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CourtHead extends StatelessWidget {
  const _CourtHead({required this.idx, required this.startedAt});
  final int idx;
  final DateTime? startedAt;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: PaddleColors.line)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Row(
        children: [
          Flexible(
            child: CourtNameLabel(
              idx: idx,
              fontSize: 18,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: PaddleColors.paddleGreenSoft,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _PulsingDot(),
                const SizedBox(width: 6),
                Text(
                  'LIVE',
                  style: PaddleText.body(
                    size: 11,
                    color: PaddleColors.paddleGreenDark,
                    weight: FontWeight.w700,
                  ).copyWith(letterSpacing: 11 * 0.08),
                ),
              ],
            ),
          ),
          const Spacer(),
          // MatchClock(startedAt: startedAt),
        ],
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = Curves.easeInOut.transform(_ctrl.value);
        return Transform.scale(
          scale: 1 + 0.4 * t,
          child: Opacity(
            opacity: 1 - 0.5 * t,
            child: Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: PaddleColors.paddleGreen,
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Team extends StatelessWidget {
  const _Team({required this.label, required this.members});
  final String label;
  final List<MatchPlayerInfo> members;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: PaddleText.body(
              size: 12,
              weight: FontWeight.w900,
              color: PaddleColors.inkSoft,
            ).copyWith(letterSpacing: 12 * 0.10),
          ),
          const SizedBox(height: 8),
          for (final p in members) ...[
            _Member(player: p),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _Member extends StatelessWidget {
  const _Member({required this.player});
  final MatchPlayerInfo player;
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Avatar(name: player.playerName, size: 28, tinted: true),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                player.playerName,
                style: PaddleText.body(size: 14, weight: FontWeight.w600, height: 1.2),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                '(${player.skillLevel.toStringAsFixed(1)})',
                style: PaddleText.body(
                  size: 11,
                  color: PaddleColors.inkFaint,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WinnerButton extends StatelessWidget {
  const _WinnerButton({required this.team, required this.onTap});
  final int team;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(12);
    return Material(
      color: const Color(0xFF647491),
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: SizedBox(
          height: 48,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const PaddleIcon.trophy(color: Colors.white),
              const SizedBox(width: 8),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'WINNER',
                    style: PaddleText.body(
                      size: 9,
                      color: Colors.white,
                      weight: FontWeight.w700,
                      height: 1,
                    ).copyWith(letterSpacing: 9 * 0.10),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'TEAM $team',
                    style: PaddleText.display(size: 14, color: Colors.white, height: 1),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyCourt extends StatelessWidget {
  const _EmptyCourt({required this.idx, required this.onQueue});
  final int idx;
  final VoidCallback onQueue;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: PaddleColors.tile,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: PaddleColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: PaddleColors.line)),
            ),
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: Row(
              children: [
                Flexible(child: CourtNameLabel(idx: idx, fontSize: 18)),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0x0A000000),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'EMPTY',
                    style: PaddleText.body(
                      size: 11,
                      color: PaddleColors.inkSoft,
                      weight: FontWeight.w700,
                    ).copyWith(letterSpacing: 11 * 0.08),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 28, 18, 20),
            child: Column(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0x0A000000),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const PaddleIcon.user(color: PaddleColors.inkSoft),
                ),
                const SizedBox(height: 10),
                Text(
                  'No active match.\nAdd 4 players to start the next round.',
                  textAlign: TextAlign.center,
                  style: PaddleText.body(size: 13, color: PaddleColors.inkSoft, height: 1.5),
                ),
                const SizedBox(height: 14),
                _QueueCta(onTap: onQueue),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QueueCta extends StatefulWidget {
  const _QueueCta({required this.onTap});
  final VoidCallback onTap;
  @override
  State<_QueueCta> createState() => _QueueCtaState();
}

class _QueueCtaState extends State<_QueueCta> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(12);
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        transform: Matrix4.translationValues(0, _pressed ? 2 : 0, 0),
        height: 52,
        width: double.infinity,
        decoration: BoxDecoration(
          color: PaddleColors.paddleGreen,
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: PaddleColors.paddleGreenDark,
              offset: Offset(0, _pressed ? 2 : 4),
              blurRadius: 0,
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          'QUEUE PLAYERS',
          style: PaddleText.display(size: 14, color: Colors.white, height: 1)
              .copyWith(letterSpacing: 14 * 0.04),
        ),
      ),
    );
  }
}

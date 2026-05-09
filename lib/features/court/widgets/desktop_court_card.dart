import 'package:flutter/material.dart';
import 'package:paddleq/core/models/match_dtos.dart';
import 'package:paddleq/core/theme/paddle_colors.dart';
import 'package:paddleq/core/theme/paddle_text.dart';
import 'package:paddleq/core/widgets/paddle_icons.dart';
import 'package:paddleq/features/court/widgets/avatar.dart';
import 'package:paddleq/features/court/widgets/court_name_label.dart';

/// iPad/desktop variant of the court card used inside the multi-court grid.
///
/// Differs from the mobile [CourtCard] in:
///  * tighter padding (14×16) and 18px radius
///  * status pill is filled green with a pulsing inner dot (vs soft-green)
///  * teams sit in soft-green tinted boxes with their own border
///  * winner buttons use the **green** primary action (vs gray on mobile)
///  * dashed border on the empty state
///
/// Team grouping uses the `team` indicator on each [MatchPlayerInfo]
/// returned by `POST /api/matches/next` — same as the mobile card — so
/// matchmaker decisions (high+low vs middle two for mixed-skill, random
/// for all-equal) are reflected directly in the UI.
class DesktopCourtCard extends StatelessWidget {
  const DesktopCourtCard({
    super.key,
    required this.idx,
    required this.match,
    required this.onWinner,
    required this.onQueue,
  });

  final int idx;

  /// Currently in-progress match on this court, or null when empty.
  final MatchResponse? match;
  final ValueChanged<int> onWinner;
  final VoidCallback onQueue;

  @override
  Widget build(BuildContext context) {
    final m = match;
    if (m == null) return _EmptyDesktopCourt(idx: idx, onQueue: onQueue);

    final team1 = m.playersOnTeam(1).toList();
    final team2 = m.playersOnTeam(2).toList();

    return Container(
      decoration: BoxDecoration(
        color: PaddleColors.tile,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: PaddleColors.line),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _DesktopCourtHead(idx: idx, startedAt: m.startedAt),
          const SizedBox(height: 10),
          _DesktopMatch(team1: team1, team2: team2),
          const SizedBox(height: 10),
          _DesktopActions(onWinner: onWinner),
        ],
      ),
    );
  }
}

class _DesktopCourtHead extends StatelessWidget {
  const _DesktopCourtHead({required this.idx, required this.startedAt});
  final int idx;
  final DateTime? startedAt;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(
          child: CourtNameLabel(
            idx: idx,
            fontSize: 14,
            tracking: 0.5,
          ),
        ),
        const SizedBox(width: 10),
        const _LivePill(),
        const Spacer(),
        // MatchClock(startedAt: startedAt),
      ],
    );
  }
}

class _LivePill extends StatefulWidget {
  const _LivePill();
  @override
  State<_LivePill> createState() => _LivePillState();
}

class _LivePillState extends State<_LivePill> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: PaddleColors.paddleGreen,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) => Opacity(
              opacity: 1 - 0.65 * Curves.easeInOut.transform(_ctrl.value),
              child: Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'LIVE',
            style: PaddleText.display(size: 9, color: Colors.white, height: 1)
                .copyWith(letterSpacing: 1.4),
          ),
        ],
      ),
    );
  }
}

class _DesktopMatch extends StatelessWidget {
  const _DesktopMatch({required this.team1, required this.team2});
  final List<MatchPlayerInfo> team1;
  final List<MatchPlayerInfo> team2;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _TeamBox(label: 'TEAM 1', members: team1)),
          const SizedBox(width: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Center(
              child: Text(
                'VS',
                style: PaddleText.display(
                  size: 14,
                  color: PaddleColors.inkFaint,
                  height: 1,
                ).copyWith(letterSpacing: 1),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: _TeamBox(label: 'TEAM 2', members: team2)),
        ],
      ),
    );
  }
}

class _TeamBox extends StatelessWidget {
  const _TeamBox({required this.label, required this.members});
  final String label;
  final List<MatchPlayerInfo> members;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0x0A2D7749),
        border: Border.all(color: PaddleColors.line),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: PaddleText.display(
              size: 10,
              color: PaddleColors.paddleGreen,
              height: 1,
            ).copyWith(letterSpacing: 1.4),
          ),
          const SizedBox(height: 8),
          for (final p in members) ...[
            _TeamMember(player: p),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _TeamMember extends StatelessWidget {
  const _TeamMember({required this.player});
  final MatchPlayerInfo player;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Avatar(name: player.playerName, size: 36, tinted: true),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                player.playerName,
                style: PaddleText.body(size: 14, weight: FontWeight.w700, height: 1.1),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                '(${player.skillLevel.toStringAsFixed(1)})',
                style: PaddleText.body(size: 11, color: PaddleColors.inkSoft),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DesktopActions extends StatelessWidget {
  const _DesktopActions({required this.onWinner});
  final ValueChanged<int> onWinner;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _GreenWinnerBtn(team: 1, onTap: () => onWinner(1))),
        const SizedBox(width: 8),
        Expanded(child: _GreenWinnerBtn(team: 2, onTap: () => onWinner(2))),
      ],
    );
  }
}

class _GreenWinnerBtn extends StatelessWidget {
  const _GreenWinnerBtn({required this.team, required this.onTap});
  final int team;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(12);
    return Material(
      color: PaddleColors.paddleGreen,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        hoverColor: PaddleColors.paddleGreenDark,
        child: SizedBox(
          height: 44,
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
                    'Winner',
                    style: PaddleText.body(
                      size: 9,
                      color: Colors.white.withValues(alpha: 0.78),
                      weight: FontWeight.w700,
                      height: 1,
                    ).copyWith(letterSpacing: 0.8),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'TEAM $team',
                    style: PaddleText.display(size: 12, color: Colors.white, height: 1),
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

class _EmptyDesktopCourt extends StatelessWidget {
  const _EmptyDesktopCourt({required this.idx, required this.onQueue});
  final int idx;
  final VoidCallback onQueue;

  @override
  Widget build(BuildContext context) {
    return _DashedBox(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Flexible(
                  child: CourtNameLabel(
                    idx: idx,
                    fontSize: 14,
                    tracking: 0.5,
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0x14000000),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    'EMPTY',
                    style: PaddleText.display(
                      size: 9,
                      color: PaddleColors.inkSoft,
                      height: 1,
                    ).copyWith(letterSpacing: 1.4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: Color(0x0D000000),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const PaddleIcon.user(color: PaddleColors.inkSoft),
            ),
            const SizedBox(height: 10),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 220),
                child: Text(
                  'No active match.\nQueue 4 waiting players to start.',
                  textAlign: TextAlign.center,
                  style: PaddleText.body(size: 13, color: PaddleColors.inkSoft, height: 1.45),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(child: _QueueOutlineCta(onTap: onQueue)),
          ],
        ),
      ),
    );
  }
}

class _QueueOutlineCta extends StatefulWidget {
  const _QueueOutlineCta({required this.onTap});
  final VoidCallback onTap;
  @override
  State<_QueueOutlineCta> createState() => _QueueOutlineCtaState();
}

class _QueueOutlineCtaState extends State<_QueueOutlineCta> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(99);
    final bg = _hover ? PaddleColors.paddleGreen : PaddleColors.tile;
    final fg = _hover ? Colors.white : PaddleColors.paddleGreen;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(color: PaddleColors.paddleGreen, width: 1.5),
            borderRadius: radius,
          ),
          child: Text(
            'QUEUE PLAYERS',
            style: PaddleText.display(size: 11, color: fg, height: 1)
                .copyWith(letterSpacing: 1),
          ),
        ),
      ),
    );
  }
}

/// Dashed-border container for the empty desktop court state. Implemented via
/// CustomPaint since Flutter doesn't ship a dashed BoxBorder.
class _DashedBox extends StatelessWidget {
  const _DashedBox({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: const _DashedBorderPainter(
        color: PaddleColors.line,
        radius: 18,
        dashLength: 6,
        dashGap: 4,
        strokeWidth: 1,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: ColoredBox(
          color: const Color(0xFFFAF9F5),
          child: child,
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({
    required this.color,
    required this.radius,
    required this.dashLength,
    required this.dashGap,
    required this.strokeWidth,
  });
  final Color color;
  final double radius;
  final double dashLength;
  final double dashGap;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final fullPath = Path()..addRRect(rrect);
    final metrics = fullPath.computeMetrics();
    final out = Path();
    for (final m in metrics) {
      var distance = 0.0;
      while (distance < m.length) {
        final next = (distance + dashLength).clamp(0, m.length).toDouble();
        out.addPath(m.extractPath(distance, next), Offset.zero);
        distance = next + dashGap;
      }
    }
    canvas.drawPath(out, paint);
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter old) =>
      old.color != color ||
      old.radius != radius ||
      old.dashLength != dashLength ||
      old.dashGap != dashGap ||
      old.strokeWidth != strokeWidth;
}

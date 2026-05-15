import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:paddleq/core/storage/past_sessions_store.dart';
import 'package:paddleq/core/theme/paddle_colors.dart';
import 'package:paddleq/core/theme/paddle_text.dart';
import 'package:paddleq/core/widgets/paddle_icons.dart';
import 'package:paddleq/features/home/cubit/past_sessions_cubit.dart';
import 'package:paddleq/features/home/widgets/past_session_dialog.dart';

/// "Past sessions" section rendered on Home below the setup form.
///
/// Subscribes to [PastSessionsCubit] (which loads from `localStorage` on
/// app start) and renders one tappable row per saved session. Tapping a
/// row opens [showPastSessionDialog] with the cached final leaderboard.
///
/// Empty state explains that nothing's been recorded yet, so the host
/// isn't confused on a fresh install.
class PastSessionsSection extends StatelessWidget {
  const PastSessionsSection({super.key, this.maxItems = 5});

  /// Max rows to render inline. The user can scroll on mobile, but past
  /// sessions can grow unbounded (cap at 50 in the store). Surfacing 5
  /// here keeps the home page from getting visually dominated by history.
  final int maxItems;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PastSessionsCubit, List<PastSession>>(
      builder: (context, sessions) {
        final visible = sessions.take(maxItems).toList(growable: false);
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
              _Header(count: sessions.length),
              if (sessions.isEmpty)
                const _EmptyState()
              else
                for (var i = 0; i < visible.length; i++) ...[
                  if (i > 0)
                    const Divider(height: 1, color: PaddleColors.line),
                  _Row(session: visible[i]),
                ],
            ],
          ),
        );
      },
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
          Text('Past sessions',
              style: PaddleText.display(size: 16, height: 1)),
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
        'Nothing recorded yet. After you end a session, its final '
        'leaderboard will appear here.',
        style: PaddleText.body(
          size: 12,
          color: PaddleColors.inkFaint,
          height: 1.4,
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.session});
  final PastSession session;

  @override
  Widget build(BuildContext context) {
    final name = session.name.trim().isEmpty
        ? 'Untitled session'
        : session.name.trim();
    final winner = session.leaderboard.isEmpty
        ? null
        : session.leaderboard.first;

    return InkWell(
      onTap: () => showPastSessionDialog(context, session),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    style: PaddleText.body(
                      size: 14,
                      weight: FontWeight.w700,
                      height: 1.2,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${session.matchType} · ${session.numberOfCourts} '
                    '${session.numberOfCourts == 1 ? "court" : "courts"} · '
                    '${_relativeTime(session.endedAt)}',
                    style: PaddleText.body(
                      size: 11,
                      color: PaddleColors.inkSoft,
                      weight: FontWeight.w700,
                      height: 1.2,
                    ).copyWith(letterSpacing: 0.4),
                  ),
                  if (winner != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        PaddleIcon.trophy(
                          color: PaddleColors.paddleGreen,
                          size: 11,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '${winner.playerName} · ${winner.wins}W / '
                            '${winner.losses}L',
                            style: PaddleText.body(
                              size: 11,
                              color: PaddleColors.paddleGreenDark,
                              weight: FontWeight.w700,
                              height: 1.2,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            const PaddleIcon.chevronRight(
              color: PaddleColors.inkFaint,
              size: 12,
            ),
          ],
        ),
      ),
    );
  }
}

String _relativeTime(DateTime utc) {
  final diff = DateTime.now().toUtc().difference(utc.toUtc());
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 30) return '${diff.inDays}d ago';
  final months = diff.inDays ~/ 30;
  return months <= 1 ? 'a month ago' : '$months months ago';
}

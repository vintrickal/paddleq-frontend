import 'package:flutter/material.dart';
import 'package:paddleq/core/storage/past_sessions_store.dart';
import 'package:paddleq/core/theme/paddle_colors.dart';
import 'package:paddleq/core/theme/paddle_text.dart';
import 'package:paddleq/features/court/widgets/leaderboard_section.dart';

/// Centered modal showing a single past session's final leaderboard.
/// Opened from the "Past sessions" list on Home.
Future<void> showPastSessionDialog(BuildContext context, PastSession session) {
  return showDialog<void>(
    context: context,
    barrierColor: const Color(0x66000000),
    builder: (_) => _PastSessionDialog(session: session),
  );
}

class _PastSessionDialog extends StatelessWidget {
  const _PastSessionDialog({required this.session});
  final PastSession session;

  @override
  Widget build(BuildContext context) {
    final name = session.name.trim().isEmpty
        ? 'Untitled session'
        : session.name.trim();
    return Dialog(
      backgroundColor: PaddleColors.tile,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  name,
                  style: PaddleText.display(size: 18, height: 1.1),
                ),
                const SizedBox(height: 4),
                Text(
                  '${session.matchType} · ${session.numberOfCourts} '
                  '${session.numberOfCourts == 1 ? "court" : "courts"} · '
                  'finished ${_relativeTime(session.endedAt)}',
                  style: PaddleText.body(
                    size: 12,
                    color: PaddleColors.inkFaint,
                    weight: FontWeight.w700,
                  ).copyWith(letterSpacing: 0.4),
                ),
                const SizedBox(height: 16),
                LeaderboardSection(entries: session.leaderboard),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Close',
                      style: PaddleText.display(
                          size: 14, color: PaddleColors.inkSoft, height: 1),
                    ),
                  ),
                ),
              ],
            ),
          ),
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

import 'package:flutter/material.dart';
import 'package:paddleq/core/storage/past_sessions_store.dart';
import 'package:paddleq/core/theme/paddle_colors.dart';
import 'package:paddleq/core/theme/paddle_text.dart';
import 'package:paddleq/features/court/widgets/leaderboard_section.dart';
import 'package:paddleq/features/home/view/home_page.dart';

/// Shown right after the host ends a session. Displays the final ranking
/// for that session and a single CTA back to Home.
///
/// The leaderboard comes from a [PastSession] snapshot captured at
/// end-time and recorded in [PastSessionsStore] — the backend's
/// leaderboard endpoint only returns the **active** session, so we can't
/// re-fetch it after the session has closed.
class LeaderboardPage extends StatelessWidget {
  const LeaderboardPage({super.key, required this.session});

  final PastSession session;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PaddleColors.paper,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Header(session: session),
                  const SizedBox(height: 22),
                  LeaderboardSection(entries: session.leaderboard),
                  const SizedBox(height: 24),
                  _BackHomeButton(
                    onPressed: () => _goHome(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _goHome(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomePage()),
      (route) => false,
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.session});
  final PastSession session;

  @override
  Widget build(BuildContext context) {
    final name = session.name.trim().isEmpty
        ? 'Untitled session'
        : session.name.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'SESSION FINISHED',
          style: PaddleText.label(
            size: 12,
            tracking: 0.18,
            weight: FontWeight.w900,
            color: PaddleColors.paddleGreenDark,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Final standings',
          textAlign: TextAlign.center,
          style: PaddleText.display(size: 28, height: 1.05),
        ),
        const SizedBox(height: 6),
        Text(
          name,
          textAlign: TextAlign.center,
          style: PaddleText.script(size: 18, color: PaddleColors.inkSoft),
        ),
        const SizedBox(height: 4),
        Text(
          '${session.matchType} · ${session.numberOfCourts} ${session.numberOfCourts == 1 ? "court" : "courts"} · '
          '${_durationLabel(session.startedAt, session.endedAt)}',
          textAlign: TextAlign.center,
          style: PaddleText.body(
            size: 12,
            color: PaddleColors.inkFaint,
            weight: FontWeight.w700,
          ).copyWith(letterSpacing: 0.5),
        ),
      ],
    );
  }

  static String _durationLabel(DateTime start, DateTime end) {
    final mins = end.difference(start).inMinutes;
    if (mins < 60) return '${mins}m';
    final h = mins ~/ 60;
    final m = mins % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }
}

class _BackHomeButton extends StatelessWidget {
  const _BackHomeButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: PaddleColors.paddleGreen,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: onPressed,
        child: Text(
          'Back to home',
          style: PaddleText.display(size: 16, color: Colors.white, height: 1)
              .copyWith(letterSpacing: 0.5),
        ),
      ),
    );
  }
}

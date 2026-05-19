import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:paddleq/core/api/api_exception.dart';
import 'package:paddleq/core/api/paddleq_api.dart';
import 'package:paddleq/core/models/session_dtos.dart';
import 'package:paddleq/core/theme/paddle_colors.dart';
import 'package:paddleq/features/court/view/court_page.dart';
import 'package:paddleq/features/home/view/home_page.dart';
import 'package:paddleq/features/welcome/view/welcome_animation_view.dart';

/// Splash / welcome animation mapped from `Welcome.html`.
///
/// The visual layers (rings, net, confetti, wordmark, sub, pulse bar) and
/// timing are owned by [WelcomeAnimationView]; this page just runs the
/// active-session probe in parallel and decides where to route once the
/// animation completes.
///
/// Refreshing the browser drops the host straight back into their session
/// instead of leaving them stuck on Home (where Setup court would 409).
class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  late final Future<SessionResponse?> _activeSessionFuture;
  bool _routed = false;

  @override
  void initState() {
    super.initState();
    // Run the active-session probe in parallel with the splash so the
    // answer is ready (or close to it) by the time the animation completes.
    _activeSessionFuture = _resolveActiveSession();
  }

  /// Returns the active session if there is one, `null` for a 404 (no
  /// session) and any other failure (network down, server error, etc.).
  /// Errors during a splash screen would be jarring — silently fall back
  /// to the normal Home flow instead.
  Future<SessionResponse?> _resolveActiveSession() async {
    try {
      return await context.read<PaddleqApi>().getActiveSession();
    } on ApiException {
      return null;
    }
  }

  Future<void> _route() async {
    if (_routed) return;
    _routed = true;
    if (!mounted) return;

    // Cap the wait so SKIP isn't blocked by a slow API. Worst case the
    // user lands on Home and tries again — better than staring at a
    // frozen splash for 30 s.
    final session = await _activeSessionFuture.timeout(
      const Duration(seconds: 2),
      onTimeout: () => null,
    );
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => session != null
            ? CourtPage(session: session)
            : const HomePage(),
        transitionDuration: const Duration(milliseconds: 280),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PaddleColors.paper,
      body: WelcomeAnimationView(
        onComplete: _route,
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:paddleq/core/api/api_exception.dart';
import 'package:paddleq/core/api/paddleq_api.dart';
import 'package:paddleq/core/models/session_dtos.dart';
import 'package:paddleq/core/theme/paddle_colors.dart';
import 'package:paddleq/core/theme/paddle_text.dart';
import 'package:paddleq/core/widgets/api_error_dialog.dart';
import 'package:paddleq/core/widgets/paddle_icons.dart';
import 'package:paddleq/core/widgets/phone_frame.dart';
import 'package:paddleq/features/court/view/court_page.dart';
import 'package:paddleq/features/home/cubit/home_cubit.dart';
import 'package:paddleq/features/home/widgets/courts_counter.dart';
import 'package:paddleq/features/home/widgets/highlight_text.dart';
import 'package:paddleq/features/home/widgets/mode_tile.dart';
import 'package:paddleq/features/home/widgets/session_name_field.dart';
import 'package:paddleq/features/home/widgets/past_sessions_section.dart';
import 'package:paddleq/features/home/widgets/setup_cta.dart';
import 'package:paddleq/features/home/widgets/step_label.dart';
import 'package:paddleq/features/home/widgets/summary_tiles.dart';
import 'package:paddleq/features/loading/view/loading_page.dart';

const double _desktopBreakpoint = 768;

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => HomeCubit(),
      child: const _HomeScaffold(),
    );
  }
}

class _HomeScaffold extends StatelessWidget {
  const _HomeScaffold();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final isDesktop = constraints.maxWidth >= _desktopBreakpoint;

      final body = isDesktop ? const _DesktopHome() : const _MobileHome();

      return Scaffold(
        backgroundColor: PaddleColors.paper,
        body: isDesktop ? body : PhoneFrame(child: body),
      );
    });
  }
}

/// Push the LoadingPage, fire `POST /api/sessions` in parallel, and replace
/// LoadingPage with CourtPage once both the animation and the API call
/// have completed.
///
/// On API failure (network down, 409 active session, etc.) the loading
/// screen is popped and the backend's `message` is surfaced in a dialog.
Future<void> _startSetupFlow(BuildContext context, HomeState state) async {
  final navigator = Navigator.of(context);
  final api = context.read<PaddleqApi>();

  final animationDone = Completer<void>();

  unawaited(
    navigator.push(
      PageRouteBuilder<void>(
        pageBuilder: (_, __, ___) => LoadingPage(
          onComplete: () {
            if (!animationDone.isCompleted) animationDone.complete();
          },
        ),
        transitionDuration: const Duration(milliseconds: 220),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    ),
  );

  final trimmedName = state.sessionName.trim();
  final request = CreateSessionRequest(
    name: trimmedName.isEmpty ? null : trimmedName,
    matchType: state.mode.label,
    numberOfCourts: state.courts,
  );

  try {
    final results = await Future.wait<Object?>([
      api.startSession(request),
      animationDone.future,
    ]);
    final session = results[0]! as SessionResponse;
    if (!context.mounted) return;
    navigator.pushReplacement(
      MaterialPageRoute(builder: (_) => CourtPage(session: session)),
    );
  } on ApiException catch (e) {
    if (!context.mounted) return;
    if (navigator.canPop()) navigator.pop();
    if (!context.mounted) return;
    await showApiErrorDialog(context, e, title: "Couldn't start session");
  }
}

// ---------------------------------------------------------------------------
// MOBILE
// ---------------------------------------------------------------------------

class _MobileHome extends StatelessWidget {
  const _MobileHome();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeCubit, HomeState>(
      builder: (context, state) {
        final cubit = context.read<HomeCubit>();
        return Column(
          children: [
            const _MobileTopBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _Hero(variant: HeroVariant.mobile),
                    SessionNameField(
                      value: state.sessionName,
                      onChanged: cubit.setSessionName,
                    ),
                    const SizedBox(height: 18),
                    const StepLabel(step: 1, text: 'Choose format'),
                    Row(
                      children: [
                        Expanded(
                          child: ModeTile(
                            title: 'Singles',
                            subtitle: '2 players / court',
                            assetPath: 'assets/images/singles.png',
                            selected: state.mode == GameMode.singles,
                            onTap: () => cubit.selectMode(GameMode.singles),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ModeTile(
                            title: 'Doubles',
                            subtitle: '4 players / court',
                            assetPath: 'assets/images/doubles.png',
                            selected: state.mode == GameMode.doubles,
                            onTap: () => cubit.selectMode(GameMode.doubles),
                          ),
                        ),
                      ],
                    ),
                    const StepLabel(step: 2, text: 'How many courts?'),
                    _CounterCard(state: state),
                    const SizedBox(height: 12),
                    SummaryTiles(
                      courts: state.courts,
                      perCourt: state.playersPerCourt,
                      totalPlayers: state.totalPlayers,
                    ),
                    if (state.showRecent) ...[
                      const StepLabel(step: 3, text: 'Or jump back in'),
                      _RecentSession(onTap: () => _startSetupFlow(context, state)),
                    ],
                    const SizedBox(height: 22),
                    const PastSessionsSection(),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
              child: SetupCta(
                label: 'Setup court',
                onPressed: () => _startSetupFlow(context, state),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MobileTopBar extends StatelessWidget {
  const _MobileTopBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 10),
      child: Row(
        children: [
          Image.asset('assets/images/logo.png', width: 30, height: 26, fit: BoxFit.contain),
          const SizedBox(width: 8),
          Text('PADDLEQ', style: PaddleText.wordmark(size: 20)),
          const Spacer(),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: PaddleColors.tile,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: PaddleColors.line),
            ),
            child: const Center(child: PaddleIcon.settings(color: PaddleColors.ink)),
          ),
        ],
      ),
    );
  }
}

enum HeroVariant { mobile, desktop }

class _Hero extends StatelessWidget {
  const _Hero({required this.variant});
  final HeroVariant variant;

  @override
  Widget build(BuildContext context) {
    if (variant == HeroVariant.desktop) return const _DesktopHero();
    return _MobileHero();
  }
}

class _MobileHero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final titleStyle = PaddleText.display(size: 30, height: 1.05);
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'good morning ✦',
            style: PaddleText.script(size: 16, color: PaddleColors.inkSoft),
          ),
          const SizedBox(height: 4),
          // Two-line headline: "Set up your <court>" / "and play."
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              Text('Set up your ', style: titleStyle),
              HighlightText(text: 'court', style: titleStyle, barOpacity: 0.10, barHeight: 7),
            ],
          ),
          Text('and play.', style: titleStyle),
          const SizedBox(height: 10),
          Text(
            "Pick a format, set how many courts you've got, and PaddleQ keeps the rotation going.",
            style: PaddleText.body(size: 13, color: PaddleColors.inkSoft, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _CounterCard extends StatelessWidget {
  const _CounterCard({required this.state});
  final HomeState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<HomeCubit>();
    return Container(
      decoration: BoxDecoration(
        color: PaddleColors.tile,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PaddleColors.line),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'COURTS',
                  style: PaddleText.label(
                    size: 11,
                    tracking: 0.10,
                    color: PaddleColors.ink,
                    weight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '1 — ${state.maxCourts}',
                  style: PaddleText.body(
                    size: 10,
                    color: PaddleColors.inkFaint,
                    weight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          CourtsCounter(
            value: state.courts,
            maxValue: state.maxCourts,
            onIncrement: cubit.increment,
            onDecrement: cubit.decrement,
            bumping: state.bumping,
          ),
        ],
      ),
    );
  }
}

class _RecentSession extends StatelessWidget {
  const _RecentSession({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(14);
    return Material(
      color: PaddleColors.tile,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: PaddleColors.line),
            borderRadius: radius,
          ),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: PaddleColors.paddleGreenSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: const PaddleIcon.refresh(color: PaddleColors.paddleGreenDark),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Doubles · 4 courts',
                      style: PaddleText.body(size: 13, weight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Last session · 8 players queued',
                      style: PaddleText.body(size: 11, color: PaddleColors.inkSoft, height: 1.3),
                    ),
                  ],
                ),
              ),
              const PaddleIcon.chevronRight(color: PaddleColors.inkFaint, size: 12),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// DESKTOP
// ---------------------------------------------------------------------------

class _DesktopHome extends StatelessWidget {
  const _DesktopHome();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _DesktopHeader(),
        Expanded(
          child: SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(40, 56, 40, 80),
                  child: BlocBuilder<HomeCubit, HomeState>(
                    builder: (context, state) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _DesktopHero(),
                          const SizedBox(height: 56),
                          Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 720),
                              child: _DesktopCard(state: state),
                            ),
                          ),
                          const SizedBox(height: 28),
                          Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 720),
                              child: SummaryTiles(
                                courts: state.courts,
                                perCourt: state.playersPerCourt,
                                totalPlayers: state.totalPlayers,
                                variant: SummaryVariant.desktop,
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                          Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 720),
                              child: const PastSessionsSection(),
                            ),
                          ),
                          const SizedBox(height: 40),
                          Center(
                            child: Text.rich(
                              TextSpan(
                                style: PaddleText.body(size: 13, color: PaddleColors.inkSoft),
                                children: [
                                  TextSpan(
                                    text: 'tip  ',
                                    style: PaddleText.script(size: 18, color: PaddleColors.ink),
                                  ),
                                  const TextSpan(text: 'press the button to set up your court'),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DesktopHeader extends StatelessWidget {
  const _DesktopHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(40, 22, 40, 22),
      decoration: const BoxDecoration(
        color: PaddleColors.paperLight,
        border: Border(bottom: BorderSide(color: Color(0x0F000000))),
      ),
      child: Row(
        children: [
          Image.asset('assets/images/logo.png', width: 64, height: 56, fit: BoxFit.contain),
          const SizedBox(width: 18),
          Text('PADDLEQ', style: PaddleText.wordmark(size: 40)),
        ],
      ),
    );
  }
}

class _NavLink extends StatelessWidget {
  const _NavLink({required this.label, this.active = false});
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Container(
        padding: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? PaddleColors.paddleGreen : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label.toUpperCase(),
          style: PaddleText.body(
            size: 13,
            color: active ? PaddleColors.ink : PaddleColors.inkSoft,
            weight: FontWeight.w600,
          ).copyWith(letterSpacing: 13 * 0.04),
        ),
      ),
    );
  }
}

class _DesktopHero extends StatelessWidget {
  const _DesktopHero();

  @override
  Widget build(BuildContext context) {
    final titleStyle = PaddleText.display(size: 64, height: 1.02);
    return Column(
      children: [
        // Eyebrow pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: PaddleColors.lineMid),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: PaddleColors.paddleGreen,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: PaddleColors.paddleGreen.withValues(alpha: 0.15),
                      blurRadius: 0,
                      spreadRadius: 4,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Pickleball queue · ready when you are'.toUpperCase(),
                style: PaddleText.label(
                  size: 12,
                  tracking: 0.18,
                  weight: FontWeight.w700,
                  color: PaddleColors.inkSoft,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            Text('Set up your ', style: titleStyle),
            HighlightText(text: 'court', style: titleStyle, barOpacity: 0.18, barHeight: 10),
          ],
        ),
        Text('and start playing.', style: titleStyle, textAlign: TextAlign.center),
        const SizedBox(height: 14),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Text(
            "Pick singles or doubles, set how many courts you've got, and PaddleQ takes care of the rotation — no whiteboards, no shouting names across the net.",
            style: PaddleText.body(size: 16, color: PaddleColors.inkSoft, height: 1.55),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

class _DesktopCard extends StatelessWidget {
  const _DesktopCard({required this.state});
  final HomeState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<HomeCubit>();
    return Container(
      decoration: BoxDecoration(
        color: PaddleColors.tile,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: PaddleColors.line),
        boxShadow: const [
          BoxShadow(color: Color(0x0D000000), blurRadius: 30, offset: Offset(0, 12)),
        ],
      ),
      padding: const EdgeInsets.all(36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SessionNameField(
            value: state.sessionName,
            onChanged: cubit.setSessionName,
          ),
          const SizedBox(height: 28),
          const StepLabel(step: 1, text: 'Choose your format', padTop: 0),
          Text('Singles or doubles?',
              style: PaddleText.display(size: 24, height: 1.05)),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: ModeTile(
                  title: 'Singles',
                  subtitle: '2 players per court',
                  assetPath: 'assets/images/singles.png',
                  selected: state.mode == GameMode.singles,
                  onTap: () => cubit.selectMode(GameMode.singles),
                  orientation: Axis.horizontal,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: ModeTile(
                  title: 'Doubles',
                  subtitle: '4 players per court',
                  assetPath: 'assets/images/doubles.png',
                  selected: state.mode == GameMode.doubles,
                  onTap: () => cubit.selectMode(GameMode.doubles),
                  orientation: Axis.horizontal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          const StepLabel(step: 2, text: 'Set up the courts', padTop: 0),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 22, 6, 28),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'NUMBER OF COURTS',
                      style: PaddleText.label(
                        size: 13,
                        tracking: 0.06,
                        weight: FontWeight.w900,
                        color: PaddleColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap +/− to adjust',
                      style: PaddleText.body(size: 12, color: PaddleColors.inkSoft),
                    ),
                  ],
                ),
                CourtsCounter(
                  value: state.courts,
                  maxValue: state.maxCourts,
                  onIncrement: cubit.increment,
                  onDecrement: cubit.decrement,
                  bumping: state.bumping,
                  variant: CounterVariant.desktop,
                ),
              ],
            ),
          ),
          SetupCta(
            label: 'Setup court',
            onPressed: () => _startSetupFlow(context, state),
            height: 72,
            fontSize: 22,
          ),
        ],
      ),
    );
  }
}


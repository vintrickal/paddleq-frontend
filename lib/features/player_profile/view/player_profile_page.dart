import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:paddleq/core/api/paddleq_api.dart';
import 'package:paddleq/core/models/match_dtos.dart';
import 'package:paddleq/core/models/queue_dtos.dart';
import 'package:paddleq/core/models/session_dtos.dart';
import 'package:paddleq/core/theme/paddle_colors.dart';
import 'package:paddleq/core/theme/paddle_text.dart';
import 'package:paddleq/features/player_profile/cubit/player_profile_cubit.dart';
import 'package:paddleq/features/welcome/view/welcome_animation_view.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Public, read-only Player Profile — deep-linked via `/p/<publicId>` and
/// isolated from the host UI tree.
///
/// Implements the `Player Profile.html` web design from the handoff:
/// sticky header, max-1280 stage, hero grid (profile-with-stats card +
/// QR side card), two-column (leaderboard + queue), full-width match
/// history. Single scrollable page — no tabs. Live data via
/// [PlayerProfileCubit] (which already fetches player + queue +
/// leaderboard + history + active matches in parallel).
class PlayerProfilePage extends StatelessWidget {
  const PlayerProfilePage({super.key, required this.publicId});

  final String publicId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<PlayerProfileCubit>(
      create: (ctx) => PlayerProfileCubit(
        api: ctx.read<PaddleqApi>(),
        publicId: publicId,
      )..load(),
      child: const _PlayerProfileScaffold(),
    );
  }
}

// ─── Local colors (mirror the design's CSS vars) ───────────────────────

class _C {
  // The design uses a slightly warmer paper (#FDFDFB) than the host's
  // PaddleColors.paper (#F3F3EF). Likewise softer line / new loss + gold
  // shades. Defined locally so they don't bleed into the host theme.
  static const paper = Color(0xFFFDFDFB);
  static const tile = Color(0xFFFFFFFF);
  static const line = Color(0x1A000000);
  static const lineSoft = Color(0x0F000000);
  static const loss = Color(0xFFA83737);
  static const gold = Color(0xFFC9A227);
  static const inkSoftWeb = Color(0xFF4F4F4F);
}

// ─── Scaffold ──────────────────────────────────────────────────────────

class _PlayerProfileScaffold extends StatefulWidget {
  const _PlayerProfileScaffold();

  @override
  State<_PlayerProfileScaffold> createState() => _PlayerProfileScaffoldState();
}

class _PlayerProfileScaffoldState extends State<_PlayerProfileScaffold> {
  /// Flips true once the [WelcomeAnimationView] intro has played to the
  /// end. The profile content is gated behind this AND the cubit having
  /// finished loading — whichever finishes second decides when we swap
  /// to the loaded view.
  bool _animationDone = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.paper,
      body: BlocBuilder<PlayerProfileCubit, PlayerProfileState>(
        builder: (ctx, state) {
          // Any terminal post-load status counts as "ready" — success,
          // failure, or unavailable (gated by the visibility window). We
          // want the welcome animation to finish in all three cases.
          final dataReady = state.status == PlayerProfileStatus.success ||
              state.status == PlayerProfileStatus.failure ||
              state.status == PlayerProfileStatus.unavailable;

          // Show the welcome animation until the intro has played AND the
          // cubit has finished its initial fetch. Either condition alone
          // isn't enough — we want the full intro beat even when the
          // network is fast, and we want to keep the loader on screen
          // when the network is slow. SKIP is hidden because this is a
          // loading gate, not a true splash — there's nothing to skip to
          // until the data is ready.
          if (!_animationDone || !dataReady) {
            return WelcomeAnimationView(
              showSkip: false,
              onComplete: () {
                if (!mounted || _animationDone) return;
                setState(() => _animationDone = true);
              },
            );
          }

          if (state.status == PlayerProfileStatus.failure) {
            return _ErrorView(
              message: state.error ?? 'Something went wrong.',
              onRetry: () {
                // Replay the loading screen on retry — feels right after
                // an error since the snapshot needs to re-hydrate.
                setState(() => _animationDone = false);
                ctx.read<PlayerProfileCubit>().load();
              },
            );
          }

          if (state.status == PlayerProfileStatus.unavailable) {
            return _UnavailableView(state: state);
          }

          return _Loaded(state: state);
        },
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Player not available',
                textAlign: TextAlign.center,
                style: PaddleText.display(size: 22, height: 1.1),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: PaddleText.body(
                    size: 13, color: PaddleColors.inkSoft, height: 1.4),
              ),
              const SizedBox(height: 18),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: PaddleColors.paddleGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: onRetry,
                child: Text(
                  'Try again',
                  style: PaddleText.display(
                      size: 13, color: Colors.white, height: 1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Unavailable (gated state) ─────────────────────────────────────────

/// Rendered when [PlayerProfileCubit] flags the profile as
/// [PlayerProfileStatus.unavailable]. Two causes:
///   * `noActiveSession` — nothing's running right now (or ever).
///   * `notCheckedIn` — a session is live but the host hasn't scanned
///     this player in yet.
///
/// The copy diverges per cause so the viewer knows what to do next. We
/// still hold the player's name, so we greet them by it. The page polls
/// in the background, so as soon as a new session starts or the host
/// checks the player in, this view flips back to [_Loaded] without a
/// manual refresh.
class _UnavailableView extends StatelessWidget {
  const _UnavailableView({required this.state});
  final PlayerProfileState state;

  @override
  Widget build(BuildContext context) {
    final name = state.player?.name;
    final reason = state.unavailableReason ?? UnavailableReason.noActiveSession;
    final copy = _copyFor(reason, state.latestSession);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _StickyHeader(),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      name == null ? copy.title : 'Hi, $name',
                      textAlign: TextAlign.center,
                      style: PaddleText.display(size: 26, height: 1.1),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      copy.body,
                      textAlign: TextAlign.center,
                      style: PaddleText.body(
                        size: 14,
                        color: PaddleColors.inkSoft,
                        height: 1.5,
                      ),
                    ),
                    if (copy.detail != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        copy.detail!,
                        textAlign: TextAlign.center,
                        style: PaddleText.body(
                          size: 12,
                          color: PaddleColors.inkFaint,
                          height: 1.5,
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0x142D7749),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        copy.pill,
                        textAlign: TextAlign.center,
                        style: PaddleText.body(
                          size: 12,
                          color: PaddleColors.paddleGreenDark,
                          weight: FontWeight.w700,
                          height: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  _UnavailableCopy _copyFor(
    UnavailableReason reason,
    SessionResponse? latest,
  ) {
    switch (reason) {
      case UnavailableReason.notCheckedIn:
        return const _UnavailableCopy(
          title: 'Not checked in yet',
          body: 'Your profile unlocks once the host scans your QR or checks '
              'you in to the active session.',
          pill: 'Waiting for check-in…',
        );
      case UnavailableReason.noActiveSession:
        final endedAt = latest?.endedAt;
        return _UnavailableCopy(
          title: 'Profile unavailable',
          body: 'Profiles are only visible while a session is in progress. '
              'Check back when your host starts the next one.',
          detail: latest == null
              ? 'No sessions have been hosted yet.'
              : endedAt == null
                  ? null
                  : 'Last session ended ${_friendlyEndedAt(endedAt.toLocal())}.',
          pill: 'Checking for a new session…',
        );
    }
  }

  String _friendlyEndedAt(DateTime when) {
    final now = DateTime.now();
    final diff = now.difference(when);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} h ago';
    final days = diff.inDays;
    if (days == 1) return 'yesterday';
    if (days < 7) return '$days days ago';
    return 'on ${when.month}/${when.day}/${when.year}';
  }
}

/// Plain-old-Dart bundle of the four strings the unavailable view shows —
/// title (when we don't know the player's name), body, optional detail
/// (e.g. "Last session ended 3 h ago") and the live-status pill. Kept
/// local because nothing else needs to know about it.
class _UnavailableCopy {
  const _UnavailableCopy({
    required this.title,
    required this.body,
    required this.pill,
    this.detail,
  });

  final String title;
  final String body;
  final String pill;
  final String? detail;
}

// ─── Loaded shell ──────────────────────────────────────────────────────

class _Loaded extends StatelessWidget {
  const _Loaded({required this.state});
  final PlayerProfileState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _StickyHeader(),
        Expanded(
          child: SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1280),
                child: LayoutBuilder(builder: (context, c) {
                  final stagePad = c.maxWidth < 720 ? 20.0 : 40.0;
                  return Padding(
                    padding: EdgeInsets.fromLTRB(stagePad, 36, stagePad, 80),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _HeroGrid(state: state, width: c.maxWidth),
                        const SizedBox(height: 20),
                        _TwoCol(state: state, width: c.maxWidth),
                        const SizedBox(height: 20),
                        _MatchHistoryCard(state: state, width: c.maxWidth),
                      ],
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Sticky header (logo + wordmark) ───────────────────────────────────

class _StickyHeader extends StatelessWidget {
  const _StickyHeader();
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _C.paper,
        border: Border(bottom: BorderSide(color: _C.lineSoft, width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 22),
      child: Row(
        children: [
          Image.asset(
            'assets/images/logo.png',
            width: 56,
            height: 50,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 18),
          Text('PADDLEQ', style: PaddleText.wordmark(size: 36)),
        ],
      ),
    );
  }
}

// ─── Hero grid: profile-with-stats card + QR side card ─────────────────

class _HeroGrid extends StatelessWidget {
  const _HeroGrid({required this.state, required this.width});
  final PlayerProfileState state;
  final double width;

  @override
  Widget build(BuildContext context) {
    // QR card sits on top, profile (with inline stats) below — a single
    // stacked column regardless of viewport. The QR card no longer has
    // a share button, so it reads as a hero "player pass" panel.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _QrSideCard(state: state),
        const SizedBox(height: 20),
        _ProfileCard(state: state, narrowStats: width < 720),
      ],
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.state, required this.narrowStats});
  final PlayerProfileState state;
  final bool narrowStats;

  @override
  Widget build(BuildContext context) {
    final p = state.player!;
    final my = state.myLeaderboardEntry;
    final games = my?.gamesPlayed ?? 0;
    final wins = my?.wins ?? p.wins;
    final losses = my?.losses ?? p.losses;
    final winRate = games > 0 ? ((wins / games) * 100).round() : 0;
    final streak = state.currentStreak;
    final session = state.activeSession;
    final statusLabel = _statusLabelFor(state.myQueueEntry);
    final initials = _initials(p.name);
    final lastLoss = _lastLossLocal(state);

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Profile row ──
          Padding(
            padding: const EdgeInsets.only(bottom: 22),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: PaddleColors.paddleGreen,
                    border: Border.all(color: PaddleColors.ink, width: 2.5),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initials,
                    style: PaddleText.display(
                        size: 32, color: Colors.white, height: 1),
                  ),
                ),
                const SizedBox(width: 22),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Wrap(
                        spacing: 14,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            p.name,
                            style: PaddleText.display(size: 36, height: 1)
                                .copyWith(letterSpacing: -0.3),
                          ),
                          if (statusLabel != null)
                            _StatusPill(status: statusLabel),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'SKILL ${_formatSkill(p.skillLevel)}',
                            style: PaddleText.label(
                              size: 12,
                              tracking: 0.04,
                              weight: FontWeight.w900,
                              color: PaddleColors.paddleGreen,
                            ),
                          ),
                          _Dot(),
                          Text(
                            _skillTier(p.skillLevel),
                            style: PaddleText.body(
                              size: 13,
                              color: _C.inkSoftWeb,
                              weight: FontWeight.w500,
                            ),
                          ),
                          if (session != null) ...[
                            _Dot(),
                            Text(
                              session.name.trim().isEmpty
                                  ? 'Untitled session'
                                  : session.name.trim(),
                              style: PaddleText.body(
                                size: 13,
                                color: _C.inkSoftWeb,
                                weight: FontWeight.w500,
                              ),
                            ),
                            _Dot(),
                            Text(
                              '#${session.id}',
                              style: PaddleText.body(
                                size: 13,
                                color: _C.inkSoftWeb,
                                weight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // ── Dashed divider ──
          const _DashedDivider(),
          const SizedBox(height: 22),
          // ── Stats grid ──
          _StatsGrid(
            narrow: narrowStats,
            stats: [
              _StatModel(
                label: 'Games',
                value: '$games',
                sub: 'this session',
              ),
              _StatModel(
                label: 'Wins',
                value: '$wins',
                sub: games > 0 ? '$winRate% win rate' : '—',
                accent: PaddleColors.active,
              ),
              _StatModel(
                label: 'Losses',
                value: '$losses',
                sub: lastLoss == null ? 'this session' : 'last loss $lastLoss',
                accent: _C.loss,
              ),
              _StatModel(
                label: 'Streak',
                value: 'W$streak',
                sub: streak > 0
                    ? '$streak in a row'
                    : 'first win restarts it',
                accent: PaddleColors.paddleGreen,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatModel {
  const _StatModel({
    required this.label,
    required this.value,
    required this.sub,
    this.accent,
  });
  final String label;
  final String value;
  final String sub;
  final Color? accent;
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.narrow, required this.stats});
  final bool narrow;
  final List<_StatModel> stats;

  @override
  Widget build(BuildContext context) {
    if (narrow) {
      return Column(
        children: [
          for (var i = 0; i < stats.length; i += 2) ...[
            Row(
              children: [
                Expanded(child: _StatTile(model: stats[i])),
                const SizedBox(width: 12),
                Expanded(
                  child: i + 1 < stats.length
                      ? _StatTile(model: stats[i + 1])
                      : const SizedBox.shrink(),
                ),
              ],
            ),
            if (i + 2 < stats.length) const SizedBox(height: 12),
          ],
        ],
      );
    }
    return Row(
      children: [
        for (var i = 0; i < stats.length; i++) ...[
          Expanded(child: _StatTile(model: stats[i])),
          if (i < stats.length - 1) const SizedBox(width: 12),
        ],
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.model});
  final _StatModel model;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: _C.paper,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            model.label.toUpperCase(),
            style: PaddleText.label(
              size: 10,
              tracking: 0.10,
              weight: FontWeight.w700,
              color: PaddleColors.inkFaint,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            model.value,
            style: PaddleText.display(
              size: 36,
              height: 1,
              color: model.accent ?? PaddleColors.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            model.sub,
            style: PaddleText.body(
                size: 12,
                color: PaddleColors.inkFaint,
                weight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _QrSideCard extends StatelessWidget {
  const _QrSideCard({required this.state});
  final PlayerProfileState state;

  @override
  Widget build(BuildContext context) {
    final p = state.player!;
    final session = state.activeSession;
    return _Card(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: PaddleColors.ink, width: 1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: QrImageView(
                data: p.qrCode,
                version: QrVersions.auto,
                size: 180,
                gapless: true,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: PaddleColors.ink,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: PaddleColors.ink,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'PLAYER PASS',
            textAlign: TextAlign.center,
            style: PaddleText.label(
              size: 11,
              tracking: 0.16,
              weight: FontWeight.w700,
              color: PaddleColors.inkFaint,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            session?.name.trim().isNotEmpty == true
                ? session!.name.trim()
                : 'No active session',
            textAlign: TextAlign.center,
            style: PaddleText.display(size: 20, height: 1),
          ),
          const SizedBox(height: 4),
          Text(
            session == null
                ? '—'
                : '#${session.id} · ${session.numberOfCourts} ${session.numberOfCourts == 1 ? "court" : "courts"}',
            textAlign: TextAlign.center,
            style: PaddleText.body(
                size: 13,
                color: PaddleColors.inkFaint,
                weight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

// ─── Two-column: leaderboard + queue ───────────────────────────────────

class _TwoCol extends StatelessWidget {
  const _TwoCol({required this.state, required this.width});
  final PlayerProfileState state;
  final double width;

  @override
  Widget build(BuildContext context) {
    final wide = width >= 1024;
    final left = _LeaderboardCard(state: state);
    final right = _QueueCard(state: state);
    if (wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 12, child: left),
          const SizedBox(width: 20),
          Expanded(flex: 10, child: right),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        left,
        const SizedBox(height: 20),
        right,
      ],
    );
  }
}

class _LeaderboardCard extends StatelessWidget {
  const _LeaderboardCard({required this.state});
  final PlayerProfileState state;

  @override
  Widget build(BuildContext context) {
    final my = state.myLeaderboardEntry;
    final streak = state.currentStreak;
    final top = state.leaderboard.take(6).toList(growable: false);
    final myId = state.player?.id;

    final rankCopy = my == null
        ? '– unranked tonight'
        : streak > 0
            ? '↑ on a W$streak run tonight'
            : '– holding rank tonight';
    final rankColor = my == null
        ? PaddleColors.inkSoft
        : streak > 0
            ? PaddleColors.active
            : _C.inkSoftWeb;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionHead(
            title: 'Leaderboard',
            accent: top.isEmpty
                ? null
                : Text(
                    'Top ${state.leaderboard.length} players'.toUpperCase(),
                    style: PaddleText.label(
                      size: 11,
                      tracking: 0.14,
                      weight: FontWeight.w700,
                      color: PaddleColors.inkFaint,
                    ),
                  ),
          ),
          // Rank hero
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: PaddleColors.paddleGreen,
                  border: Border.all(color: PaddleColors.ink, width: 3),
                ),
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'RANK',
                      style: PaddleText.label(
                        size: 10,
                        tracking: 0.10,
                        weight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      my == null ? '—' : '#${my.rank}',
                      style: PaddleText.display(
                          size: 28, color: Colors.white, height: 1),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rankCopy,
                      style: PaddleText.body(
                          size: 14,
                          weight: FontWeight.w700,
                          color: rankColor),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _Kpi(
                            label: 'WINS',
                            value: '${my?.wins ?? 0}',
                          ),
                        ),
                        Expanded(
                          child: _Kpi(
                            label: 'STREAK',
                            value: 'W$streak',
                            valueColor:
                                streak > 0 ? PaddleColors.active : null,
                          ),
                        ),
                        Expanded(
                          child: _Kpi(
                            label: 'GAMES',
                            value: '${my?.gamesPlayed ?? 0}',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const _DashedDivider(),
          const SizedBox(height: 14),
          if (top.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Leaderboard empty — no completed matches yet.',
                style: PaddleText.body(
                    size: 13, color: PaddleColors.inkFaint, height: 1.4),
              ),
            )
          else
            Column(
              children: [
                for (final r in top)
                  _LadderRow(entry: r, isMe: r.playerId == myId),
              ],
            ),
        ],
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({required this.label, required this.value, this.valueColor});
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: PaddleText.label(
            size: 11,
            tracking: 0.16,
            weight: FontWeight.w700,
            color: PaddleColors.inkFaint,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: PaddleText.display(
            size: 20,
            height: 1.1,
            color: valueColor ?? PaddleColors.ink,
          ),
        ),
      ],
    );
  }
}

class _LadderRow extends StatelessWidget {
  const _LadderRow({required this.entry, required this.isMe});
  final LeaderboardEntryResponse entry;
  final bool isMe;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? PaddleColors.paddleGreenSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              child: Text(
                '${entry.rank}',
                style: PaddleText.display(
                  size: 16,
                  height: 1,
                  color: entry.rank == 1 ? _C.gold : PaddleColors.ink,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text.rich(
                TextSpan(
                  style: PaddleText.body(
                    size: 14,
                    weight: isMe ? FontWeight.w900 : FontWeight.w600,
                  ),
                  children: [
                    TextSpan(text: entry.playerName),
                    if (isMe)
                      TextSpan(
                        text: '  (you)',
                        style: PaddleText.body(
                          size: 12,
                          color: PaddleColors.paddleGreen,
                          weight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '(${entry.skillLevel.toStringAsFixed(1)})',
              style: PaddleText.body(size: 13, color: PaddleColors.inkFaint),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 56,
              child: Text(
                '${entry.wins}',
                textAlign: TextAlign.right,
                style: PaddleText.display(size: 15, height: 1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QueueCard extends StatelessWidget {
  const _QueueCard({required this.state});
  final PlayerProfileState state;

  @override
  Widget build(BuildContext context) {
    final upcoming = state.queue
        .where((e) =>
            e.status == QueueEntryStatus.waiting ||
            e.status == QueueEntryStatus.resting)
        .toList(growable: false);

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionHead(
            title: 'Upcoming Queue',
            accent: Text(
              '${upcoming.length} UP NEXT',
              style: PaddleText.label(
                size: 11,
                tracking: 0.14,
                weight: FontWeight.w700,
                color: PaddleColors.inkFaint,
              ),
            ),
          ),
          if (upcoming.isEmpty)
            Text(
              'Queue is empty. Nobody waiting right now.',
              style: PaddleText.body(
                  size: 13, color: PaddleColors.inkFaint, height: 1.4),
            )
          else
            Column(
              children: [
                for (var i = 0; i < upcoming.length; i++)
                  _QueueRow(
                    entry: upcoming[i],
                    index: i,
                    isMe: upcoming[i].playerId == state.player?.id,
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _QueueRow extends StatelessWidget {
  const _QueueRow({
    required this.entry,
    required this.index,
    required this.isMe,
  });
  final QueueEntryResponse entry;
  final int index;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final waited = entry.checkedInAt == null
        ? '—'
        : '${DateTime.now().toUtc().difference(entry.checkedInAt!.toUtc()).inMinutes} min';
    final status = switch (entry.status) {
      QueueEntryStatus.waiting => 'Waiting',
      QueueEntryStatus.playing => 'Active Match',
      QueueEntryStatus.resting => 'Resting',
      _ => 'Queued',
    };
    return Container(
      decoration: BoxDecoration(
        border: index == 0
            ? null
            : const Border(top: BorderSide(color: _C.line, width: 1)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: PaddleColors.ink, width: 1.5),
            ),
            alignment: Alignment.center,
            child: Text(
              '${index + 1}',
              style: PaddleText.display(size: 14, height: 1),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    style: PaddleText.body(
                      size: 15,
                      weight: isMe ? FontWeight.w900 : FontWeight.w700,
                    ),
                    children: [
                      TextSpan(text: entry.playerName),
                      TextSpan(
                        text: '  (${entry.skillLevel.toStringAsFixed(1)})',
                        style: PaddleText.body(
                          size: 14,
                          weight: FontWeight.w400,
                          color: PaddleColors.inkFaint,
                        ),
                      ),
                      if (isMe)
                        TextSpan(
                          text: '  (you)',
                          style: PaddleText.body(
                            size: 12,
                            weight: FontWeight.w700,
                            color: PaddleColors.paddleGreen,
                          ),
                        ),
                    ],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'WAITING · $waited',
                  style: PaddleText.label(
                    size: 11,
                    tracking: 0.08,
                    weight: FontWeight.w700,
                    color: PaddleColors.inkFaint,
                  ),
                ),
              ],
            ),
          ),
          _StatusPill(status: status),
        ],
      ),
    );
  }
}

// ─── Match history ─────────────────────────────────────────────────────

class _MatchHistoryCard extends StatelessWidget {
  const _MatchHistoryCard({required this.state, required this.width});
  final PlayerProfileState state;
  final double width;

  @override
  Widget build(BuildContext context) {
    final my = state.myHistory;
    return _Card(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionHead(
            title: 'Match History',
            accent: Text(
              '${my.length} ${my.length == 1 ? "match" : "matches"}'
                  .toUpperCase(),
              style: PaddleText.label(
                size: 11,
                tracking: 0.14,
                weight: FontWeight.w700,
                color: PaddleColors.paddleGreen,
              ),
            ),
          ),
          if (my.isEmpty)
            Text(
              'You haven\'t finished a match in this session yet.',
              style: PaddleText.body(
                  size: 13, color: PaddleColors.inkFaint, height: 1.4),
            )
          else
            Column(
              children: [
                for (var i = 0; i < my.length; i++)
                  _MatchRow(
                    match: my[i],
                    myId: state.player!.id,
                    isFirst: i == 0,
                    isNarrow: width < 720,
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _MatchRow extends StatelessWidget {
  const _MatchRow({
    required this.match,
    required this.myId,
    required this.isFirst,
    required this.isNarrow,
  });
  final MatchResponse match;
  final String myId;
  final bool isFirst;
  final bool isNarrow;

  @override
  Widget build(BuildContext context) {
    MatchPlayerInfo? me;
    for (final p in match.players) {
      if (p.playerId == myId) {
        me = p;
        break;
      }
    }
    final isWin =
        match.winningTeam != null && me != null && me.team == match.winningTeam;
    final partner = match.players.firstWhere(
      (p) => p.playerId != myId && me != null && p.team == me.team,
      orElse: () => const MatchPlayerInfo(
          playerId: '', playerName: '—', skillLevel: 0, team: 0),
    );
    final opponents = match.players
        .where((p) => me == null ? false : p.team != me.team)
        .toList(growable: false);
    final court = match.courtNumber == null
        ? '—'
        : 'Court ${match.courtNumber}';
    final time = match.completedAt == null
        ? '—'
        : _shortTime(match.completedAt!.toLocal());

    final badgeBg = isWin
        ? const Color(0x1A0E920E)
        : const Color(0x1AA83737);
    final badgeFg = isWin ? PaddleColors.active : _C.loss;

    final badge = Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: badgeBg,
        border: Border.all(color: badgeFg, width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Text(
        isWin ? 'W' : 'L',
        style: PaddleText.display(size: 20, color: badgeFg, height: 1),
      ),
    );

    final scoreCol = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isWin ? 'Win' : 'Loss',
          style: PaddleText.display(size: 22, height: 1),
        ),
        const SizedBox(height: 4),
        Text(
          '$court · $time'.toUpperCase(),
          style: PaddleText.label(
            size: 11,
            tracking: 0.08,
            weight: FontWeight.w700,
            color: PaddleColors.inkFaint,
          ),
        ),
      ],
    );

    final partnerCol = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PARTNER',
          style: PaddleText.label(
            size: 10,
            tracking: 0.10,
            weight: FontWeight.w700,
            color: PaddleColors.inkFaint,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          partner.playerName.isEmpty
              ? '—'
              : '${partner.playerName} (${partner.skillLevel.toStringAsFixed(1)})',
          style: PaddleText.body(
              size: 14, weight: FontWeight.w600, height: 1.3),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );

    final opponentsCol = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'OPPONENTS',
          style: PaddleText.label(
            size: 10,
            tracking: 0.10,
            weight: FontWeight.w700,
            color: PaddleColors.inkFaint,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          opponents.isEmpty
              ? '—'
              : opponents.map((o) => o.playerName).join(' + '),
          style: PaddleText.body(
              size: 14, weight: FontWeight.w600, height: 1.3),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );

    return Container(
      decoration: BoxDecoration(
        border: isFirst
            ? null
            : const Border(top: BorderSide(color: _C.line, width: 1)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: isNarrow
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                badge,
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      scoreCol,
                      const SizedBox(height: 8),
                      partnerCol,
                      const SizedBox(height: 6),
                      opponentsCol,
                    ],
                  ),
                ),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                badge,
                const SizedBox(width: 16),
                SizedBox(width: 140, child: scoreCol),
                const SizedBox(width: 16),
                Expanded(flex: 10, child: partnerCol),
                const SizedBox(width: 16),
                Expanded(flex: 12, child: opponentsCol),
                const SizedBox(width: 16),
                _ChevronButton(),
              ],
            ),
    );
  }
}

class _ChevronButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border.all(color: _C.line),
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.chevron_right,
          size: 20, color: PaddleColors.inkSoft),
    );
  }
}

// ─── Shared building blocks ────────────────────────────────────────────

class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding});
  final Widget child;
  final EdgeInsetsGeometry? padding;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _C.tile,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.line),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 14,
              offset: Offset(0, 4)),
        ],
      ),
      padding: padding ?? const EdgeInsets.all(28),
      child: child,
    );
  }
}

class _SectionHead extends StatelessWidget {
  const _SectionHead({required this.title, this.accent});
  final String title;
  final Widget? accent;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              color: PaddleColors.paddleGreen,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: PaddleText.label(
                size: 11,
                tracking: 0.16,
                weight: FontWeight.w900,
                color: PaddleColors.ink,
              ),
            ),
          ),
          if (accent != null) accent!,
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = switch (status) {
      'Active Match' => (PaddleColors.active, const Color(0x1A0E920E)),
      'Waiting' => (PaddleColors.warn, const Color(0x1FC7891B)),
      'Resting' => (PaddleColors.rest, const Color(0x29727272)),
      'Win' => (PaddleColors.active, const Color(0x1A0E920E)),
      'Loss' => (_C.loss, const Color(0x1FA83737)),
      _ => (PaddleColors.inkFaint, const Color(0x1F727272)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.toUpperCase(),
        style: PaddleText.label(
          size: 10,
          tracking: 0.10,
          weight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 3,
      height: 3,
      decoration: const BoxDecoration(
        color: PaddleColors.inkFaint,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _DashedDivider extends StatelessWidget {
  const _DashedDivider();
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(double.infinity, 1),
      painter: _DashedPainter(),
    );
  }
}

class _DashedPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _C.line
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.square;
    const dash = 6.0;
    const gap = 4.0;
    var x = 0.0;
    final y = size.height / 2;
    while (x < size.width) {
      canvas.drawLine(Offset(x, y), Offset(x + dash, y), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedPainter old) => false;
}


// ─── Pure helpers ──────────────────────────────────────────────────────

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'))
    ..removeWhere((p) => p.isEmpty);
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts[0][0] + parts[1][0]).toUpperCase();
}

String _formatSkill(double v) =>
    v == v.truncateToDouble() ? v.toStringAsFixed(1) : v.toString();

String _skillTier(double v) {
  if (v < 2.5) return 'Beginner';
  if (v < 3.5) return 'Intermediate';
  if (v < 4.5) return 'Advanced';
  return 'Expert';
}

String? _statusLabelFor(QueueEntryResponse? entry) {
  if (entry == null) return null;
  return switch (entry.status) {
    QueueEntryStatus.playing => 'Active Match',
    QueueEntryStatus.waiting => 'Waiting',
    QueueEntryStatus.resting => 'Resting',
    QueueEntryStatus.finished => 'Session done',
    _ => null,
  };
}

String? _lastLossLocal(PlayerProfileState state) {
  final id = state.player?.id;
  if (id == null) return null;
  for (final m in state.myHistory) {
    if (m.winningTeam == null) continue;
    MatchPlayerInfo? mine;
    for (final p in m.players) {
      if (p.playerId == id) {
        mine = p;
        break;
      }
    }
    if (mine == null) continue;
    if (mine.team != m.winningTeam) {
      if (m.completedAt != null) return _shortTime(m.completedAt!.toLocal());
      return null;
    }
  }
  return null;
}

String _shortTime(DateTime local) {
  final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final mm = local.minute.toString().padLeft(2, '0');
  final ampm = local.hour < 12 ? 'a' : 'p';
  return '$hour12:$mm$ampm';
}

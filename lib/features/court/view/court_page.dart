import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:paddleq/core/api/api_exception.dart';
import 'package:paddleq/core/api/paddleq_api.dart';
import 'package:paddleq/core/models/match_dtos.dart';
import 'package:paddleq/core/models/session_dtos.dart';
import 'package:paddleq/core/storage/past_sessions_store.dart';
import 'package:paddleq/core/theme/paddle_colors.dart';
import 'package:paddleq/core/theme/paddle_text.dart';
import 'package:paddleq/core/widgets/api_error_dialog.dart';
import 'package:paddleq/core/widgets/paddle_icons.dart';
import 'package:paddleq/core/widgets/phone_frame.dart';
import 'package:paddleq/features/court/cubit/court_cubit.dart';
import 'package:paddleq/features/court/widgets/add_player_modal.dart';
import 'package:paddleq/features/court/widgets/add_player_sheet.dart';
import 'package:paddleq/features/court/widgets/cancel_match_dialog.dart';
import 'package:paddleq/features/court/widgets/court_card.dart';
import 'package:paddleq/features/court/widgets/leaderboard_section.dart';
import 'package:paddleq/features/court/widgets/match_history_section.dart';
import 'package:paddleq/features/court/widgets/desktop_court_card.dart';
import 'package:paddleq/features/court/widgets/player_qr_dialog.dart';
import 'package:paddleq/features/court/widgets/player_rail.dart';
import 'package:paddleq/features/court/widgets/player_row.dart';
import 'package:paddleq/features/court/widgets/qr_scan_sheet.dart';
import 'package:paddleq/features/home/cubit/home_cubit.dart';
import 'package:paddleq/features/home/cubit/past_sessions_cubit.dart';
import 'package:paddleq/features/home/view/home_page.dart';
import 'package:paddleq/features/leaderboard/view/leaderboard_page.dart';

const double _desktopBreakpoint = 768;

class CourtPage extends StatelessWidget {
  const CourtPage({super.key, required this.session});

  /// Live session this page is bound to (returned by `POST /api/sessions`
  /// or `GET /api/sessions/active`).
  final SessionResponse session;

  GameMode get _mode =>
      session.matchType == 'Singles' ? GameMode.singles : GameMode.doubles;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => CourtCubit(
        api: ctx.read<PaddleqApi>(),
        mode: _mode,
        courtCount: session.numberOfCourts,
        sessionName: session.name,
        sessionId: session.id,
      )..loadQueue(),
      child: Scaffold(
        backgroundColor: PaddleColors.paper,
        body: LayoutBuilder(builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= _desktopBreakpoint;
          if (isDesktop) return const _DesktopCourtBody();
          return PhoneFrame(child: _CourtBody());
        }),
      ),
    );
  }
}

class _CourtBody extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CourtCubit, CourtState>(
      builder: (context, state) {
        return Stack(
          children: [
            Column(
              children: [
                const _TopBar(),
                _MetaRow(state: state),
                if (state.sessionName.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                    child: _SessionHeader(name: state.sessionName),
                  ),
                _Tabs(state: state),
                const _QueueStatusBanner(),
                Expanded(
                  child: state.tab == CourtTab.courts
                      ? _CourtsTab(state: state)
                      : _PlayersTab(state: state),
                ),
              ],
            ),
            if (state.tab == CourtTab.players) const _Fab(),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Top bar / meta row / tabs
// ---------------------------------------------------------------------------

class _TopBar extends StatelessWidget {
  const _TopBar();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 10),
      child: Row(
        children: [
          _IconBox(
            shape: BoxShape.circle,
            onTap: () => _navigateBackOrHome(context),
            child: const PaddleIcon.back(color: PaddleColors.ink),
          ),
          const SizedBox(width: 10),
          Image.asset('assets/images/logo.png', width: 28, height: 24, fit: BoxFit.contain),
          const SizedBox(width: 8),
          Text('PADDLEQ', style: PaddleText.wordmark(size: 18)),
          const Spacer(),
          _IconBox(
            onTap: () => showQrScanSheet(context),
            child: const PaddleIcon.qr(color: PaddleColors.ink),
          ),
          const SizedBox(width: 8),
          BlocSelector<CourtCubit, CourtState, int?>(
            selector: (s) => s.sessionId,
            builder: (context, sessionId) => _EndSessionButton(
              onTap: sessionId == null
                  ? null
                  : () => _confirmAndEndSession(context, sessionId),
            ),
          ),
        ],
      ),
    );
  }
}

class _IconBox extends StatelessWidget {
  const _IconBox({
    required this.child,
    this.shape = BoxShape.rectangle,
    this.onTap,
  });
  final Widget child;
  final BoxShape shape;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PaddleColors.tile,
      shape: shape == BoxShape.circle
          ? const CircleBorder(side: BorderSide(color: PaddleColors.line))
          : RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: PaddleColors.line),
            ),
      child: InkWell(
        customBorder: shape == BoxShape.circle
            ? const CircleBorder()
            : RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.state});
  final CourtState state;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 14),
      child: Row(
        children: [
          Text(
            '${state.courtCount} COURTS',
            style: PaddleText.body(
              size: 13,
              color: const Color(0xFF784343),
              weight: FontWeight.w700,
            ).copyWith(letterSpacing: 13 * 0.06),
          ),
          const SizedBox(width: 10),
          Container(
            width: 4,
            height: 4,
            decoration: const BoxDecoration(
              color: Color(0x33000000),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            state.mode.label.toUpperCase(),
            style: PaddleText.body(
              size: 13,
              color: const Color(0xFF177903),
              weight: FontWeight.w700,
            ).copyWith(letterSpacing: 13 * 0.06),
          ),
        ],
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.state});
  final CourtState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CourtCubit>();
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 14),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0x0D000000),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TabButton(
              active: state.tab == CourtTab.courts,
              label: 'Courts',
              count: state.courtCount,
              onTap: () => cubit.selectTab(CourtTab.courts),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _TabButton(
              active: state.tab == CourtTab.players,
              label: 'Players',
              count: state.players.length,
              onTap: () => cubit.selectTab(CourtTab.players),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({required this.active, required this.label, required this.count, required this.onTap});
  final bool active;
  final String label;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(9);
    return Material(
      color: active ? PaddleColors.tile : Colors.transparent,
      borderRadius: radius,
      elevation: active ? 1 : 0,
      shadowColor: const Color(0x0F000000),
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label.toUpperCase(),
                style: PaddleText.body(
                  size: 12,
                  weight: FontWeight.w700,
                  color: active ? PaddleColors.ink : PaddleColors.inkSoft,
                ).copyWith(letterSpacing: 12 * 0.08),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: active ? PaddleColors.paddleGreen : const Color(0x1F000000),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: PaddleText.body(
                    size: 10,
                    color: active ? Colors.white : PaddleColors.inkSoft,
                    weight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Courts tab
// ---------------------------------------------------------------------------

class _CourtsTab extends StatelessWidget {
  const _CourtsTab({required this.state});
  final CourtState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CourtCubit>();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Pager(
            current: state.currentCourt,
            total: state.courtCount,
            onPrev: cubit.prevCourt,
            onNext: cubit.nextCourt,
          ),
          CourtCard(
            idx: state.currentCourt,
            match: state.matchOnCourt(state.currentCourt),
            onWinner: (team) =>
                _handleCompleteMatch(context, state.currentCourt, team),
            onQueue: () => _handleFormNextMatch(context),
            onCancel: () => _handleCancelMatch(context, state.currentCourt),
          ),
          const SizedBox(height: 10),
          _Dots(
            count: state.courtCount,
            current: state.currentCourt,
            onSelect: cubit.jumpToCourt,
          ),
          if (state.flash != null) ...[
            const SizedBox(height: 16),
            _Flash(text: state.flash!),
          ],
          _SectionTitle(title: 'Up next', count: state.waitingCount),
          ..._upNext(state),
          const SizedBox(height: 18),
          MatchHistorySection(matches: state.matchHistory),
          const SizedBox(height: 14),
          LeaderboardSection(entries: state.leaderboard),
        ],
      ),
    );
  }

  List<Widget> _upNext(CourtState state) {
    final waiting = state.players
        .where((p) => p.status == PlayerStatus.waiting)
        .take(4)
        .toList();
    return [
      for (var i = 0; i < waiting.length; i++) ...[
        if (i > 0) const SizedBox(height: 8),
        PlayerRow(player: waiting[i]),
      ],
    ];
  }
}

class _Pager extends StatelessWidget {
  const _Pager({
    required this.current,
    required this.total,
    required this.onPrev,
    required this.onNext,
  });

  final int current;
  final int total;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 12),
      child: Row(
        children: [
          // Flexible(child: CourtNameLabel(idx: current, fontSize: 18)),
          const Spacer(),
          _RoundChevButton(
            disabled: current == 1,
            onTap: onPrev,
            icon: const PaddleIcon.chevronLeft(color: PaddleColors.ink),
          ),
          const SizedBox(width: 6),
          Text(
            '$current / $total',
            style: PaddleText.display(size: 12, color: PaddleColors.inkSoft, height: 1),
          ),
          const SizedBox(width: 6),
          _RoundChevButton(
            disabled: current == total,
            onTap: onNext,
            icon: const PaddleIcon.chevronRight(color: PaddleColors.ink),
          ),
        ],
      ),
    );
  }
}

class _RoundChevButton extends StatelessWidget {
  const _RoundChevButton({required this.disabled, required this.onTap, required this.icon});
  final bool disabled;
  final VoidCallback onTap;
  final Widget icon;
  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: disabled ? 0.35 : 1,
      child: Material(
        color: PaddleColors.tile,
        shape: CircleBorder(side: BorderSide(color: PaddleColors.line)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: disabled ? null : onTap,
          child: SizedBox(width: 32, height: 32, child: Center(child: icon)),
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.current, required this.onSelect});
  final int count;
  final int current;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 1; i <= count; i++) ...[
            GestureDetector(
              onTap: () => onSelect(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: i == current ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == current ? PaddleColors.paddleGreen : const Color(0x26000000),
                  borderRadius: BorderRadius.circular(i == current ? 3 : 999),
                ),
              ),
            ),
            if (i < count) const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}

class _Flash extends StatelessWidget {
  const _Flash({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: PaddleColors.paddleGreen,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: PaddleText.display(size: 13, color: Colors.white, height: 1.2),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.count, this.action});
  final String title;
  final int count;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
      child: Row(
        children: [
          Text(title, style: PaddleText.display(size: 18, height: 1)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
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
          if (action != null) ...[const Spacer(), action!],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Players tab
// ---------------------------------------------------------------------------

class _PlayersTab extends StatelessWidget {
  const _PlayersTab({required this.state});
  final CourtState state;

  @override
  Widget build(BuildContext context) {
    final filtered = switch (state.filter) {
      PlayerFilter.all => state.players,
      PlayerFilter.active => state.players.where((p) => p.status == PlayerStatus.active).toList(),
      PlayerFilter.waiting => state.players.where((p) => p.status == PlayerStatus.waiting).toList(),
      PlayerFilter.resting => state.players.where((p) => p.status == PlayerStatus.resting).toList(),
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionTitle(
            title: 'All players',
            count: state.players.length,
            action: _AddInline(onTap: () => _openAdd(context)),
          ),
          _FilterChips(state: state),
          const SizedBox(height: 12),
          for (var i = 0; i < filtered.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            PlayerRow(player: filtered[i]),
          ],
          if (state.flash != null) ...[
            const SizedBox(height: 16),
            _Flash(text: state.flash!),
          ],
        ],
      ),
    );
  }

  void _openAdd(BuildContext context) {
    final cubit = context.read<CourtCubit>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => AddPlayerSheet(
        onAdd: (name, skill) =>
            _registerAndShowQr(sheetCtx, cubit, name: name, skill: skill),
      ),
    );
  }
}

/// Shared by mobile + desktop add flows: registers the player on the backend,
/// checks them into the active session, then (on success) pops the form and
/// shows their QR code so they can save it for future check-ins.
///
/// Errors stay inside the form: we surface the backend message via the
/// shared error dialog and leave the sheet/modal open so the host can fix
/// and retry.
Future<void> _registerAndShowQr(
  BuildContext formContext,
  CourtCubit cubit, {
  required String name,
  required String skill,
}) async {
  try {
    final player = await cubit.registerAndCheckIn(
      name: name,
      skillLevel: double.parse(skill),
    );
    if (!formContext.mounted) return;
    final navigator = Navigator.of(formContext);
    final rootContext = navigator.context;
    navigator.pop();
    if (!rootContext.mounted) return;
    await showPlayerQrDialog(rootContext, player);
  } on ApiException catch (e) {
    if (!formContext.mounted) return;
    await showApiErrorDialog(formContext, e, title: "Couldn't add player");
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.state});
  final CourtState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CourtCubit>();
    final counts = {
      PlayerFilter.all: state.players.length,
      PlayerFilter.active: state.activeCount,
      PlayerFilter.waiting: state.waitingCount,
      PlayerFilter.resting: state.restingCount,
    };
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: PlayerFilter.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final f = PlayerFilter.values[i];
          final selected = state.filter == f;
          return _FilterChip(
            label: '${f.label} · ${counts[f]}',
            selected: selected,
            onTap: () => cubit.selectFilter(f),
          );
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? PaddleColors.ink : PaddleColors.tile,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? PaddleColors.ink : PaddleColors.line,
            ),
          ),
          child: Text(
            label,
            style: PaddleText.body(
              size: 11,
              color: selected ? Colors.white : PaddleColors.inkSoft,
              weight: FontWeight.w700,
            ).copyWith(letterSpacing: 11 * 0.08),
          ),
        ),
      ),
    );
  }
}

class _AddInline extends StatelessWidget {
  const _AddInline({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PaddleColors.tile,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: PaddleColors.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const PaddleIcon.plus(color: PaddleColors.ink),
              const SizedBox(width: 6),
              Text(
                'Add',
                style: PaddleText.body(
                  size: 12,
                  weight: FontWeight.w700,
                  color: PaddleColors.ink,
                ).copyWith(letterSpacing: 12 * 0.04),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Fab extends StatelessWidget {
  const _Fab();
  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 16,
      bottom: 22,
      child: Material(
        color: PaddleColors.paddleGreen,
        shape: const CircleBorder(),
        elevation: 6,
        shadowColor: const Color(0x662D7749),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () {
            final cubit = context.read<CourtCubit>();
            showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (sheetCtx) => AddPlayerSheet(
                onAdd: (name, skill) =>
                    _registerAndShowQr(sheetCtx, cubit, name: name, skill: skill),
              ),
            );
          },
          child: const SizedBox(
            width: 56,
            height: 56,
            child: Center(child: PaddleIcon.plus(color: Colors.white, size: 18)),
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// DESKTOP / iPAD LAYOUT
// ===========================================================================

class _DesktopCourtBody extends StatelessWidget {
  const _DesktopCourtBody();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CourtCubit, CourtState>(
      builder: (context, state) {
        return Stack(
          children: [
            Column(
              children: [
                _DesktopTopBar(state: state),
                const _QueueStatusBanner(),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _DesktopMain(state: state)),
                      PlayerRail(onAdd: () => _openAddModal(context)),
                    ],
                  ),
                ),
              ],
            ),
            if (state.flash != null)
              Positioned(top: 96, left: 0, right: 0, child: _FlashToast(text: state.flash!)),
          ],
        );
      },
    );
  }

  void _openAddModal(BuildContext context) {
    final cubit = context.read<CourtCubit>();
    showDialog<void>(
      context: context,
      barrierColor: const Color(0x66000000),
      builder: (dialogCtx) => AddPlayerModal(
        onAdd: (name, skill) =>
            _registerAndShowQr(dialogCtx, cubit, name: name, skill: skill),
      ),
    );
  }
}

class _DesktopTopBar extends StatelessWidget {
  const _DesktopTopBar({required this.state});
  final CourtState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      decoration: const BoxDecoration(
        color: PaddleColors.paper,
        border: Border(bottom: BorderSide(color: PaddleColors.line)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Row(
        children: [
          _SquareIconBtn(
            onTap: () => _navigateBackOrHome(context),
            child: const PaddleIcon.back(color: PaddleColors.ink),
          ),
          const SizedBox(width: 18),
          Image.asset('assets/images/logo.png', width: 40, height: 40, fit: BoxFit.contain),
          const SizedBox(width: 12),
          Text('PADDLEQ', style: PaddleText.wordmark(size: 26).copyWith(letterSpacing: 1)),
          const SizedBox(width: 32),
          Expanded(child: _DesktopMetaRow(state: state)),
          _SquareIconBtn(
            onTap: () => showQrScanSheet(context),
            child: const PaddleIcon.qr(color: PaddleColors.ink),
          ),
          const SizedBox(width: 8),
          _EndSessionButton(
            height: 40,
            fontSize: 13,
            onTap: state.sessionId == null
                ? null
                : () => _confirmAndEndSession(context, state.sessionId!),
          ),
        ],
      ),
    );
  }
}

class _DesktopMetaRow extends StatelessWidget {
  const _DesktopMetaRow({required this.state});
  final CourtState state;

  @override
  Widget build(BuildContext context) {
    final style = PaddleText.display(
      size: 12,
      color: PaddleColors.inkSoft,
      height: 1,
    ).copyWith(letterSpacing: 1.5);
    return Wrap(
      spacing: 14,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('${state.courtCount} COURTS', style: style),
        _MetaDot(color: PaddleColors.paddleGreen),
        Text(state.mode.label.toUpperCase(), style: style),
        _MetaDot(color: PaddleColors.warn),
        Text('${state.activeCount} PLAYING', style: style),
        _MetaDot(color: const Color(0xFF0E5FBA)),
        Text('${state.waitingCount} IN QUEUE', style: style),
      ],
    );
  }
}

class _MetaDot extends StatelessWidget {
  const _MetaDot({required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _SquareIconBtn extends StatelessWidget {
  const _SquareIconBtn({required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(12);
    return Material(
      color: PaddleColors.tile,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        hoverColor: PaddleColors.paddleGreenSoft,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            border: Border.all(color: PaddleColors.line),
            borderRadius: radius,
          ),
          alignment: Alignment.center,
          child: child,
        ),
      ),
    );
  }
}

class _DesktopMain extends StatelessWidget {
  const _DesktopMain({required this.state});
  final CourtState state;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 22, 22, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (state.sessionName.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _SessionHeader(name: state.sessionName),
            ),
          Text('Live courts', style: PaddleText.display(size: 22, height: 1)),
          const SizedBox(height: 16),
          _CourtsGrid(state: state),
          const SizedBox(height: 24),
          // Match history + leaderboard, side-by-side.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: MatchHistorySection(matches: state.matchHistory)),
              const SizedBox(width: 16),
              Expanded(child: LeaderboardSection(entries: state.leaderboard)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SessionHeader extends StatelessWidget {
  const _SessionHeader({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'SESSION',
          style: PaddleText.label(
            size: 11,
            tracking: 0.18,
            weight: FontWeight.w900,
            color: PaddleColors.inkSoft,
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            name,
            overflow: TextOverflow.ellipsis,
            style: PaddleText.display(
              size: 14,
              color: PaddleColors.paddleGreenDark,
              height: 1,
            ),
          ),
        ),
      ],
    );
  }
}

class _CourtsGrid extends StatelessWidget {
  const _CourtsGrid({required this.state});
  final CourtState state;

  @override
  Widget build(BuildContext context) {
    final cols = state.courtCount <= 2 ? 1 : 2;

    return LayoutBuilder(builder: (ctx, c) {
      const gap = 16.0;
      // Fixed cell height — the parent is a SingleChildScrollView so we
      // can't divide the available height anymore. 300px is roughly the
      // tallest a desktop court card needs in doubles mode with 4
      // players + winner buttons.
      const cellH = 300.0;
      final cellW = (c.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (var i = 0; i < state.courtCount; i++)
            SizedBox(
              width: cellW,
              height: cellH,
              child: DesktopCourtCard(
                idx: i + 1,
                match: state.matchOnCourt(i + 1),
                onWinner: (team) =>
                    _handleCompleteMatch(context, i + 1, team),
                onQueue: () => _handleFormNextMatch(context),
                onCancel: () => _handleCancelMatch(context, i + 1),
              ),
            ),
        ],
      );
    });
  }
}

class _FlashToast extends StatelessWidget {
  const _FlashToast({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutBack,
        builder: (_, t, child) => Opacity(
          opacity: t.clamp(0, 1),
          child: Transform.translate(
            offset: Offset(0, (1 - t) * -8),
            child: child,
          ),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          decoration: BoxDecoration(
            color: PaddleColors.paddleGreen,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: PaddleColors.paddleGreen.withValues(alpha: 0.5),
                blurRadius: 40,
                offset: const Offset(0, 12),
                spreadRadius: -8,
              ),
            ],
          ),
          child: Text(
            text,
            style: PaddleText.display(size: 14, color: Colors.white, height: 1)
                .copyWith(letterSpacing: 0.5),
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// END-SESSION ACTION
// ===========================================================================

/// Outlined "END" pill — destructive, sits in the top bar.
class _EndSessionButton extends StatelessWidget {
  const _EndSessionButton({
    required this.onTap,
    this.height = 36,
    this.fontSize = 11,
  });

  /// Disabled when null (e.g. before the session id has been resolved).
  final VoidCallback? onTap;
  final double height;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(height / 2);
    final disabled = onTap == null;
    final color = disabled
        ? PaddleColors.danger.withValues(alpha: 0.45)
        : PaddleColors.danger;

    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        hoverColor: PaddleColors.dangerSoft,
        child: Container(
          height: height,
          padding: EdgeInsets.symmetric(horizontal: height * 0.42),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: color, width: 1.5),
          ),
          child: Text(
            'END',
            style: PaddleText.display(size: fontSize, color: color, height: 1)
                .copyWith(letterSpacing: 1.5),
          ),
        ),
      ),
    );
  }
}

/// Either pops Court (the normal Setup-court path leaves Home in the stack)
/// or replaces it with Home (the active-session bootstrap path lands on
/// Court directly with nothing underneath).
void _navigateBackOrHome(BuildContext context) {
  final nav = Navigator.of(context);
  if (nav.canPop()) {
    nav.pop();
  } else {
    nav.pushReplacement(
      MaterialPageRoute(builder: (_) => const HomePage()),
    );
  }
}

/// Shows the destructive confirmation modal; on confirm:
///   1. snapshots the in-memory leaderboard + session metadata,
///   2. fires `POST /api/sessions/{id}/end`,
///   3. records the resulting [PastSession] in [PastSessionsCubit] /
///      `localStorage` (the leaderboard endpoint can't be re-queried for
///      a closed session, so we have to capture before-and-after here),
///   4. routes to [LeaderboardPage], clearing the back stack so the host
///      can't accidentally navigate back into the dead session.
///
/// On 409 (matches still in progress) and other errors the backend
/// `message` surfaces via [showApiErrorDialog] and the Court page stays.
Future<void> _confirmAndEndSession(BuildContext context, int sessionId) async {
  final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => const _EndSessionConfirmDialog(),
      ) ??
      false;
  if (!confirmed || !context.mounted) return;

  final api = context.read<PaddleqApi>();
  final pastSessions = context.read<PastSessionsCubit>();
  final cubit = context.read<CourtCubit>();
  final snapshot = cubit.state;
  // Capture the leaderboard *before* hitting the endpoint — the server
  // will refuse to return it for a closed session.
  final leaderboardSnapshot =
      List<LeaderboardEntryResponse>.unmodifiable(snapshot.leaderboard);

  try {
    final closed = await api.endSession(sessionId);
    final past = PastSession(
      sessionId: closed.id,
      name: closed.name,
      matchType: closed.matchType,
      numberOfCourts: closed.numberOfCourts,
      startedAt: closed.startedAt,
      endedAt: closed.endedAt ?? DateTime.now().toUtc(),
      leaderboard: leaderboardSnapshot,
    );
    await pastSessions.recordSession(past);
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => LeaderboardPage(session: past)),
      (route) => false,
    );
  } on ApiException catch (e) {
    if (!context.mounted) return;
    await showApiErrorDialog(context, e, title: "Couldn't end session");
  }
}

class _EndSessionConfirmDialog extends StatelessWidget {
  const _EndSessionConfirmDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: PaddleColors.tile,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(
        'End session?',
        style: PaddleText.display(size: 18, height: 1.1),
      ),
      content: Text(
        'This closes the session and finishes any waiting players. '
        'Matches still in progress will block this — finish them first.',
        style: PaddleText.body(size: 14, color: PaddleColors.inkSoft, height: 1.4),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(8, 0, 12, 12),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            'Cancel',
            style: PaddleText.display(size: 14, color: PaddleColors.inkSoft),
          ),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: PaddleColors.danger,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(
            'End session',
            style: PaddleText.display(size: 14, color: Colors.white, height: 1),
          ),
        ),
      ],
    );
  }
}

// ===========================================================================
// QUEUE LOAD STATUS
// ===========================================================================

/// Top-of-page strip that reflects the current `GET /api/queue` request.
///
///  • loading → thin progress bar (non-blocking; lists keep rendering)
///  • failure → red banner with the backend message + a Retry button
///  • idle / success → collapses to nothing
class _QueueStatusBanner extends StatelessWidget {
  const _QueueStatusBanner();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CourtCubit, CourtState>(
      buildWhen: (a, b) =>
          a.queueStatus != b.queueStatus || a.queueError != b.queueError,
      builder: (context, state) {
        switch (state.queueStatus) {
          case QueueLoadStatus.loading:
            return const SizedBox(
              height: 2,
              child: LinearProgressIndicator(
                minHeight: 2,
                backgroundColor: Color(0x14000000),
                color: PaddleColors.paddleGreen,
              ),
            );
          case QueueLoadStatus.failure:
            return Padding(
              padding: const EdgeInsets.fromLTRB(18, 6, 18, 6),
              child: _QueueErrorBanner(
                message: state.queueError ?? 'Could not load queue',
                onRetry: () => context.read<CourtCubit>().loadQueue(),
              ),
            );
          case QueueLoadStatus.idle:
          case QueueLoadStatus.success:
            return const SizedBox.shrink();
        }
      },
    );
  }
}

class _QueueErrorBanner extends StatelessWidget {
  const _QueueErrorBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: PaddleColors.dangerSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PaddleColors.danger.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: PaddleText.body(
                size: 13,
                color: PaddleColors.danger,
                weight: FontWeight.w700,
                height: 1.3,
              ),
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: PaddleColors.danger,
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            onPressed: onRetry,
            child: Text(
              'Retry',
              style: PaddleText.display(size: 13, color: PaddleColors.danger, height: 1),
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// MATCH ACTIONS — form-next + complete
// ===========================================================================

/// Tries `POST /api/matches/next`. On a 409 with a skill-related message,
/// silently retries once with `?allowSkillMix=true` — the cubit's success
/// flash already calls out that skill mix kicked in, so the host doesn't
/// lose track. Non-skill 409s (no session, all courts in use) and other
/// errors land in the standard error dialog.
Future<void> _handleFormNextMatch(BuildContext context) async {
  final cubit = context.read<CourtCubit>();
  await _attemptFormMatch(context, cubit, allowSkillMix: false);
}

Future<void> _attemptFormMatch(
  BuildContext context,
  CourtCubit cubit, {
  required bool allowSkillMix,
}) async {
  try {
    await cubit.formNextMatch(allowSkillMix: allowSkillMix);
  } on ApiException catch (e) {
    if (!context.mounted) return;
    if (e.isConflict && !allowSkillMix && _looksRetryable(e.message)) {
      // Auto-promote to skill-mix and retry — no popup.
      await _attemptFormMatch(context, cubit, allowSkillMix: true);
    } else {
      await showApiErrorDialog(context, e, title: "Couldn't form match");
    }
  }
}

/// Heuristic: a 409 message that mentions skill is a hint we can retry with
/// `allowSkillMix=true`. "All courts in use" / "No active session" 409s
/// don't include the word, so we don't waste a retry on them.
bool _looksRetryable(String message) {
  final lower = message.toLowerCase();
  return lower.contains('skill') || lower.contains('compatible');
}

/// Tries `POST /api/matches/{id}/complete` for the match on [courtIdx].
/// On any error, surfaces the backend message and re-syncs from the server
/// (the local match list may be stale — e.g. someone else completed it).
Future<void> _handleCompleteMatch(
  BuildContext context,
  int courtIdx,
  int team,
) async {
  final cubit = context.read<CourtCubit>();
  try {
    await cubit.completeMatchOnCourt(courtIdx, team);
  } on ApiException catch (e) {
    if (!context.mounted) return;
    await showApiErrorDialog(context, e, title: "Couldn't record winner");
    await cubit.loadQueue();
  }
}

/// Opens the cancel-match confirmation modal for the match currently
/// playing on [courtIdx]. If the local state has no record of a match on
/// that court (race / stale), we silently fall back to a re-sync.
Future<void> _handleCancelMatch(BuildContext context, int courtIdx) async {
  final cubit = context.read<CourtCubit>();
  final match = cubit.state.matchOnCourt(courtIdx);
  if (match == null) {
    await cubit.loadQueue();
    return;
  }
  await showCancelMatchDialog(context, courtIdx: courtIdx, match: match);
}

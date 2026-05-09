import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:paddleq/core/theme/paddle_colors.dart';
import 'package:paddleq/core/theme/paddle_text.dart';
import 'package:paddleq/core/widgets/paddle_icons.dart';
import 'package:paddleq/features/court/cubit/court_cubit.dart';
import 'package:paddleq/features/court/widgets/avatar.dart';

/// Fixed-width 360px right rail used in the iPad/desktop Court layout.
///
/// Contents:
///  * Header: "Players" title + green count pill + "{N} waiting · {N} on court"
///  * Filter chips bar (WAITING / PLAYING / RESTING / ALL)
///  * Player list (with rank prefix when filtering by WAITING)
///  * Footer: "Add player" full-width button
class PlayerRail extends StatelessWidget {
  const PlayerRail({super.key, required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CourtCubit, CourtState>(
      builder: (context, state) {
        final filtered = _applyFilter(state);
        return Container(
          width: 360,
          decoration: const BoxDecoration(
            color: PaddleColors.tile,
            border: Border(left: BorderSide(color: PaddleColors.line)),
          ),
          child: Column(
            children: [
              _RailHead(state: state),
              _FilterBar(state: state),
              Expanded(child: _PlayerList(state: state, filtered: filtered)),
              _RailFooter(onAdd: onAdd),
            ],
          ),
        );
      },
    );
  }

  List<Player> _applyFilter(CourtState s) {
    final base = switch (s.filter) {
      PlayerFilter.all => s.players,
      PlayerFilter.active => s.players.where((p) => p.status == PlayerStatus.active).toList(),
      PlayerFilter.waiting => s.players.where((p) => p.status == PlayerStatus.waiting).toList(),
      PlayerFilter.resting => s.players.where((p) => p.status == PlayerStatus.resting).toList(),
    };
    return base;
  }
}

class _RailHead extends StatelessWidget {
  const _RailHead({required this.state});
  final CourtState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: PaddleColors.line)),
      ),
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Players', style: PaddleText.display(size: 16, height: 1)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: PaddleColors.paddleGreen,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  '${state.players.length}',
                  style: PaddleText.body(
                    size: 10,
                    color: Colors.white,
                    weight: FontWeight.w700,
                  ).copyWith(letterSpacing: 1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${state.waitingCount} waiting · ${state.activeCount} on court',
            style: PaddleText.script(size: 15, color: PaddleColors.inkSoft),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.state});
  final CourtState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CourtCubit>();
    final entries = <(PlayerFilter, String, int)>[
      (PlayerFilter.waiting, 'WAITING', state.waitingCount),
      (PlayerFilter.active, 'PLAYING', state.activeCount),
      (PlayerFilter.resting, 'RESTING', state.restingCount),
      (PlayerFilter.all, 'ALL', state.players.length),
    ];
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: PaddleColors.line)),
      ),
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 12),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final (f, label, count) in entries)
            _RailChip(
              label: '$label · $count',
              selected: state.filter == f,
              onTap: () => cubit.selectFilter(f),
            ),
        ],
      ),
    );
  }
}

class _RailChip extends StatelessWidget {
  const _RailChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(99);
    return Material(
      color: selected ? PaddleColors.paddleGreen : PaddleColors.tile,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: selected ? PaddleColors.paddleGreen : PaddleColors.line,
            ),
          ),
          child: Text(
            label,
            style: PaddleText.display(
              size: 9,
              color: selected ? Colors.white : PaddleColors.inkSoft,
              height: 1,
            ).copyWith(letterSpacing: 0.8),
          ),
        ),
      ),
    );
  }
}

class _PlayerList extends StatelessWidget {
  const _PlayerList({required this.state, required this.filtered});
  final CourtState state;
  final List<Player> filtered;

  @override
  Widget build(BuildContext context) {
    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            'nobody here yet',
            style: PaddleText.script(size: 16, color: PaddleColors.inkFaint),
          ),
        ),
      );
    }
    final isWaiting = state.filter == PlayerFilter.waiting;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
      itemCount: filtered.length,
      itemBuilder: (_, i) => _RailRow(
        player: filtered[i],
        rank: isWaiting ? i + 1 : null,
      ),
    );
  }
}

class _RailRow extends StatefulWidget {
  const _RailRow({required this.player, required this.rank});
  final Player player;
  final int? rank;

  @override
  State<_RailRow> createState() => _RailRowState();
}

class _RailRowState extends State<_RailRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.player;
    final resting = p.status == PlayerStatus.resting;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
        decoration: BoxDecoration(
          color: _hover ? PaddleColors.paddleGreenSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Opacity(
          opacity: resting ? 0.55 : 1,
          child: Row(
            children: [
              if (widget.rank != null)
                SizedBox(
                  width: 22,
                  child: Text(
                    '${widget.rank}',
                    textAlign: TextAlign.center,
                    style: PaddleText.display(
                      size: 12,
                      color: PaddleColors.inkFaint,
                      height: 1,
                    ),
                  ),
                ),
              if (widget.rank != null) const SizedBox(width: 12),
              Avatar(name: p.name),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            p.name,
                            style: PaddleText.body(
                              size: 14,
                              weight: FontWeight.w700,
                              height: 1.2,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '(${p.skill})',
                          style: PaddleText.body(size: 14, color: PaddleColors.inkFaint),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    _StatusBadge(status: p.status),
                  ],
                ),
              ),
              if (p.court != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: PaddleColors.paddleGreen,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'C${p.court}',
                    style: PaddleText.display(size: 10, color: Colors.white, height: 1)
                        .copyWith(letterSpacing: 0.5),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final PlayerStatus status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, label) = switch (status) {
      PlayerStatus.active => (
          const Color(0x1F0E920E),
          PaddleColors.active,
          'Active match'
        ),
      PlayerStatus.waiting => (
          const Color(0x26C7891B),
          PaddleColors.warn,
          'Waiting'
        ),
      PlayerStatus.resting => (
          const Color(0x12000000),
          PaddleColors.rest,
          'Resting'
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label.toUpperCase(),
        style: PaddleText.display(size: 8, color: fg, height: 1)
            .copyWith(letterSpacing: 1),
      ),
    );
  }
}

class _RailFooter extends StatelessWidget {
  const _RailFooter({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: PaddleColors.line)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      child: SizedBox(
        height: 48,
        child: Material(
          color: PaddleColors.paddleGreen,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onAdd,
            hoverColor: PaddleColors.paddleGreenDark,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const PaddleIcon.plus(color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    'Add player',
                    style: PaddleText.display(size: 13, color: Colors.white, height: 1)
                        .copyWith(letterSpacing: 0.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

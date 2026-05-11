import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:paddleq/core/api/api_exception.dart';
import 'package:paddleq/core/models/match_dtos.dart';
import 'package:paddleq/core/theme/paddle_colors.dart';
import 'package:paddleq/core/theme/paddle_text.dart';
import 'package:paddleq/core/widgets/api_error_dialog.dart';
import 'package:paddleq/features/court/cubit/court_cubit.dart';
import 'package:paddleq/features/court/widgets/avatar.dart';

/// "Cancel match" confirmation modal. Shown when the host taps the small
/// cancel link on an in-progress court card.
///
/// Two required choices before submission:
///   1. Which player can't continue (radio-selected from the match roster) —
///      the backend needs this to know who goes to Resting.
///   2. A reason explaining the cancellation (free text, mandatory client-
///      side; backend allows up to 500 chars).
///
/// On Confirm, fires [CourtCubit.voidMatchOnCourt] which calls
/// `POST /api/matches/{id}/void` and refreshes the snapshot. Errors stay
/// inside the dialog and surface via the shared error dialog.
Future<void> showCancelMatchDialog(
  BuildContext context, {
  required int courtIdx,
  required MatchResponse match,
}) {
  final cubit = context.read<CourtCubit>();
  return showDialog<void>(
    context: context,
    barrierColor: const Color(0x66000000),
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: _CancelMatchDialog(courtIdx: courtIdx, match: match),
    ),
  );
}

class _CancelMatchDialog extends StatefulWidget {
  const _CancelMatchDialog({required this.courtIdx, required this.match});
  final int courtIdx;
  final MatchResponse match;

  @override
  State<_CancelMatchDialog> createState() => _CancelMatchDialogState();
}

class _CancelMatchDialogState extends State<_CancelMatchDialog> {
  String? _selectedPlayerId;
  final _reasonCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      !_submitting &&
      _selectedPlayerId != null &&
      _reasonCtrl.text.trim().isNotEmpty;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _submitting = true);
    try {
      await context.read<CourtCubit>().voidMatchOnCourt(
            widget.courtIdx,
            unavailablePlayerId: _selectedPlayerId!,
            reason: _reasonCtrl.text.trim(),
          );
      if (!mounted) return;
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      await showApiErrorDialog(context, e, title: "Couldn't cancel match");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: PaddleColors.tile,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Cancel match?',
                  style: PaddleText.display(size: 18, height: 1.1),
                ),
                const SizedBox(height: 4),
                Text(
                  'Pick the player who can\'t continue. The rest return to '
                  'the queue. No wins / losses / games are counted.',
                  style: PaddleText.body(
                    size: 13,
                    color: PaddleColors.inkSoft,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                _Label(text: 'PLAYER UNAVAILABLE'),
                const SizedBox(height: 6),
                _PlayerPicker(
                  players: widget.match.players,
                  selectedId: _selectedPlayerId,
                  onChanged: _submitting
                      ? null
                      : (id) => setState(() => _selectedPlayerId = id),
                ),
                const SizedBox(height: 14),
                _Label(text: 'REASON'),
                const SizedBox(height: 6),
                TextField(
                  controller: _reasonCtrl,
                  enabled: !_submitting,
                  minLines: 2,
                  maxLines: 4,
                  maxLength: 500,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) => setState(() {}),
                  style:
                      PaddleText.body(size: 14, weight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: 'e.g. ankle twist on court 1',
                    hintStyle: PaddleText.body(
                        size: 14, color: PaddleColors.inkFaint),
                    filled: true,
                    fillColor: PaddleColors.paper,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: PaddleColors.line, width: 1.5),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: PaddleColors.line, width: 1.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: PaddleColors.paddleGreen, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 36,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: PaddleColors.ink,
                          side: const BorderSide(
                              color: PaddleColors.line, width: 1.5),
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _submitting
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: Text(
                          'Back',
                          style: PaddleText.display(
                              size: 14, color: PaddleColors.ink, height: 1),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 64,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: PaddleColors.danger,
                          foregroundColor: Colors.white,
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          disabledBackgroundColor: const Color(0x1F000000),
                          disabledForegroundColor: const Color(0x66000000),
                        ),
                        onPressed: _canSubmit ? _submit : null,
                        child: _submitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : Text(
                                'Cancel match',
                                style: PaddleText.display(
                                  size: 14,
                                  color: Colors.white,
                                  height: 1,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: PaddleText.label(
          size: 11,
          tracking: 0.12,
          weight: FontWeight.w900,
          color: PaddleColors.inkSoft,
        ),
      );
}

class _PlayerPicker extends StatelessWidget {
  const _PlayerPicker({
    required this.players,
    required this.selectedId,
    required this.onChanged,
  });

  final List<MatchPlayerInfo> players;
  final String? selectedId;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < players.length; i++) ...[
          _PlayerOption(
            player: players[i],
            selected: players[i].playerId == selectedId,
            onTap: onChanged == null
                ? null
                : () => onChanged!(players[i].playerId),
          ),
          if (i < players.length - 1) const SizedBox(height: 6),
        ],
      ],
    );
  }
}

class _PlayerOption extends StatelessWidget {
  const _PlayerOption({
    required this.player,
    required this.selected,
    required this.onTap,
  });

  final MatchPlayerInfo player;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(12);
    return Material(
      color: selected
          ? PaddleColors.dangerSoft
          : PaddleColors.paper,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: selected ? PaddleColors.danger : PaddleColors.line,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              _Radio(selected: selected),
              const SizedBox(width: 10),
              Avatar(name: player.playerName, size: 32),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      player.playerName,
                      style: PaddleText.body(
                        size: 14,
                        weight: FontWeight.w700,
                        height: 1.2,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Skill ${player.skillLevel.toStringAsFixed(1)} · TEAM ${player.team}',
                      style: PaddleText.body(
                        size: 11,
                        color: PaddleColors.inkSoft,
                        weight: FontWeight.w700,
                      ).copyWith(letterSpacing: 0.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Radio extends StatelessWidget {
  const _Radio({required this.selected});
  final bool selected;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? PaddleColors.danger : PaddleColors.lineMid,
          width: 1.8,
        ),
      ),
      child: selected
          ? Center(
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: PaddleColors.danger,
                  shape: BoxShape.circle,
                ),
              ),
            )
          : null,
    );
  }
}

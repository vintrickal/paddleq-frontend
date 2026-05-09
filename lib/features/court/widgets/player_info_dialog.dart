import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:paddleq/core/api/api_exception.dart';
import 'package:paddleq/core/api/paddleq_api.dart';
import 'package:paddleq/core/models/player_dtos.dart';
import 'package:paddleq/core/theme/paddle_colors.dart';
import 'package:paddleq/core/theme/paddle_text.dart';
import 'package:paddleq/core/widgets/api_error_dialog.dart';
import 'package:paddleq/features/court/cubit/court_cubit.dart';
import 'package:paddleq/features/court/widgets/edit_player_sheet.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Player profile modal — same visual family as the post-registration QR
/// dialog (`PlayerQrDialog`), with two action buttons:
///
/// * **Edit** — placeholder; needs a backend `PUT /api/players/{id}` to do
///   anything useful. For now it surfaces a "coming soon" notice.
/// * **Rest** — wired to `POST /api/queue/leave` via [CourtCubit.restPlayer].
///   Only enabled while the player's status is Waiting (Playing players
///   can't leave per the backend).
///
/// Uses [showDialog] (centered Dialog) so it renders identically on mobile,
/// tablet, and desktop without bottom-sheet vs. dialog branching.
Future<void> showPlayerInfoDialog(BuildContext context, Player player) {
  final cubit = context.read<CourtCubit>();
  return showDialog<void>(
    context: context,
    barrierColor: const Color(0x66000000),
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: _PlayerInfoDialog(player: player),
    ),
  );
}

class _PlayerInfoDialog extends StatefulWidget {
  const _PlayerInfoDialog({required this.player});
  final Player player;

  @override
  State<_PlayerInfoDialog> createState() => _PlayerInfoDialogState();
}

class _PlayerInfoDialogState extends State<_PlayerInfoDialog> {
  PlayerResponse? _full;
  String? _loadError;
  bool _resting = false;

  bool get _canRest =>
      _full?.qrCode != null &&
      widget.player.status == PlayerStatus.waiting &&
      !_resting;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final api = context.read<PaddleqApi>();
      final response = await api.getPlayer(widget.player.id);
      if (!mounted) return;
      setState(() => _full = response);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _loadError = e.message);
    }
  }

  Future<void> _rest() async {
    final qr = _full?.qrCode;
    if (qr == null || _resting) return;
    setState(() => _resting = true);
    try {
      await context.read<CourtCubit>().restPlayer(qr);
      if (!mounted) return;
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _resting = false);
      await showApiErrorDialog(context, e, title: "Couldn't move to rest");
    }
  }

  Future<void> _edit() async {
    // The CourtCubit is in scope here via the BlocProvider.value wrapping
    // the info dialog — but that scope dies the moment we pop. Capture the
    // cubit reference up front and pass it explicitly to the edit sheet so
    // the sheet doesn't need to look it up against an out-of-scope context.
    final cubit = context.read<CourtCubit>();
    final navigator = Navigator.of(context);
    final outer = navigator.context;
    navigator.pop();
    if (!outer.mounted) return;
    await showEditPlayerSheet(outer, cubit, widget.player);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: PaddleColors.tile,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Player info',
                style: PaddleText.display(size: 18, height: 1.1),
              ),
              const SizedBox(height: 4),
              Text(
                'Tap REST to send the player on a break.',
                textAlign: TextAlign.center,
                style: PaddleText.body(
                    size: 13, color: PaddleColors.inkSoft, height: 1.4),
              ),
              const SizedBox(height: 16),
              _QrSlot(qrCode: _full?.qrCode, error: _loadError),
              const SizedBox(height: 14),
              Text(
                widget.player.name,
                textAlign: TextAlign.center,
                style: PaddleText.display(size: 18, height: 1.1),
              ),
              const SizedBox(height: 2),
              Text(
                'Skill ${widget.player.skill}',
                style:
                    PaddleText.body(size: 12, color: PaddleColors.inkSoft),
              ),
              const SizedBox(height: 14),
              _Stats(player: widget.player, full: _full),
              const SizedBox(height: 18),
              _ActionRow(
                canRest: _canRest,
                resting: _resting,
                qrLoading: _full == null && _loadError == null,
                onEdit: _resting ? null : _edit,
                onRest: _canRest ? _rest : null,
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed:
                    _resting ? null : () => Navigator.of(context).pop(),
                child: Text(
                  'Close',
                  style: PaddleText.display(
                      size: 14, color: PaddleColors.inkSoft, height: 1),
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
// QR slot — same visual treatment as PlayerQrDialog
// ---------------------------------------------------------------------------

class _QrSlot extends StatelessWidget {
  const _QrSlot({required this.qrCode, required this.error});
  final String? qrCode;
  final String? error;

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (error != null) {
      body = Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          error!,
          textAlign: TextAlign.center,
          style: PaddleText.body(
              size: 12, color: PaddleColors.danger, height: 1.4),
        ),
      );
    } else if (qrCode == null) {
      body = const Padding(
        padding: EdgeInsets.all(40),
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            color: PaddleColors.paddleGreen,
            strokeWidth: 3,
          ),
        ),
      );
    } else {
      body = Padding(
        padding: const EdgeInsets.all(14),
        child: QrImageView(
          data: qrCode!,
          version: QrVersions.auto,
          size: 200,
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
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PaddleColors.line),
      ),
      child: Center(child: body),
    );
  }
}

// ---------------------------------------------------------------------------
// Stats row — Wins / Losses / Games (today)
// ---------------------------------------------------------------------------

class _Stats extends StatelessWidget {
  const _Stats({required this.player, required this.full});
  final Player player;
  final PlayerResponse? full;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _StatTile(label: 'Wins', value: full?.wins.toString() ?? '—'),
        _StatTile(label: 'Losses', value: full?.losses.toString() ?? '—'),
        _StatTile(
          label: 'Games today',
          value: player.gamesPlayed.toString(),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: PaddleText.display(size: 22, height: 1)),
        const SizedBox(height: 4),
        Text(
          label.toUpperCase(),
          style: PaddleText.label(
            size: 10,
            tracking: 0.12,
            weight: FontWeight.w900,
            color: PaddleColors.inkSoft,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Edit + Rest action row
// ---------------------------------------------------------------------------

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.canRest,
    required this.resting,
    required this.qrLoading,
    required this.onEdit,
    required this.onRest,
  });

  final bool canRest;
  final bool resting;
  final bool qrLoading;
  final VoidCallback? onEdit;
  final VoidCallback? onRest;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            label: 'Edit',
            background: PaddleColors.tile,
            foreground: PaddleColors.ink,
            border: PaddleColors.line,
            onTap: onEdit,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionButton(
            label: 'Rest',
            background: PaddleColors.warn,
            foreground: Colors.white,
            border: PaddleColors.warn,
            onTap: onRest,
            busy: resting,
            loadingHint: qrLoading,
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.background,
    required this.foreground,
    required this.border,
    required this.onTap,
    this.busy = false,
    this.loadingHint = false,
  });

  final String label;
  final Color background;
  final Color foreground;
  final Color border;
  final VoidCallback? onTap;
  final bool busy;

  /// When the underlying QR fetch is still in flight, render the disabled
  /// state with a subtle progress indicator instead of the bare label.
  final bool loadingHint;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null && !busy;
    final radius = BorderRadius.circular(12);
    return Material(
      color: disabled ? const Color(0x14000000) : background,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: disabled ? PaddleColors.line : border,
              width: 1.5,
            ),
          ),
          alignment: Alignment.center,
          child: busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : (disabled && loadingHint)
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: foreground.withValues(alpha: 0.6),
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      label,
                      style: PaddleText.display(
                        size: 14,
                        color: disabled
                            ? const Color(0x66000000)
                            : foreground,
                        height: 1,
                      ).copyWith(letterSpacing: 14 * 0.04),
                    ),
        ),
      ),
    );
  }
}

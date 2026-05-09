import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:paddleq/core/api/api_exception.dart';
import 'package:paddleq/core/theme/paddle_colors.dart';
import 'package:paddleq/core/theme/paddle_text.dart';
import 'package:paddleq/core/widgets/api_error_dialog.dart';
import 'package:paddleq/core/widgets/paddle_icons.dart';
import 'package:paddleq/features/court/cubit/court_cubit.dart';

/// Edit-player form — visually a twin of [AddPlayerSheet], with the name
/// + skill prefilled and a Save action wired to `PUT /api/players/{publicId}`
/// via [CourtCubit.updatePlayer].
///
/// Bottom sheet on mobile, centered modal on desktop. Save closes the form
/// on success; on `ApiException` the form stays open and the standard error
/// dialog surfaces the backend message.
const _skills = ['2.0', '2.5', '3.0', '3.5', '4.0'];

/// Opens the edit form. The [cubit] must be passed explicitly because the
/// caller is typically running *after* an earlier dialog has been popped,
/// so any context that would have resolved the cubit via `context.read`
/// is no longer in scope. The sheet/modal wraps itself in
/// `BlocProvider.value` using this reference.
Future<void> showEditPlayerSheet(
  BuildContext context,
  CourtCubit cubit,
  Player player,
) {
  final size = MediaQuery.sizeOf(context);
  final isDesktop = size.width >= 768;

  if (isDesktop) {
    return showDialog<void>(
      context: context,
      barrierColor: const Color(0x66000000),
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: _EditPlayerModal(player: player),
      ),
    );
  }

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: _EditPlayerSheet(player: player),
    ),
  );
}

// ---------------------------------------------------------------------------
// Mobile — bottom sheet
// ---------------------------------------------------------------------------

class _EditPlayerSheet extends StatefulWidget {
  const _EditPlayerSheet({required this.player});
  final Player player;
  @override
  State<_EditPlayerSheet> createState() => _EditPlayerSheetState();
}

class _EditPlayerSheetState extends State<_EditPlayerSheet>
    with _EditFormLogic<_EditPlayerSheet> {
  @override
  Player get player => widget.player;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: PaddleColors.tile,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [
          BoxShadow(color: Color(0x2E000000), blurRadius: 40, offset: Offset(0, -10)),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        18,
        10,
        18,
        28 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0x2E000000),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Text('Edit player', style: PaddleText.display(size: 18, height: 1)),
              const Spacer(),
              _CircleBtn(
                onTap: submitting ? null : () => Navigator.of(context).pop(),
                child: const PaddleIcon.x(color: PaddleColors.ink),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...formBody(context),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Desktop — centered modal
// ---------------------------------------------------------------------------

class _EditPlayerModal extends StatefulWidget {
  const _EditPlayerModal({required this.player});
  final Player player;
  @override
  State<_EditPlayerModal> createState() => _EditPlayerModalState();
}

class _EditPlayerModalState extends State<_EditPlayerModal>
    with _EditFormLogic<_EditPlayerModal> {
  @override
  Player get player => widget.player;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Material(
          color: PaddleColors.tile,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text('Edit player',
                        style: PaddleText.display(size: 20, height: 1)),
                    const Spacer(),
                    _CircleBtn(
                      onTap:
                          submitting ? null : () => Navigator.of(context).pop(),
                      child: const PaddleIcon.x(color: PaddleColors.ink),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...formBody(context),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared form body + submission logic
// ---------------------------------------------------------------------------

mixin _EditFormLogic<T extends StatefulWidget> on State<T> {
  Player get player;

  late final TextEditingController _nameCtrl;
  late String _skill;
  bool submitting = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: player.name);
    _skill = _skills.contains(player.skill) ? player.skill : '3.0';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  bool get _dirty {
    final name = _nameCtrl.text.trim();
    return name.isNotEmpty &&
        (name != player.name || _skill != player.skill);
  }

  Future<void> _submit() async {
    if (submitting || !_dirty) return;
    setState(() => submitting = true);
    final name = _nameCtrl.text.trim();
    try {
      await context.read<CourtCubit>().updatePlayer(
            publicId: player.id,
            name: name,
            skillLevel: double.parse(_skill),
          );
      if (!mounted) return;
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => submitting = false);
      await showApiErrorDialog(context, e, title: "Couldn't update player");
    }
  }

  List<Widget> formBody(BuildContext context) {
    return [
      Text(
        'NAME',
        style: PaddleText.label(
          size: 11,
          tracking: 0.12,
          weight: FontWeight.w900,
          color: PaddleColors.inkSoft,
        ),
      ),
      const SizedBox(height: 6),
      TextField(
        controller: _nameCtrl,
        textCapitalization: TextCapitalization.words,
        enabled: !submitting,
        style: PaddleText.body(size: 15, weight: FontWeight.w700),
        decoration: InputDecoration(
          hintText: 'Player name',
          hintStyle: PaddleText.body(
              size: 15, color: PaddleColors.inkFaint, weight: FontWeight.w700),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: PaddleColors.line, width: 1.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: PaddleColors.line, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: PaddleColors.paddleGreen, width: 1.5),
          ),
        ),
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _submit(),
      ),
      const SizedBox(height: 12),
      Text(
        'SKILL LEVEL',
        style: PaddleText.label(
          size: 11,
          tracking: 0.12,
          weight: FontWeight.w900,
          color: PaddleColors.inkSoft,
        ),
      ),
      const SizedBox(height: 6),
      Row(
        children: [
          for (var i = 0; i < _skills.length; i++) ...[
            Expanded(
              child: _SkillButton(
                label: _skills[i],
                selected: _skill == _skills[i],
                onTap: submitting
                    ? null
                    : () => setState(() => _skill = _skills[i]),
              ),
            ),
            if (i < _skills.length - 1) const SizedBox(width: 6),
          ],
        ],
      ),
      const SizedBox(height: 18),
      Row(
        children: [
          Expanded(
            flex: 32,
            child: _Btn(
              label: 'Cancel',
              onTap: submitting ? null : () => Navigator.of(context).pop(),
              background: const Color(0x0D000000),
              foreground: PaddleColors.ink,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 68,
            child: _Btn(
              label: 'Save',
              onTap: (!submitting && _dirty) ? _submit : null,
              background: PaddleColors.paddleGreen,
              foreground: Colors.white,
              busy: submitting,
            ),
          ),
        ],
      ),
    ];
  }
}

// ---------------------------------------------------------------------------
// Building blocks (skill button, action button, close circle)
// ---------------------------------------------------------------------------

class _SkillButton extends StatelessWidget {
  const _SkillButton({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(10);
    return Material(
      color: selected ? PaddleColors.paddleGreen : PaddleColors.tile,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          height: 44,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: selected ? PaddleColors.paddleGreen : PaddleColors.line,
              width: 1.5,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: PaddleText.display(
              size: 13,
              color: selected ? Colors.white : PaddleColors.ink,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  const _Btn({
    required this.label,
    required this.onTap,
    required this.background,
    required this.foreground,
    this.busy = false,
  });
  final String label;
  final VoidCallback? onTap;
  final Color background;
  final Color foreground;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    final radius = BorderRadius.circular(12);
    return Material(
      color: disabled ? const Color(0x1F000000) : background,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: SizedBox(
          height: 50,
          child: Center(
            child: busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : Text(
                    label,
                    style: PaddleText.display(
                      size: 14,
                      color: disabled ? const Color(0x66000000) : foreground,
                      height: 1,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _CircleBtn extends StatelessWidget {
  const _CircleBtn({required this.child, required this.onTap});
  final Widget child;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0x0D000000),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 32,
          height: 32,
          child: Center(child: child),
        ),
      ),
    );
  }
}

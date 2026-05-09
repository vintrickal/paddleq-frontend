import 'package:flutter/material.dart';
import 'package:paddleq/core/theme/paddle_colors.dart';
import 'package:paddleq/core/theme/paddle_text.dart';
import 'package:paddleq/core/widgets/paddle_icons.dart';

const _skills = ['2.0', '2.5', '3.0', '3.5', '4.0'];

class AddPlayerSheet extends StatefulWidget {
  const AddPlayerSheet({super.key, required this.onAdd});

  /// Returns the entered name + selected skill. The sheet awaits the future,
  /// disables the submit button + shows a spinner while it's pending, and
  /// stays open if the future throws (so the caller can surface errors).
  /// Caller is responsible for popping the sheet on success.
  final Future<void> Function(String name, String skill) onAdd;

  @override
  State<AddPlayerSheet> createState() => _AddPlayerSheetState();
}

class _AddPlayerSheetState extends State<AddPlayerSheet> {
  final _controller = TextEditingController();
  String _skill = '3.0';
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _controller.text.trim();
    if (name.isEmpty || _submitting) return;
    setState(() => _submitting = true);
    try {
      await widget.onAdd(name, _skill);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

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
              Text('Add player', style: PaddleText.display(size: 18, height: 1)),
              const Spacer(),
              _CircleBtn(onTap: () => Navigator.of(context).pop(), child: const PaddleIcon.x(color: PaddleColors.ink)),
            ],
          ),
          const SizedBox(height: 16),
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
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            style: PaddleText.body(size: 15, weight: FontWeight.w700),
            decoration: InputDecoration(
              hintText: 'e.g. HARU YUKI',
              hintStyle: PaddleText.body(size: 15, color: PaddleColors.inkFaint, weight: FontWeight.w700),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
                borderSide: const BorderSide(color: PaddleColors.paddleGreen, width: 1.5),
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
                    onTap: () => setState(() => _skill = _skills[i]),
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
                child: _SheetButton(
                  label: 'Cancel',
                  onTap: _submitting ? null : () => Navigator.of(context).pop(),
                  background: const Color(0x0D000000),
                  foreground: PaddleColors.ink,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 68,
                child: _SheetButton(
                  label: 'Add to queue',
                  onTap: (_submitting || _controller.text.trim().isEmpty)
                      ? null
                      : _submit,
                  background: PaddleColors.paddleGreen,
                  foreground: Colors.white,
                  busy: _submitting,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SkillButton extends StatelessWidget {
  const _SkillButton({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;
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

class _SheetButton extends StatelessWidget {
  const _SheetButton({
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
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: foreground,
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
  final VoidCallback onTap;
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

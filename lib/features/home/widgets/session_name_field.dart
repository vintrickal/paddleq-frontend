import 'package:flutter/material.dart';
import 'package:paddleq/core/theme/paddle_colors.dart';
import 'package:paddleq/core/theme/paddle_text.dart';

/// Labeled text input for naming the play session.
///
/// Visual treatment is borrowed from the add-player sheet (white tile, rounded
/// corners, focus ring in paddle-green). The [onChanged] callback fires on
/// every keystroke so the parent cubit stays in sync.
class SessionNameField extends StatefulWidget {
  const SessionNameField({
    super.key,
    required this.value,
    required this.onChanged,
    this.placeholder = 'e.g. Tuesday Night Open Play',
  });

  final String value;
  final ValueChanged<String> onChanged;
  final String placeholder;

  @override
  State<SessionNameField> createState() => _SessionNameFieldState();
}

class _SessionNameFieldState extends State<SessionNameField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant SessionNameField old) {
    super.didUpdateWidget(old);
    if (widget.value != _controller.text) {
      _controller.text = widget.value;
      _controller.selection =
          TextSelection.collapsed(offset: _controller.text.length);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SESSION NAME',
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
          onChanged: widget.onChanged,
          textInputAction: TextInputAction.next,
          style: PaddleText.body(
            size: 15,
            weight: FontWeight.w700,
            color: PaddleColors.ink,
          ),
          decoration: InputDecoration(
            hintText: widget.placeholder,
            hintStyle: PaddleText.body(
              size: 15,
              weight: FontWeight.w400,
              color: PaddleColors.inkFaint,
            ),
            filled: true,
            fillColor: PaddleColors.tile,
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
        ),
      ],
    );
  }
}

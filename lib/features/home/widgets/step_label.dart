import 'package:flutter/material.dart';
import 'package:paddleq/core/theme/paddle_colors.dart';
import 'package:paddleq/core/theme/paddle_text.dart';

/// Numbered step label: black filled circle + uppercase tracked caption.
class StepLabel extends StatelessWidget {
  const StepLabel({super.key, required this.step, required this.text, this.padTop = 22});

  final int step;
  final String text;
  final double padTop;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(0, padTop, 0, 10),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: const BoxDecoration(color: PaddleColors.ink, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(
              '$step',
              style: PaddleText.display(size: 10, color: Colors.white, height: 1),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            text.toUpperCase(),
            style: PaddleText.label(
              size: 11,
              tracking: 0.14,
              weight: FontWeight.w700,
              color: PaddleColors.inkSoft,
            ),
          ),
        ],
      ),
    );
  }
}

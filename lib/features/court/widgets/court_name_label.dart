import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:paddleq/core/theme/paddle_colors.dart';
import 'package:paddleq/core/theme/paddle_text.dart';
import 'package:paddleq/core/widgets/paddle_icons.dart';
import 'package:paddleq/features/court/cubit/court_cubit.dart';

/// Tappable label that renders a court's display name (host-renamed, or
/// the default `Court N`) and opens a rename dialog on tap.
///
/// The custom name is stored in [CourtState.courtNames] — in-memory for
/// the lifetime of the cubit. A small pencil icon trails the name to make
/// the affordance discoverable.
class CourtNameLabel extends StatelessWidget {
  const CourtNameLabel({
    super.key,
    required this.idx,
    this.fontSize = 18,
    this.tracking = 0,
    this.color = PaddleColors.ink,
  });

  final int idx;
  final double fontSize;
  final double tracking;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<CourtCubit, CourtState, String>(
      selector: (s) => s.courtLabel(idx),
      builder: (context, label) {
        return InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _renameCourt(context, idx, label),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: PaddleText.display(
                      size: fontSize,
                      height: 1,
                      color: color,
                    ).copyWith(
                      letterSpacing: tracking == 0 ? null : tracking,
                    ),
                  ),
                ),
                SizedBox(width: fontSize * 0.34),
                PaddleIcon.edit(
                  color: PaddleColors.inkFaint,
                  size: fontSize * 0.7,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

Future<void> _renameCourt(BuildContext context, int idx, String current) async {
  final cubit = context.read<CourtCubit>();
  final controller = TextEditingController(text: current);
  final defaultName = 'Court $idx';

  await showDialog<void>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        backgroundColor: PaddleColors.tile,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'Rename court',
          style: PaddleText.display(size: 18, height: 1.1),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Names are saved for this session only.',
              style: PaddleText.body(
                  size: 12, color: PaddleColors.inkSoft, height: 1.4),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              maxLength: 30,
              style: PaddleText.body(size: 15, weight: FontWeight.w700),
              decoration: InputDecoration(
                hintText: defaultName,
                hintStyle: PaddleText.body(
                    size: 15, color: PaddleColors.inkFaint, weight: FontWeight.w700),
                filled: true,
                fillColor: Colors.white,
                counterText: '',
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: PaddleColors.line, width: 1.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                      color: PaddleColors.paddleGreen, width: 1.5),
                ),
              ),
              onSubmitted: (value) {
                cubit.renameCourt(idx, value);
                Navigator.of(ctx).pop();
              },
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(8, 0, 12, 12),
        actions: [
          TextButton(
            onPressed: () {
              cubit.renameCourt(idx, '');
              Navigator.of(ctx).pop();
            },
            child: Text(
              'Reset',
              style: PaddleText.display(
                  size: 13, color: PaddleColors.inkSoft, height: 1),
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancel',
              style: PaddleText.display(
                  size: 14, color: PaddleColors.inkSoft, height: 1),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: PaddleColors.paddleGreen,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              cubit.renameCourt(idx, controller.text);
              Navigator.of(ctx).pop();
            },
            child: Text(
              'Save',
              style: PaddleText.display(
                  size: 14, color: Colors.white, height: 1),
            ),
          ),
        ],
      );
    },
  );

  controller.dispose();
}

import 'package:flutter/material.dart';
import 'package:paddleq/core/api/api_exception.dart';
import 'package:paddleq/core/theme/paddle_colors.dart';
import 'package:paddleq/core/theme/paddle_text.dart';

/// Shows a friendly modal explaining a failed API call.
///
/// Surfaces the backend's `message` directly when available, plus the first
/// validation error per field for 400 responses. Pure presentation — caller
/// decides what to do after dismissal.
Future<void> showApiErrorDialog(
  BuildContext context,
  ApiException error, {
  String? title,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => _ApiErrorDialog(error: error, title: title),
  );
}

class _ApiErrorDialog extends StatelessWidget {
  const _ApiErrorDialog({required this.error, this.title});

  final ApiException error;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final resolvedTitle = title ?? _defaultTitle(error);
    final fieldErrors = error.validationErrors;

    return AlertDialog(
      backgroundColor: PaddleColors.tile,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(
        resolvedTitle,
        style: PaddleText.display(size: 18, height: 1.1),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            error.message,
            style: PaddleText.body(size: 14, color: PaddleColors.inkSoft, height: 1.4),
          ),
          if (fieldErrors != null && fieldErrors.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final entry in fieldErrors.entries)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '• ${entry.key}: ${entry.value.first}',
                  style: PaddleText.body(size: 12, color: PaddleColors.inkSoft),
                ),
              ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'OK',
            style: PaddleText.display(size: 14, color: PaddleColors.paddleGreen),
          ),
        ),
      ],
    );
  }

  static String _defaultTitle(ApiException e) {
    if (e.isNetwork) return "Can't reach PaddleQ";
    if (e.isConflict) return 'Heads up';
    if (e.isBadRequest) return 'Check your input';
    if (e.isNotFound) return 'Not found';
    if (e.isServer) return 'Server error';
    return 'Something went wrong';
  }
}

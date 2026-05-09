import 'dart:async';

import 'package:flutter/material.dart';
import 'package:paddleq/core/theme/paddle_colors.dart';
import 'package:paddleq/core/theme/paddle_text.dart';
import 'package:paddleq/core/widgets/paddle_icons.dart';

/// Live MM:SS counter ticking up from `match.startedAt`.
///
/// Designed for the per-court header. Returns an empty widget when
/// [startedAt] is null (no match yet); when set, runs a 1-second ticker
/// scoped to its own state so the parent card doesn't rebuild every tick.
///
/// Times are computed in UTC against `DateTime.now().toUtc()` to avoid
/// any timezone drift between client and server.
class MatchClock extends StatefulWidget {
  const MatchClock({
    super.key,
    required this.startedAt,
    this.size = 12,
    this.color = PaddleColors.inkSoft,
  });

  final DateTime? startedAt;
  final double size;
  final Color color;

  @override
  State<MatchClock> createState() => _MatchClockState();
}

class _MatchClockState extends State<MatchClock> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(covariant MatchClock old) {
    super.didUpdateWidget(old);
    if (old.startedAt != widget.startedAt) {
      _ticker?.cancel();
      _start();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _start() {
    if (widget.startedAt == null) return;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final start = widget.startedAt;
    if (start == null) return const SizedBox.shrink();

    final raw = DateTime.now().toUtc().difference(start.toUtc());
    final clamped = raw.isNegative ? Duration.zero : raw;
    final hours = clamped.inHours;
    final mm = (clamped.inMinutes % 60).toString().padLeft(2, '0');
    final ss = (clamped.inSeconds % 60).toString().padLeft(2, '0');
    final label = hours > 0 ? '$hours:$mm:$ss' : '$mm:$ss';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PaddleIcon.clock(color: widget.color, size: widget.size),
        SizedBox(width: widget.size * 0.5),
        Text(
          label,
          style: PaddleText.display(
            size: widget.size,
            color: widget.color,
            height: 1,
          ),
        ),
      ],
    );
  }
}

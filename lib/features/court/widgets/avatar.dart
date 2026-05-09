import 'package:flutter/material.dart';
import 'package:paddleq/core/theme/paddle_text.dart';

const _avatarColors = <Color>[
  Color(0xFF2D7749),
  Color(0xFF0E5FBA),
  Color(0xFFC24A1E),
  Color(0xFF7A3FB7),
  Color(0xFF1F1F1F),
  Color(0xFFC7891B),
  Color(0xFF2A8C8E),
  Color(0xFFA02A6E),
];

Color avatarColor(String name) {
  var h = 0;
  for (final code in name.codeUnits) {
    h = (h * 31 + code) & 0x7fffffff;
  }
  return _avatarColors[h % _avatarColors.length];
}

String avatarInitials(String name) {
  final parts = name.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts[0][0] + parts[1][0]).toUpperCase();
}

/// Solid-fill circular avatar with white initials. [tinted] = soft background
/// tint with the color used for the initials (used inside the team panels).
class Avatar extends StatelessWidget {
  const Avatar({
    super.key,
    required this.name,
    this.size = 38,
    this.tinted = false,
  });

  final String name;
  final double size;
  final bool tinted;

  @override
  Widget build(BuildContext context) {
    final color = avatarColor(name);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tinted ? color.withValues(alpha: 0.13) : color,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        avatarInitials(name),
        style: PaddleText.display(
          size: size * 0.34,
          color: tinted ? color : Colors.white,
          height: 1,
        ),
      ),
    );
  }
}

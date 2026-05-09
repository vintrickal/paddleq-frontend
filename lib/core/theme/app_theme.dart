import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:paddleq/core/theme/paddle_colors.dart';

abstract final class AppTheme {
  static ThemeData get light {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      colorScheme: const ColorScheme.light(
        primary: PaddleColors.paddleGreen,
        onPrimary: Colors.white,
        secondary: PaddleColors.paddleGreenDark,
        surface: PaddleColors.tile,
        onSurface: PaddleColors.ink,
      ),
      scaffoldBackgroundColor: PaddleColors.paper,
      textTheme: GoogleFonts.chivoTextTheme(base.textTheme).apply(
        bodyColor: PaddleColors.ink,
        displayColor: PaddleColors.ink,
      ),
    );
  }
}

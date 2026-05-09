import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:paddleq/core/theme/paddle_colors.dart';

/// Typography primitives mapped from the Claude Design handoff.
///
/// HTML class → Dart helper:
///   .t-wordmark → [wordmark]      (Faster One)
///   .t-display  → [display]       (Dela Gothic One)
///   .t-script   → [script]        (Covered By Your Grace / Indie Flower)
///   .t-label    → [label]         (Chivo 900, uppercase, tracked)
abstract final class PaddleText {
  static TextStyle wordmark({double size = 20, Color color = PaddleColors.ink}) =>
      GoogleFonts.fasterOne(
        fontSize: size,
        color: color,
        letterSpacing: size * 0.02,
        height: 1,
      );

  static TextStyle display({double size = 24, Color color = PaddleColors.ink, double height = 1.05}) =>
      GoogleFonts.delaGothicOne(
        fontSize: size,
        color: color,
        height: height,
        letterSpacing: size * 0.01,
      );

  static TextStyle script({double size = 16, Color color = PaddleColors.inkSoft}) =>
      GoogleFonts.coveredByYourGrace(fontSize: size, color: color);

  static TextStyle label({
    double size = 11,
    Color color = PaddleColors.inkSoft,
    FontWeight weight = FontWeight.w900,
    double tracking = 0.14,
  }) =>
      GoogleFonts.chivo(
        fontSize: size,
        color: color,
        fontWeight: weight,
        letterSpacing: size * tracking,
      );

  static TextStyle body({double size = 13, Color color = PaddleColors.ink, FontWeight weight = FontWeight.w400, double height = 1.5}) =>
      GoogleFonts.chivo(
        fontSize: size,
        color: color,
        fontWeight: weight,
        height: height,
      );
}

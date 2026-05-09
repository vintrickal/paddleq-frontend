import 'package:flutter/material.dart';

abstract final class PaddleColors {
  static const paddleGreen = Color(0xFF2D7749);
  static const paddleGreenDark = Color(0xFF225F3A);
  static const paddleGreenSoft = Color(0x1A2D7749);
  static const paddleGreenSoftStrong = Color(0x2D2D7749);

  static const ink = Color(0xFF141414);
  static const inkSoft = Color(0xFF5A5A5A);
  static const inkFaint = Color(0xFF8A8A8A);

  static const line = Color(0x14000000);
  static const lineSoft = Color(0x0A000000);
  static const lineMid = Color(0x1F000000);

  static const paper = Color(0xFFF3F3EF);
  static const paperLight = Color(0xFFFDFDFB);
  static const tile = Color(0xFFFFFFFF);

  static const warn = Color(0xFFC7891B);
  static const rest = Color(0xFF8A8A8A);
  static const active = Color(0xFF0E920E);

  /// Informational accent — used for the games-played pill and other
  /// neutral metadata badges.
  static const paddleBlue = Color(0xFF1D72B8);
  static const paddleBlueSoft = Color(0x141D72B8);

  /// Destructive accent — used for end-session and other irreversible actions.
  static const danger = Color(0xFFC53030);
  static const dangerSoft = Color(0x14C53030);

  static const overlay = Color(0x8C0F1411);
}

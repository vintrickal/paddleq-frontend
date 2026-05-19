import 'package:flutter/material.dart';
import 'package:paddleq/app.dart';

void main() {
  // Parse the initial URL once and decide whether to boot into the
  // public, deep-linked Player Profile page instead of the regular
  // host flow (Welcome → Home → Court). This is the *only* entry point
  // to the profile screen — it isn't reachable from the host UI.
  //
  //   /p/<publicId>   → render PlayerProfilePage(publicId)
  //   anything else   → normal app
  final segments = Uri.base.pathSegments;
  String? playerProfileId;
  for (var i = 0; i < segments.length - 1; i++) {
    if (segments[i] == 'p' && segments[i + 1].isNotEmpty) {
      playerProfileId = segments[i + 1];
      break;
    }
  }

  runApp(PaddleQApp(initialPlayerProfileId: playerProfileId));
}

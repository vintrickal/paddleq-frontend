import 'package:flutter/material.dart';
import 'package:paddleq/core/models/player_dtos.dart';
import 'package:paddleq/core/theme/paddle_colors.dart';
import 'package:paddleq/core/theme/paddle_text.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Modal shown after a new player has been registered + checked in. Displays
/// their permanent QR code so they can screenshot it and reuse it for
/// self-check-in next session.
Future<void> showPlayerQrDialog(BuildContext context, PlayerResponse player) {
  return showDialog<void>(
    context: context,
    builder: (_) => _PlayerQrDialog(player: player),
  );
}

class _PlayerQrDialog extends StatelessWidget {
  const _PlayerQrDialog({required this.player});
  final PlayerResponse player;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: PaddleColors.tile,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Player added',
                style: PaddleText.display(size: 18, height: 1.1),
              ),
              const SizedBox(height: 4),
              Text(
                'Save this QR — scan it to check in next time.',
                textAlign: TextAlign.center,
                style: PaddleText.body(
                    size: 13, color: PaddleColors.inkSoft, height: 1.4),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: PaddleColors.line),
                ),
                child: QrImageView(
                  data: player.qrCode,
                  version: QrVersions.auto,
                  size: 220,
                  gapless: true,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: PaddleColors.ink,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: PaddleColors.ink,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                player.name,
                textAlign: TextAlign.center,
                style: PaddleText.display(size: 18, height: 1.1),
              ),
              const SizedBox(height: 2),
              Text(
                'Skill ${_formatSkill(player.skillLevel)}',
                style: PaddleText.body(size: 12, color: PaddleColors.inkSoft),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: PaddleColors.paddleGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Done',
                    style: PaddleText.display(
                        size: 14, color: Colors.white, height: 1),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatSkill(double v) =>
      v == v.truncateToDouble() ? v.toStringAsFixed(1) : v.toString();
}

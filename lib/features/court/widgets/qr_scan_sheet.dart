import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:paddleq/core/api/api_exception.dart';
import 'package:paddleq/core/theme/paddle_colors.dart';
import 'package:paddleq/core/theme/paddle_text.dart';
import 'package:paddleq/core/widgets/paddle_icons.dart';
import 'package:paddleq/features/court/cubit/court_cubit.dart';

/// Bottom sheet (mobile) / dialog (desktop) for checking players in by QR.
///
/// Two modes — camera (default) and manual text entry. The host can scan
/// multiple players in one session: after each successful scan the camera
/// stays open and a brief banner confirms the check-in. Errors surface
/// inline so the camera feed isn't lost.
///
/// Open with [showQrScanSheet]; the `BuildContext` you pass must have a
/// [CourtCubit] in scope.
Future<void> showQrScanSheet(BuildContext context) {
  final cubit = context.read<CourtCubit>();
  final size = MediaQuery.sizeOf(context);
  final isDesktop = size.width >= 768;

  if (isDesktop) {
    return showDialog<void>(
      context: context,
      barrierColor: const Color(0x80000000),
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(40),
        backgroundColor: Colors.transparent,
        child: BlocProvider.value(
          value: cubit,
          child: const _QrScanSheet(),
        ),
      ),
    );
  }

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: const _QrScanSheet(),
    ),
  );
}

enum _Mode { camera, manual }

enum _BannerKind { none, success, error }

class _QrScanSheet extends StatefulWidget {
  const _QrScanSheet();

  @override
  State<_QrScanSheet> createState() => _QrScanSheetState();
}

class _QrScanSheetState extends State<_QrScanSheet> {
  static const _scanCooldown = Duration(milliseconds: 1800);

  late final MobileScannerController _scanner;
  final TextEditingController _manualCtrl = TextEditingController();

  _Mode _mode = _Mode.camera;
  bool _busy = false;
  String? _lastCode;
  DateTime? _lastScanAt;

  _BannerKind _bannerKind = _BannerKind.none;
  String? _bannerText;
  Timer? _bannerTimer;

  @override
  void initState() {
    super.initState();
    _scanner = MobileScannerController(
      formats: const [BarcodeFormat.qrCode],
      detectionSpeed: DetectionSpeed.noDuplicates,
    );
  }

  @override
  void dispose() {
    _scanner.dispose();
    _manualCtrl.dispose();
    _bannerTimer?.cancel();
    super.dispose();
  }

  void _showBanner(_BannerKind kind, String text) {
    _bannerTimer?.cancel();
    setState(() {
      _bannerKind = kind;
      _bannerText = text;
    });
    _bannerTimer = Timer(const Duration(milliseconds: 2400), () {
      if (!mounted) return;
      setState(() => _bannerKind = _BannerKind.none);
    });
  }

  Future<void> _handleCode(String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty || _busy) return;

    final now = DateTime.now();
    if (_lastCode == trimmed &&
        _lastScanAt != null &&
        now.difference(_lastScanAt!) < _scanCooldown) {
      return; // ignore the same code rapid-firing
    }
    _lastCode = trimmed;
    _lastScanAt = now;

    setState(() => _busy = true);
    try {
      final response = await context.read<CourtCubit>().checkInByQrCode(trimmed);
      if (!mounted) return;
      _showBanner(_BannerKind.success, '${response.playerName} — checked in');
      _manualCtrl.clear();
    } on ApiException catch (e) {
      if (!mounted) return;
      _showBanner(_BannerKind.error, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _onBarcode(BarcodeCapture capture) {
    if (_busy) return;
    for (final b in capture.barcodes) {
      final raw = b.rawValue;
      if (raw == null || raw.isEmpty) continue;
      _handleCode(raw);
      break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Material(
        color: PaddleColors.tile,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 480,
            maxHeight: MediaQuery.sizeOf(context).height * 0.86,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _Handle(),
              _Header(onClose: () => Navigator.of(context).pop()),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 6, 18, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_mode == _Mode.camera)
                        _CameraView(
                          controller: _scanner,
                          onBarcode: _onBarcode,
                          busy: _busy,
                        )
                      else
                        _ManualEntry(
                          controller: _manualCtrl,
                          onSubmit: _handleCode,
                          busy: _busy,
                        ),
                      const SizedBox(height: 12),
                      if (_bannerKind != _BannerKind.none)
                        _StatusBanner(kind: _bannerKind, text: _bannerText ?? ''),
                      const SizedBox(height: 14),
                      _ModeToggle(
                        mode: _mode,
                        onChanged: (m) {
                          setState(() {
                            _mode = m;
                            _bannerKind = _BannerKind.none;
                          });
                          if (m == _Mode.camera) {
                            unawaited(_scanner.start());
                          } else {
                            unawaited(_scanner.stop());
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Handle extends StatelessWidget {
  const _Handle();
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: const Color(0x2E000000),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      );
}

class _Header extends StatelessWidget {
  const _Header({required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 14, 6),
      child: Row(
        children: [
          Text('Scan player QR', style: PaddleText.display(size: 18, height: 1)),
          const Spacer(),
          IconButton(
            onPressed: onClose,
            icon: const PaddleIcon.x(color: PaddleColors.ink),
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }
}

class _CameraView extends StatelessWidget {
  const _CameraView({
    required this.controller,
    required this.onBarcode,
    required this.busy,
  });

  final MobileScannerController controller;
  final void Function(BarcodeCapture) onBarcode;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          fit: StackFit.expand,
          children: [
            MobileScanner(
              controller: controller,
              onDetect: onBarcode,
              errorBuilder: (context, error, _) => _CameraError(error: error),
              fit: BoxFit.cover,
            ),
            const _ViewfinderOverlay(),
            if (busy)
              ColoredBox(
                color: const Color(0x80000000),
                child: const Center(
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  ),
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 12,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xB3000000),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Point at the player\'s QR',
                    style: PaddleText.body(
                      size: 11,
                      color: Colors.white,
                      weight: FontWeight.w700,
                    ).copyWith(letterSpacing: 0.6),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ViewfinderOverlay extends StatelessWidget {
  const _ViewfinderOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(builder: (context, c) {
        final box = c.maxWidth * 0.66;
        return Center(
          child: Container(
            width: box,
            height: box,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.7), width: 2),
              boxShadow: const [
                BoxShadow(color: Color(0x66000000), blurRadius: 0, spreadRadius: 999),
              ],
            ),
          ),
        );
      }),
    );
  }
}

class _CameraError extends StatelessWidget {
  const _CameraError({required this.error});
  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: PaddleColors.ink,
      padding: const EdgeInsets.all(20),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "Camera unavailable",
            textAlign: TextAlign.center,
            style: PaddleText.display(size: 16, color: Colors.white, height: 1.2),
          ),
          const SizedBox(height: 8),
          Text(
            error.errorDetails?.message ?? 'Use "Type code instead" below.',
            textAlign: TextAlign.center,
            style: PaddleText.body(size: 12, color: Colors.white70, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _ManualEntry extends StatelessWidget {
  const _ManualEntry({
    required this.controller,
    required this.onSubmit,
    required this.busy,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSubmit;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: PaddleColors.paper,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: PaddleColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'PASTE OR TYPE QR CODE',
            style: PaddleText.label(
              size: 11,
              tracking: 0.12,
              weight: FontWeight.w900,
              color: PaddleColors.inkSoft,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            maxLines: 1,
            enabled: !busy,
            textInputAction: TextInputAction.done,
            onSubmitted: onSubmit,
            style: PaddleText.body(size: 14, weight: FontWeight.w700),
            decoration: InputDecoration(
              hintText: 'Paste the QR string',
              hintStyle: PaddleText.body(size: 14, color: PaddleColors.inkFaint),
              filled: true,
              fillColor: PaddleColors.tile,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: PaddleColors.line, width: 1.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: PaddleColors.line, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: PaddleColors.paddleGreen, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 10),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: PaddleColors.paddleGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed:
                busy ? null : () => onSubmit(controller.text),
            child: busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : Text(
                    'Check in',
                    style: PaddleText.display(size: 14, color: Colors.white, height: 1),
                  ),
          ),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.kind, required this.text});
  final _BannerKind kind;
  final String text;

  @override
  Widget build(BuildContext context) {
    final isError = kind == _BannerKind.error;
    final bg = isError ? PaddleColors.dangerSoft : PaddleColors.paddleGreenSoft;
    final fg = isError ? PaddleColors.danger : PaddleColors.paddleGreenDark;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fg.withValues(alpha: 0.25)),
      ),
      child: Text(
        text,
        style: PaddleText.body(size: 13, weight: FontWeight.w700, color: fg, height: 1.3),
      ),
    );
  }
}

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.mode, required this.onChanged});
  final _Mode mode;
  final ValueChanged<_Mode> onChanged;

  @override
  Widget build(BuildContext context) {
    final isManual = mode == _Mode.manual;
    return Center(
      child: TextButton.icon(
        style: TextButton.styleFrom(
          foregroundColor: PaddleColors.ink,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        ),
        onPressed: () => onChanged(isManual ? _Mode.camera : _Mode.manual),
        icon: isManual
            ? const PaddleIcon.qr(color: PaddleColors.ink)
            : const PaddleIcon.edit(color: PaddleColors.ink),
        label: Text(
          isManual ? 'Use camera instead' : 'Type code instead',
          style: PaddleText.body(size: 13, weight: FontWeight.w700, color: PaddleColors.ink),
        ),
      ),
    );
  }
}

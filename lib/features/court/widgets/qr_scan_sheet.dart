import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:paddleq/core/api/api_exception.dart';
import 'package:paddleq/core/api/paddleq_api.dart';
import 'package:paddleq/core/models/player_dtos.dart';
import 'package:paddleq/core/theme/paddle_colors.dart';
import 'package:paddleq/core/theme/paddle_text.dart';
import 'package:paddleq/core/widgets/paddle_icons.dart';
import 'package:paddleq/features/court/cubit/court_cubit.dart';
import 'package:paddleq/features/court/widgets/avatar.dart';

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

enum _Mode { camera, search }

enum _BannerKind { none, success, error }

class _QrScanSheet extends StatefulWidget {
  const _QrScanSheet();

  @override
  State<_QrScanSheet> createState() => _QrScanSheetState();
}

class _QrScanSheetState extends State<_QrScanSheet> {
  static const _scanCooldown = Duration(milliseconds: 1800);
  static const _searchDebounce = Duration(milliseconds: 300);
  static const _minSearchLen = 2;

  late final MobileScannerController _scanner;
  final TextEditingController _searchCtrl = TextEditingController();

  _Mode _mode = _Mode.camera;
  bool _busy = false;
  String? _lastCode;
  DateTime? _lastScanAt;

  /// Search state (only used when `_mode == _Mode.search`).
  List<PlayerSearchResult> _results = const [];
  bool _searching = false;
  String? _searchError;
  Timer? _debounce;

  /// Monotonic id incremented on each search dispatch, so out-of-order
  /// responses from earlier queries can be discarded.
  int _searchToken = 0;

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
    _searchCtrl.dispose();
    _bannerTimer?.cancel();
    _debounce?.cancel();
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

  /// Debounced search-as-you-type. Queries shorter than [_minSearchLen]
  /// clear the result list without hitting the API.
  void _onSearchQueryChanged(String raw) {
    _debounce?.cancel();
    final trimmed = raw.trim();
    if (trimmed.length < _minSearchLen) {
      setState(() {
        _results = const [];
        _searching = false;
        _searchError = null;
      });
      return;
    }
    _debounce = Timer(_searchDebounce, () => _runSearch(trimmed));
  }

  Future<void> _runSearch(String query) async {
    final token = ++_searchToken;
    setState(() {
      _searching = true;
      _searchError = null;
    });
    try {
      final api = context.read<PaddleqApi>();
      final hits = await api.searchPlayers(query);
      if (!mounted || token != _searchToken) return;
      setState(() {
        _results = hits;
        _searching = false;
      });
    } on ApiException catch (e) {
      if (!mounted || token != _searchToken) return;
      setState(() {
        _searching = false;
        _searchError = e.message;
        _results = const [];
      });
    }
  }

  Future<void> _handleResultTap(PlayerSearchResult result) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final response =
          await context.read<CourtCubit>().checkInByPlayerId(result.playerId);
      if (!mounted) return;
      _showBanner(_BannerKind.success, '${response.playerName} — checked in');
      // Wipe the search so the host is ready to look up the next player.
      // Any in-flight debounce is cancelled (its token won't match anymore)
      // and the results list collapses back to the type-to-search hint.
      _debounce?.cancel();
      _searchCtrl.clear();
      _searchToken++;
      setState(() {
        _results = const [];
        _searchError = null;
        _searching = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      _showBanner(_BannerKind.error, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
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
                        _SearchEntry(
                          controller: _searchCtrl,
                          results: _results,
                          searching: _searching,
                          busy: _busy,
                          error: _searchError,
                          onChanged: _onSearchQueryChanged,
                          onResultTap: _handleResultTap,
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
            error.errorDetails?.message ??
                'Use "Search by name instead" below.',
            textAlign: TextAlign.center,
            style: PaddleText.body(size: 12, color: Colors.white70, height: 1.4),
          ),
        ],
      ),
    );
  }
}

/// Name-search entry — replaces the old paste-QR field. The user types a
/// player's name; results from `GET /api/players/search` stream into a
/// tappable list below. Tapping a result fires `POST /api/queue/check-in-by-id`
/// via [_QrScanSheetState._handleResultTap].
class _SearchEntry extends StatelessWidget {
  const _SearchEntry({
    required this.controller,
    required this.results,
    required this.searching,
    required this.busy,
    required this.error,
    required this.onChanged,
    required this.onResultTap,
  });

  final TextEditingController controller;
  final List<PlayerSearchResult> results;
  final bool searching;
  final bool busy;
  final String? error;
  final ValueChanged<String> onChanged;
  final ValueChanged<PlayerSearchResult> onResultTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      decoration: BoxDecoration(
        color: PaddleColors.paper,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: PaddleColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'SEARCH PLAYER BY NAME',
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
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.search,
            enabled: !busy,
            onChanged: onChanged,
            style: PaddleText.body(size: 14, weight: FontWeight.w700),
            decoration: InputDecoration(
              hintText: 'Start typing a name…',
              hintStyle: PaddleText.body(size: 14, color: PaddleColors.inkFaint),
              filled: true,
              fillColor: PaddleColors.tile,
              prefixIcon: const Padding(
                padding: EdgeInsets.only(left: 12, right: 8),
                child: PaddleIcon.user(color: PaddleColors.inkSoft, size: 18),
              ),
              prefixIconConstraints:
                  const BoxConstraints(minWidth: 0, minHeight: 0),
              suffixIcon: searching
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          color: PaddleColors.paddleGreen,
                          strokeWidth: 2.2,
                        ),
                      ),
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: PaddleColors.line, width: 1.5),
              ),
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
          ),
          const SizedBox(height: 8),
          _SearchResults(
            controller: controller,
            results: results,
            searching: searching,
            busy: busy,
            error: error,
            onResultTap: onResultTap,
          ),
        ],
      ),
    );
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({
    required this.controller,
    required this.results,
    required this.searching,
    required this.busy,
    required this.error,
    required this.onResultTap,
  });

  final TextEditingController controller;
  final List<PlayerSearchResult> results;
  final bool searching;
  final bool busy;
  final String? error;
  final ValueChanged<PlayerSearchResult> onResultTap;

  @override
  Widget build(BuildContext context) {
    final query = controller.text.trim();
    final showHint = query.length < 2;
    if (error != null) {
      return _ResultsHint(text: error!, isError: true);
    }
    if (showHint) {
      return const _ResultsHint(
        text: 'Type at least 2 characters to search.',
        isError: false,
      );
    }
    if (results.isEmpty && !searching) {
      return _ResultsHint(
        text: 'No players matched “$query”.',
        isError: false,
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final r in results) ...[
          _ResultRow(
            result: r,
            disabled: busy,
            onTap: () => onResultTap(r),
          ),
          const SizedBox(height: 6),
        ],
      ],
    );
  }
}

class _ResultsHint extends StatelessWidget {
  const _ResultsHint({required this.text, required this.isError});
  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      child: Text(
        text,
        style: PaddleText.body(
          size: 12,
          color: isError ? PaddleColors.danger : PaddleColors.inkSoft,
          height: 1.4,
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.result,
    required this.disabled,
    required this.onTap,
  });

  final PlayerSearchResult result;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(12);
    return Opacity(
      opacity: disabled ? 0.55 : 1,
      child: Material(
        color: PaddleColors.tile,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: disabled ? null : onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: PaddleColors.line),
            ),
            child: Row(
              children: [
                Avatar(name: result.name, size: 32),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Flexible(
                            child: Text(
                              result.name,
                              style: PaddleText.body(
                                size: 14,
                                weight: FontWeight.w700,
                                height: 1.2,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '(${result.skillLevel.toStringAsFixed(1)})',
                            style: PaddleText.script(
                              size: 13,
                              color: PaddleColors.inkFaint,
                            ),
                          ),
                        ],
                      ),
                      if (result.currentQueueStatus != null) ...[
                        const SizedBox(height: 3),
                        _StatusBadge(status: result.currentQueueStatus!),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                const PaddleIcon.chevronRight(
                  color: PaddleColors.inkFaint,
                  size: 12,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pill mirroring the StatusPill colors but built from the raw backend
/// status string (since search results aren't local Players).
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'Playing' => PaddleColors.active,
      'Waiting' => PaddleColors.warn,
      'Resting' => PaddleColors.rest,
      _ => PaddleColors.inkFaint,
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          status,
          style: PaddleText.body(
            size: 11,
            color: color,
            weight: FontWeight.w700,
          ).copyWith(letterSpacing: 11 * 0.06),
        ),
      ],
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
    final isSearch = mode == _Mode.search;
    return Center(
      child: TextButton.icon(
        style: TextButton.styleFrom(
          foregroundColor: PaddleColors.ink,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        ),
        onPressed: () => onChanged(isSearch ? _Mode.camera : _Mode.search),
        icon: isSearch
            ? const PaddleIcon.qr(color: PaddleColors.ink)
            : const PaddleIcon.user(color: PaddleColors.ink),
        label: Text(
          isSearch ? 'Use camera instead' : 'Search by name instead',
          style: PaddleText.body(size: 13, weight: FontWeight.w700, color: PaddleColors.ink),
        ),
      ),
    );
  }
}

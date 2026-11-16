import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zenify/zenify.dart';

import '../../core/controllers.dart';
import '../../core/models.dart';
import '../../core/translation_service.dart';
import '../../ui/puzzle_icon.dart';
import '../scanner/unified_scan_screen.dart';
import 'ar_tabletop_puzzle_screen.dart';

/// Sober implementation of [MinigameFeatureSlot] providing:
/// 1. [launchFloatingPuzzleCatch] — per-station floating AR puzzle piece hunt.
/// 2. [launchGreenhouseActivity] — Greenhouse AR / 4-object scan activity slot for Nico.
/// 3. [buildFinalPuzzleScreen] — Tabletop AR 3x3 sliding-tile puzzle with corner hole fill.
class DefaultMinigameFeatureSlot implements MinigameFeatureSlot {
  const DefaultMinigameFeatureSlot({this.onOpenScannerCatch});

  final ValueChanged<String>? onOpenScannerCatch;

  @override
  Future<void> launchFloatingPuzzleCatch(
    BuildContext context, {
    required StationSpec station,
    required TourProgressController progress,
  }) async {
    final choice = await showModalBottomSheet<_PuzzleCatchChoice>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _FloatingPuzzlePreviewSheet(
        station: station,
        progress: progress,
      ),
    );

    if (!context.mounted || choice == null) return;

    switch (choice) {
      case _PuzzleCatchChoice.openLiveArScanner:
        final externalHook = onOpenScannerCatch;
        if (externalHook != null) {
          externalHook(station.id);
          return;
        }
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => _StandaloneArCatchRoute(station: station),
          ),
        );
      case _PuzzleCatchChoice.instantDemoCatch:
        unawaited(HapticFeedback.mediumImpact());
        progress.markPuzzlePieceCollected(station.id);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: TrText(
              'Collected puzzle piece for ${station.title} (${progress.collectedPuzzleCount}/${progress.totalPuzzleStations})',
            ),
          ),
        );
    }
  }

  @override
  Future<void> launchGreenhouseActivity(
    BuildContext context, {
    required TourProgressController progress,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _GreenhouseActivitySheet(),
    );
  }

  @override
  Widget buildFinalPuzzleScreen(
    BuildContext context, {
    required TourProgressController progress,
    required VoidCallback onBackToLobby,
  }) {
    return ArTabletopPuzzleScreen(
      progress: progress,
      onBackToLobby: onBackToLobby,
    );
  }
}

enum _PuzzleCatchChoice { openLiveArScanner, instantDemoCatch }

class _FloatingPuzzlePreviewSheet extends StatelessWidget {
  const _FloatingPuzzlePreviewSheet({
    required this.station,
    required this.progress,
  });

  final StationSpec station;
  final TourProgressController progress;

  @override
  Widget build(BuildContext context) {
    final alreadyCollected = progress.hasCollectedPiece(station.id);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: EdgeInsets.fromLTRB(
            24,
            22,
            24,
            MediaQuery.paddingOf(context).bottom + 24,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF22201E).withValues(alpha: 0.84),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: PuzzlePieceIcon(
                      collected: alreadyCollected,
                      size: 22,
                      activeColor: const Color(0xFFD9CBB8),
                      inactiveColor: const Color(0xFFF7F5F0),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TrText(
                          alreadyCollected
                              ? 'AR Puzzle Piece Collected'
                              : 'Floating AR Puzzle Piece Nearby',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFF9F7F3),
                          ),
                        ),
                        const SizedBox(height: 2),
                        TrText(
                          station.title,
                          style: TextStyle(
                            fontSize: 13,
                            color: const Color(
                              0xFFE8E2D8,
                            ).withValues(alpha: 0.78),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const TrText(
                'Open the AR camera to spot the floating puzzle piece around you and press the center shutter button to capture it.',
                style: TextStyle(
                  fontSize: 13.8,
                  height: 1.5,
                  color: Color(0xFFF0ECE4),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFF4F1EB),
                  foregroundColor: const Color(0xFF22201E),
                  minimumSize: const Size.fromHeight(50),
                ),
                onPressed: () => Navigator.of(
                  context,
                ).pop(_PuzzleCatchChoice.openLiveArScanner),
                icon: const Icon(Icons.camera_alt_outlined, size: 19),
                label: const TrText('Open AR Camera to Catch'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFF4F1EB),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.28)),
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: () => Navigator.of(
                  context,
                ).pop(_PuzzleCatchChoice.instantDemoCatch),
                child: const TrText('Quick Collect (Preview Mode)'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StandaloneArCatchRoute extends StatefulWidget {
  const _StandaloneArCatchRoute({required this.station});
  final StationSpec station;

  @override
  State<_StandaloneArCatchRoute> createState() =>
      _StandaloneArCatchRouteState();
}

class _StandaloneArCatchRouteState extends State<_StandaloneArCatchRoute> {
  final ScanShutterController _shutter = ScanShutterController();

  @override
  void dispose() {
    _shutter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: UnifiedScanScreen(
              shutterController: _shutter,
              initialCatchStationId: widget.station.id,
              onBackToLobby: () => Navigator.of(context).pop(),
              onOpenSideMenu: () => Navigator.of(context).pop(),
              onStationMatched: (_) => Navigator.of(context).pop(),
            ),
          ),
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: SafeArea(
              top: false,
              child: Center(
                child: Semantics(
                  button: true,
                  label: 'Capture floating AR puzzle piece',
                  child: GestureDetector(
                    onTap: _shutter.triggerShutter,
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFF7F5F0).withValues(alpha: 0.92),
                        border: Border.all(
                          color: const Color(0xFF262523),
                          width: 3,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Container(
                        width: 54,
                        height: 54,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF262523),
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          color: Color(0xFFF7F5F0),
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GreenhouseActivitySheet extends StatelessWidget {
  const _GreenhouseActivitySheet();

  @override
  Widget build(BuildContext context) {
    final progress = Zen.findOrNull<TourProgressController>();
    const items = [
      'Book on the dissertation shelf',
      'Velvet lounge chair',
      'Atrium staircase',
      'Power outlet by the study desks',
    ];

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: EdgeInsets.fromLTRB(
            24,
            22,
            24,
            MediaQuery.paddingOf(context).bottom + 24,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF22201E).withValues(alpha: 0.86),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const TrText(
                'Greenhouse Interactive Activity (Slot for Nico)',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFF9F7F3),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Ready for Nico\'s AR plant-moving marker activity or 4-object camera quest:',
                style: TextStyle(
                  fontSize: 13.5,
                  color: const Color(0xFFE8E2D8).withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(height: 14),
              for (final item in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.crop_free_rounded,
                        size: 16,
                        color: Color(0xFFD9CBB8),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TrText(
                          item,
                          style: const TextStyle(
                            fontSize: 13.5,
                            color: Color(0xFFF4F1EB),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 14),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFF4F1EB),
                  foregroundColor: const Color(0xFF22201E),
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: () {
                  progress?.unlockAndSetCurrentStation('greenhouse');
                  Navigator.of(context).pop();
                },
                child: const TrText('Close Preview'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

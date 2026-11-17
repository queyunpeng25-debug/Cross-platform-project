import 'package:flutter/material.dart';

import '../../core/controllers.dart';
import '../../core/models.dart';
import 'ar_tabletop_puzzle_screen.dart';
import 'station_minigames.dart';

/// Museum-styled implementation of [MinigameFeatureSlot] providing:
/// 1. [launchFloatingPuzzleCatch] — opens the dedicated 10-20s station mini-challenge.
/// 2. [launchGreenhouseActivity] — opens the Greenhouse 2x2 photo checklist activity.
/// 3. [buildFinalPuzzleScreen] — Tabletop AR 3x3 sliding-tile puzzle with dynamic master image slicing.
class DefaultMinigameFeatureSlot implements MinigameFeatureSlot {
  const DefaultMinigameFeatureSlot({this.onOpenScannerCatch});

  final ValueChanged<String>? onOpenScannerCatch;

  @override
  Future<void> launchFloatingPuzzleCatch(
    BuildContext context, {
    required StationSpec station,
    required TourProgressController progress,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StationMinigameHostSheet(
        station: station,
        progress: progress,
      ),
    );
  }

  @override
  Future<void> launchGreenhouseActivity(
    BuildContext context, {
    required TourProgressController progress,
  }) async {
    final spec = progress.catalog.findById('greenhouse') ??
        const StationSpec(
          id: 'greenhouse',
          title: 'Learning Hub Greenhouse',
          subtitle: '',
          floor: 1,
          floorLabel: '1st Floor · Room C130a',
          scanHintParenthetical: '',
          triggerModeSummary: '',
          heroAsset: 'assets/stations/greenhouse_1f.jpg',
          paragraphs: [],
          callouts: [],
          owner: StationOwner.andrea,
          normalizedX: 0.45,
          normalizedY: 0.52,
        );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StationMinigameHostSheet(
        station: spec,
        progress: progress,
      ),
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

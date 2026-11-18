import 'package:flutter/material.dart';

import '../../core/controllers.dart';
import '../../core/models.dart';
import 'ar_tabletop_puzzle_screen.dart';
import 'greenhouse_angle_minigame_screen.dart';
import 'station_minigames.dart';

/// Museum-styled implementation of [MinigameFeatureSlot] providing:
/// 1. [launchFloatingPuzzleCatch] — launches full-screen live camera AR mini-challenge.
/// 2. [launchGreenhouseActivity] — launches full-screen live camera AR Greenhouse photo quest.
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
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ArStationMinigameScreen(
          station: station,
          progress: progress,
        ),
      ),
    );
  }

  @override
  Future<void> launchGreenhouseActivity(
    BuildContext context, {
    required TourProgressController progress,
  }) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => GreenhouseAngleMinigameScreen(
          progress: progress,
        ),
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

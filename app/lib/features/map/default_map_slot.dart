import 'package:flutter/material.dart';

import '../../core/controllers.dart';
import 'building_map_screen.dart';

/// **Mustafa's** implementation of the [MapFeatureSlot] team contract.
///
/// The class keeps its original name so `main.dart` and the app shell do not
/// need any change: the shell calls [buildMapScreen] whenever the Map tab in
/// the bottom dock (or the Lobby's map shortcut) is opened.
///
/// Everything map-related lives in `lib/features/map/`:
/// - `building_map_screen.dart`   interactive map UI (floors, pins, details)
/// - `cs_building_map_data.dart`  floor-plan geometry, facilities, pin spots
/// - `floor_plan_painter.dart`    draws the floor plan
/// - `map_pins.dart` / `map_panels.dart`  pins, beacon, legend, controls
/// - `map_positioning.dart`       QR parsing + "You are here" logic
/// - `locate_scanner_screen.dart` camera scanner behind "Locate me"
///
/// Shared state used (read-only except for scans):
/// - `progress.catalog.stations`, `progress.statusFor(id)` (Red / Green /
///   Blue), `progress.isStationUnlocked(...)`, `progress.hasCollectedPiece(id)`
/// - `progress.unlockAndSetCurrentStation(id)` when a station QR is scanned
///   from the map, exactly like the main scanner does.
class DefaultMapFeatureSlot implements MapFeatureSlot {
  const DefaultMapFeatureSlot();

  @override
  Widget buildMapScreen(
    BuildContext context, {
    required TourProgressController progress,
    required AppSettingsController settings,
    required ValueChanged<String> onOpenStation,
    required VoidCallback onBackToLobby,
  }) {
    return CsBuildingMapScreen(
      progress: progress,
      settings: settings,
      onOpenStation: onOpenStation,
      onBackToLobby: onBackToLobby,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:zenify/zenify.dart';

import '../../core/controllers.dart';
import '../../core/models.dart';
import '../../core/translation_service.dart';

/// Minimal default implementation of [MapFeatureSlot] reserved for **Mustafa**.
///
/// ### Ready-to-Use API for Mustafa's Interactive Building Map
/// Replace [DefaultMapFeatureSlot] in `CsExplorerAppModule` (or edit this file)
/// and read/update live building tour state via [TourProgressController]:
/// - `progress.catalog.stations` -> `List<StationSpec>` with `floor`,
///   `floorLabel`, `normalizedX` (`0.0..1.0`), and `normalizedY` (`0.0..1.0`).
/// - `progress.statusFor(stationId)` -> [StationVisitStatus]:
///   - `StationVisitStatus.current`   -> **Red** marker (active user position)
///   - `StationVisitStatus.visited`   -> **Green** marker (previously reached)
///   - `StationVisitStatus.unvisited` -> **Blue** marker (not yet scanned)
/// - `progress.currentStationId.value` / `progress.visitedStationIds.value`
/// - `progress.collectedPuzzleIds.value` / `progress.hasCollectedPiece(id)`
/// - `progress.isStationUnlocked(id, demoUnlockAll: settings.demoUnlockAll.value)`
/// - `progress.unlockAndSetCurrentStation(id)` -> updates current position when
///   a map/floor QR code is scanned.
/// - `onOpenStation(stationId)` -> navigates to a station's guide page.
/// - `onBackToLobby()` -> returns to the Lobby guide screen.
class DefaultMapFeatureSlot implements MapFeatureSlot {
  const DefaultMapFeatureSlot();

  static const Color _redCurrent = Color(0xFFC94A38);
  static const Color _greenVisited = Color(0xFF2E6F4E);
  static const Color _blueUnvisited = Color(0xFF3A6EA5);

  @override
  Widget buildMapScreen(
    BuildContext context, {
    required TourProgressController progress,
    required AppSettingsController settings,
    required ValueChanged<String> onOpenStation,
    required VoidCallback onBackToLobby,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark
        ? theme.scaffoldBackgroundColor
        : const Color(0xFFF6F4EE);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: ZenObserver(() {
          final demoUnlock = settings.demoUnlockAll.value;
          final stations = progress.catalog.stations;

          final currentStations = stations
              .where(
                (s) => progress.statusFor(s.id) == StationVisitStatus.current,
              )
              .toList();
          final visitedStations = stations
              .where(
                (s) => progress.statusFor(s.id) == StationVisitStatus.visited,
              )
              .toList();
          final unvisitedStations = stations
              .where(
                (s) => progress.statusFor(s.id) == StationVisitStatus.unvisited,
              )
              .toList();

          final unlockedStations = stations
              .where(
                (s) => progress.isStationUnlocked(
                  s.id,
                  demoUnlockAll: demoUnlock,
                ),
              )
              .toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 128),
            children: [
              // Top bar with >= 48x48 `<` Back button
              Row(
                children: [
                  Semantics(
                    button: true,
                    label: 'Back to Lobby',
                    child: Material(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: onBackToLobby,
                        child: const SizedBox(
                          width: 48,
                          height: 48,
                          child: Icon(Icons.chevron_left_rounded, size: 28),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TrText(
                      'CS Building Map',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Minimal Module Slot Header Card for Mustafa
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                  side: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.6,
                    ),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFF3A5A78).withValues(
                                alpha: 0.14,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.map_outlined,
                              color: Color(0xFF3A5A78),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TrText(
                              'Interactive Building Map — Module Slot for Mustafa',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TrText(
                        'Reserved extension slot (MapFeatureSlot) so Mustafa can plug in his custom CS building floor-plan UI with full creative freedom while reading live station statuses and QR positioning from TourProgressController.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          height: 1.45,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.76,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Compact Live State Readout Card
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                  side: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.6,
                    ),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TrText(
                        'Live TourProgressController Readout',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _StatusReadoutRow(
                        dotColor: _redCurrent,
                        label: 'Current Red Station',
                        value: currentStations.isEmpty
                            ? 'None'
                            : currentStations.map((s) => s.title).join(', '),
                      ),
                      const Divider(height: 22),
                      _StatusReadoutRow(
                        dotColor: _greenVisited,
                        label: 'Visited Green Stations',
                        value: visitedStations.isEmpty
                            ? 'None yet'
                            : visitedStations.map((s) => s.title).join(', '),
                      ),
                      const Divider(height: 22),
                      _StatusReadoutRow(
                        dotColor: _blueUnvisited,
                        label: 'Unvisited Blue Stations',
                        value: unvisitedStations.isEmpty
                            ? 'All stations visited!'
                            : unvisitedStations.map((s) => s.title).join(', '),
                      ),
                      const Divider(height: 22),
                      _StatusReadoutRow(
                        dotColor: const Color(0xFFD99B26),
                        label: 'Collected Puzzle Pieces',
                        value:
                            '${progress.collectedPuzzleCount} / ${progress.totalPuzzleStations} pieces',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Clickable Unlocked Station Chips to verify `onOpenStation(id)`
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                  side: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.6,
                    ),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TrText(
                        'Test Unlocked Station Navigation (onOpenStation)',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TrText(
                        demoUnlock
                            ? 'Demo Mode is active — all stations are unlocked for testing.'
                            : 'Tap any unlocked station chip below to open its guide screen:',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.72,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final station in unlockedStations)
                            ActionChip(
                              materialTapTargetSize:
                                  MaterialTapTargetSize.padded,
                              avatar: Icon(
                                Icons.place_rounded,
                                size: 17,
                                color: switch (progress.statusFor(station.id)) {
                                  StationVisitStatus.current => _redCurrent,
                                  StationVisitStatus.visited => _greenVisited,
                                  StationVisitStatus.unvisited =>
                                    _blueUnvisited,
                                },
                              ),
                              label: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: TrText(
                                  '${station.title} (F${station.floor})',
                                ),
                              ),
                              onPressed: () => onOpenStation(station.id),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _StatusReadoutRow extends StatelessWidget {
  const _StatusReadoutRow({
    required this.dotColor,
    required this.label,
    required this.value,
  });

  final Color dotColor;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Container(
            width: 11,
            height: 11,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TrText(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              TrText(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.78),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

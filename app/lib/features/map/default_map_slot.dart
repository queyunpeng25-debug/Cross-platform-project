import 'package:flutter/material.dart';
import 'package:zenify/zenify.dart';

import '../../core/controllers.dart';
import '../../core/models.dart';
import '../../core/translation_service.dart';

/// Interactive Building Map feature slot displaying Floor 1 and Floor 2
/// architectural floor-plans with dynamic Point of Interest (POI) markers.
///
/// Markers reflect live [TourProgressController] status:
/// - Red (larger, pulsing): Current active user station
/// - Green: Visited stations
/// - Blue: Unvisited stations
/// - Puzzle piece badge: Station puzzle piece collected
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
    return _CsBuildingMapScreen(
      progress: progress,
      settings: settings,
      onOpenStation: onOpenStation,
      onBackToLobby: onBackToLobby,
    );
  }
}

class _CsBuildingMapScreen extends StatefulWidget {
  const _CsBuildingMapScreen({
    required this.progress,
    required this.settings,
    required this.onOpenStation,
    required this.onBackToLobby,
  });

  final TourProgressController progress;
  final AppSettingsController settings;
  final ValueChanged<String> onOpenStation;
  final VoidCallback onBackToLobby;

  @override
  State<_CsBuildingMapScreen> createState() => _CsBuildingMapScreenState();
}

class _CsBuildingMapScreenState extends State<_CsBuildingMapScreen>
    with SingleTickerProviderStateMixin {
  static const Color _redCurrent = Color(0xFFE53935);
  static const Color _greenVisited = Color(0xFF2E7D32);
  static const Color _blueUnvisited = Color(0xFF1976D2);
  static const Color _amberPuzzle = Color(0xFFF59E0B);

  late final AnimationController _pulseController;
  late final TransformationController _transformController;
  late int _selectedFloor;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    )..repeat();
    _transformController = TransformationController();

    // Auto-detect floor based on user's current / last-scanned station
    _selectedFloor = _detectUserCurrentFloor();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _transformController.dispose();
    super.dispose();
  }

  int _detectUserCurrentFloor() {
    final currentId = widget.progress.currentStationId.value;
    final current = widget.progress.catalog.findById(currentId);
    if (current == null) return 1;
    if (current.floor == 2) return 2;
    if (current.floor == 3) return 3;
    return 1;
  }

  void _selectFloor(int floor) {
    if (_selectedFloor != floor) {
      setState(() {
        _selectedFloor = floor;
        _transformController.value = Matrix4.identity();
      });
    }
  }

  void _resetZoom() {
    setState(() {
      _transformController.value = Matrix4.identity();
    });
  }

  String _shortStationLabel(String id) {
    switch (id) {
      case 'lobby':
        return 'CS Lobby';
      case 'greenhouse':
        return 'Greenhouse';
      case 'guilds':
        return 'Guild Rooms';
      case 'canteen':
        return 'Lunch & Subway';
      case 'portraits':
        return 'Portrait Gallery';
      case 'locked_corridors':
        return 'Locked Wings';
      case 'tuas_bridge':
        return 'TUAS Bridge';
      case 'computers':
        return 'Retro PC Exhibit';
      case 'study_places':
        return 'Loft & Pods';
      default:
        return 'Station';
    }
  }

  void _showStationModal(
    BuildContext context,
    StationSpec station,
    StationVisitStatus status,
    bool hasPiece,
    bool isUnlocked,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final Color statusColor;
    final String statusLabel;
    final IconData statusIcon;

    switch (status) {
      case StationVisitStatus.current:
        statusColor = _redCurrent;
        statusLabel = 'Current Station (You are here)';
        statusIcon = Icons.my_location_rounded;
      case StationVisitStatus.visited:
        statusColor = _greenVisited;
        statusLabel = 'Visited Station';
        statusIcon = Icons.check_circle_rounded;
      case StationVisitStatus.unvisited:
        statusColor = _blueUnvisited;
        statusLabel = 'Unvisited Station';
        statusIcon = Icons.place_rounded;
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E2622) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bottomSheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top drag handle
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Station Title & Close Button
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TrText(
                            station.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                            ),
                          ),
                          const SizedBox(height: 3),
                          TrText(
                            station.floorLabel,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.65,
                              ),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(bottomSheetContext).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Status Chips Row
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    // Visit status chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: statusColor.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 14, color: statusColor),
                          const SizedBox(width: 5),
                          TrText(
                            statusLabel,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Puzzle piece status chip
                    if (station.hasPuzzlePiece)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: hasPiece
                              ? _amberPuzzle.withValues(alpha: 0.16)
                              : theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: hasPiece
                                ? _amberPuzzle.withValues(alpha: 0.45)
                                : theme.colorScheme.outlineVariant,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '🧩',
                              style: TextStyle(
                                fontSize: 12,
                                color: hasPiece ? _amberPuzzle : null,
                              ),
                            ),
                            const SizedBox(width: 5),
                            TrText(
                              hasPiece
                                  ? 'Puzzle Piece Collected'
                                  : 'Puzzle Piece Waiting',
                              style: TextStyle(
                                color: hasPiece
                                    ? const Color(0xFFB45309)
                                    : theme.colorScheme.onSurfaceVariant,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),

                // Description
                TrText(
                  station.subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.78),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),

                // Action button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: isUnlocked
                      ? FilledButton.icon(
                          icon: const Icon(Icons.arrow_forward_rounded),
                          label: const TrText('Open Station Guide'),
                          onPressed: () {
                            Navigator.of(bottomSheetContext).pop();
                            widget.onOpenStation(station.id);
                          },
                        )
                      : OutlinedButton.icon(
                          icon: const Icon(Icons.qr_code_scanner_rounded),
                          label: const TrText(
                            'Locked — Scan on-site QR to unlock',
                          ),
                          onPressed: () =>
                              Navigator.of(bottomSheetContext).pop(),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark
        ? theme.scaffoldBackgroundColor
        : const Color(0xFFF6F4EE);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: ZenObserver(() {
          final currentStationFloor = _detectUserCurrentFloor();
          final demoUnlock = widget.settings.demoUnlockAll.value;

          return Column(
            children: [
              // 1. Top Bar: Back button, Title, and Zoom Reset
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                child: Row(
                  children: [
                    Semantics(
                      button: true,
                      label: 'Back to Lobby',
                      child: Material(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: widget.onBackToLobby,
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TrText(
                            'CS Building Map',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                          TrText(
                            'T-talo · Konemiehentie 2',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_selectedFloor != 3)
                      Semantics(
                        button: true,
                        label: 'Reset map zoom',
                        child: Material(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: _resetZoom,
                            child: const SizedBox(
                              width: 48,
                              height: 48,
                              child: Icon(
                                Icons.center_focus_strong_rounded,
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // 2. Floor Selector Tab Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: _FloorTabPill(
                        floor: 1,
                        title: '1st Floor',
                        subtitle: '6 stations',
                        isSelected: _selectedFloor == 1,
                        isUserHere: currentStationFloor == 1,
                        activeColor: _redCurrent,
                        onTap: () => _selectFloor(1),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _FloorTabPill(
                        floor: 2,
                        title: '2nd Floor',
                        subtitle: '2 stations',
                        isSelected: _selectedFloor == 2,
                        isUserHere: currentStationFloor == 2,
                        activeColor: _redCurrent,
                        onTap: () => _selectFloor(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _FloorTabPill(
                        floor: 3,
                        title: '3rd Floor',
                        subtitle: 'Loft & Pods',
                        isSelected: _selectedFloor == 3,
                        isUserHere: currentStationFloor == 3,
                        activeColor: _redCurrent,
                        onTap: () => _selectFloor(3),
                      ),
                    ),
                  ],
                ),
              ),

              // 3. User Location Quick-Jump Banner (if on a different floor)
              if (currentStationFloor != _selectedFloor)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 3,
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _selectFloor(currentStationFloor),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _redCurrent.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _redCurrent.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.my_location_rounded,
                            size: 15,
                            color: _redCurrent,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TrText(
                              'You are currently at Floor $currentStationFloor · Tap to view',
                              style: const TextStyle(
                                color: _redCurrent,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: _redCurrent,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // 4. Main Body: Floor 1/2 Interactive Viewer OR Floor 3 Card
              Expanded(
                child: _selectedFloor == 3
                    ? _buildFloor3View(context, demoUnlock)
                    : _buildInteractiveFloorMap(
                        context,
                        floor: _selectedFloor,
                        demoUnlock: demoUnlock,
                      ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildInteractiveFloorMap(
    BuildContext context, {
    required int floor,
    required bool demoUnlock,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final String mapAsset;
    final double mapWidth;
    final double mapHeight;

    if (floor == 1) {
      mapAsset = 'assets/map_floor_1.jpg';
      mapWidth = 508.0;
      mapHeight = 1024.0;
    } else {
      mapAsset = 'assets/map_floor_2.jpg';
      mapWidth = 681.0;
      mapHeight = 1024.0;
    }

    final stationsOnFloor = widget.progress.catalog.stations
        .where((s) => s.floor == floor)
        .toList();

    return Stack(
      children: [
        // Pinch-to-zoom interactive floor map
        InteractiveViewer(
          transformationController: _transformController,
          minScale: 0.8,
          maxScale: 4.5,
          boundaryMargin: const EdgeInsets.all(80),
          child: Center(
            child: FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                width: mapWidth,
                height: mapHeight,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Background architectural floorplan image
                    Image.asset(
                      mapAsset,
                      width: mapWidth,
                      height: mapHeight,
                      fit: BoxFit.fill,
                    ),

                    // Dynamic POI markers overlaid on user-specified positions
                    for (final station in stationsOnFloor)
                      _buildStationMarker(
                        context,
                        station: station,
                        mapWidth: mapWidth,
                        mapHeight: mapHeight,
                        demoUnlock: demoUnlock,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Floating Legend Pill at bottom (clear of floating dock)
        Positioned(
          left: 16,
          right: 16,
          bottom: 92,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: (isDark ? const Color(0xFF1B231F) : Colors.white)
                    .withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.16),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.4,
                  ),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _LegendDot(color: _redCurrent, label: 'Current'),
                  SizedBox(width: 12),
                  _LegendDot(color: _greenVisited, label: 'Visited'),
                  SizedBox(width: 12),
                  _LegendDot(color: _blueUnvisited, label: 'Unvisited'),
                  SizedBox(width: 12),
                  _LegendPuzzleDot(label: 'Puzzle 🧩'),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStationMarker(
    BuildContext context, {
    required StationSpec station,
    required double mapWidth,
    required double mapHeight,
    required bool demoUnlock,
  }) {
    final status = widget.progress.statusFor(station.id);
    final isCurrent = status == StationVisitStatus.current;
    final isVisited = status == StationVisitStatus.visited;
    final hasPiece = widget.progress.hasCollectedPiece(station.id);
    final isUnlocked = widget.progress.isStationUnlocked(
      station.id,
      demoUnlockAll: demoUnlock,
    );

    final cx = station.normalizedX * mapWidth;
    final cy = station.normalizedY * mapHeight;

    // Current is larger (38px diameter), visited/unvisited are 28px diameter
    final markerRadius = isCurrent ? 19.0 : 14.0;
    final markerDiameter = markerRadius * 2;

    return Positioned(
      left: cx - 65,
      top: cy - markerRadius,
      width: 130,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _showStationModal(
          context,
          station,
          status,
          hasPiece,
          isUnlocked,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Marker Dot + Pulsing Ripple + Puzzle Badge
            SizedBox(
              width: 56,
              height: 56,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  // Animated radar ripple for current station
                  if (isCurrent)
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, _) {
                        final val = _pulseController.value;
                        final rippleSize = markerDiameter + 16 * val;
                        final alpha = (1.0 - val) * 0.6;
                        return Container(
                          width: rippleSize,
                          height: rippleSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _redCurrent.withValues(alpha: alpha),
                              width: 2.5,
                            ),
                          ),
                        );
                      },
                    ),

                  // Main Colored Circle
                  Container(
                    width: markerDiameter,
                    height: markerDiameter,
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? _redCurrent
                          : (isVisited ? _greenVisited : _blueUnvisited),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: isCurrent ? 3.0 : 2.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (isCurrent ? _redCurrent : Colors.black)
                              .withValues(alpha: isCurrent ? 0.45 : 0.28),
                          blurRadius: isCurrent ? 8 : 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        isCurrent
                            ? Icons.my_location_rounded
                            : (isVisited
                                ? Icons.check_rounded
                                : Icons.place_rounded),
                        size: isCurrent ? 18 : 13,
                        color: Colors.white,
                      ),
                    ),
                  ),

                  // Small Puzzle Piece Badge at top-right if collected
                  if (hasPiece)
                    Positioned(
                      top: isCurrent ? 4 : 8,
                      right: isCurrent ? 4 : 8,
                      child: Container(
                        width: 17,
                        height: 17,
                        decoration: BoxDecoration(
                          color: _amberPuzzle,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.35),
                              blurRadius: 3,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text(
                            '🧩',
                            style: TextStyle(fontSize: 9),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Short Station Name Label Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.22),
                  width: 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: TrText(
                _shortStationLabel(station.id),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloor3View(BuildContext context, bool demoUnlock) {
    final theme = Theme.of(context);
    final loftStation = widget.progress.catalog.findById('study_places');

    final status = loftStation != null
        ? widget.progress.statusFor(loftStation.id)
        : StationVisitStatus.unvisited;
    final hasPiece = loftStation != null &&
        widget.progress.hasCollectedPiece(loftStation.id);
    final isUnlocked = loftStation != null &&
        widget.progress.isStationUnlocked(
          loftStation.id,
          demoUnlockAll: demoUnlock,
        );

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 120),
      children: [
        // Architectural Notice Card
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
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
                        color: const Color(0xFF6B4E71).withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.apartment_rounded,
                        color: Color(0xFF6B4E71),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TrText(
                            '3rd Floor Mezzanine & Study Loft',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          TrText(
                            'Parvi T1 & Walk-in Call Pods',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.65,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        size: 20,
                        color: Color(0xFFD97706),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: TrText(
                          'Floor plan unavailable for 3rd-floor gallery. Accessible via central stairs near CS Lobby.',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TrText(
                  'The 3rd floor houses Parvi T1, quiet study pods, and soundproof walk-in booths overlooking the central entrance hall. Take the main lobby stairs or 2F elevator.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.78),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Loft Station Status Card
        if (loftStation != null)
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
              side: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
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
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: switch (status) {
                            StationVisitStatus.current => _redCurrent,
                            StationVisitStatus.visited => _greenVisited,
                            StationVisitStatus.unvisited => _blueUnvisited,
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TrText(
                          loftStation.title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (hasPiece)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _amberPuzzle.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _amberPuzzle.withValues(alpha: 0.4),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('🧩', style: TextStyle(fontSize: 11)),
                              SizedBox(width: 4),
                              TrText(
                                'Collected',
                                style: TextStyle(
                                  color: Color(0xFFB45309),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TrText(
                    loftStation.subtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: isUnlocked
                        ? FilledButton.icon(
                            icon: const Icon(Icons.arrow_forward_rounded),
                            label: const TrText('Open 3rd Floor Guide'),
                            onPressed: () =>
                                widget.onOpenStation(loftStation.id),
                          )
                        : OutlinedButton.icon(
                            icon: const Icon(Icons.qr_code_scanner_rounded),
                            label: const TrText(
                              'Locked — Scan on-site QR to unlock',
                            ),
                            onPressed: () {},
                          ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 14),

        // Quick Floor Switchers
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.map_outlined),
                label: const TrText('1st Floor Map'),
                onPressed: () => _selectFloor(1),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.map_outlined),
                label: const TrText('2nd Floor Map'),
                onPressed: () => _selectFloor(2),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FloorTabPill extends StatelessWidget {
  const _FloorTabPill({
    required this.floor,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.isUserHere,
    required this.activeColor,
    required this.onTap,
  });

  final int floor;
  final String title;
  final String subtitle;
  final bool isSelected;
  final bool isUserHere;
  final Color activeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final bgColor = isSelected
        ? scheme.primary
        : (isDark ? const Color(0xFF232D28) : Colors.white);
    final fgColor = isSelected
        ? scheme.onPrimary
        : scheme.onSurface;
    final subColor = isSelected
        ? scheme.onPrimary.withValues(alpha: 0.78)
        : scheme.onSurfaceVariant;

    return Semantics(
      button: true,
      selected: isSelected,
      label: '$title, $subtitle',
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        elevation: isSelected ? 2 : 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? scheme.primary
                    : scheme.outlineVariant.withValues(alpha: 0.6),
                width: isSelected ? 1.5 : 1.0,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isUserHere) ...[
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white : activeColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                    Flexible(
                      child: TrText(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: fgColor,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                TrText(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: subColor,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1.2),
          ),
        ),
        const SizedBox(width: 5),
        TrText(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _LegendPuzzleDot extends StatelessWidget {
  const _LegendPuzzleDot({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('🧩', style: TextStyle(fontSize: 10)),
        const SizedBox(width: 4),
        TrText(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

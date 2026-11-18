/// Centralized puzzle configuration for the Final Tabletop AR Puzzle and
/// the Station-by-Station AR Spatial Puzzle Piece Hunt.
library;

/// The master image asset for the 3x3 puzzle tiles.
/// Converted to PNG from the user's provided master artwork.
const String kPuzzleImageAsset = 'assets/puzzle_master.png';

/// Fallback asset available in the repository if puzzle_master.png is not loaded.
const String kFallbackPuzzleImageAsset = 'assets/stations/greenhouse_1f.jpg';

/// Allows picking custom images at runtime during testing / Demo Mode.
const bool kAllowRuntimeImagePicker = true;

/// Preset assets available for fast in-app switching during demos/tests.
class PuzzlePresetImage {
  const PuzzlePresetImage({required this.title, required this.assetPath});

  final String title;
  final String assetPath;
}

const List<PuzzlePresetImage> kPuzzlePresetImages = [
  PuzzlePresetImage(
    title: 'Master Puzzle Artwork (Current)',
    assetPath: 'assets/puzzle_master.png',
  ),
  PuzzlePresetImage(
    title: 'Greenhouse Learning Hub',
    assetPath: 'assets/stations/greenhouse_1f.jpg',
  ),
  PuzzlePresetImage(
    title: 'CS Building Lobby (T-talo)',
    assetPath: 'assets/stations/lobby.jpg',
  ),
  PuzzlePresetImage(
    title: 'Evolution of Computers',
    assetPath: 'assets/stations/computers_2f.jpg',
  ),
  PuzzlePresetImage(
    title: 'CS Pioneers Gallery',
    assetPath: 'assets/stations/portraits_1f.jpg',
  ),
  PuzzlePresetImage(
    title: 'Sodexo Dining & Subway',
    assetPath: 'assets/stations/canteen_1f.jpg',
  ),
  PuzzlePresetImage(
    title: 'Student Guilds (TiK / Athene / DG)',
    assetPath: 'assets/stations/guilds_1f.jpg',
  ),
  PuzzlePresetImage(
    title: '3rd Floor Loft & Skylights',
    assetPath: 'assets/stations/study_3f.jpg',
  ),
  PuzzlePresetImage(
    title: 'Locked Corridors & PCB Wall',
    assetPath: 'assets/stations/locked_corridors_2f.jpg',
  ),
  PuzzlePresetImage(
    title: 'Skybridge to TUAS',
    assetPath: 'assets/stations/tuas_bridge_2f.jpg',
  ),
];

/// Defines the real-world 3D spatial positioning of a station's puzzle piece,
/// anchored relative to the physical station QR code / marker.
class StationPuzzleSpatialOffset {
  const StationPuzzleSpatialOffset({
    required this.stationId,
    required this.tileIndex,
    required this.gridRow,
    required this.gridCol,
    required this.azimuth,
    required this.elevation,
    required this.distance,
    required this.title,
    required this.hintDescription,
    required this.areaAnchorName,
  });

  /// The unique station ID matching [StationSpec.id].
  final String stationId;

  /// Index of the puzzle piece in the 3x3 grid (0 to 8).
  final int tileIndex;

  /// Row in the 3x3 puzzle grid (0: top, 1: middle, 2: bottom).
  final int gridRow;

  /// Column in the 3x3 puzzle grid (0: left, 1: center, 2: right).
  final int gridCol;

  /// Horizontal azimuth angle in degrees (-180° to +180°):
  /// 0° = straight ahead, -45° = left, +45° = right.
  final double azimuth;

  /// Vertical elevation pitch in degrees (-90° to +90°):
  /// 0° = horizontal eye level, >0 = look up, <0 = look down.
  final double elevation;

  /// Distance from the visitor / QR anchor in meters.
  final double distance;

  /// Display name of the piece.
  final String title;

  /// Guided spatial navigation hint for finding this piece in the real space.
  final String hintDescription;

  /// Physical anchor description in the campus building.
  final String areaAnchorName;

  /// Creates a copy with optional updated values (useful for per-session spatial randomization).
  StationPuzzleSpatialOffset copyWith({
    String? stationId,
    int? tileIndex,
    int? gridRow,
    int? gridCol,
    double? azimuth,
    double? elevation,
    double? distance,
    String? title,
    String? hintDescription,
    String? areaAnchorName,
  }) {
    return StationPuzzleSpatialOffset(
      stationId: stationId ?? this.stationId,
      tileIndex: tileIndex ?? this.tileIndex,
      gridRow: gridRow ?? this.gridRow,
      gridCol: gridCol ?? this.gridCol,
      azimuth: azimuth ?? this.azimuth,
      elevation: elevation ?? this.elevation,
      distance: distance ?? this.distance,
      title: title ?? this.title,
      hintDescription: hintDescription ?? this.hintDescription,
      areaAnchorName: areaAnchorName ?? this.areaAnchorName,
    );
  }
}

/// Exact world-locked spatial offsets for each of the 8 stations:
/// (The 9th space in the 3x3 sliding puzzle is the empty hole at bottom-right)
///
/// 1. `lobby`: Eye-level straight ahead (0° azimuth, 0° elevation, 2.2m) — Tutorial intro.
/// 2. `greenhouse`: Far left and elevated high into the indoor canopy (-75° azimuth, +42° elevation, 2.6m).
/// 3. `computers`: Turn right and look down above the retro vitrine (+95° azimuth, -16° elevation, 1.8m).
/// 4. `canteen`: Turn rear-left looking down towards cafeteria tables (-130° azimuth, -20° elevation, 1.7m).
/// 5. `guilds`: Turn rear-right floating outside guild entrance (+135° azimuth, +10° elevation, 2.2m).
/// 6. `study_places`: Overhead towards 3rd floor skylight loft (+60° azimuth, +48° elevation, 2.7m).
/// 7. `locked_corridors`: Turn almost backwards low near baseboard (-160° azimuth, -28° elevation, 1.6m).
/// 8. `tuas_bridge`: Turn left down the pedestrian bridge hallway (-85° azimuth, +12° elevation, 3.2m).
const Map<String, StationPuzzleSpatialOffset> kStationPuzzleOffsets = {
  'lobby': StationPuzzleSpatialOffset(
    stationId: 'lobby',
    tileIndex: 0,
    gridRow: 0,
    gridCol: 0,
    azimuth: 0.0,
    elevation: 0.0,
    distance: 2.2,
    title: 'Top-Left Piece',
    hintDescription: 'Look straight ahead at eye level in the main atrium (Tutorial)',
    areaAnchorName: 'Lobby Atrium QR Anchor',
  ),
  'greenhouse': StationPuzzleSpatialOffset(
    stationId: 'greenhouse',
    tileIndex: 1,
    gridRow: 0,
    gridCol: 1,
    azimuth: -75.0,
    elevation: 42.0,
    distance: 2.6,
    title: 'Top-Center Piece',
    hintDescription: 'Turn left and look high up towards the indoor canopy and wooden ceiling beams',
    areaAnchorName: 'Greenhouse C130a QR Anchor',
  ),
  'computers': StationPuzzleSpatialOffset(
    stationId: 'computers',
    tileIndex: 2,
    gridRow: 0,
    gridCol: 2,
    azimuth: 95.0,
    elevation: -16.0,
    distance: 1.8,
    title: 'Top-Right Piece',
    hintDescription: 'Turn right and look down, hovering near the vintage computers showcase',
    areaAnchorName: 'Vintage Computers Showcase QR Anchor',
  ),
  'canteen': StationPuzzleSpatialOffset(
    stationId: 'canteen',
    tileIndex: 3,
    gridRow: 1,
    gridCol: 0,
    azimuth: -130.0,
    elevation: -20.0,
    distance: 1.7,
    title: 'Middle-Left Piece',
    hintDescription: 'Turn around to your left and look downwards above the cafeteria dining tables',
    areaAnchorName: 'Sodexo Dining QR Anchor',
  ),
  'guilds': StationPuzzleSpatialOffset(
    stationId: 'guilds',
    tileIndex: 4,
    gridRow: 1,
    gridCol: 1,
    azimuth: 135.0,
    elevation: 10.0,
    distance: 2.2,
    title: 'Center Heart Piece',
    hintDescription: 'Turn around to your right, floating outside the student guild entrance',
    areaAnchorName: 'Guild Rooms QR Anchor',
  ),
  'study_places': StationPuzzleSpatialOffset(
    stationId: 'study_places',
    tileIndex: 5,
    gridRow: 1,
    gridCol: 2,
    azimuth: 60.0,
    elevation: 48.0,
    distance: 2.7,
    title: 'Middle-Right Piece',
    hintDescription: 'Turn right and look high up towards the skylight and roof trusses',
    areaAnchorName: '3rd Floor Loft QR Anchor',
  ),
  'locked_corridors': StationPuzzleSpatialOffset(
    stationId: 'locked_corridors',
    tileIndex: 6,
    gridRow: 2,
    gridCol: 0,
    azimuth: -160.0,
    elevation: -28.0,
    distance: 1.6,
    title: 'Bottom-Left Piece',
    hintDescription: 'Turn around backwards and look down near the floor baseboard and card reader',
    areaAnchorName: 'Locked Wing Card Reader QR Anchor',
  ),
  'tuas_bridge': StationPuzzleSpatialOffset(
    stationId: 'tuas_bridge',
    tileIndex: 7,
    gridRow: 2,
    gridCol: 1,
    azimuth: -85.0,
    elevation: 12.0,
    distance: 3.2,
    title: 'Bottom-Center Piece',
    hintDescription: 'Turn left and look down the pedestrian bridge hallway towards TUAS',
    areaAnchorName: 'TUAS Skybridge QR Anchor',
  ),
};

/// Retrieves the spatial offset definition for a given station ID.
StationPuzzleSpatialOffset getStationPuzzleOffset(String stationId) {
  return kStationPuzzleOffsets[stationId] ??
      StationPuzzleSpatialOffset(
        stationId: stationId,
        tileIndex: 0,
        gridRow: 0,
        gridCol: 0,
        azimuth: 0.0,
        elevation: 0.0,
        distance: 2.0,
        title: 'Puzzle Piece',
        hintDescription: 'Hovering nearby in AR space',
        areaAnchorName: 'Station QR Marker',
      );
}

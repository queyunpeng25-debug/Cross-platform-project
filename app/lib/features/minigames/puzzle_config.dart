/// Centralized puzzle configuration for the Final Tabletop AR Puzzle.
/// Allows swapping the master image dynamically without slicing 9 files manually.
library;

/// The master image asset for the 3x3 puzzle tiles.
/// If 'assets/puzzle_master.png' is present, it will be loaded; otherwise
/// the system automatically falls back to [kFallbackPuzzleImageAsset].
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

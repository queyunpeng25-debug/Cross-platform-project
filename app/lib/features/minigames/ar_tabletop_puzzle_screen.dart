import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:zenify/zenify.dart';

import '../../core/controllers.dart';
import '../../core/translation_service.dart';
import '../../ui/puzzle_icon.dart';
import 'puzzle_config.dart';

/// Sealed hierarchy representing runtime puzzle image sources.
sealed class PuzzleImageSource {
  const PuzzleImageSource();
}

class AssetPuzzleImageSource extends PuzzleImageSource {
  const AssetPuzzleImageSource(this.assetPath);
  final String assetPath;
}

class MemoryPuzzleImageSource extends PuzzleImageSource {
  const MemoryPuzzleImageSource(this.bytes);
  final Uint8List bytes;
}

/// Tabletop AR Sliding-Tile Final Puzzle (`3x3` square tiles with 1 corner hole):
/// 1. Dynamic master image slicing into 3x3 grid via code.
/// 2. Live camera / tabletop marker feed with Studio backdrop fallback.
/// 3. Runtime image picker to swap graphics during oral exams and testing.
/// 4. "Solve / Skip" fallback button for Demo Mode.
class ArTabletopPuzzleScreen extends StatefulWidget {
  const ArTabletopPuzzleScreen({
    super.key,
    required this.progress,
    required this.onBackToLobby,
  });

  final TourProgressController progress;
  final VoidCallback onBackToLobby;

  @override
  State<ArTabletopPuzzleScreen> createState() => _ArTabletopPuzzleScreenState();
}

class _ArTabletopPuzzleScreenState extends State<ArTabletopPuzzleScreen>
    with TickerProviderStateMixin {
  static const int _gridSize = 3;
  static const int _totalCells = _gridSize * _gridSize; // 9
  static const int _holeTileId = _totalCells - 1; // 8 (bottom-right corner)

  late final AnimationController _spawnController;
  late final AnimationController _cornerFillController;

  /// Current active image source (defaults to [kPuzzleImageAsset]).
  PuzzleImageSource _imageSource = const AssetPuzzleImageSource(kPuzzleImageAsset);

  /// Maps board cell `0..8` -> `tileId` (`0..7` are image tiles, `8` is the hole).
  late List<int> _board;

  /// Records valid scramble history so a subtle "Hint Step" can undo 1 step if desired.
  final List<int> _solutionStack = <int>[];

  bool _anchoredOnTable = true;
  bool _perspectiveTilt = true;
  bool _useCameraFeed = true;
  bool _isSolved = false;
  int _moves = 0;

  @override
  void initState() {
    super.initState();
    _spawnController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );
    _cornerFillController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 680),
    );
    _scrambleNewBoard(shuffleSteps: 16);
    _spawnController.forward(from: 0);
  }

  @override
  void dispose() {
    _spawnController.dispose();
    _cornerFillController.dispose();
    super.dispose();
  }

  void _scrambleNewBoard({int shuffleSteps = 16}) {
    final rng = math.Random();
    final next = List<int>.generate(_totalCells, (i) => i);
    _solutionStack.clear();

    var holeCell = _holeTileId;
    int? previousHoleCell;

    for (var step = 0; step < shuffleSteps; step++) {
      final neighbors = _orthogonalNeighbors(holeCell)
          .where((cell) => cell != previousHoleCell)
          .toList();
      final chosen = neighbors[rng.nextInt(neighbors.length)];
      _solutionStack.add(holeCell);
      next[holeCell] = next[chosen];
      next[chosen] = _holeTileId;
      previousHoleCell = holeCell;
      holeCell = chosen;
    }

    setState(() {
      _board = next;
      _moves = 0;
      _isSolved = false;
    });
    _cornerFillController.reset();
    _spawnController.forward(from: 0);
  }

  List<int> _orthogonalNeighbors(int cell) {
    final row = cell ~/ _gridSize;
    final col = cell % _gridSize;
    final result = <int>[];
    if (row > 0) result.add((row - 1) * _gridSize + col);
    if (row < _gridSize - 1) result.add((row + 1) * _gridSize + col);
    if (col > 0) result.add(row * _gridSize + (col - 1));
    if (col < _gridSize - 1) result.add(row * _gridSize + (col + 1));
    return result;
  }

  void _onTapCell(int tappedCell) {
    if (_isSolved || _spawnController.isAnimating) return;

    final holeCell = _board.indexOf(_holeTileId);
    if (!_orthogonalNeighbors(holeCell).contains(tappedCell)) return;

    HapticFeedback.selectionClick();
    setState(() {
      if (_solutionStack.isNotEmpty && _solutionStack.last == tappedCell) {
        _solutionStack.removeLast();
      } else {
        _solutionStack.add(holeCell);
      }

      _board[holeCell] = _board[tappedCell];
      _board[tappedCell] = _holeTileId;
      _moves++;

      if (_checkSolved()) {
        _isSolved = true;
        HapticFeedback.mediumImpact();
        _cornerFillController.forward(from: 0);
      }
    });
  }

  void _playHintStep() {
    if (_isSolved || _spawnController.isAnimating) return;
    if (_solutionStack.isEmpty) return;
    final nextCell = _solutionStack.last;
    _onTapCell(nextCell);
  }

  void _solveInstantly() {
    if (_isSolved) return;
    setState(() {
      _board = List<int>.generate(_totalCells, (i) => i);
      _moves++;
      _isSolved = true;
      _cornerFillController.forward(from: 0);
    });
    HapticFeedback.heavyImpact();
  }

  bool _checkSolved() {
    for (var i = 0; i < _totalCells; i++) {
      if (_board[i] != i) return false;
    }
    return true;
  }

  Offset _spawnScatterOffset(int tileId, double boardSize) {
    final angle = (tileId / 8.0) * math.pi * 2.0 - math.pi / 3;
    final radius = boardSize * 0.62;
    return Offset(math.cos(angle) * radius, math.sin(angle) * radius - 30);
  }

  Future<void> _openImagePickerSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => _ImagePickerSheet(
        onPickFromGallery: () async {
          Navigator.of(sheetContext).pop();
          try {
            final picker = ImagePicker();
            final file = await picker.pickImage(source: ImageSource.gallery);
            if (file != null) {
              final bytes = await file.readAsBytes();
              if (mounted) {
                setState(() {
                  _imageSource = MemoryPuzzleImageSource(bytes);
                });
                _scrambleNewBoard(shuffleSteps: 16);
              }
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: TrText('Unable to pick image: $e')),
              );
            }
          }
        },
        onSelectPreset: (preset) {
          Navigator.of(sheetContext).pop();
          setState(() {
            _imageSource = AssetPuzzleImageSource(preset.assetPath);
          });
          _scrambleNewBoard(shuffleSteps: 16);
        },
        onResetDefault: () {
          Navigator.of(sheetContext).pop();
          setState(() {
            _imageSource = const AssetPuzzleImageSource(kPuzzleImageAsset);
          });
          _scrambleNewBoard(shuffleSteps: 16);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = Zen.findOrNull<AppSettingsController>();
    final isDemoMode = settings?.demoUnlockAll.value ?? false;
    final showImagePickerButton = isDemoMode;

    return Scaffold(
      backgroundColor: const Color(0xFF141312),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Background Feed: Live MobileScanner Camera OR Studio Backdrop
          if (_useCameraFeed)
            MobileScanner(
              onDetect: (capture) {
                for (final code in capture.barcodes) {
                  final raw = code.rawValue?.trim() ?? '';
                  if (raw.contains('marker') || raw.contains('table')) {
                    if (!_anchoredOnTable && mounted) {
                      setState(() => _anchoredOnTable = true);
                    }
                  }
                }
              },
              errorBuilder: (_, _) => const _StudioTabletopBackdrop(),
            )
          else
            const _StudioTabletopBackdrop(),

          // Tabletop ambient vignette
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 0.95,
                    colors: [
                      Colors.black.withValues(alpha: 0.14),
                      Colors.black.withValues(alpha: 0.58),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 2. Top Bar (< Back to Lobby + Tabletop View Toggles)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                child: Row(
                  children: [
                    _TopGlassButton(
                      icon: Icons.chevron_left_rounded,
                      semanticsLabel: 'Back to Lobby',
                      onTap: widget.onBackToLobby,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF22201E,
                              ).withValues(alpha: 0.56),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.16),
                              ),
                            ),
                            child: Row(
                              children: [
                                const PuzzlePieceIcon(
                                  collected: true,
                                  size: 18,
                                  activeColor: Color(0xFFD9CBB8),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TrText(
                                    _isSolved
                                        ? 'Puzzle Completed!'
                                        : 'Tabletop AR Puzzle · Moves: $_moves',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFFF7F5F0),
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (showImagePickerButton)
                      _TopGlassButton(
                        icon: Icons.palette_outlined,
                        semanticsLabel: 'Change Test Image',
                        onTap: _openImagePickerSheet,
                      ),
                    const SizedBox(width: 8),
                    _TopGlassButton(
                      icon: _perspectiveTilt
                          ? Icons.view_in_ar_rounded
                          : Icons.grid_on_rounded,
                      semanticsLabel: 'Toggle 3D tabletop perspective',
                      onTap: () =>
                          setState(() => _perspectiveTilt = !_perspectiveTilt),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 3. Center Tabletop Anchored 3x3 Sliding Tile Board
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 72),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final shortest = math.min(
                    constraints.maxWidth - 40,
                    constraints.maxHeight - 240,
                  );
                  final boardSize = shortest.clamp(200.0, 340.0);
                final tileSize = boardSize / _gridSize;

                final matrix = Matrix4.identity();
                if (_perspectiveTilt) {
                  matrix
                    ..setEntry(3, 2, 0.0011)
                    ..rotateX(-0.24);
                }

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutCubic,
                  transform: matrix,
                  transformAlignment: Alignment.center,
                  child: Container(
                    width: boardSize + 20,
                    height: boardSize + 20,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF242220).withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: const Color(0xFFD9CBB8).withValues(alpha: 0.42),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.48),
                          blurRadius: 32,
                          offset: const Offset(0, 18),
                        ),
                      ],
                    ),
                    child: AnimatedBuilder(
                      animation: Listenable.merge([
                        _spawnController,
                        _cornerFillController,
                      ]),
                      builder: (context, _) {
                        final spawnT = Curves.easeOutBack.transform(
                          _spawnController.value.clamp(0.0, 1.0),
                        );
                        final cornerT = Curves.easeOutCubic.transform(
                          _cornerFillController.value.clamp(0.0, 1.0),
                        );

                        final gap = _isSolved ? (3.0 * (1.0 - cornerT)) : 3.0;

                        final cellOfTile = <int, int>{};
                        for (var cell = 0; cell < _totalCells; cell++) {
                          cellOfTile[_board[cell]] = cell;
                        }

                        return SizedBox(
                          width: boardSize,
                          height: boardSize,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              // Recessed grid bed
                              Positioned.fill(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF141312,
                                    ).withValues(alpha: 0.72),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),

                              // 8 Sliding Image Tiles (tileId 0..7)
                              for (var tileId = 0; tileId < _holeTileId; tileId++)
                                _buildSlidingTile(
                                  tileId: tileId,
                                  currentCell: cellOfTile[tileId] ?? tileId,
                                  tileSize: tileSize,
                                  boardSize: boardSize,
                                  gap: gap,
                                  spawnProgress: spawnT,
                                ),

                              // Missing 9th Corner Piece (tileId 8)
                              if (_isSolved)
                                Positioned(
                                  left: 2 * tileSize + gap * 0.5,
                                  top:
                                      2 * tileSize +
                                      gap * 0.5 -
                                      (1.0 - cornerT) * 38.0,
                                  width: tileSize - gap,
                                  height: tileSize - gap,
                                  child: Opacity(
                                    opacity: cornerT.clamp(0.0, 1.0),
                                    child: _CroppedPictureTile(
                                      tileId: _holeTileId,
                                      gridSize: _gridSize,
                                      fullBoardSize: boardSize,
                                      imageSource: _imageSource,
                                      borderRadius: _isSolved && cornerT > 0.95
                                          ? 0
                                          : 8,
                                      showNumberBadge: false,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
            ),
          ),

          // 4. Bottom Controls & Instructions
          Positioned(
            left: 16,
            right: 16,
            bottom: 100,
            child: SafeArea(
              top: false,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF22201E).withValues(alpha: 0.64),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.16),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TrText(
                          _isSolved
                              ? 'All tiles aligned — the missing corner piece locked in to complete the picture!'
                              : 'Point at a tabletop surface and tap any tile next to the empty space to slide it into place.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFFF4F1EB),
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            _BottomControlChip(
                              icon: Icons.refresh_rounded,
                              label: 'Shuffle Table',
                              onTap: () => _scrambleNewBoard(shuffleSteps: 16),
                            ),
                            if (!_isSolved && _solutionStack.isNotEmpty)
                              _BottomControlChip(
                                icon: Icons.auto_fix_high_rounded,
                                label: 'Hint Move',
                                onTap: _playHintStep,
                              ),
                            _BottomControlChip(
                              icon: _useCameraFeed
                                  ? Icons.videocam_outlined
                                  : Icons.videocam_off_outlined,
                              label: _useCameraFeed
                                  ? 'AR Camera On'
                                  : 'Tabletop Studio',
                              onTap: () => setState(
                                () => _useCameraFeed = !_useCameraFeed,
                              ),
                            ),
                            if (showImagePickerButton)
                              _BottomControlChip(
                                icon: Icons.image_outlined,
                                label: 'Change Image',
                                onTap: _openImagePickerSheet,
                              ),
                            if (isDemoMode && !_isSolved)
                              _BottomControlChip(
                                icon: Icons.fast_forward_rounded,
                                label: 'Solve / Skip (Demo)',
                                onTap: _solveInstantly,
                              ),
                          ],
                        ),
                      ],
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

  Widget _buildSlidingTile({
    required int tileId,
    required int currentCell,
    required double tileSize,
    required double boardSize,
    required double gap,
    required double spawnProgress,
  }) {
    final targetRow = currentCell ~/ _gridSize;
    final targetCol = currentCell % _gridSize;
    final targetLeft = targetCol * tileSize + gap * 0.5;
    final targetTop = targetRow * tileSize + gap * 0.5;

    final scatter = _spawnScatterOffset(tileId, boardSize);
    final introDx = scatter.dx * (1.0 - spawnProgress);
    final introDy = scatter.dy * (1.0 - spawnProgress);

    return AnimatedPositioned(
      key: ValueKey<int>(tileId),
      duration: const Duration(milliseconds: 190),
      curve: Curves.easeOutCubic,
      left: targetLeft + introDx,
      top: targetTop + introDy,
      width: tileSize - gap,
      height: tileSize - gap,
      child: GestureDetector(
        onTap: () => _onTapCell(currentCell),
        child: Semantics(
          button: true,
          label: 'Puzzle tile ${tileId + 1}',
          child: _CroppedPictureTile(
            tileId: tileId,
            gridSize: _gridSize,
            fullBoardSize: boardSize,
            imageSource: _imageSource,
            borderRadius: _isSolved ? 0 : 8,
            showNumberBadge: !_isSolved,
          ),
        ),
      ),
    );
  }
}

/// Slices the master image dynamically into 3x3 tiles without manual 9-file cropping.
class _CroppedPictureTile extends StatelessWidget {
  const _CroppedPictureTile({
    required this.tileId,
    required this.gridSize,
    required this.fullBoardSize,
    required this.imageSource,
    required this.borderRadius,
    required this.showNumberBadge,
  });

  final int tileId;
  final int gridSize;
  final double fullBoardSize;
  final PuzzleImageSource imageSource;
  final double borderRadius;
  final bool showNumberBadge;

  @override
  Widget build(BuildContext context) {
    final homeRow = tileId ~/ gridSize;
    final homeCol = tileId % gridSize;
    final cellSpan = fullBoardSize / gridSize;

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            left: -homeCol * cellSpan,
            top: -homeRow * cellSpan,
            width: fullBoardSize,
            height: fullBoardSize,
            child: _buildImage(imageSource, fullBoardSize),
          ),
          if (showNumberBadge)
            Positioned(
              top: 6,
              left: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.58),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${tileId + 1}',
                  style: const TextStyle(
                    color: Color(0xFFF7F5F0),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImage(PuzzleImageSource source, double size) {
    return switch (source) {
      AssetPuzzleImageSource(:final assetPath) => Image.asset(
          assetPath,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Image.asset(
            kFallbackPuzzleImageAsset,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => ColoredBox(
              color: Color.lerp(
                const Color(0xFF4A433B),
                const Color(0xFF8A7B68),
                tileId / 8.0,
              )!,
            ),
          ),
        ),
      MemoryPuzzleImageSource(:final bytes) => Image.memory(
          bytes,
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
    };
  }
}

class _ImagePickerSheet extends StatelessWidget {
  const _ImagePickerSheet({
    required this.onPickFromGallery,
    required this.onSelectPreset,
    required this.onResetDefault,
  });

  final VoidCallback onPickFromGallery;
  final ValueChanged<PuzzlePresetImage> onSelectPreset;
  final VoidCallback onResetDefault;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: EdgeInsets.fromLTRB(
            22,
            16,
            22,
            MediaQuery.paddingOf(context).bottom + 20,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1D1B).withValues(alpha: 0.94),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.20)),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4.5,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.32),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const TrText(
                    'Select Test Puzzle Image',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFF7F5F0),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFFF7F5F0)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFF4F1EB),
                  foregroundColor: const Color(0xFF22201E),
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: onPickFromGallery,
                icon: const Icon(Icons.photo_library_outlined, size: 19),
                label: const TrText('Pick Image from Device Gallery'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFF4F1EB),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.24)),
                  minimumSize: const Size.fromHeight(44),
                ),
                onPressed: onResetDefault,
                icon: const Icon(Icons.restart_alt_rounded, size: 18),
                label: const TrText('Reset to Master Asset (puzzle_master.png)'),
              ),
              const SizedBox(height: 14),
              const TrText(
                'Or Choose from Preset Station Photos:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFD9CBB8),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 110,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: kPuzzlePresetImages.length,
                  itemBuilder: (context, index) {
                    final preset = kPuzzlePresetImages[index];
                    return GestureDetector(
                      onTap: () => onSelectPreset(preset),
                      child: Container(
                        width: 100,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2B2824),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                                child: Image.asset(
                                  preset.assetPath,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFF4A433B)),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(6),
                              child: TrText(
                                preset.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  color: Color(0xFFF7F5F0),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudioTabletopBackdrop extends StatelessWidget {
  const _StudioTabletopBackdrop();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF2C2824),
            Color(0xFF1D1B19),
            Color(0xFF141312),
          ],
        ),
      ),
    );
  }
}

class _TopGlassButton extends StatelessWidget {
  const _TopGlassButton({
    required this.icon,
    required this.semanticsLabel,
    required this.onTap,
  });

  final IconData icon;
  final String semanticsLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticsLabel,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Material(
            color: const Color(0xFF22201E).withValues(alpha: 0.56),
            child: InkWell(
              onTap: onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                child: Icon(icon, color: const Color(0xFFF7F5F0), size: 20),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomControlChip extends StatelessWidget {
  const _BottomControlChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40, minWidth: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 15, color: const Color(0xFFD9CBB8)),
                  const SizedBox(width: 6),
                  TrText(
                    label,
                    style: const TextStyle(
                      color: Color(0xFFF7F5F0),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

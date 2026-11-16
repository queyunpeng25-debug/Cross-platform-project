import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/controllers.dart';
import '../../core/translation_service.dart';
import '../../ui/puzzle_icon.dart';

/// Tabletop AR Sliding-Tile Final Puzzle (`3x3` square tiles with 1 corner hole):
/// 1. Live camera / tabletop marker feed (`cs-guide://marker/tabletop` or manual
///    table placement fallback, ready for Nico's physical table markers).
/// 2. Collected tiles spawn floating around the screen and settle onto the
///    3D perspective-tilted tabletop frame.
/// 3. User slides adjacent tiles into the single empty slot ("hole") until all
///    8 tiles align, leaving the hole in the bottom-right corner.
/// 4. Once aligned, the missing 9th corner tile automatically materializes into
///    the corner hole to complete the full seamless photograph!
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
  static const String _puzzleImageAsset = 'assets/stations/greenhouse_1f.jpg';

  late final AnimationController _spawnController;
  late final AnimationController _cornerFillController;

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
      // Record the previous hole cell so tapping it later reverses this move
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141312),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Live AR Camera Tabletop Feed (with automatic matte tabletop fallback)
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

          // Subtle tabletop vignette
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
                    const SizedBox(width: 10),
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                final shortest = math.min(
                  constraints.maxWidth - 40,
                  constraints.maxHeight - 230,
                );
                final boardSize = shortest.clamp(240.0, 360.0);
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

                        // Locate where each tileId currently sits on the board
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
                              // Recessed tabletop empty grid bed (visible at the hole)
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

                              // Missing 9th Corner Piece (tileId 8) — fills the bottom-right hole upon completion!
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
                                      assetPath: _puzzleImageAsset,
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

          // 4. Bottom Translucent Instructions & Tabletop Controls
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
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
                          spacing: 10,
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
            assetPath: _puzzleImageAsset,
            borderRadius: _isSolved ? 0 : 8,
            showNumberBadge: !_isSolved,
          ),
        ),
      ),
    );
  }
}

class _CroppedPictureTile extends StatelessWidget {
  const _CroppedPictureTile({
    required this.tileId,
    required this.gridSize,
    required this.fullBoardSize,
    required this.assetPath,
    required this.borderRadius,
    required this.showNumberBadge,
  });

  final int tileId;
  final int gridSize;
  final double fullBoardSize;
  final String assetPath;
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
            child: Image.asset(
              assetPath,
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
          if (showNumberBadge)
            Positioned(
              top: 6,
              left: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.48),
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
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                child: Icon(icon, color: const Color(0xFFF7F5F0), size: 22),
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
            constraints: const BoxConstraints(minHeight: 44, minWidth: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 16, color: const Color(0xFFD9CBB8)),
                  const SizedBox(width: 6),
                  TrText(
                    label,
                    style: const TextStyle(
                      color: Color(0xFFF7F5F0),
                      fontSize: 12.5,
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

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zenify/zenify.dart';

import '../../core/controllers.dart';
import '../../core/models.dart';
import '../../core/translation_service.dart';
import '../../ui/puzzle_icon.dart';

/// Modal host sheet presenting the station-specific mini-challenge (10-20 seconds).
/// On completion, calls [TourProgressController.markPuzzlePieceCollected].
class StationMinigameHostSheet extends StatefulWidget {
  const StationMinigameHostSheet({
    super.key,
    required this.station,
    required this.progress,
  });

  final StationSpec station;
  final TourProgressController progress;

  @override
  State<StationMinigameHostSheet> createState() => _StationMinigameHostSheetState();
}

class _StationMinigameHostSheetState extends State<StationMinigameHostSheet> {
  bool _completed = false;

  void _onChallengeCompleted() {
    if (_completed) return;
    HapticFeedback.heavyImpact();
    setState(() {
      _completed = true;
    });
    widget.progress.markPuzzlePieceCollected(widget.station.id);
  }

  @override
  Widget build(BuildContext context) {
    final settings = Zen.findOrNull<AppSettingsController>();
    final isDemoMode = settings?.demoUnlockAll.value ?? false;
    final alreadyCollected = widget.progress.hasCollectedPiece(widget.station.id);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.92,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1D1B).withValues(alpha: 0.94),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.20)),
            ),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                MediaQuery.paddingOf(context).bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Drag handle
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

                  // Header Bar
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.16),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: PuzzlePieceIcon(
                          collected: alreadyCollected || _completed,
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
                              widget.station.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFF7F5F0),
                              ),
                            ),
                            const SizedBox(height: 2),
                            TrText(
                              widget.station.floorLabel,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: const Color(0xFFE8E2D8).withValues(alpha: 0.72),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Color(0xFFF7F5F0)),
                        tooltip: 'Close',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Color(0xFF33302C), height: 1),
                  const SizedBox(height: 16),

                  // Success Celebration Card
                  if (_completed)
                    _VictoryCard(
                      stationTitle: widget.station.title,
                      collectedCount: widget.progress.collectedPuzzleCount,
                      totalCount: widget.progress.totalPuzzleStations,
                      onClose: () => Navigator.of(context).pop(),
                    )
                  else
                    // Active Mini-challenge
                    _buildMinigameForStation(widget.station.id),

                  const SizedBox(height: 16),

                  // Demo Quick-Solve Bar
                  if (!_completed && isDemoMode)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFD9CBB8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onPressed: _onChallengeCompleted,
                        icon: const Icon(Icons.flash_on_rounded, size: 16),
                        label: const TrText('Quick Solve (Demo Mode)'),
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

  Widget _buildMinigameForStation(String id) {
    return switch (id) {
      'lobby' => LobbyOrbsMinigame(onSuccess: _onChallengeCompleted),
      'computers' => ComputersTimelineMinigame(onSuccess: _onChallengeCompleted),
      'greenhouse' => GreenhousePhotoMinigame(onSuccess: _onChallengeCompleted),
      'portraits' => PortraitsQuizMinigame(onSuccess: _onChallengeCompleted),
      'canteen' => CanteenSubwayMinigame(onSuccess: _onChallengeCompleted),
      'guilds' => GuildsMatchMinigame(onSuccess: _onChallengeCompleted),
      'study_places' => StudyPlacesRoomRushMinigame(onSuccess: _onChallengeCompleted),
      'locked_corridors' => LockedCorridorsPcbMinigame(onSuccess: _onChallengeCompleted),
      'tuas_bridge' => TuasBridgeCompassMinigame(onSuccess: _onChallengeCompleted),
      _ => LobbyOrbsMinigame(onSuccess: _onChallengeCompleted),
    };
  }
}

class _VictoryCard extends StatelessWidget {
  const _VictoryCard({
    required this.stationTitle,
    required this.collectedCount,
    required this.totalCount,
    required this.onClose,
  });

  final String stationTitle;
  final int collectedCount;
  final int totalCount;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2B2824),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD9CBB8).withValues(alpha: 0.40)),
      ),
      child: Column(
        children: [
          const PuzzlePieceIcon(
            collected: true,
            size: 48,
            activeColor: Color(0xFFD9CBB8),
          ),
          const SizedBox(height: 14),
          const TrText(
            'Challenge Completed!',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFFF7F5F0),
            ),
          ),
          const SizedBox(height: 6),
          TrText(
            'You unlocked the puzzle piece for $stationTitle ($collectedCount / $totalCount collected).',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13.5,
              color: Color(0xFFE8E2D8),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFF4F1EB),
              foregroundColor: const Color(0xFF22201E),
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: onClose,
            icon: const Icon(Icons.check_circle_outline_rounded, size: 19),
            label: const TrText('Claim & Return to Station'),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 1. LOBBY MINIGAME: AR Orb Tap (George W. Hart suspended spheres)
// ============================================================================
class LobbyOrbsMinigame extends StatefulWidget {
  const LobbyOrbsMinigame({super.key, required this.onSuccess});
  final VoidCallback onSuccess;

  @override
  State<LobbyOrbsMinigame> createState() => _LobbyOrbsMinigameState();
}

class _LobbyOrbsMinigameState extends State<LobbyOrbsMinigame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  final Set<int> _tappedIndices = <int>{};

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _tapOrb(int index) {
    if (_tappedIndices.contains(index)) return;
    HapticFeedback.selectionClick();
    setState(() {
      _tappedIndices.add(index);
    });
    if (_tappedIndices.length >= 3) {
      widget.onSuccess();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TrText(
          'Lobby Suspended Orbs',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFFF7F5F0),
          ),
        ),
        const SizedBox(height: 4),
        const TrText(
          'Look up at George W. Hart\'s twin geometric plywood spheres! Tap all 3 floating mathematical orbs to collect the lobby puzzle piece.',
          style: TextStyle(fontSize: 13, color: Color(0xFFDDD7CD), height: 1.4),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.touch_app_outlined, size: 16, color: Color(0xFFD9CBB8)),
            const SizedBox(width: 6),
            TrText(
              'Orbs collected: ${_tappedIndices.length} / 3',
              style: const TextStyle(
                color: Color(0xFFD9CBB8),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Container(
            height: 230,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.1,
                colors: [
                  const Color(0xFF332E29),
                  const Color(0xFF191817),
                ],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Stack(
              children: [
                // Floating Orb 0 (Left-Center)
                AnimatedBuilder(
                  animation: _animController,
                  builder: (context, _) {
                    final t = _animController.value;
                    final dy = math.sin(t * math.pi * 2) * 12.0;
                    return Positioned(
                      left: 36,
                      top: 48 + dy,
                      child: _buildOrb(0, size: 68),
                    );
                  },
                ),
                // Floating Orb 1 (Center-Top)
                AnimatedBuilder(
                  animation: _animController,
                  builder: (context, _) {
                    final t = _animController.value;
                    final dy = math.cos(t * math.pi * 2) * 14.0;
                    return Positioned(
                      left: 140,
                      top: 24 + dy,
                      child: _buildOrb(1, size: 76),
                    );
                  },
                ),
                // Floating Orb 2 (Right-Bottom)
                AnimatedBuilder(
                  animation: _animController,
                  builder: (context, _) {
                    final t = _animController.value;
                    final dy = math.sin((t + 0.5) * math.pi * 2) * 10.0;
                    return Positioned(
                      right: 36,
                      top: 76 + dy,
                      child: _buildOrb(2, size: 72),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOrb(int index, {required double size}) {
    final tapped = _tappedIndices.contains(index);

    return GestureDetector(
      onTap: () => _tapOrb(index),
      child: AnimatedScale(
        scale: tapped ? 0.88 : 1.0,
        duration: const Duration(milliseconds: 220),
        child: AnimatedOpacity(
          opacity: tapped ? 0.38 : 1.0,
          duration: const Duration(milliseconds: 220),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: tapped
                  ? []
                  : [
                      BoxShadow(
                        color: const Color(0xFFD9CBB8).withValues(alpha: 0.45),
                        blurRadius: 20,
                        spreadRadius: 3,
                      ),
                    ],
              gradient: RadialGradient(
                colors: tapped
                    ? [
                        const Color(0xFF5D7A68),
                        const Color(0xFF26332A),
                      ]
                    : [
                        const Color(0xFFF7EBD9),
                        const Color(0xFFD9CBB8),
                        const Color(0xFF8A7B68),
                      ],
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Inner geometric lattice rings
                Container(
                  width: size * 0.72,
                  height: size * 0.72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.5),
                      width: 1.4,
                    ),
                  ),
                ),
                Container(
                  width: size * 0.44,
                  height: size * 0.44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.7),
                      width: 1.2,
                    ),
                  ),
                ),
                if (tapped)
                  const Icon(
                    Icons.check_rounded,
                    color: Color(0xFFF7F5F0),
                    size: 26,
                  )
                else
                  const Icon(
                    Icons.blur_on_rounded,
                    color: Color(0xFF242220),
                    size: 24,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 2. COMPUTERS MINIGAME: Chronological Timeline Drag & Drop
// ============================================================================
class _ComputerItem {
  const _ComputerItem({
    required this.id,
    required this.name,
    required this.year,
    required this.description,
  });

  final String id;
  final String name;
  final int year;
  final String description;
}

class ComputersTimelineMinigame extends StatefulWidget {
  const ComputersTimelineMinigame({super.key, required this.onSuccess});
  final VoidCallback onSuccess;

  @override
  State<ComputersTimelineMinigame> createState() => _ComputersTimelineMinigameState();
}

class _ComputersTimelineMinigameState extends State<ComputersTimelineMinigame> {
  static const List<_ComputerItem> _canonical = [
    _ComputerItem(
      id: 'ibm',
      name: 'IBM PC/AT',
      year: 1984,
      description: '1984 · Microsoft XENIX Unix desktop',
    ),
    _ComputerItem(
      id: 'next',
      name: 'NeXTstation',
      year: 1990,
      description: '1990 · Steve Jobs\' NeXTSTEP workstation',
    ),
    _ComputerItem(
      id: 'sgi',
      name: 'SGI O2',
      year: 1996,
      description: '1996 · Hollywood 3D graphics computer',
    ),
    _ComputerItem(
      id: 'imac',
      name: 'iMac G3',
      year: 1998,
      description: '1998 · Translucent Bondi Blue icon',
    ),
  ];

  late List<_ComputerItem> _items;
  bool _checked = false;
  bool _isCorrect = false;

  @override
  void initState() {
    super.initState();
    // Shuffled initial order
    _items = [
      _canonical[2], // SGI 1996
      _canonical[0], // IBM 1984
      _canonical[3], // iMac 1998
      _canonical[1], // NeXT 1990
    ];
  }

  void _verifyOrder() {
    var correct = true;
    for (var i = 0; i < _items.length; i++) {
      if (_items[i].year != _canonical[i].year) {
        correct = false;
        break;
      }
    }
    setState(() {
      _checked = true;
      _isCorrect = correct;
    });

    if (correct) {
      widget.onSuccess();
    } else {
      HapticFeedback.lightImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TrText(
          'Timeline Challenge: Evolution of Computers',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFFF7F5F0),
          ),
        ),
        const SizedBox(height: 4),
        const TrText(
          'Drag the computer cards into strict chronological order from oldest (1984) to newest (1998).',
          style: TextStyle(fontSize: 13, color: Color(0xFFDDD7CD), height: 1.4),
        ),
        const SizedBox(height: 14),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _items.length,
          onReorderItem: (oldIndex, newIndex) {
            setState(() {
              final item = _items.removeAt(oldIndex);
              _items.insert(newIndex, item);
              _checked = false;
            });
          },
          itemBuilder: (context, index) {
            final item = _items[index];
            return Container(
              key: ValueKey(item.id),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF2B2824),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _checked
                      ? (_items[index].year == _canonical[index].year
                          ? const Color(0xFF5D7A68)
                          : const Color(0xFFC85A48))
                      : Colors.white.withValues(alpha: 0.14),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.drag_handle_rounded, color: Color(0xFFD9CBB8), size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TrText(
                          item.name,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFF7F5F0),
                          ),
                        ),
                        const SizedBox(height: 2),
                        TrText(
                          item.description,
                          style: TextStyle(
                            fontSize: 12,
                            color: const Color(0xFFDDD7CD).withValues(alpha: 0.76),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_checked && _items[index].year == _canonical[index].year)
                    const Icon(Icons.check_circle_rounded, color: Color(0xFF5D7A68), size: 18),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        if (_checked && !_isCorrect)
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: TrText(
              'Not quite in chronological order. Hint: IBM PC/AT (1984) is first, followed by NeXTstation (1990)!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFFE89A8A), fontSize: 12.5),
            ),
          ),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFF4F1EB),
            foregroundColor: const Color(0xFF22201E),
            minimumSize: const Size.fromHeight(48),
          ),
          onPressed: _verifyOrder,
          icon: const Icon(Icons.swap_vert_rounded, size: 18),
          label: const TrText('Verify Chronological Order'),
        ),
      ],
    );
  }
}

// ============================================================================
// 3. GREENHOUSE MINIGAME: 2x2 Photo Quest Checklist
// ============================================================================
class _GreenhouseTarget {
  const _GreenhouseTarget({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
}

class GreenhousePhotoMinigame extends StatefulWidget {
  const GreenhousePhotoMinigame({super.key, required this.onSuccess});
  final VoidCallback onSuccess;

  @override
  State<GreenhousePhotoMinigame> createState() => _GreenhousePhotoMinigameState();
}

class _GreenhousePhotoMinigameState extends State<GreenhousePhotoMinigame> {
  static const List<_GreenhouseTarget> _targets = [
    _GreenhouseTarget(
      id: 'plant',
      title: 'Greenhouse Plant',
      subtitle: 'Jungle vegetation & potted flora',
      icon: Icons.local_florist_rounded,
    ),
    _GreenhouseTarget(
      id: 'thesis',
      title: 'Doctoral Dissertation',
      subtitle: 'Public defense theses on shelf',
      icon: Icons.menu_book_rounded,
    ),
    _GreenhouseTarget(
      id: 'timber',
      title: 'Wooden Structure',
      subtitle: 'Pine frame from 2012 workshop',
      icon: Icons.forest_rounded,
    ),
    _GreenhouseTarget(
      id: 'table',
      title: 'Discussion Table',
      subtitle: 'Brainstorming desk in room C130a',
      icon: Icons.table_restaurant_rounded,
    ),
  ];

  final Set<String> _confirmed = <String>{};

  void _confirmTarget(String id) {
    if (_confirmed.contains(id)) return;
    HapticFeedback.selectionClick();
    setState(() {
      _confirmed.add(id);
    });
    if (_confirmed.length >= _targets.length) {
      widget.onSuccess();
    }
  }

  void _confirmAll() {
    HapticFeedback.selectionClick();
    setState(() {
      for (final t in _targets) {
        _confirmed.add(t.id);
      }
    });
    widget.onSuccess();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TrText(
          'Greenhouse 2×2 Photo Quest',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFFF7F5F0),
          ),
        ),
        const SizedBox(height: 4),
        const TrText(
          'Confirm all 4 targets inside the student-designed Greenhouse Learning Hub to unlock the puzzle piece.',
          style: TextStyle(fontSize: 13, color: Color(0xFFDDD7CD), height: 1.4),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.15,
          ),
          itemCount: _targets.length,
          itemBuilder: (context, index) {
            final target = _targets[index];
            final done = _confirmed.contains(target.id);

            return Material(
              color: done ? const Color(0xFF26332A) : const Color(0xFF2B2824),
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _confirmTarget(target.id),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: done
                          ? const Color(0xFF5D7A68)
                          : Colors.white.withValues(alpha: 0.14),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Icon(
                            target.icon,
                            color: done ? const Color(0xFF5D7A68) : const Color(0xFFD9CBB8),
                            size: 24,
                          ),
                          Icon(
                            done
                                ? Icons.check_circle_rounded
                                : Icons.camera_alt_outlined,
                            size: 18,
                            color: done
                                ? const Color(0xFF5D7A68)
                                : Colors.white.withValues(alpha: 0.5),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TrText(
                            target.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFF7F5F0),
                            ),
                          ),
                          const SizedBox(height: 2),
                          TrText(
                            target.subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.5,
                              color: const Color(0xFFDDD7CD).withValues(alpha: 0.72),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFF4F1EB),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.24)),
            minimumSize: const Size.fromHeight(44),
          ),
          onPressed: _confirmAll,
          icon: const Icon(Icons.done_all_rounded, size: 18),
          label: const TrText('Quick Confirm All Targets (Demo)'),
        ),
      ],
    );
  }
}

// ============================================================================
// 4. PORTRAITS MINIGAME: CS Pioneer Research Quiz
// ============================================================================
class _PioneerQuizQuestion {
  const _PioneerQuizQuestion({
    required this.pioneerName,
    required this.role,
    required this.question,
    required this.options,
    required this.correctIndex,
  });

  final String pioneerName;
  final String role;
  final String question;
  final List<String> options;
  final int correctIndex;
}

class PortraitsQuizMinigame extends StatefulWidget {
  const PortraitsQuizMinigame({super.key, required this.onSuccess});
  final VoidCallback onSuccess;

  @override
  State<PortraitsQuizMinigame> createState() => _PortraitsQuizMinigameState();
}

class _PortraitsQuizMinigameState extends State<PortraitsQuizMinigame> {
  static const List<_PioneerQuizQuestion> _questions = [
    _PioneerQuizQuestion(
      pioneerName: 'Kaisa Nyberg',
      role: 'Professor Emerita',
      question: 'Which groundbreaking field did Professor Emerita Kaisa Nyberg pioneer with AES S-boxes & pairing?',
      options: [
        'Cryptography & Bluetooth Security',
        'Computer Graphics & Raytracing',
        'Quantum Hardware Cooling',
      ],
      correctIndex: 0,
    ),
    _PioneerQuizQuestion(
      pioneerName: 'Erkki Oja',
      role: 'Academy Professor',
      question: 'What famous neural network rule was formulated by Erkki Oja in 1982?',
      options: [
        'Backpropagation Through Time',
        'Oja\'s Rule (PCA Neural Learning)',
        'Transformer Attention Matrix',
      ],
      correctIndex: 1,
    ),
    _PioneerQuizQuestion(
      pioneerName: 'Hans Andersin',
      role: 'First CS Professor (1968)',
      question: 'What was Hans \'Hasse\' Andersin\'s historic contribution to Finnish computing?',
      options: [
        'TKK\'s first CS professor and ESKO pioneer',
        'Author of the Linux Kernel 1.0',
        'Founder of Nokia Mobile Division',
      ],
      correctIndex: 0,
    ),
    _PioneerQuizQuestion(
      pioneerName: 'Teuvo Kohonen',
      role: 'Academician of Science',
      question: 'Academician Teuvo Kohonen is world-famous for which foundational AI invention?',
      options: [
        'Convolutional Neural Networks',
        'Relational Database SQL Engine',
        'Self-Organizing Maps (SOM / Kohonen Networks)',
      ],
      correctIndex: 2,
    ),
  ];

  int _selectedQuestionIndex = 0;
  int? _chosenOptionIndex;
  bool? _isCorrect;

  void _chooseOption(int index) {
    final q = _questions[_selectedQuestionIndex];
    final correct = (index == q.correctIndex);
    setState(() {
      _chosenOptionIndex = index;
      _isCorrect = correct;
    });

    if (correct) {
      widget.onSuccess();
    } else {
      HapticFeedback.lightImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _questions[_selectedQuestionIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const TrText(
              'CS Pioneers Knowledge Quiz',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFFF7F5F0),
              ),
            ),
            PopupMenuButton<int>(
              tooltip: 'Switch Pioneer',
              color: const Color(0xFF2B2824),
              icon: const Icon(Icons.person_search_rounded, color: Color(0xFFD9CBB8), size: 20),
              onSelected: (idx) {
                setState(() {
                  _selectedQuestionIndex = idx;
                  _chosenOptionIndex = null;
                  _isCorrect = null;
                });
              },
              itemBuilder: (context) => [
                for (var i = 0; i < _questions.length; i++)
                  PopupMenuItem(
                    value: i,
                    child: TrText(_questions[i].pioneerName),
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.verified_user_outlined, size: 14, color: Color(0xFFD9CBB8)),
              const SizedBox(width: 6),
              TrText(
                '${q.pioneerName} · ${q.role}',
                style: const TextStyle(
                  color: Color(0xFFD9CBB8),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        TrText(
          q.question,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFFF7F5F0),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 14),
        for (var i = 0; i < q.options.length; i++) ...[
          _buildOptionButton(
            index: i,
            text: q.options[i],
            isCorrectChoice: i == q.correctIndex,
          ),
          const SizedBox(height: 8),
        ],
        if (_isCorrect == false)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: TrText(
              'Not that field! Re-read the pioneer plaque and try another option.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFFE89A8A), fontSize: 12.5),
            ),
          ),
      ],
    );
  }

  Widget _buildOptionButton({
    required int index,
    required String text,
    required bool isCorrectChoice,
  }) {
    Color border = Colors.white.withValues(alpha: 0.16);
    Color bg = const Color(0xFF2B2824);

    if (_chosenOptionIndex == index) {
      if (isCorrectChoice) {
        border = const Color(0xFF5D7A68);
        bg = const Color(0xFF26332A);
      } else {
        border = const Color(0xFFC85A48);
        bg = const Color(0xFF33201E);
      }
    }

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _chooseOption(index),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border),
          ),
          child: Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.10),
                ),
                alignment: Alignment.center,
                child: Text(
                  String.fromCharCode(65 + index), // A, B, C
                  style: const TextStyle(
                    color: Color(0xFFF7F5F0),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TrText(
                  text,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: Color(0xFFF7F5F0),
                  ),
                ),
              ),
              if (_chosenOptionIndex == index)
                Icon(
                  isCorrectChoice ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  color: isCorrectChoice ? const Color(0xFF5D7A68) : const Color(0xFFC85A48),
                  size: 18,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 5. CANTEEN MINIGAME: 15-Second Subway Builder
// ============================================================================
class CanteenSubwayMinigame extends StatefulWidget {
  const CanteenSubwayMinigame({super.key, required this.onSuccess});
  final VoidCallback onSuccess;

  @override
  State<CanteenSubwayMinigame> createState() => _CanteenSubwayMinigameState();
}

class _CanteenSubwayMinigameState extends State<CanteenSubwayMinigame> {
  static const int _totalSeconds = 15;
  int _secondsRemaining = _totalSeconds;
  Timer? _timer;
  int _step = 0; // 0 -> Bread, 1 -> Filling, 2 -> Sauce

  static const List<String> _targetRecipe = [
    'Italian Herbs & Cheese Bread',
    'Turkey & Smoked Cheddar',
    'Chipotle Southwest Sauce',
  ];

  static const List<String> _options = [
    'Italian Herbs & Cheese Bread',
    'Gluten-Free Rye',
    'Turkey & Smoked Cheddar',
    'Tuna & Sweetcorn',
    'Chipotle Southwest Sauce',
    'Sweet Onion Teriyaki',
  ];

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _secondsRemaining = _totalSeconds;
    _step = 0;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_secondsRemaining > 1) {
          _secondsRemaining--;
        } else {
          _secondsRemaining = 0;
          timer.cancel();
        }
      });
    });
  }

  void _tapIngredient(String item) {
    if (_secondsRemaining <= 0 || _step >= 3) return;

    if (item == _targetRecipe[_step]) {
      HapticFeedback.selectionClick();
      setState(() {
        _step++;
      });
      if (_step == 3) {
        _timer?.cancel();
        widget.onSuccess();
      }
    } else {
      HapticFeedback.lightImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final expired = _secondsRemaining <= 0 && _step < 3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const TrText(
              'Speed Sub Builder (15s)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFFF7F5F0),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _secondsRemaining <= 4
                    ? const Color(0xFFC85A48).withValues(alpha: 0.3)
                    : Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.timer_outlined, size: 14, color: Color(0xFFD9CBB8)),
                  const SizedBox(width: 4),
                  Text(
                    '${_secondsRemaining}s',
                    style: TextStyle(
                      color: _secondsRemaining <= 4
                          ? const Color(0xFFE89A8A)
                          : const Color(0xFFF7F5F0),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: _secondsRemaining / _totalSeconds,
          backgroundColor: Colors.white.withValues(alpha: 0.12),
          valueColor: AlwaysStoppedAnimation(
            _secondsRemaining <= 4 ? const Color(0xFFC85A48) : const Color(0xFFD9CBB8),
          ),
          borderRadius: BorderRadius.circular(4),
          minHeight: 5,
        ),
        const SizedBox(height: 12),
        TrText(
          _step < 3
              ? 'Step ${_step + 1} of 3: Tap "${_targetRecipe[_step]}" to build the sandwich!'
              : 'Subway successfully assembled!',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFFD9CBB8),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in _options)
              Material(
                color: const Color(0xFF2B2824),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _tapIngredient(item),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _targetRecipe.take(_step).contains(item)
                            ? const Color(0xFF5D7A68)
                            : Colors.white.withValues(alpha: 0.14),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_targetRecipe.take(_step).contains(item))
                          const Padding(
                            padding: EdgeInsets.only(right: 6),
                            child: Icon(Icons.check_rounded, color: Color(0xFF5D7A68), size: 16),
                          ),
                        TrText(
                          item,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFFF7F5F0),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (expired) ...[
          const Center(
            child: TrText(
              'Time expired! Press Retry to restart the 15-second rush.',
              style: TextStyle(color: Color(0xFFE89A8A), fontSize: 12.5),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFF4F1EB),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.24)),
              minimumSize: const Size.fromHeight(44),
            ),
            onPressed: _startTimer,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const TrText('Retry Sub Rush'),
          ),
        ],
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const TrText(
            'Campus Tip: CS building Subway serves Kela-subsidized ~3.10 € student lunch subs with Frank / Slice card.',
            style: TextStyle(fontSize: 11.5, color: Color(0xFFDDD7CD)),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// 6. GUILDS MINIGAME: Tap to Match Guild to Overalls & Room
// ============================================================================
class _GuildMatchItem {
  const _GuildMatchItem({
    required this.id,
    required this.name,
    required this.description,
    required this.color,
  });

  final String id;
  final String name;
  final String description;
  final Color color;
}

class GuildsMatchMinigame extends StatefulWidget {
  const GuildsMatchMinigame({super.key, required this.onSuccess});
  final VoidCallback onSuccess;

  @override
  State<GuildsMatchMinigame> createState() => _GuildsMatchMinigameState();
}

class _GuildsMatchMinigameState extends State<GuildsMatchMinigame> {
  static const List<_GuildMatchItem> _guilds = [
    _GuildMatchItem(
      id: 'tik',
      name: 'Tietokilta (TiK)',
      description: 'All-black overalls with @ tassel · Room C114 · 1986',
      color: Color(0xFF262523),
    ),
    _GuildMatchItem(
      id: 'athene',
      name: 'Athene',
      description: 'Forest green with black sleeve · Room A117 PALLASKATU',
      color: Color(0xFF5C554C),
    ),
    _GuildMatchItem(
      id: 'dg',
      name: 'Data Guild',
      description: 'Black with silver sleeve · Room A120b Database · 2019',
      color: Color(0xFF6E665C),
    ),
  ];

  String? _selectedGuildId;
  final Set<String> _matchedIds = <String>{};

  void _tapGuild(String id) {
    if (_matchedIds.contains(id)) return;
    HapticFeedback.selectionClick();
    setState(() {
      _selectedGuildId = id;
    });
  }

  void _tapDescription(String id) {
    if (_matchedIds.contains(id)) return;
    if (_selectedGuildId == null) return;

    if (_selectedGuildId == id) {
      HapticFeedback.selectionClick();
      setState(() {
        _matchedIds.add(id);
        _selectedGuildId = null;
      });
      if (_matchedIds.length >= _guilds.length) {
        widget.onSuccess();
      }
    } else {
      HapticFeedback.lightImpact();
      setState(() {
        _selectedGuildId = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TrText(
          'Match the 3 Student Guilds',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFFF7F5F0),
          ),
        ),
        const SizedBox(height: 4),
        const TrText(
          'Select a guild on the left, then tap its matching overalls and room description on the right.',
          style: TextStyle(fontSize: 13, color: Color(0xFFDDD7CD), height: 1.4),
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left: Guilds
            Expanded(
              flex: 4,
              child: Column(
                children: [
                  for (final g in _guilds) ...[
                    _buildGuildCard(g),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Right: Descriptions (shuffled order: athene, dg, tik)
            Expanded(
              flex: 6,
              child: Column(
                children: [
                  _buildDescCard(_guilds[1]), // Athene
                  const SizedBox(height: 8),
                  _buildDescCard(_guilds[2]), // DG
                  const SizedBox(height: 8),
                  _buildDescCard(_guilds[0]), // TiK
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGuildCard(_GuildMatchItem g) {
    final isMatched = _matchedIds.contains(g.id);
    final isSelected = _selectedGuildId == g.id;

    return Material(
      color: isMatched
          ? const Color(0xFF26332A)
          : (isSelected ? const Color(0xFF453D34) : const Color(0xFF2B2824)),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _tapGuild(g.id),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isMatched
                  ? const Color(0xFF5D7A68)
                  : (isSelected ? const Color(0xFFD9CBB8) : Colors.white.withValues(alpha: 0.14)),
              width: isSelected ? 1.8 : 1.0,
            ),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isMatched)
                const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: Icon(Icons.check_rounded, color: Color(0xFF5D7A68), size: 16),
                ),
              Flexible(
                child: TrText(
                  g.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFF7F5F0),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDescCard(_GuildMatchItem g) {
    final isMatched = _matchedIds.contains(g.id);

    return Material(
      color: isMatched ? const Color(0xFF26332A) : const Color(0xFF2B2824),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _tapDescription(g.id),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isMatched
                  ? const Color(0xFF5D7A68)
                  : Colors.white.withValues(alpha: 0.14),
            ),
          ),
          child: TrText(
            g.description,
            style: TextStyle(
              fontSize: 11.5,
              color: isMatched ? const Color(0xFFF7F5F0) : const Color(0xFFDDD7CD),
              height: 1.3,
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 7. STUDY PLACES MINIGAME: Aalto Space Tablet Free Room Rush
// ============================================================================
class StudyPlacesRoomRushMinigame extends StatefulWidget {
  const StudyPlacesRoomRushMinigame({super.key, required this.onSuccess});
  final VoidCallback onSuccess;

  @override
  State<StudyPlacesRoomRushMinigame> createState() => _StudyPlacesRoomRushMinigameState();
}

class _StudyPlacesRoomRushMinigameState extends State<StudyPlacesRoomRushMinigame> {
  static const List<String> _rooms = ['C130e', 'C134 Tomato', 'C135 Cucumber', 'C136 Carrot'];
  int _freeIndex = 0;
  Timer? _rotationTimer;

  @override
  void initState() {
    super.initState();
    _startRotation();
  }

  @override
  void dispose() {
    _rotationTimer?.cancel();
    super.dispose();
  }

  void _startRotation() {
    _rotationTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted) return;
      setState(() {
        _freeIndex = (_freeIndex + 1) % _rooms.length;
      });
    });
  }

  void _tapTablet(int index) {
    if (index == _freeIndex) {
      _rotationTimer?.cancel();
      HapticFeedback.selectionClick();
      widget.onSuccess();
    } else {
      HapticFeedback.lightImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TrText(
          'Aalto Space: Find the Free Room',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFFF7F5F0),
          ),
        ),
        const SizedBox(height: 4),
        const TrText(
          'Door tablets outside pods glow green when free and red when occupied. Room states shift every 2s — tap the GREEN tablet to claim the room!',
          style: TextStyle(fontSize: 13, color: Color(0xFFDDD7CD), height: 1.4),
        ),
        const SizedBox(height: 14),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.25,
          ),
          itemCount: _rooms.length,
          itemBuilder: (context, index) {
            final isFree = (index == _freeIndex);
            final statusColor = isFree ? const Color(0xFF5D7A68) : const Color(0xFFC85A48);
            final statusLabel = isFree ? 'FREE · AVAILABLE' : 'OCCUPIED';

            return Material(
              color: isFree ? const Color(0xFF26332A) : const Color(0xFF33201E),
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _tapTablet(index),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: statusColor, width: isFree ? 2 : 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: statusColor,
                            ),
                          ),
                          Icon(
                            isFree ? Icons.meeting_room_outlined : Icons.lock_clock_outlined,
                            size: 16,
                            color: statusColor,
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TrText(
                            _rooms[index],
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFF7F5F0),
                            ),
                          ),
                          const SizedBox(height: 2),
                          TrText(
                            statusLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

// ============================================================================
// 8. LOCKED CORRIDORS MINIGAME: PCB Circuit Connect (2F mural)
// ============================================================================
class LockedCorridorsPcbMinigame extends StatefulWidget {
  const LockedCorridorsPcbMinigame({super.key, required this.onSuccess});
  final VoidCallback onSuccess;

  @override
  State<LockedCorridorsPcbMinigame> createState() => _LockedCorridorsPcbMinigameState();
}

class _LockedCorridorsPcbMinigameState extends State<LockedCorridorsPcbMinigame> {
  // 3x3 grid rotation angles in quadrants: 0 = 0°, 1 = 90°, 2 = 180°, 3 = 270°
  // Initial scrambled puzzle where solution connects cell (0,0) [Input] -> (2,2) [Output]
  late List<int> _rotations;

  @override
  void initState() {
    super.initState();
    _rotations = [1, 2, 3, 0, 2, 1, 3, 1, 0];
  }

  void _rotateTile(int index) {
    HapticFeedback.selectionClick();
    setState(() {
      _rotations[index] = (_rotations[index] + 1) % 4;
    });

    if (_isCircuitClosed()) {
      widget.onSuccess();
    }
  }

  bool _isCircuitClosed() {
    // Condition: corner (0) must face right (0 or 2), center (4) must connect, and end (8) must face right
    // Simplified elegant check so the player solves it within 10-15s
    return (_rotations[0] == 0 && _rotations[1] == 0 && _rotations[4] == 1 && _rotations[7] == 0 && _rotations[8] == 0);
  }

  void _solveInstantly() {
    setState(() {
      _rotations[0] = 0;
      _rotations[1] = 0;
      _rotations[4] = 1;
      _rotations[7] = 0;
      _rotations[8] = 0;
    });
    widget.onSuccess();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TrText(
          'PCB Circuit Connector',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFFF7F5F0),
          ),
        ),
        const SizedBox(height: 4),
        const TrText(
          'Inspired by the 2nd-floor staff café motherboard mural! Tap tiles to rotate copper tracks and connect power from Input (top-left) to the Lab Wing Output (bottom-right).',
          style: TextStyle(fontSize: 13, color: Color(0xFFDDD7CD), height: 1.4),
        ),
        const SizedBox(height: 14),
        Center(
          child: Container(
            width: 220,
            height: 220,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E2822),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFD9CBB8).withValues(alpha: 0.3)),
            ),
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
              ),
              itemCount: 9,
              itemBuilder: (context, index) {
                final rot = _rotations[index];

                return GestureDetector(
                  onTap: () => _rotateTile(index),
                  child: AnimatedRotation(
                    turns: rot / 4.0,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF2B3A31),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                      ),
                      child: CustomPaint(
                        painter: _PcbTrackPainter(index: index),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFF4F1EB),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.24)),
            minimumSize: const Size.fromHeight(44),
          ),
          onPressed: _solveInstantly,
          icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
          label: const TrText('Auto-Connect Circuit (Demo)'),
        ),
      ],
    );
  }
}

class _PcbTrackPainter extends CustomPainter {
  const _PcbTrackPainter({required this.index});
  final int index;

  @override
  void paint(Canvas canvas, Size size) {
    final copperPaint = Paint()
      ..color = const Color(0xFFD9CBB8)
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = const Color(0xFFE5D5C0)
      ..style = PaintingStyle.fill;

    final midX = size.width * 0.5;
    final midY = size.height * 0.5;

    // Draw track depending on whether it's elbow or straight
    if (index % 2 == 0) {
      // Elbow corner track
      final path = Path()
        ..moveTo(0, midY)
        ..lineTo(midX, midY)
        ..lineTo(midX, size.height);
      canvas.drawPath(path, copperPaint);
    } else {
      // Straight horizontal track
      canvas.drawLine(Offset(0, midY), Offset(size.width, midY), copperPaint);
    }

    canvas.drawCircle(Offset(midX, midY), 3.0, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _PcbTrackPainter oldDelegate) => false;
}

// ============================================================================
// 9. TUAS BRIDGE MINIGAME: Directional Compass to Maarintie 8
// ============================================================================
class TuasBridgeCompassMinigame extends StatefulWidget {
  const TuasBridgeCompassMinigame({super.key, required this.onSuccess});
  final VoidCallback onSuccess;

  @override
  State<TuasBridgeCompassMinigame> createState() => _TuasBridgeCompassMinigameState();
}

class _TuasBridgeCompassMinigameState extends State<TuasBridgeCompassMinigame> {
  static const double _targetDegrees = 45.0; // North-East towards TUAS
  double _currentDegrees = 180.0;
  bool _aligned = false;

  void _onPanUpdate(DragUpdateDetails details, Size size) {
    if (_aligned) return;
    final center = Offset(size.width * 0.5, size.height * 0.5);
    final pos = details.localPosition - center;
    var deg = (math.atan2(pos.dy, pos.dx) * 180.0 / math.pi) + 90.0;
    if (deg < 0) deg += 360.0;

    final diff = (deg - _targetDegrees).abs();
    if (diff <= 8.0 || diff >= 352.0) {
      if (!_aligned) {
        HapticFeedback.mediumImpact();
        setState(() {
          _currentDegrees = _targetDegrees;
          _aligned = true;
        });
        widget.onSuccess();
      }
    } else {
      setState(() {
        _currentDegrees = deg;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TrText(
          'Skybridge Compass to Maarintie 8',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFFF7F5F0),
          ),
        ),
        const SizedBox(height: 4),
        const TrText(
          'Rotate the compass dial to point toward the 2nd-floor skybridge connecting to TUAS building (Maarintie 8) at 45° North-East.',
          style: TextStyle(fontSize: 13, color: Color(0xFFDDD7CD), height: 1.4),
        ),
        const SizedBox(height: 14),
        Center(
          child: LayoutBuilder(
            builder: (context, constraints) {
              const dialSize = 190.0;

              return GestureDetector(
                onPanUpdate: (d) => _onPanUpdate(d, const Size(dialSize, dialSize)),
                child: Container(
                  width: dialSize,
                  height: dialSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF242220),
                    border: Border.all(
                      color: _aligned ? const Color(0xFF5D7A68) : const Color(0xFFD9CBB8).withValues(alpha: 0.35),
                      width: _aligned ? 2.5 : 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Cardinal markers
                      const Positioned(top: 8, child: Text('N', style: TextStyle(color: Color(0xFFDDD7CD), fontSize: 11, fontWeight: FontWeight.w700))),
                      const Positioned(right: 10, child: Text('E', style: TextStyle(color: Color(0xFFDDD7CD), fontSize: 11, fontWeight: FontWeight.w700))),
                      const Positioned(bottom: 8, child: Text('S', style: TextStyle(color: Color(0xFFDDD7CD), fontSize: 11, fontWeight: FontWeight.w700))),
                      const Positioned(left: 10, child: Text('W', style: TextStyle(color: Color(0xFFDDD7CD), fontSize: 11, fontWeight: FontWeight.w700))),

                      // Target Goal at 45° NE
                      Transform.rotate(
                        angle: _targetDegrees * math.pi / 180.0,
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 24),
                            child: Icon(
                              Icons.apartment_rounded,
                              size: 16,
                              color: _aligned ? const Color(0xFF5D7A68) : const Color(0xFFD9CBB8).withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      ),

                      // Rotating Needle
                      Transform.rotate(
                        angle: _currentDegrees * math.pi / 180.0,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 5,
                              height: 52,
                              decoration: BoxDecoration(
                                color: _aligned ? const Color(0xFF5D7A68) : const Color(0xFFC85A48),
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                              ),
                            ),
                            Container(
                              width: 5,
                              height: 52,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.4),
                                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(4)),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Center Pivot Pin
                      Container(
                        width: 14,
                        height: 14,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFF7F5F0),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: TrText(
            _aligned
                ? 'Skybridge Aligned! Coatless winter passage unlocked.'
                : 'Current: ${_currentDegrees.toStringAsFixed(0)}° (Target: 45° NE)',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _aligned ? const Color(0xFF5D7A68) : const Color(0xFFD9CBB8),
            ),
          ),
        ),
      ],
    );
  }
}

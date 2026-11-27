import 'package:flutter/material.dart';
import 'package:zenify/zenify.dart';

import '../../core/controllers.dart';
import '../../core/device_capabilities.dart';
import '../../core/translation_service.dart';
import 'station_detail_screen.dart';

/// The CS Lobby root screen uses the same full-screen photograph + asymmetric
/// translucent glass overlay as every other station, topped with a compact
/// guide introduction and a collapsible floor-by-floor route card.
class LobbyHomeScreen extends StatelessWidget {
  const LobbyHomeScreen({
    super.key,
    required this.onOpenSideMenu,
    required this.onOpenScan,
    required this.onOpenMap,
    required this.onOpenStation,
    required this.onCatchLobbyPuzzle,
    this.showMenuButton = true,
  });

  final VoidCallback onOpenSideMenu;
  final VoidCallback onOpenScan;
  final VoidCallback onOpenMap;
  final ValueChanged<String> onOpenStation;
  final VoidCallback onCatchLobbyPuzzle;
  final bool showMenuButton;

  @override
  Widget build(BuildContext context) {
    final catalog = Zen.find<StationCatalogRepository>();
    return StationDetailScreen(
      station: catalog.lobby,
      isRootLobbyView: true,
      reserveBottomDockSpace: true,
      showMenuButton: showMenuButton,
      introSection: _LobbyGuideIntroSection(
        onOpenMap: onOpenMap,
        onOpenScan: onOpenScan,
      ),
      onBackToLobby: () {},
      onOpenSideMenu: onOpenSideMenu,
      onCatchPuzzlePiece: onCatchLobbyPuzzle,
      onRunSecondaryAction: onOpenScan,
    );
  }
}

class _LobbyGuideIntroSection extends StatefulWidget {
  const _LobbyGuideIntroSection({
    required this.onOpenMap,
    required this.onOpenScan,
  });

  final VoidCallback onOpenMap;
  final VoidCallback onOpenScan;

  @override
  State<_LobbyGuideIntroSection> createState() =>
      _LobbyGuideIntroSectionState();
}

class _LobbyGuideIntroSectionState extends State<_LobbyGuideIntroSection> {
  bool _routeExpanded = false;

  @override
  Widget build(BuildContext context) {
    final isLaptop = DeviceCapabilities.isLaptopMode;
    final supportsCamera = DeviceCapabilities.supportsCameraScan;
    final supportsAr = DeviceCapabilities.supportsArExperiences;

    final steps = isLaptop
        ? const [
            (
              '1',
              'Explore Every Stop',
              'Browse all 9 building stations directly from the Guide sidebar or Map.',
            ),
            (
              '2',
              'Interactive Highlights',
              'Try the 3-floor building map, canteen menu, and 2F Retro PC price game.',
            ),
            (
              '3',
              'On-Site Mobile Extras',
              'Open CS Explorer on a phone in T-talo for camera scanning and AR activities.',
            ),
          ]
        : const [
            (
              '1',
              'Follow the Map',
              'Open Map below to see all 9 stops across Floors 1–3 and locate yourself.',
            ),
            (
              '2',
              'Scan to Unlock',
              'Tap Scan at each stop on QR codes, signs, or 1F portraits to open its guide.',
            ),
            (
              '3',
              'Collect & Play',
              'Try the Lobby puzzle piece below, collect all 8, and unlock the Final Puzzle in Guide.',
            ),
          ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Compact Guide Introduction Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.11),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.explore_outlined,
                      size: 18,
                      color: Color(0xFFE6DDD0),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: TrText(
                      'How This Guide Works',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFF9F7F3),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              for (var i = 0; i < steps.length; i++) ...[
                _GuideIntroStepRow(
                  number: steps[i].$1,
                  title: steps[i].$2,
                  description: steps[i].$3,
                ),
                if (i < steps.length - 1) const SizedBox(height: 8),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _LobbyQuickChip(
                    icon: Icons.map_outlined,
                    label: 'Open Building Map',
                    onTap: widget.onOpenMap,
                  ),
                  if (supportsCamera)
                    _LobbyQuickChip(
                      icon: Icons.qr_code_scanner_rounded,
                      label: 'Start Scanning',
                      onTap: widget.onOpenScan,
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // 2. Collapsible Route Instructions Card (Compact / Collapsed by default)
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                button: true,
                toggled: _routeExpanded,
                label: _routeExpanded
                    ? 'Collapse suggested route instructions'
                    : 'Expand suggested route instructions',
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () =>
                        setState(() => _routeExpanded = !_routeExpanded),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 52),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.route_rounded,
                                size: 18,
                                color: Color(0xFFE6DDD0),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const TrText(
                                    'Suggested Route · 1F → 3F',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFFF9F7F3),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  TrText(
                                    _routeExpanded
                                        ? '9 stops across 3 floors'
                                        : '9 stops · Tap to view floor-by-floor route',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: const Color(
                                        0xFFF0ECE4,
                                      ).withValues(alpha: 0.78),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            AnimatedRotation(
                              turns: _routeExpanded ? 0.5 : 0.0,
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOutCubic,
                              child: const Icon(
                                Icons.expand_more_rounded,
                                size: 22,
                                color: Color(0xFFE6DDD0),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: _routeExpanded
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Divider(
                              height: 12,
                              color: Colors.white.withValues(alpha: 0.14),
                            ),
                            const SizedBox(height: 4),
                            const _RouteFloorRow(
                              floorBadge: '1F',
                              heading: 'Start here · Main Level',
                              stops:
                                  'Lobby → Learning Hub Greenhouse (C130a) → CS Pioneers Portraits (3D AR) → Student Guild Rooms → Canteen & Subway → Locked Research Wings entrance',
                            ),
                            const SizedBox(height: 10),
                            const _RouteFloorRow(
                              floorBadge: '2F',
                              heading: 'Main stairs or lift',
                              stops:
                                  'Evolution of Computers (price-matching quiz) → Indoor Skybridge to TUAS (Maarintie 8)',
                            ),
                            const SizedBox(height: 10),
                            const _RouteFloorRow(
                              floorBadge: '3F',
                              heading: 'Top floor',
                              stops:
                                  'Quiet Study Loft (Parvi T1) & walk-in call pods',
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 11,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.only(top: 1),
                                    child: Icon(
                                      Icons.flag_outlined,
                                      size: 15,
                                      color: Color(0xFFD9CBB8),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TrText(
                                      supportsAr
                                          ? 'Final step: open the Guide menu after collecting all 8 puzzle pieces to Assemble the Final Puzzle.'
                                          : 'Tip: switch floors anytime in Map or pick any stop directly from the Guide sidebar.',
                                      style: TextStyle(
                                        fontSize: 12.2,
                                        height: 1.4,
                                        color: const Color(
                                          0xFFF0ECE4,
                                        ).withValues(alpha: 0.88),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GuideIntroStepRow extends StatelessWidget {
  const _GuideIntroStepRow({
    required this.number,
    required this.title,
    required this.description,
  });

  final String number;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          margin: const EdgeInsets.only(top: 1),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(7),
          ),
          alignment: Alignment.center,
          child: Text(
            number,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFFF9F7F3),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TrText(
                title,
                style: const TextStyle(
                  fontSize: 13.2,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFF9F7F3),
                ),
              ),
              const SizedBox(height: 1),
              TrText(
                description,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  color: const Color(0xFFF0ECE4).withValues(alpha: 0.86),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RouteFloorRow extends StatelessWidget {
  const _RouteFloorRow({
    required this.floorBadge,
    required this.heading,
    required this.stops,
  });

  final String floorBadge;
  final String heading;
  final String stops;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          padding: const EdgeInsets.symmetric(vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            floorBadge,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFFF9F7F3),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TrText(
                heading,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFF9F7F3),
                ),
              ),
              const SizedBox(height: 2),
              TrText(
                stops,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.42,
                  color: const Color(0xFFF0ECE4).withValues(alpha: 0.86),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LobbyQuickChip extends StatelessWidget {
  const _LobbyQuickChip({
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
        color: const Color(0xFF22201E).withValues(alpha: 0.56),
        borderRadius: BorderRadius.circular(11),
        child: InkWell(
          borderRadius: BorderRadius.circular(11),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 16, color: const Color(0xFFD9CBB8)),
                  const SizedBox(width: 7),
                  Flexible(
                    child: TrText(
                      label,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFF9F7F3),
                      ),
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

import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/translation_service.dart';

/// Primary bottom navigation destinations for the CS Explorer shell.
enum ActiveDockTab { infos, scan, map }

/// Signature *AMuse*-inspired floating dock implementing the
/// **Frosted Split & Shutter Bloom** transition (`Curves.easeOutBack`, ~340ms):
/// - In [ActiveDockTab.infos] or [ActiveDockTab.map]: renders a single cohesive
///   frosted-glass capsule centered near the bottom (`[ Infos | Scan | Map ]`).
/// - In [ActiveDockTab.scan]: smoothly splits outward toward the left and right
///   edges (`← Infos` and `Map`) while the center item blooms into a `72x72`
///   double-ring tactile camera **Shutter** button.
class FrostedSplitDock extends StatelessWidget {
  const FrostedSplitDock({
    super.key,
    required this.activeTab,
    required this.onSelectInfos,
    required this.onSelectScanOrShutter,
    required this.onSelectMap,
    this.shutterPulse = false,
  });

  final ActiveDockTab activeTab;
  final VoidCallback onSelectInfos;
  final VoidCallback onSelectScanOrShutter;
  final VoidCallback onSelectMap;
  final bool shutterPulse;

  static const Duration _splitDuration = Duration(milliseconds: 340);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isScanMode = activeTab == ActiveDockTab.scan;

    final glassFill = isDark
        ? const Color(0xFF1C211F).withValues(alpha: 0.78)
        : const Color(0xFFFAF9F6).withValues(alpha: 0.84);
    final glassBorder = isDark
        ? const Color(0xFFF3F1EC).withValues(alpha: 0.16)
        : const Color(0xFF1E2D27).withValues(alpha: 0.12);
    final activePillFill = isDark
        ? theme.colorScheme.primary.withValues(alpha: 0.22)
        : theme.colorScheme.primary.withValues(alpha: 0.12);

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 6, 16, 14),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxWidth = constraints.maxWidth.isFinite
                  ? constraints.maxWidth
                  : 360.0;
              final compactWidth = maxWidth.clamp(276.0, 344.0);
              final cohesiveSlotWidth =
                  ((compactWidth - 16.0) / 3.0).clamp(84.0, 108.0);
              final cohesiveOffset = cohesiveSlotWidth + 2.0;

              final splitPillWidth =
                  ((maxWidth - 72.0 - 24.0) / 2.0).clamp(88.0, 124.0);
              final splitOffset = (maxWidth / 2.0) - (splitPillWidth / 2.0);

              return TweenAnimationBuilder<double>(
                tween: Tween<double>(end: isScanMode ? 1.0 : 0.0),
                duration: _splitDuration,
                curve: Curves.easeOutBack,
                builder: (context, rawProgress, _) {
                  final clamped = rawProgress.clamp(0.0, 1.0);
                  final sideOffset = lerpDouble(
                        cohesiveOffset,
                        splitOffset,
                        rawProgress,
                      ) ??
                      cohesiveOffset;
                  final sideWidth = lerpDouble(
                        cohesiveSlotWidth,
                        splitPillWidth,
                        clamped,
                      ) ??
                      cohesiveSlotWidth;
                  final capsuleWidth = lerpDouble(
                        compactWidth,
                        maxWidth,
                        clamped,
                      ) ??
                      compactWidth;

                  return SizedBox(
                    width: maxWidth,
                    height: 76,
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        // Cohesive unified frosted-glass capsule (Infos / Map modes)
                        if (clamped < 0.99)
                          IgnorePointer(
                            child: Opacity(
                              opacity: (1.0 - clamped).clamp(0.0, 1.0),
                              child: Container(
                                width: capsuleWidth.clamp(240.0, maxWidth),
                                height: 60,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(32),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: isDark ? 0.34 : 0.10,
                                      ),
                                      blurRadius: 22,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(32),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(
                                      sigmaX: 18,
                                      sigmaY: 18,
                                    ),
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: glassFill,
                                        borderRadius: BorderRadius.circular(32),
                                        border: Border.all(color: glassBorder),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                        // Left item: Infos (or "← Infos" frosted pill in Scan mode)
                        Transform.translate(
                          offset: Offset(-sideOffset, 0),
                          child: _DockSidePill(
                            width: sideWidth,
                            splitProgress: clamped,
                            isActive: activeTab == ActiveDockTab.infos,
                            isSplitMode: isScanMode,
                            showBackArrow: isScanMode,
                            icon: activeTab == ActiveDockTab.infos
                                ? Icons.museum_rounded
                                : Icons.museum_outlined,
                            label: 'Infos',
                            semanticsLabel: isScanMode
                                ? 'Back to Infos'
                                : 'Infos tab',
                            glassFill: glassFill,
                            glassBorder: glassBorder,
                            activePillFill: activePillFill,
                            isDark: isDark,
                            onTap: onSelectInfos,
                          ),
                        ),

                        // Right item: Map (or standalone "Map" frosted pill in Scan mode)
                        Transform.translate(
                          offset: Offset(sideOffset, 0),
                          child: _DockSidePill(
                            width: sideWidth,
                            splitProgress: clamped,
                            isActive: activeTab == ActiveDockTab.map,
                            isSplitMode: isScanMode,
                            showBackArrow: false,
                            icon: activeTab == ActiveDockTab.map
                                ? Icons.map_rounded
                                : Icons.map_outlined,
                            label: 'Map',
                            semanticsLabel: 'Map tab',
                            glassFill: glassFill,
                            glassBorder: glassBorder,
                            activePillFill: activePillFill,
                            isDark: isDark,
                            onTap: onSelectMap,
                          ),
                        ),

                        // Center item: Scan tab OR blooming 72x72 Camera Shutter
                        _CenterScanOrShutterButton(
                          isScanMode: isScanMode,
                          rawBloomProgress: rawProgress,
                          splitProgress: clamped,
                          shutterPulse: shutterPulse,
                          cohesiveWidth: cohesiveSlotWidth,
                          isDark: isDark,
                          onTap: onSelectScanOrShutter,
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DockSidePill extends StatelessWidget {
  const _DockSidePill({
    required this.width,
    required this.splitProgress,
    required this.isActive,
    required this.isSplitMode,
    required this.showBackArrow,
    required this.icon,
    required this.label,
    required this.semanticsLabel,
    required this.glassFill,
    required this.glassBorder,
    required this.activePillFill,
    required this.isDark,
    required this.onTap,
  });

  final double width;
  final double splitProgress;
  final bool isActive;
  final bool isSplitMode;
  final bool showBackArrow;
  final IconData icon;
  final String label;
  final String semanticsLabel;
  final Color glassFill;
  final Color glassBorder;
  final Color activePillFill;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fgColor = isActive
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface.withValues(alpha: 0.88);

    final bgColor = Color.lerp(
      isActive ? activePillFill : Colors.transparent,
      glassFill,
      splitProgress,
    )!;
    final borderColor = Color.lerp(
      isActive
          ? theme.colorScheme.primary.withValues(alpha: 0.24)
          : Colors.transparent,
      glassBorder,
      splitProgress,
    )!;

    final pillContent = Container(
      constraints: BoxConstraints(
        minWidth: width.clamp(48.0, 180.0),
        maxWidth: width.clamp(48.0, 180.0),
        minHeight: 48,
      ),
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: borderColor),
        boxShadow: splitProgress > 0.15
            ? [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: (isDark ? 0.30 : 0.09) * splitProgress,
                  ),
                  blurRadius: 16 * splitProgress,
                  offset: Offset(0, 6 * splitProgress),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            showBackArrow ? Icons.arrow_back_rounded : icon,
            size: 19,
            color: fgColor,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: TrText(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge?.copyWith(
                color: fgColor,
                fontWeight: isActive || isSplitMode
                    ? FontWeight.w700
                    : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    final interactivePill = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: onTap,
        child: pillContent,
      ),
    );

    return Semantics(
      button: true,
      selected: isActive,
      label: semanticsLabel,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: splitProgress > 0.01
            ? BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: 16 * splitProgress,
                  sigmaY: 16 * splitProgress,
                ),
                child: interactivePill,
              )
            : interactivePill,
      ),
    );
  }
}

class _CenterScanOrShutterButton extends StatelessWidget {
  const _CenterScanOrShutterButton({
    required this.isScanMode,
    required this.rawBloomProgress,
    required this.splitProgress,
    required this.shutterPulse,
    required this.cohesiveWidth,
    required this.isDark,
    required this.onTap,
  });

  final bool isScanMode;
  final double rawBloomProgress;
  final double splitProgress;
  final bool shutterPulse;
  final double cohesiveWidth;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final fgIdle = theme.colorScheme.onSurface.withValues(alpha: 0.88);

    final idleWidth = cohesiveWidth.clamp(84.0, 108.0);
    final animatedWidth =
        (lerpDouble(idleWidth, 72.0, rawBloomProgress) ?? idleWidth)
            .clamp(48.0, 140.0);
    final animatedHeight =
        (lerpDouble(50.0, 72.0, rawBloomProgress) ?? 50.0).clamp(48.0, 84.0);
    final animatedRadius =
        (lerpDouble(25.0, 36.0, splitProgress) ?? 25.0).clamp(16.0, 42.0);
    final pulseScale = isScanMode && shutterPulse ? 1.08 : 1.0;
    final shutterBg = isDark
        ? const Color(0xFF1C211F).withValues(alpha: 0.92)
        : const Color(0xFFFAF9F6).withValues(alpha: 0.95);

    return Semantics(
      button: true,
      selected: isScanMode,
      label: isScanMode ? 'Take Photo or Scan' : 'Scan tab',
      child: AnimatedScale(
        scale: pulseScale,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutBack,
        child: Container(
          width: animatedWidth,
          height: animatedHeight,
          decoration: BoxDecoration(
            color: Color.lerp(Colors.transparent, shutterBg, splitProgress),
            borderRadius: BorderRadius.circular(animatedRadius),
            border: splitProgress > 0.02
                ? Border.all(
                    color: primary.withValues(alpha: splitProgress),
                    width: 3.0 * splitProgress,
                  )
                : null,
            boxShadow: splitProgress > 0.05
                ? [
                    BoxShadow(
                      color: primary.withValues(
                        alpha: (isDark ? 0.38 : 0.25) * splitProgress,
                      ),
                      blurRadius: (shutterPulse ? 24.0 : 18.0) * splitProgress,
                      spreadRadius: (shutterPulse ? 2.0 : 0.0) * splitProgress,
                      offset: Offset(0, 6 * splitProgress),
                    ),
                  ]
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(animatedRadius),
              onTap: onTap,
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOutBack,
                  switchOutCurve: Curves.easeIn,
                  child: isScanMode
                      ? Container(
                          key: const ValueKey<String>('shutter_ring'),
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: primary,
                            border: Border.all(
                              color: theme.colorScheme.onPrimary.withValues(
                                alpha: 0.85,
                              ),
                              width: 2.0,
                            ),
                          ),
                          child: Icon(
                            Icons.camera_alt_rounded,
                            size: 25,
                            color: theme.colorScheme.onPrimary,
                          ),
                        )
                      : Padding(
                          key: const ValueKey<String>('scan_label'),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.qr_code_scanner_rounded,
                                size: 19,
                                color: fgIdle,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: TrText(
                                  'Scan',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: fgIdle,
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
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:zenify/zenify.dart';

import '../core/controllers.dart';
import '../core/device_capabilities.dart';
import '../core/models.dart';
import '../core/translation_service.dart';
import 'puzzle_icon.dart';
import 'theme.dart';

/// Sober, minimal *AMuse*-inspired navigation panel.
/// - Header: clean app mark + title only (no counters, legends, or quick toggles).
/// - Stations: typographic state transition from non-clickable muted grey
///   (locked) to clickable charcoal/ivory (unlocked) and warm stone (current),
///   paired with a drawn vector [PuzzlePieceIcon].
/// - Footer: Settings, Meet the Team, and the Demo Mode prototype toggle.
class SideMenuPanel extends StatelessWidget {
  const SideMenuPanel({
    super.key,
    required this.onSelectStation,
    required this.onOpenSettings,
    required this.onOpenTeam,
    required this.onOpenFinalPuzzle,
    this.inDrawer = true,
  });

  final ValueChanged<String> onSelectStation;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenTeam;
  final VoidCallback onOpenFinalPuzzle;
  final bool inDrawer;

  void _invokeMenuAction(BuildContext context, VoidCallback action) {
    final scaffold = Scaffold.maybeOf(context);
    action();
    if (inDrawer && (scaffold?.isDrawerOpen ?? false)) {
      scaffold!.closeDrawer();
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = Zen.find<TourProgressController>();
    final settings = Zen.find<AppSettingsController>();

    return ZenObserver(() {
      final theme = Theme.of(context);
      final scheme = theme.colorScheme;
      final isDark = theme.brightness == Brightness.dark;

      final demoUnlock = settings.demoUnlockAll.value;
      final isLaptop = DeviceCapabilities.isLaptopMode;
      final showArPuzzles = DeviceCapabilities.supportsArExperiences;
      final allowBrowseAll =
          demoUnlock || DeviceCapabilities.autoUnlockStations;
      final stations = progress.catalog.stations;
      final finalReady = progress.isFinalPuzzleReady(demoUnlockAll: demoUnlock);

      return ColoredBox(
        color: theme.scaffoldBackgroundColor,
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Minimal App Brand Header (Logo + Title only)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 16, 16),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.account_balance_outlined,
                        size: 19,
                        color: scheme.onPrimary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'CS Explorer',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    if (inDrawer)
                      Semantics(
                        button: true,
                        label: 'Close menu',
                        child: IconButton(
                          onPressed: () => Scaffold.maybeOf(context)?.closeDrawer(),
                          icon: Icon(
                            Icons.close_rounded,
                            size: 20,
                            color: scheme.onSurfaceVariant,
                          ),
                          tooltip: 'Close menu',
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(),

              // 2. Clean Typographic Stations List + Final Puzzle Button
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  children: [
                    for (final station in stations) ...[
                      _SoberStationRow(
                        station: station,
                        isCurrent:
                            progress.statusFor(station.id) ==
                            StationVisitStatus.current,
                        isUnlocked: progress.isStationUnlocked(
                          station.id,
                          demoUnlockAll: allowBrowseAll,
                        ),
                        hasPiece: progress.hasCollectedPiece(station.id),
                        showPuzzleBadge: showArPuzzles,
                        isDark: isDark,
                        onTapUnlocked: () => _invokeMenuAction(
                          context,
                          () => onSelectStation(station.id),
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                    if (showArPuzzles && finalReady) ...[
                      const SizedBox(height: 12),
                      _FinalPuzzleMenuButton(
                        onTap: () =>
                            _invokeMenuAction(context, onOpenFinalPuzzle),
                      ),
                    ] else if (isLaptop) ...[
                      const SizedBox(height: 12),
                      _LockedFinalPuzzleMenuRow(
                        onTap: () {
                          ScaffoldMessenger.maybeOf(context)
                            ?..hideCurrentSnackBar()
                            ..showSnackBar(
                              const SnackBar(
                                behavior: SnackBarBehavior.floating,
                                duration: Duration(seconds: 3),
                                content: TrText(
                                  'Collect AR puzzle pieces on a phone or tablet to unlock the Final AR Puzzle.',
                                ),
                              ),
                            );
                        },
                      ),
                    ],
                  ],
                ),
              ),

              const Divider(),

              // 3. Sober Footer Actions: Settings & Meet the Team
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                child: Column(
                  children: [
                    _FooterNavItem(
                      icon: Icons.tune_rounded,
                      label: 'Settings',
                      semanticsLabel: 'Open Settings',
                      onTap: () => _invokeMenuAction(context, onOpenSettings),
                    ),
                    const SizedBox(height: 2),
                    _FooterNavItem(
                      icon: Icons.people_outline_rounded,
                      label: 'Meet the Team',
                      semanticsLabel: 'Open Meet the Team and Contributors',
                      onTap: () => _invokeMenuAction(context, onOpenTeam),
                    ),
                  ],
                ),
              ),

              // 4. Bottom Footer: Demo Mode Toggle (Mobile) OR Laptop Mode Notice
              if (isLaptop)
                _LaptopModeFooterBar(isDark: isDark)
              else
                SafeArea(
                  top: false,
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? CsAppTheme.darkSurface
                          : const Color(0xFFEFEDE7),
                      border: Border(
                        top: BorderSide(color: scheme.outlineVariant),
                      ),
                    ),
                    child: Semantics(
                      toggled: demoUnlock,
                      label: 'DEMO MODE Prototype Build unlock switch',
                      child: InkWell(
                        onTap: () => settings.setDemoUnlockAll(!demoUnlock),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 52),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 6,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      TrText(
                                        'DEMO MODE · Prototype Build',
                                        style: theme.textTheme.labelMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 0.2,
                                            ),
                                      ),
                                      TrText(
                                        demoUnlock
                                            ? 'All stations unlocked for preview'
                                            : 'Scan stations on-site to unlock',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              fontSize: 11,
                                              color: scheme.onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: demoUnlock,
                                  onChanged: settings.setDemoUnlockAll,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }
}

class _SoberStationRow extends StatelessWidget {
  const _SoberStationRow({
    required this.station,
    required this.isCurrent,
    required this.isUnlocked,
    required this.hasPiece,
    required this.isDark,
    required this.onTapUnlocked,
    this.showPuzzleBadge = true,
  });

  final StationSpec station;
  final bool isCurrent;
  final bool isUnlocked;
  final bool hasPiece;
  final bool isDark;
  final VoidCallback onTapUnlocked;
  final bool showPuzzleBadge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final Color titleColor;
    if (!isUnlocked) {
      titleColor = isDark
          ? CsAppTheme.darkMutedGrey
          : CsAppTheme.lightMutedGrey;
    } else if (isCurrent) {
      titleColor = scheme.secondary;
    } else {
      titleColor = scheme.onSurface;
    }

    final Color subtitleColor = !isUnlocked
        ? (isDark
              ? CsAppTheme.darkMutedGrey.withValues(alpha: 0.82)
              : CsAppTheme.lightMutedGrey)
        : scheme.onSurfaceVariant;

    final rowBg = isCurrent && isUnlocked
        ? scheme.secondary.withValues(alpha: isDark ? 0.14 : 0.10)
        : Colors.transparent;

    final content = Container(
      constraints: const BoxConstraints(minHeight: 54),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: rowBg,
        borderRadius: BorderRadius.circular(12),
        border: isCurrent && isUnlocked
            ? Border(
                left: BorderSide(
                  color: scheme.secondary,
                  width: 3,
                ),
              )
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TrText(
                  station.title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 14.5,
                    fontWeight: isCurrent
                        ? FontWeight.w700
                        : (isUnlocked ? FontWeight.w600 : FontWeight.w400),
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 2),
                TrText(
                  station.floorLabel,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 11.5,
                    color: subtitleColor,
                  ),
                ),
              ],
            ),
          ),
          if (showPuzzleBadge && station.hasPuzzlePiece) ...[
            const SizedBox(width: 10),
            Semantics(
              label: hasPiece
                  ? 'Puzzle piece collected'
                  : 'Puzzle piece uncollected',
              child: PuzzlePieceIcon(
                collected: hasPiece,
                size: 19,
                activeColor: isCurrent ? scheme.secondary : scheme.primary,
                inactiveColor: scheme.onSurface.withValues(
                  alpha: isUnlocked ? 0.30 : 0.18,
                ),
              ),
            ),
          ],
        ],
      ),
    );

    if (!isUnlocked) {
      return Semantics(
        enabled: false,
        label: '${station.title}, locked, ${station.floorLabel}',
        child: content,
      );
    }

    return Semantics(
      button: true,
      selected: isCurrent,
      label: '${station.title}, ${station.floorLabel}',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTapUnlocked,
          child: content,
        ),
      ),
    );
  }
}

class _FinalPuzzleMenuButton extends StatelessWidget {
  const _FinalPuzzleMenuButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Semantics(
      button: true,
      label: 'Assemble the Final Puzzle',
      child: Material(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  PuzzlePieceIcon(
                    collected: true,
                    size: 20,
                    activeColor: scheme.onPrimary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TrText(
                      'Assemble the Final Puzzle',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: scheme.onPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: scheme.onPrimary,
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

class _LockedFinalPuzzleMenuRow extends StatelessWidget {
  const _LockedFinalPuzzleMenuRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Semantics(
      button: true,
      label: 'Final AR Puzzle, Mobile only',
      child: Material(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 52),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.7),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TrText(
                        'Final AR Puzzle',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TrText(
                        'Mobile only',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
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

class _LaptopModeFooterBar extends StatelessWidget {
  const _LaptopModeFooterBar({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? CsAppTheme.darkSurface : const Color(0xFFEFEDE7),
          border: Border(top: BorderSide(color: scheme.outlineVariant)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Row(
          children: [
            Icon(
              Icons.laptop_mac_rounded,
              size: 18,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  TrText(
                    'Laptop Guide Mode',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                  TrText(
                    'Browse all stations · AR mobile-only',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FooterNavItem extends StatelessWidget {
  const _FooterNavItem({
    required this.icon,
    required this.label,
    required this.semanticsLabel,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String semanticsLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Semantics(
      button: true,
      label: semanticsLabel,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Icon(icon, size: 19, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TrText(
                      label,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: scheme.onSurfaceVariant,
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

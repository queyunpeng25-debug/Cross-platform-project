import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zenify/zenify.dart';

import '../../core/controllers.dart';
import '../../core/device_capabilities.dart';
import '../../core/models.dart';
import '../../core/translation_service.dart';
import '../../ui/puzzle_icon.dart';

/// Shared museum-style station view modeled directly on the *Natural History Museum*
/// reference:
/// - **100% full-screen background photograph** (`Positioned.fill`) of the space.
/// - **Genuinely translucent frosted-glass sheet** (`AsymmetricTranslucentSheet`)
///   with a sweeping rounded curve on **top-left ONLY** (`Radius.circular(68)`)
///   and a straight horizontal top edge meeting the right border.
/// - Sober neutral charcoal & warm-stone typography, drawn vector [PuzzlePieceIcon],
///   zero videos/timings/reviews, and clean matte bottom action button(s).
class StationDetailScreen extends StatelessWidget {
  const StationDetailScreen({
    super.key,
    required this.station,
    required this.onBackToLobby,
    required this.onOpenSideMenu,
    required this.onCatchPuzzlePiece,
    this.onRunSecondaryAction,
    this.introSection,
    this.showMenuButton = true,
    this.isRootLobbyView = false,
    this.reserveBottomDockSpace = false,
  });

  final StationSpec station;
  final VoidCallback onBackToLobby;
  final VoidCallback onOpenSideMenu;
  final VoidCallback onCatchPuzzlePiece;
  final VoidCallback? onRunSecondaryAction;
  final Widget? introSection;
  final bool showMenuButton;
  final bool isRootLobbyView;
  final bool reserveBottomDockSpace;

  static const String _aaltoSpaceUrl =
      'https://www.aalto.fi/en/services/aalto-space-mobile-application';

  bool get _mentionsAaltoSpace {
    for (final p in station.paragraphs) {
      if (p.toLowerCase().contains('aalto space')) return true;
    }
    for (final c in station.callouts) {
      if (c.body.toLowerCase().contains('aalto space')) return true;
    }
    return false;
  }

  bool get _isSecondaryActionMobileOnly =>
      station.secondaryActionKind == SecondaryActionKind.portraitArScanner ||
      station.secondaryActionKind == SecondaryActionKind.greenhouseMinigame ||
      station.secondaryActionKind == SecondaryActionKind.openScanner;

  String _resolvedSecondaryActionLabel() {
    if (DeviceCapabilities.isMobileWeb &&
        station.secondaryActionKind == SecondaryActionKind.portraitArScanner) {
      return 'Scan Portrait (Web Camera)';
    }
    return station.secondaryActionLabel!;
  }

  Future<void> _launchExternalLink(BuildContext context, String rawUrl) async {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) return;
    var ok = false;
    try {
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      ok = false;
    }
    if (!ok && context.mounted) {
      ScaffoldMessenger.maybeOf(context)
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: TrText('Could not open link: $rawUrl')),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = Zen.findOrNull<TourProgressController>();
    if (progress == null) {
      return _buildGlassOverlayScreen(context, pieceCaught: false);
    }

    return ZenObserver(() {
      final caught = progress.hasCollectedPiece(station.id);
      return _buildGlassOverlayScreen(context, pieceCaught: caught);
    });
  }

  Widget _buildGlassOverlayScreen(
    BuildContext context, {
    required bool pieceCaught,
  }) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final bottomClearance = reserveBottomDockSpace
        ? bottomInset + 92.0
        : bottomInset + 16.0;

    final isLaptop = DeviceCapabilities.isLaptopMode;
    final showArPuzzles = DeviceCapabilities.supportsArExperiences;
    final showPuzzleCta = station.hasPuzzlePiece && showArPuzzles;
    final showSecondaryAction =
        !isRootLobbyView &&
        station.secondaryActionKind != null &&
        station.secondaryActionLabel != null &&
        onRunSecondaryAction != null;
    final isSecondaryLocked = isLaptop && _isSecondaryActionMobileOnly;

    return ColoredBox(
      color: const Color(0xFF1A1918),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalHeight = constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : MediaQuery.sizeOf(context).height;
          final sheetTop = math.max(120.0, totalHeight * 0.30);

          return Stack(
            fit: StackFit.expand,
            children: [
              // 1. 100% Full-Screen Background Photograph (shines behind glass all the way down)
              Positioned.fill(
                child: Image.asset(
                  station.heroAsset,
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  errorBuilder: (_, _, _) => const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF3A3530), Color(0xFF1E1C1A)],
                      ),
                    ),
                  ),
                ),
              ),

              // Subtle top/bottom vignette for effortless icon contrast
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.0, 0.28, 1.0],
                      colors: [
                        Colors.black.withValues(alpha: 0.36),
                        Colors.black.withValues(alpha: 0.06),
                        Colors.black.withValues(alpha: 0.32),
                      ],
                    ),
                  ),
                ),
              ),

              // 2. Top Floating Controls (Menu or Back on top-left, Puzzle status on top-right)
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
                        if (!isRootLobbyView) ...[
                          _FrostedIconSquircle(
                            icon: Icons.chevron_left_rounded,
                            iconSize: 26,
                            semanticsLabel: 'Back to Lobby',
                            onTap: onBackToLobby,
                          ),
                          const SizedBox(width: 10),
                        ],
                        if (showMenuButton)
                          _FrostedIconSquircle(
                            icon: Icons.menu_rounded,
                            iconSize: 21,
                            label: isRootLobbyView ? 'Guide' : null,
                            semanticsLabel: 'Open building stations menu',
                            onTap: onOpenSideMenu,
                          ),
                        const Spacer(),
                        if (station.hasPuzzlePiece || isLaptop)
                          _FrostedStatusPill(
                            floorLabel: station.floorLabel,
                            pieceCaught: pieceCaught,
                            showPuzzleIcon:
                                showArPuzzles && station.hasPuzzlePiece,
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              // 3. Asymmetric Translucent Frosted Glass Sheet
              // (Rounded ONLY on top-left, continuous straight line on top-right)
              Positioned(
                top: sheetTop,
                left: 0,
                right: 0,
                bottom: 0,
                child: AsymmetricTranslucentSheet(
                  topLeftRadius: 68,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(26, 30, 24, 18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Title & Subtitle
                              TrText(
                                station.title,
                                style: const TextStyle(
                                  fontSize: 25,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.4,
                                  height: 1.18,
                                  color: Color(0xFFF9F7F3),
                                ),
                              ),
                              const SizedBox(height: 6),
                              TrText(
                                station.subtitle,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(
                                    0xFFE8E2D8,
                                  ).withValues(alpha: 0.84),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Optional custom intro section (e.g. Lobby guide & route)
                              if (introSection != null) ...[
                                introSection!,
                                const SizedBox(height: 16),
                              ],

                              // Conversational body paragraphs
                              for (final paragraph in station.paragraphs) ...[
                                TrText(
                                  paragraph,
                                  style: const TextStyle(
                                    fontSize: 14.5,
                                    height: 1.58,
                                    color: Color(0xFFF4F1EB),
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],

                              // Optional Aalto Space quick link chip
                              if (_mentionsAaltoSpace) ...[
                                const SizedBox(height: 2),
                                _TranslucentLinkChip(
                                  icon: Icons.open_in_new_rounded,
                                  label: 'Open Aalto Space Room Booking',
                                  onTap: () =>
                                      _launchExternalLink(context, _aaltoSpaceUrl),
                                ),
                                const SizedBox(height: 16),
                              ],

                              // Compact translucent Insider Highlights
                              if (station.callouts.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                for (final callout in station.callouts) ...[
                                  _TranslucentCalloutCard(callout: callout),
                                  const SizedBox(height: 10),
                                ],
                              ],

                              // Student Guilds Linktree Hub (when station has guilds)
                              if (station.guilds.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                _SoberGuildsHub(
                                  guilds: station.guilds,
                                  onLaunchUrl: (url) =>
                                      _launchExternalLink(context, url),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),

                      // 4. Bottom Matte Charcoal Action Bar
                      if (showSecondaryAction || showPuzzleCta)
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            22,
                            8,
                            22,
                            bottomClearance,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (showSecondaryAction) ...[
                                if (isSecondaryLocked)
                                  _LockedMobileActionButton(
                                    label: station.secondaryActionLabel!,
                                    onTap: onRunSecondaryAction!,
                                  )
                                else
                                  _SoberActionButton(
                                    label: _resolvedSecondaryActionLabel(),
                                    icon: Icons.explore_outlined,
                                    filled: false,
                                    onTap: onRunSecondaryAction!,
                                  ),
                                if (showPuzzleCta) const SizedBox(height: 10),
                              ],
                              if (showPuzzleCta)
                                _SoberActionButton(
                                  label: pieceCaught
                                      ? 'Puzzle Piece Collected · Replay AR'
                                      : station.puzzleCtaLabel,
                                  customLeading: PuzzlePieceIcon(
                                    collected: pieceCaught,
                                    size: 19,
                                    activeColor: const Color(0xFFD9CBB8),
                                    inactiveColor: const Color(0xFFF7F5F0),
                                  ),
                                  filled: true,
                                  onTap: onCatchPuzzlePiece,
                                ),
                            ],
                          ),
                        )
                      else if (reserveBottomDockSpace)
                        SizedBox(height: bottomClearance),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FrostedIconSquircle extends StatelessWidget {
  const _FrostedIconSquircle({
    required this.icon,
    required this.iconSize,
    required this.semanticsLabel,
    required this.onTap,
    this.label,
  });

  final IconData icon;
  final double iconSize;
  final String semanticsLabel;
  final VoidCallback onTap;
  final String? label;

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
            color: const Color(0xFF22201E).withValues(alpha: 0.44),
            child: InkWell(
              onTap: onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: label != null ? 14 : 11,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, size: iconSize, color: Colors.white),
                      if (label != null) ...[
                        const SizedBox(width: 8),
                        TrText(
                          label!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
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

class _FrostedStatusPill extends StatelessWidget {
  const _FrostedStatusPill({
    required this.floorLabel,
    required this.pieceCaught,
    this.showPuzzleIcon = true,
  });

  final String floorLabel;
  final bool pieceCaught;
  final bool showPuzzleIcon;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF22201E).withValues(alpha: 0.44),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.20),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: showPuzzleIcon ? 150 : 220,
                ),
                child: TrText(
                  floorLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFF3F0EA),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (showPuzzleIcon) ...[
                const SizedBox(width: 8),
                PuzzlePieceIcon(
                  collected: pieceCaught,
                  size: 16,
                  activeColor: const Color(0xFFD9CBB8),
                  inactiveColor: Colors.white.withValues(alpha: 0.55),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TranslucentCalloutCard extends StatelessWidget {
  const _TranslucentCalloutCard({required this.callout});

  final StationCallout callout;

  static IconData _resolveIcon(String key) {
    return switch (key) {
      'stairs' || 'signs' => Icons.signpost_outlined,
      'food' || 'canteen' => Icons.restaurant_outlined,
      'coat' || 'wardrobe' => Icons.checkroom_outlined,
      'pool' || 'billiards' => Icons.sports_bar_outlined,
      'booking' || 'room' => Icons.meeting_room_outlined,
      'office' || 'staff' => Icons.badge_outlined,
      'lab' || 'science' => Icons.biotech_outlined,
      'coffee' || 'cafe' => Icons.coffee_outlined,
      'key' || 'lock' => Icons.vpn_key_outlined,
      'quiet' || 'study' => Icons.menu_book_outlined,
      'bridge' || 'shortcut' => Icons.directions_walk_rounded,
      _ => Icons.info_outline_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.16),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(
              _resolveIcon(callout.icon),
              size: 18,
              color: const Color(0xFFE6DDD0),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TrText(
                  callout.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFF9F7F3),
                  ),
                ),
                const SizedBox(height: 4),
                TrText(
                  callout.body,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.48,
                    color: const Color(0xFFF0ECE4).withValues(alpha: 0.88),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TranslucentLinkChip extends StatelessWidget {
  const _TranslucentLinkChip({
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
        color: Colors.white.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 17, color: const Color(0xFFE6DDD0)),
                  const SizedBox(width: 8),
                  Flexible(
                    child: TrText(
                      label,
                      style: const TextStyle(
                        fontSize: 13,
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

class _SoberGuildsHub extends StatelessWidget {
  const _SoberGuildsHub({
    required this.guilds,
    required this.onLaunchUrl,
  });

  final List<GuildProfile> guilds;
  final ValueChanged<String> onLaunchUrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TrText(
          'Student Guild Channels & Links',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Color(0xFFF9F7F3),
          ),
        ),
        const SizedBox(height: 10),
        for (final guild in guilds) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        guild.shortTag,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFF9F7F3),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TrText(
                        guild.name,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFF9F7F3),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                TrText(
                  guild.description,
                  style: TextStyle(
                    fontSize: 12.8,
                    height: 1.45,
                    color: const Color(0xFFF0ECE4).withValues(alpha: 0.86),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final link in guild.links)
                      Semantics(
                        button: true,
                        label: '${guild.name} ${link.label}',
                        child: Material(
                          color: const Color(0xFF22201E).withValues(alpha: 0.56),
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => onLaunchUrl(link.url),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                minHeight: 40,
                                minWidth: 48,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.north_east_rounded,
                                      size: 14,
                                      color: Color(0xFFD9CBB8),
                                    ),
                                    const SizedBox(width: 6),
                                    TrText(
                                      link.label,
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFFF9F7F3),
                                      ),
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
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _SoberActionButton extends StatelessWidget {
  const _SoberActionButton({
    required this.label,
    required this.filled,
    required this.onTap,
    this.icon,
    this.customLeading,
  });

  final String label;
  final bool filled;
  final VoidCallback onTap;
  final IconData? icon;
  final Widget? customLeading;

  @override
  Widget build(BuildContext context) {
    final bg = filled
        ? const Color(0xFF242220)
        : Colors.white.withValues(alpha: 0.14);
    final border = filled
        ? Colors.white.withValues(alpha: 0.14)
        : Colors.white.withValues(alpha: 0.28);

    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 52),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (customLeading != null) ...[
                  customLeading!,
                  const SizedBox(width: 10),
                ] else if (icon != null) ...[
                  Icon(icon, size: 19, color: const Color(0xFFF7F5F0)),
                  const SizedBox(width: 10),
                ],
                Flexible(
                  child: TrText(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.1,
                      color: Color(0xFFF7F5F0),
                    ),
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

class _LockedMobileActionButton extends StatelessWidget {
  const _LockedMobileActionButton({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label, Mobile only',
      child: Material(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 52),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.18),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 18,
                  color: const Color(0xFFE8E2D8).withValues(alpha: 0.72),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: TrText(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFE8E2D8).withValues(alpha: 0.78),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const TrText(
                    'Mobile only',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFD9CBB8),
                    ),
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

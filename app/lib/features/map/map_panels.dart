import 'package:flutter/material.dart';

import '../../core/translation_service.dart';
import '../../ui/puzzle_icon.dart';
import '../../ui/theme.dart';
import 'cs_building_map_data.dart';
import 'map_pins.dart';

/// Rounded status label, e.g. "Visited" or "Puzzle piece collected".
class MapStatusPill extends StatelessWidget {
  const MapStatusPill({
    super.key,
    required this.label,
    this.color,
    this.icon,
    this.leading,
  });

  final String label;
  final Color? color;
  final IconData? icon;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = color ?? theme.colorScheme.onSurface;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tint.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null)
            leading!
          else if (icon != null)
            Icon(icon, size: 14, color: tint)
          else
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
            ),
          const SizedBox(width: 6),
          Flexible(
            child: TrText(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Coloured circle with an icon, used as the leading visual of a card.
class MapRoundIcon extends StatelessWidget {
  const MapRoundIcon({super.key, required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Icon(icon, color: Colors.white, size: 21),
    );
  }
}

/// Zoom in / zoom out / reset / my-location buttons on the map.
class MapZoomControls extends StatelessWidget {
  const MapZoomControls({
    super.key,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onReset,
    required this.onMyLocation,
    this.onLegend,
  });

  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onReset;
  final VoidCallback? onMyLocation;

  /// Shown only when the legend is not already visible on screen.
  final VoidCallback? onLegend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget button(IconData icon, String tooltip, VoidCallback? onPressed) {
      return IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        visualDensity: VisualDensity.compact,
      );
    }

    return Material(
      color: theme.colorScheme.surface.withValues(alpha: 0.94),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          button(Icons.add_rounded, 'Zoom in', onZoomIn),
          button(Icons.remove_rounded, 'Zoom out', onZoomOut),
          button(Icons.fit_screen_rounded, 'Show whole floor', onReset),
          button(Icons.my_location_rounded, 'Show my position', onMyLocation),
          if (onLegend != null)
            button(Icons.info_outline_rounded, 'Map legend', onLegend),
        ],
      ),
    );
  }
}

/// Banner shown when the visitor is on a different floor than the one shown.
class OffFloorBanner extends StatelessWidget {
  const OffFloorBanner({super.key, required this.floor, required this.onTap});

  final int floor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const white = TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.w700,
      fontSize: 12.5,
    );
    return Material(
      color: kYouAreHereRed,
      borderRadius: BorderRadius.circular(999),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.my_location_rounded, color: Colors.white, size: 16),
              const SizedBox(width: 6),
              const Flexible(
                child: TrText(
                  'You are on',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: white,
                ),
              ),
              const SizedBox(width: 4),
              Text(CsBuildingMapData.floorShort(floor), style: white),
              const SizedBox(width: 6),
              const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

/// Explains every symbol on the map. Used in a card (wide) or bottom sheet.
class MapLegend extends StatelessWidget {
  const MapLegend({super.key, this.showMobileFeatures = true});

  final bool showMobileFeatures;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget dot(Color color) => Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 2)],
      ),
    );

    Widget row(Widget visual, String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(width: 26, child: Center(child: visual)),
          const SizedBox(width: 10),
          Expanded(
            child: TrText(text, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TrText(
          'Map legend',
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        row(
          SizedBox.square(
            dimension: 22,
            child: CustomPaint(painter: _MiniBeaconPainter()),
          ),
          'You are here',
        ),
        row(
          dot(CsStatusColors.currentRed),
          showMobileFeatures
              ? 'Current station (last one you scanned)'
              : 'Current station',
        ),
        row(dot(CsStatusColors.visitedGreen), 'Visited station'),
        row(dot(CsStatusColors.unvisitedBlue), 'Station not visited yet'),
        if (showMobileFeatures) ...[
          row(
            const Icon(Icons.lock_rounded, size: 16),
            'Locked: scan its marker on site',
          ),
          row(
            const PuzzlePieceIcon(collected: false, size: 18),
            'Puzzle piece still hidden at this station',
          ),
          row(
            const PuzzlePieceIcon(
              collected: true,
              size: 18,
              activeColor: kPuzzleGold,
            ),
            'Puzzle piece collected',
          ),
        ],
        row(
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: kCallPodGlow,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: kCallPodGlow.withValues(alpha: 0.6),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(Icons.phone_in_talk_rounded, size: 11, color: Colors.white),
          ),
          'Call pods: walk-in, not bookable',
        ),
        if (showMobileFeatures)
          row(
            const Icon(Icons.qr_code_2_rounded, size: 18),
            'Spot with a "You are here" QR sticker',
          ),
        row(
          SizedBox.square(
            dimension: 18,
            child: CustomPaint(
              painter: _HatchSwatchPainter(theme.colorScheme.onSurface),
            ),
          ),
          'Keycard-only research wing, or open space above the lobby',
        ),
      ],
    );
  }
}

class _MiniBeaconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    canvas.drawCircle(c, size.width / 2, Paint()..color = kYouAreHereRed.withValues(alpha: 0.25));
    canvas.drawCircle(c, 6, Paint()..color = Colors.white);
    canvas.drawCircle(c, 4, Paint()..color = kYouAreHereRed);
  }

  @override
  bool shouldRepaint(_MiniBeaconPainter oldDelegate) => false;
}

class _HatchSwatchPainter extends CustomPainter {
  _HatchSwatchPainter(this.ink);

  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(4));
    canvas.drawRRect(rrect, Paint()..color = ink.withValues(alpha: 0.06));
    canvas.save();
    canvas.clipRRect(rrect);
    final line = Paint()
      ..color = ink.withValues(alpha: 0.35)
      ..strokeWidth = 1;
    for (var x = -size.height; x < size.width; x += 4) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), line);
    }
    canvas.restore();
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = ink.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_HatchSwatchPainter oldDelegate) => oldDelegate.ink != ink;
}

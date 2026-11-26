import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/translation_service.dart';
import '../../ui/puzzle_icon.dart';
import 'map_models.dart';

/// Amber used to "light up" call pods on the map.
const Color kCallPodGlow = Color(0xFFE3A23B);

/// Gold used for collected puzzle pieces (matches the puzzle hunt accent).
const Color kPuzzleGold = Color(0xFFD99B26);

/// Red used for the "You are here" beacon.
const Color kYouAreHereRed = Color(0xFFC85A48);

IconData iconForPlace(MapPlaceKind kind) => switch (kind) {
  MapPlaceKind.lift => Icons.elevator_rounded,
  MapPlaceKind.stairs => Icons.stairs_rounded,
  MapPlaceKind.toilet => Icons.wc_rounded,
  MapPlaceKind.entrance => Icons.door_front_door_rounded,
  MapPlaceKind.accessibleEntrance => Icons.accessible_forward_rounded,
  MapPlaceKind.infoDesk => Icons.support_agent_rounded,
  MapPlaceKind.wardrobe => Icons.checkroom_rounded,
  MapPlaceKind.callPod => Icons.phone_in_talk_rounded,
  MapPlaceKind.parking => Icons.local_parking_rounded,
  MapPlaceKind.skybridge => Icons.swap_horiz_rounded,
  MapPlaceKind.billiards => Icons.table_restaurant_rounded,
  MapPlaceKind.transit => Icons.directions_subway_rounded,
};

enum PuzzleBadge { none, hidden, collected }

/// Small caption shown under pins.
class _PinCaption extends StatelessWidget {
  const _PinCaption(this.text, {this.emphasised = false});

  final String text;
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 1),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(6),
        boxShadow: const [
          BoxShadow(color: Color(0x22000000), blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
      child: TrText(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: emphasised ? FontWeight.w800 : FontWeight.w600,
          fontSize: 10.5,
          height: 1.15,
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 17,
      height: 17,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        shape: BoxShape.circle,
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 2)],
      ),
      child: child,
    );
  }
}

/// Tour station pin: status colour (red / green / blue), station icon,
/// optional lock and puzzle-piece badges, and a caption when zoomed in.
class StationMapPin extends StatelessWidget {
  const StationMapPin({
    super.key,
    required this.icon,
    required this.color,
    required this.caption,
    required this.showCaption,
    required this.locked,
    required this.puzzle,
    required this.selected,
    required this.semanticLabel,
    required this.onTap,
  });

  static const double boxWidth = 124;
  static const double hitSize = 44;
  static const double boxHeight = hitSize + 22;

  /// Point inside the box that sits exactly on the map coordinate.
  static const Offset anchor = Offset(boxWidth / 2, hitSize / 2);

  final IconData icon;
  final Color color;
  final String caption;
  final bool showCaption;
  final bool locked;
  final PuzzleBadge puzzle;
  final bool selected;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final circle = selected ? 38.0 : 32.0;
    return SizedBox(
      width: boxWidth,
      height: boxHeight,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            button: true,
            selected: selected,
            label: semanticLabel,
            excludeSemantics: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: SizedBox(
                width: hitSize,
                height: hitSize,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: circle,
                      height: circle,
                      decoration: BoxDecoration(
                        color: locked ? Color.lerp(color, Colors.grey, 0.45) : color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: selected ? 3 : 2.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.28),
                            blurRadius: selected ? 10 : 5,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(icon, size: selected ? 19 : 17, color: Colors.white),
                    ),
                    if (puzzle != PuzzleBadge.none)
                      Positioned(
                        right: -1,
                        top: -1,
                        child: _Badge(
                          child: PuzzlePieceIcon(
                            collected: puzzle == PuzzleBadge.collected,
                            size: 13,
                            activeColor: kPuzzleGold,
                          ),
                        ),
                      ),
                    if (locked)
                      const Positioned(
                        right: -1,
                        bottom: -1,
                        child: _Badge(
                          child: Icon(Icons.lock_rounded, size: 10),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (showCaption || selected)
            Flexible(
              child: GestureDetector(
                onTap: onTap,
                child: _PinCaption(caption, emphasised: selected),
              ),
            ),
        ],
      ),
    );
  }
}

/// Facility / call-pod pin. Call pods glow amber so they stand out.
class PlaceMapPin extends StatelessWidget {
  const PlaceMapPin({
    super.key,
    required this.place,
    required this.selected,
    required this.showCaption,
    required this.onTap,
  });

  static const double boxWidth = 112;
  static const double hitSize = 40;
  static const double boxHeight = hitSize + 20;
  static const Offset anchor = Offset(boxWidth / 2, hitSize / 2);

  final MapPlace place;
  final bool selected;
  final bool showCaption;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCallPod = place.kind == MapPlaceKind.callPod;
    final fill = isCallPod ? kCallPodGlow : theme.colorScheme.surface;
    final iconColor = isCallPod ? Colors.white : theme.colorScheme.onSurface;
    final circle = selected ? 30.0 : (isCallPod ? 27.0 : 24.0);

    return SizedBox(
      width: boxWidth,
      height: boxHeight,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            button: true,
            selected: selected,
            label: '${place.label}, ${place.hasQrMarker ? 'has a You are here QR code' : 'facility'}',
            excludeSemantics: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: SizedBox(
                width: hitSize,
                height: hitSize,
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: circle,
                    height: circle,
                    decoration: BoxDecoration(
                      color: fill,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected
                            ? theme.colorScheme.onSurface
                            : (isCallPod
                                  ? Colors.white
                                  : theme.colorScheme.outline),
                        width: selected ? 2.4 : 1.4,
                      ),
                      boxShadow: [
                        if (isCallPod)
                          BoxShadow(
                            color: kCallPodGlow.withValues(alpha: 0.65),
                            blurRadius: 16,
                            spreadRadius: 4,
                          ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Icon(
                      iconForPlace(place.kind),
                      size: selected ? 17 : 15,
                      color: iconColor,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (showCaption || selected)
            Flexible(
              child: GestureDetector(
                onTap: onTap,
                child: _PinCaption(place.label, emphasised: selected),
              ),
            ),
        ],
      ),
    );
  }
}

/// Puzzle-only marker, used when the station layer is hidden but the
/// puzzle-piece layer is visible.
class PuzzleMapMarker extends StatelessWidget {
  const PuzzleMapMarker({
    super.key,
    required this.collected,
    required this.semanticLabel,
    required this.onTap,
  });

  static const double size = 36;
  static const Offset anchor = Offset(size / 2, size / 2);

  final bool collected;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              shape: BoxShape.circle,
              border: Border.all(
                color: collected ? kPuzzleGold : theme.colorScheme.outline,
                width: 1.6,
              ),
              boxShadow: const [
                BoxShadow(color: Color(0x33000000), blurRadius: 3),
              ],
            ),
            child: PuzzlePieceIcon(
              collected: collected,
              size: 18,
              activeColor: kPuzzleGold,
            ),
          ),
        ),
      ),
    );
  }
}

/// Pulsing "You are here" beacon. Purely visual: taps pass through it.
class YouAreHereBeacon extends StatefulWidget {
  const YouAreHereBeacon({super.key, this.showDot = true});

  static const double size = 84;
  static const Offset anchor = Offset(size / 2, size / 2);

  /// Hide the centre dot when a station pin already sits on top of it.
  final bool showDot;

  @override
  State<YouAreHereBeacon> createState() => _YouAreHereBeaconState();
}

class _YouAreHereBeaconState extends State<YouAreHereBeacon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1700),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion) {
      _pulse.stop();
      _pulse.value = 0.55;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox.square(
        dimension: YouAreHereBeacon.size,
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, _) => CustomPaint(
            painter: _BeaconPainter(progress: _pulse.value, showDot: widget.showDot),
          ),
        ),
      ),
    );
  }
}

class _BeaconPainter extends CustomPainter {
  _BeaconPainter({required this.progress, required this.showDot});

  final double progress;
  final bool showDot;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final maxRadius = size.width / 2;
    for (final phase in [0.0, 0.5]) {
      final t = (progress + phase) % 1.0;
      final radius = 12 + (maxRadius - 12) * Curves.easeOut.transform(t);
      canvas.drawCircle(
        centre,
        radius,
        Paint()..color = kYouAreHereRed.withValues(alpha: 0.32 * (1 - t)),
      );
    }
    if (showDot) {
      canvas.drawCircle(centre, 10, Paint()..color = Colors.white);
      canvas.drawCircle(centre, 7, Paint()..color = kYouAreHereRed);
    }
  }

  @override
  bool shouldRepaint(_BeaconPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.showDot != showDot;
}

/// "You are here" chip that floats above the beacon.
class YouAreHereChip extends StatelessWidget {
  const YouAreHereChip({super.key});

  static const Size size = Size(120, 24);

  /// Bottom centre of the chip sits just above the beacon/pin.
  static const Offset anchor = Offset(60, 24 + 22);

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: kYouAreHereRed,
            borderRadius: BorderRadius.circular(999),
            boxShadow: const [
              BoxShadow(color: Color(0x40000000), blurRadius: 4, offset: Offset(0, 1)),
            ],
          ),
          child: const TrText(
            'You are here',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

/// Caption for a zone (e.g. "Main lobby"), optionally rotated for streets.
class MapZoneLabel extends StatelessWidget {
  const MapZoneLabel({
    super.key,
    required this.text,
    required this.color,
    this.translate = true,
    this.quarterTurns = 0,
  });

  static const Size baseSize = Size(160, 18);

  static Size sizeFor(int quarterTurns) => quarterTurns.isOdd
      ? Size(baseSize.height, baseSize.width)
      : baseSize;

  final String text;
  final Color color;
  final bool translate;
  final int quarterTurns;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: color,
      fontSize: 10.5,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.3,
    );
    final label = SizedBox.fromSize(
      size: baseSize,
      child: Center(
        child: translate
            ? TrText(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: style,
              )
            : Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: style,
              ),
      ),
    );
    return IgnorePointer(
      child: quarterTurns == 0
          ? label
          : RotatedBox(quarterTurns: quarterTurns, child: label),
    );
  }
}

/// Small compass showing where true north is (the plan is rotated ~10°).
class MapCompass extends StatelessWidget {
  const MapCompass({super.key, required this.rotationDegrees});

  final double rotationDegrees;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: 'Compass: north is up, slightly to the left',
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: 0.92),
          shape: BoxShape.circle,
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Transform.rotate(
          angle: rotationDegrees * math.pi / 180,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.navigation_rounded, size: 14, color: kYouAreHereRed),
              Text(
                'N',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

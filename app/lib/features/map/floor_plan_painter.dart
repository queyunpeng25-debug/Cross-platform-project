import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'cs_building_map_data.dart';
import 'map_models.dart';

/// Converts plan metres into canvas pixels for a given viewport size.
///
/// The whole [CsBuildingMapData.planBounds] is fitted ("contain") into the
/// viewport, so the building is fully visible at zoom 1 on any screen.
@immutable
class PlanProjection {
  const PlanProjection({required this.scale, required this.origin});

  factory PlanProjection.fit(Size viewport, Rect plan, {double padding = 10}) {
    final availableWidth = math.max(1.0, viewport.width - 2 * padding);
    final availableHeight = math.max(1.0, viewport.height - 2 * padding);
    final scale = math.min(
      availableWidth / plan.width,
      availableHeight / plan.height,
    );
    final drawnWidth = plan.width * scale;
    final drawnHeight = plan.height * scale;
    return PlanProjection(
      scale: scale,
      origin: Offset(
        (viewport.width - drawnWidth) / 2 - plan.left * scale,
        (viewport.height - drawnHeight) / 2 - plan.top * scale,
      ),
    );
  }

  /// Canvas pixels per plan metre at zoom 1.
  final double scale;

  /// Canvas position of the plan origin (0 m, 0 m).
  final Offset origin;

  Offset toCanvas(Offset planPoint) => origin + planPoint * scale;

  Offset toPlan(Offset canvasPoint) => (canvasPoint - origin) / scale;

  @override
  bool operator ==(Object other) =>
      other is PlanProjection && other.scale == scale && other.origin == origin;

  @override
  int get hashCode => Object.hash(scale, origin);
}

/// Colours for the floor plan, derived from the app's light / dark theme.
@immutable
class MapPalette {
  const MapPalette._({
    required this.brightness,
    required this.site,
    required this.building,
    required this.wingTints,
    required this.wall,
    required this.interiorLine,
    required this.corridor,
    required this.lobby,
    required this.restaurant,
    required this.classroom,
    required this.voidFill,
    required this.hatch,
    required this.locked,
    required this.road,
    required this.parking,
    required this.neighbour,
    required this.wingLetter,
    required this.label,
    required this.mutedLabel,
  });

  factory MapPalette.of(ThemeData theme) {
    final dark = theme.brightness == Brightness.dark;
    final ink = theme.colorScheme.onSurface;
    return MapPalette._(
      brightness: theme.brightness,
      site: dark ? const Color(0xFF1B1A19) : const Color(0xFFEFECE5),
      building: dark ? const Color(0xFF262523) : const Color(0xFFFFFFFF),
      wingTints: dark
          ? const {
              'A': Color(0xFF2B2926),
              'B': Color(0xFF272A2C),
              'C': Color(0xFF282725),
            }
          : const {
              'A': Color(0xFFFBF8F2),
              'B': Color(0xFFF5F7F8),
              'C': Color(0xFFFFFFFF),
            },
      wall: ink.withValues(alpha: dark ? 0.70 : 0.62),
      interiorLine: ink.withValues(alpha: 0.16),
      corridor: dark ? const Color(0xFF34322F) : const Color(0xFFF7F5F0),
      lobby: dark ? const Color(0xFF3B342B) : const Color(0xFFF5ECDD),
      restaurant: dark ? const Color(0xFF2D352C) : const Color(0xFFE9F0E6),
      classroom: dark ? const Color(0xFF2A313A) : const Color(0xFFE8EEF4),
      voidFill: dark ? const Color(0xFF1E1D1C) : const Color(0xFFECE8E0),
      hatch: ink.withValues(alpha: dark ? 0.14 : 0.10),
      locked: dark ? const Color(0xFF232221) : const Color(0xFFF1EFEB),
      road: dark ? const Color(0xFF2B2927) : const Color(0xFFE2DDD3),
      parking: dark ? const Color(0xFF242A31) : const Color(0xFFE3E8EE),
      neighbour: dark ? const Color(0xFF2B2927) : const Color(0xFFE4E0D8),
      wingLetter: ink.withValues(alpha: dark ? 0.10 : 0.07),
      label: ink.withValues(alpha: 0.78),
      mutedLabel: ink.withValues(alpha: 0.55),
    );
  }

  final Brightness brightness;
  final Color site;
  final Color building;
  final Map<String, Color> wingTints;
  final Color wall;
  final Color interiorLine;
  final Color corridor;
  final Color lobby;
  final Color restaurant;
  final Color classroom;
  final Color voidFill;
  final Color hatch;
  final Color locked;
  final Color road;
  final Color parking;
  final Color neighbour;
  final Color wingLetter;
  final Color label;
  final Color mutedLabel;

  @override
  bool operator ==(Object other) =>
      other is MapPalette && other.brightness == brightness;

  @override
  int get hashCode => brightness.hashCode;
}

/// Draws one floor of the CS building. Pins and labels are separate widgets
/// layered on top (see `map_pins.dart`) so they stay crisp at any zoom level.
class FloorPlanPainter extends CustomPainter {
  FloorPlanPainter({
    required this.floor,
    required this.projection,
    required this.palette,
  });

  final int floor;
  final PlanProjection projection;
  final MapPalette palette;

  static const Map<MapZoneKind, int> _paintOrder = {
    MapZoneKind.neighbourBuilding: 0,
    MapZoneKind.road: 1,
    MapZoneKind.parking: 2,
    MapZoneKind.lockedWing: 10,
    MapZoneKind.classroom: 11,
    MapZoneKind.restaurant: 12,
    MapZoneKind.lobby: 13,
    MapZoneKind.entranceHall: 14,
    MapZoneKind.corridor: 15,
    MapZoneKind.studyLoft: 16,
    MapZoneKind.atriumVoid: 17,
    MapZoneKind.stairs: 18,
    MapZoneKind.skybridge: 30,
  };

  static bool _isExterior(MapZoneKind kind) =>
      kind == MapZoneKind.neighbourBuilding ||
      kind == MapZoneKind.road ||
      kind == MapZoneKind.parking;

  Path _path(List<Offset> points) {
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final p = projection.toCanvas(points[i]);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    return path..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = palette.site);

    final zones = CsBuildingMapData.zonesOnFloor(floor).toList()
      ..sort((a, b) => _paintOrder[a.kind]!.compareTo(_paintOrder[b.kind]!));

    for (final zone in zones.where((z) => _isExterior(z.kind))) {
      _paintZone(canvas, zone);
    }

    // Building shell and wing tints.
    final shell = _path(CsBuildingMapData.outline);
    canvas.drawShadow(shell, Colors.black, 3, false);
    canvas.drawPath(shell, Paint()..color = palette.building);
    canvas.save();
    canvas.clipPath(shell);
    CsBuildingMapData.wings.forEach((letter, points) {
      canvas.drawPath(
        _path(points),
        Paint()..color = palette.wingTints[letter] ?? palette.building,
      );
    });

    for (final zone in zones.where(
      (z) => !_isExterior(z.kind) && z.kind != MapZoneKind.skybridge,
    )) {
      _paintZone(canvas, zone);
    }

    final wingLine = Paint()
      ..color = palette.interiorLine
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, projection.scale * 0.35);
    for (final points in CsBuildingMapData.wings.values) {
      canvas.drawPath(_path(points), wingLine);
    }
    _paintWingLetters(canvas);
    canvas.restore();

    canvas.drawPath(
      shell,
      Paint()
        ..color = palette.wall
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = math.max(1.4, projection.scale * 0.5),
    );

    for (final zone in zones.where((z) => z.kind == MapZoneKind.skybridge)) {
      _paintZone(canvas, zone);
    }
  }

  void _paintZone(Canvas canvas, MapZone zone) {
    final path = _path(zone.points);
    switch (zone.kind) {
      case MapZoneKind.neighbourBuilding:
        canvas.drawPath(path, Paint()..color = palette.neighbour);
        canvas.drawPath(path, _stroke(palette.interiorLine, 1.2));
      case MapZoneKind.road:
        canvas.drawPath(path, Paint()..color = palette.road);
        final bounds = path.getBounds();
        _dashedLine(
          canvas,
          Offset(bounds.center.dx, bounds.top),
          Offset(bounds.center.dx, bounds.bottom),
          palette.building.withValues(alpha: 0.9),
          dash: projection.scale * 3,
          gap: projection.scale * 2.5,
          width: math.max(1.0, projection.scale * 0.35),
        );
      case MapZoneKind.parking:
        canvas.drawPath(path, Paint()..color = palette.parking);
        _parkingBays(canvas, path);
      case MapZoneKind.lockedWing:
        canvas.drawPath(path, Paint()..color = palette.locked);
        _hatch(canvas, path, palette.hatch, spacing: projection.scale * 3.2);
      case MapZoneKind.classroom:
        canvas.drawPath(path, Paint()..color = palette.classroom);
      case MapZoneKind.restaurant:
        canvas.drawPath(path, Paint()..color = palette.restaurant);
      case MapZoneKind.lobby:
      case MapZoneKind.entranceHall:
      case MapZoneKind.studyLoft:
        canvas.drawPath(path, Paint()..color = palette.lobby);
      case MapZoneKind.corridor:
        canvas.drawPath(path, Paint()..color = palette.corridor);
      case MapZoneKind.atriumVoid:
        canvas.drawPath(path, Paint()..color = palette.voidFill);
        _hatch(canvas, path, palette.hatch, spacing: projection.scale * 1.6);
        _dashedPath(canvas, zone.points, palette.mutedLabel);
      case MapZoneKind.stairs:
        canvas.drawPath(path, Paint()..color = palette.corridor);
        _stairSteps(canvas, path);
        canvas.drawPath(path, _stroke(palette.mutedLabel, 1.0));
      case MapZoneKind.skybridge:
        canvas.drawPath(path, Paint()..color = palette.corridor);
        canvas.drawPath(path, _stroke(palette.wall, 1.4));
    }
  }

  Paint _stroke(Color color, double width) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width;

  void _hatch(Canvas canvas, Path path, Color color, {required double spacing}) {
    final step = math.max(4.0, spacing);
    final bounds = path.getBounds();
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    canvas.save();
    canvas.clipPath(path);
    for (var x = bounds.left - bounds.height; x < bounds.right; x += step) {
      canvas.drawLine(
        Offset(x, bounds.bottom),
        Offset(x + bounds.height, bounds.top),
        paint,
      );
    }
    canvas.restore();
  }

  void _stairSteps(Canvas canvas, Path path) {
    final bounds = path.getBounds();
    final step = math.max(3.0, projection.scale * 0.9);
    final paint = _stroke(palette.mutedLabel.withValues(alpha: 0.45), 1);
    canvas.save();
    canvas.clipPath(path);
    for (var y = bounds.top + step; y < bounds.bottom; y += step) {
      canvas.drawLine(Offset(bounds.left, y), Offset(bounds.right, y), paint);
    }
    canvas.restore();
  }

  void _parkingBays(Canvas canvas, Path path) {
    final bounds = path.getBounds();
    final step = math.max(5.0, projection.scale * 2.6);
    final paint = _stroke(palette.building.withValues(alpha: 0.75), 1);
    canvas.save();
    canvas.clipPath(path);
    for (var x = bounds.left + step; x < bounds.right; x += step) {
      canvas.drawLine(
        Offset(x, bounds.top),
        Offset(x, bounds.top + bounds.height * 0.42),
        paint,
      );
      canvas.drawLine(
        Offset(x, bounds.bottom - bounds.height * 0.42),
        Offset(x, bounds.bottom),
        paint,
      );
    }
    canvas.restore();
  }

  void _dashedPath(Canvas canvas, List<Offset> planPoints, Color color) {
    for (var i = 0; i < planPoints.length; i++) {
      final a = projection.toCanvas(planPoints[i]);
      final b = projection.toCanvas(planPoints[(i + 1) % planPoints.length]);
      _dashedLine(
        canvas,
        a,
        b,
        color,
        dash: math.max(3.0, projection.scale * 1.2),
        gap: math.max(2.0, projection.scale * 0.9),
        width: 1,
      );
    }
  }

  void _dashedLine(
    Canvas canvas,
    Offset a,
    Offset b,
    Color color, {
    required double dash,
    required double gap,
    required double width,
  }) {
    final paint = _stroke(color, width);
    final total = (b - a).distance;
    if (total <= 0) return;
    final direction = (b - a) / total;
    var travelled = 0.0;
    while (travelled < total) {
      final end = math.min(travelled + dash, total);
      canvas.drawLine(a + direction * travelled, a + direction * end, paint);
      travelled = end + gap;
    }
  }

  void _paintWingLetters(Canvas canvas) {
    CsBuildingMapData.wingLetterAt.forEach((letter, at) {
      final painter = TextPainter(
        text: TextSpan(
          text: letter,
          style: TextStyle(
            color: palette.wingLetter,
            fontSize: projection.scale * 9,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final centre = projection.toCanvas(at);
      painter.paint(
        canvas,
        centre - Offset(painter.width / 2, painter.height / 2),
      );
      painter.dispose();
    });
  }

  @override
  bool shouldRepaint(FloorPlanPainter oldDelegate) =>
      oldDelegate.floor != floor ||
      oldDelegate.projection != projection ||
      oldDelegate.palette != palette;
}

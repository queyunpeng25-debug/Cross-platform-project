import 'package:flutter/widgets.dart';

/// Plain data types used by Mustafa's CS building map.
///
/// All positions are in **plan metres**: a flat coordinate system aligned with
/// the building's long axis (x grows towards Konemiehentie / east, y grows
/// towards Maarintie / south). The origin is the top-left corner of the
/// building's bounding box. Keeping real metres (instead of pixels) means the
/// same data renders correctly on any phone, tablet or desktop size.

/// Kinds of non-station places that can be drawn on the map.
enum MapPlaceKind {
  lift,
  stairs,
  toilet,
  entrance,
  accessibleEntrance,
  infoDesk,
  wardrobe,
  callPod,
  parking,
  skybridge,
  billiards,
  transit,
}

/// Map layers the visitor can switch on and off with the filter chips.
enum MapLayer { stations, puzzlePieces, callPods, facilities }

/// A point of interest that is not a tour station (lift, call pod, parking…).
class MapPlace {
  const MapPlace({
    required this.id,
    required this.floor,
    required this.position,
    required this.kind,
    required this.label,
    required this.description,
    this.hasQrMarker = false,
    this.minPxPerMetre = 0,
  });

  /// Stable id. For places with [hasQrMarker] this id is what the printed
  /// "You are here" QR code encodes (`?map=<id>` or `cs-guide://map/<id>`).
  final String id;
  final int floor;
  final Offset position;
  final MapPlaceKind kind;
  final String label;
  final String description;

  /// True when a printed "You are here" QR sticker exists for this spot.
  final bool hasQrMarker;

  /// Hide the icon until the map is zoomed in to at least this many screen
  /// pixels per metre, so small facilities do not clutter the overview.
  final double minPxPerMetre;

  /// Call pods are their own layer; everything else is a facility.
  MapLayer get layer =>
      kind == MapPlaceKind.callPod ? MapLayer.callPods : MapLayer.facilities;
}

/// Visual role of a drawn area on a floor plan.
enum MapZoneKind {
  lobby,
  restaurant,
  corridor,
  entranceHall,
  classroom,
  atriumVoid,
  studyLoft,
  lockedWing,
  skybridge,
  stairs,
  neighbourBuilding,
  parking,
  road,
}

/// A polygon drawn on one floor (or on every floor when [floor] is null).
class MapZone {
  const MapZone({
    required this.kind,
    required this.points,
    this.floor,
    this.label,
    this.labelAt,
    this.translateLabel = true,
    this.minPxPerMetreForLabel = 0,
  });

  final MapZoneKind kind;
  final List<Offset> points;

  /// Floor this zone belongs to; `null` means it is drawn on every floor.
  final int? floor;

  /// Optional caption shown on the map (e.g. "Main lobby").
  final String? label;

  /// Where to place [label]; defaults to the polygon's centre.
  final Offset? labelAt;

  /// Street names and room codes should not be sent to the translator.
  final bool translateLabel;

  /// Hide [label] until the map is zoomed in this far (screen px per metre).
  final double minPxPerMetreForLabel;

  bool isOnFloor(int f) => floor == null || floor == f;

  Offset get centre {
    var sx = 0.0;
    var sy = 0.0;
    for (final p in points) {
      sx += p.dx;
      sy += p.dy;
    }
    return Offset(sx / points.length, sy / points.length);
  }
}

/// Where a tour station (from `stations_data.json`) appears on the map.
class StationMapPlacement {
  const StationMapPlacement({
    required this.position,
    required this.shortLabel,
    required this.icon,
    this.floor,
  });

  final Offset position;

  /// Short caption under the pin (station titles are too long for a map).
  final String shortLabel;
  final IconData icon;

  /// Optional floor override; `null` uses the station's own `floor` value.
  final int? floor;
}

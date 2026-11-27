import 'package:flutter/material.dart';

import '../../core/models.dart';
import 'map_models.dart';

/// Floor-plan data for the Computer Science Building (T-talo, Konemiehentie 2).
///
/// **Where the geometry comes from**
/// - The building outline and the A / B / C wing shapes are derived from
///   OpenStreetMap (way 4217650 and its `building:part`s), © OpenStreetMap
///   contributors, ODbL 1.0. The map UI shows this attribution.
/// - Entrance letters (main entrance A, accessible door L, west door F), the
///   main stairs and the 2nd-floor skybridge to TUAS are also mapped in OSM.
/// - Lift + accessible toilet "next to the dining line" and the back-lot
///   parking come from Aalto's accessibility page for the building.
/// - Everything else (restaurant area, call pods, pins) is a best-effort
///   schematic placement. Adjust the numbers below after walking the building:
///   x = metres from the west end, y = metres from the north wall.
abstract final class CsBuildingMapData {
  /// Size of the building's bounding box in metres.
  static const Size buildingSize = Size(119.3, 68.4);

  /// Visible area of the map, including a margin for TUAS, parking and roads.
  static const Rect planBounds = Rect.fromLTRB(-20, -18, 132, 78);

  /// True north is rotated 10° counter-clockwise from "up" on this plan.
  static const double northRotationDegrees = -10;

  static const List<int> floors = [1, 2, 3];

  static String floorShort(int floor) => '${floor}F';

  static String floorName(int floor) => switch (floor) {
    1 => '1st floor',
    2 => '2nd floor',
    3 => '3rd floor',
    _ => 'Floor $floor',
  };

  // ---------------------------------------------------------------------------
  // Building shell (OpenStreetMap)
  // ---------------------------------------------------------------------------

  static const List<Offset> outline = [
    Offset(47.2, 13.0), Offset(80.3, 17.5), Offset(80.2, 16.2), //
    Offset(83.4, 16.1), Offset(83.5, 17.9), Offset(119.3, 22.8), //
    Offset(118.0, 32.3), Offset(115.4, 32.0), Offset(115.4, 45.9), //
    Offset(100.5, 46.2), Offset(98.8, 51.8), Offset(113.2, 53.4), //
    Offset(112.5, 59.6), Offset(114.9, 60.0), Offset(112.6, 68.4), //
    Offset(83.6, 61.0), Offset(83.6, 61.9), Offset(80.0, 61.9), //
    Offset(80.0, 60.1), Offset(47.1, 60.0), Offset(47.1, 61.5), //
    Offset(43.7, 61.5), Offset(43.7, 60.0), Offset(11.0, 59.9), //
    Offset(11.0, 61.4), Offset(7.4, 61.4), Offset(7.4, 59.9), //
    Offset(0.0, 59.9), Offset(0.0, 54.8), Offset(1.0, 54.7), //
    Offset(1.2, 44.6), Offset(6.8, 44.6), Offset(6.9, 7.6), //
    Offset(7.7, 0.0), Offset(29.0, 2.8), Offset(28.0, 10.4), //
    Offset(44.0, 12.6), Offset(43.8, 10.9), Offset(47.0, 10.6), //
  ];

  /// Wings as mapped in OSM. Room codes start with the wing letter
  /// (A117 Athene, C114 Tietokilta, C130a Greenhouse…), which makes the
  /// letters a handy orientation aid for visitors.
  static const Map<String, List<Offset>> wings = {
    'A': [
      Offset(6.8, 44.6), Offset(87.1, 44.9), Offset(87.3, 51.2), //
      Offset(113.2, 53.4), Offset(112.5, 59.6), Offset(114.9, 60.0), //
      Offset(112.6, 68.4), Offset(80.0, 60.1), Offset(0.0, 59.9), //
      Offset(1.2, 44.6), //
    ],
    'B': [
      Offset(6.8, 40.7), Offset(19.4, 40.7), Offset(19.9, 17.6), //
      Offset(83.8, 26.6), Offset(83.5, 17.9), Offset(28.0, 10.4), //
      Offset(29.0, 2.8), Offset(7.7, 0.0), //
    ],
    'C': [
      Offset(83.8, 26.6), Offset(83.5, 17.9), Offset(119.3, 22.8), //
      Offset(118.0, 32.3), Offset(115.4, 32.0), Offset(115.4, 45.9), //
      Offset(100.5, 46.2), Offset(98.8, 51.8), Offset(87.3, 51.2), //
      Offset(87.1, 44.9), Offset(6.8, 44.6), Offset(6.8, 40.7), //
      Offset(19.4, 40.7), Offset(19.9, 17.6), //
    ],
  };

  /// Where the big faint wing letters are painted.
  static const Map<String, Offset> wingLetterAt = {
    'A': Offset(57.0, 54.5),
    'B': Offset(13.0, 22.0),
    'C': Offset(104.0, 25.5),
  };

  // ---------------------------------------------------------------------------
  // Zones per floor
  // ---------------------------------------------------------------------------

  static const List<Offset> _stairs = [
    Offset(46.6, 29.0), Offset(50.4, 29.0), //
    Offset(50.4, 42.4), Offset(46.6, 42.4), //
  ];

  static const List<MapZone> zones = [
    // --- Surroundings (every floor) ---
    MapZone(
      kind: MapZoneKind.neighbourBuilding,
      points: [
        Offset(-20, -2), Offset(-16, -2), Offset(-16, 64), Offset(-20, 64), //
      ],
      label: 'TUAS',
      labelAt: Offset(-18, 18),
      translateLabel: false,
    ),
    MapZone(
      kind: MapZoneKind.road,
      points: [
        Offset(122, -18), Offset(129, -18), Offset(129, 78), Offset(122, 78), //
      ],
      label: 'Konemiehentie',
      labelAt: Offset(125.5, 52),
      translateLabel: false,
    ),
    MapZone(
      kind: MapZoneKind.parking,
      floor: 1,
      points: [
        Offset(4, -18), Offset(86, -18), Offset(86, -6), Offset(4, -9), //
      ],
    ),
    MapZone(kind: MapZoneKind.stairs, points: _stairs),

    // --- 1st floor ---
    MapZone(
      kind: MapZoneKind.corridor,
      floor: 1,
      points: [
        Offset(6.8, 43.2), Offset(87.5, 43.6), Offset(87.5, 46.2), //
        Offset(6.8, 45.9), //
      ],
    ),
    MapZone(
      kind: MapZoneKind.corridor,
      floor: 1,
      points: [
        Offset(86.6, 19.0), Offset(89.4, 19.4), Offset(89.4, 44.0), //
        Offset(86.6, 44.0), //
      ],
    ),
    MapZone(
      kind: MapZoneKind.lobby,
      floor: 1,
      points: [
        Offset(50.6, 22.0), Offset(83.8, 26.6), Offset(86.6, 27.0), //
        Offset(86.6, 43.6), Offset(50.6, 43.4), //
      ],
      label: 'Main lobby',
      labelAt: Offset(61, 41.4),
    ),
    MapZone(
      kind: MapZoneKind.greenhouse,
      floor: 1,
      points: [
        Offset(20.2, 18.0), Offset(46.4, 21.7), Offset(46.4, 43.0), //
        Offset(20.2, 43.0), //
      ],
      label: 'Greenhouse',
      labelAt: Offset(33, 38.5),
      minPxPerMetreForLabel: 4.5,
    ),
    MapZone(
      kind: MapZoneKind.restaurant,
      floor: 1,
      points: [
        Offset(50.6, 22.0), Offset(68.0, 24.4), Offset(68.0, 35.8), //
        Offset(50.6, 35.8), //
      ],
      label: 'Restaurant & Subway',
      labelAt: Offset(59.3, 33.8),
      minPxPerMetreForLabel: 4.5,
    ),
    MapZone(
      kind: MapZoneKind.entranceHall,
      floor: 1,
      points: [
        Offset(89.4, 40.0), Offset(96.5, 40.0), Offset(96.5, 45.9), //
        Offset(100.5, 46.2), Offset(98.8, 51.8), Offset(87.3, 51.2), //
        Offset(87.5, 46.2), Offset(89.4, 46.2), //
      ],
      label: 'Entrance hall',
      labelAt: Offset(93, 44),
      minPxPerMetreForLabel: 9,
    ),
    MapZone(
      kind: MapZoneKind.classroom,
      floor: 1,
      points: [
        Offset(96.5, 45.9), Offset(96.6, 27.3), Offset(115.4, 28.4), //
        Offset(115.4, 45.9), //
      ],
      label: 'Paniikki (C106)',
      labelAt: Offset(106, 37),
      translateLabel: false,
      minPxPerMetreForLabel: 4.5,
    ),

    // --- 2nd floor ---
    MapZone(
      kind: MapZoneKind.lockedWing,
      floor: 2,
      points: [
        Offset(6.8, 40.7), Offset(19.4, 40.7), Offset(19.9, 17.6), //
        Offset(83.8, 26.6), Offset(83.5, 17.9), Offset(28.0, 10.4), //
        Offset(29.0, 2.8), Offset(7.7, 0.0), //
      ],
      label: 'Research wing · keycard',
      labelAt: Offset(44, 15.5),
      minPxPerMetreForLabel: 4.5,
    ),
    MapZone(
      kind: MapZoneKind.lockedWing,
      floor: 2,
      points: [
        Offset(6.8, 45.4), Offset(87.1, 45.4), Offset(87.3, 51.2), //
        Offset(113.2, 53.4), Offset(112.5, 59.6), Offset(114.9, 60.0), //
        Offset(112.6, 68.4), Offset(80.0, 60.1), Offset(0.0, 59.9), //
        Offset(1.2, 45.4), //
      ],
      label: 'Research wing · keycard',
      labelAt: Offset(58, 53),
      minPxPerMetreForLabel: 4.5,
    ),
    MapZone(
      kind: MapZoneKind.corridor,
      floor: 2,
      points: [
        Offset(50.4, 27.2), Offset(85.8, 27.2), Offset(85.8, 44.2), //
        Offset(50.4, 44.2), //
      ],
    ),
    MapZone(
      kind: MapZoneKind.corridor,
      floor: 2,
      points: [
        Offset(6.8, 42.6), Offset(50.4, 42.6), Offset(50.4, 45.4), //
        Offset(6.8, 45.4), //
      ],
    ),
    MapZone(
      kind: MapZoneKind.atriumVoid,
      floor: 2,
      points: [
        Offset(52.0, 29.0), Offset(84.0, 29.0), Offset(84.0, 42.4), //
        Offset(52.0, 42.4), //
      ],
      label: 'Open to the lobby below',
      labelAt: Offset(68, 35.7),
      minPxPerMetreForLabel: 4,
    ),
    MapZone(
      kind: MapZoneKind.skybridge,
      floor: 2,
      points: [
        Offset(-16.0, 42.4), Offset(6.8, 42.4), Offset(6.8, 45.6), //
        Offset(-16.0, 45.6), //
      ],
      label: 'Skybridge',
      labelAt: Offset(-4.5, 39.5),
      minPxPerMetreForLabel: 5,
    ),

    // --- 3rd floor ---
    MapZone(
      kind: MapZoneKind.lockedWing,
      floor: 3,
      points: [
        Offset(6.8, 40.7), Offset(19.4, 40.7), Offset(19.9, 17.6), //
        Offset(83.8, 26.6), Offset(83.5, 17.9), Offset(28.0, 10.4), //
        Offset(29.0, 2.8), Offset(7.7, 0.0), //
      ],
      label: 'Research wing · keycard',
      labelAt: Offset(44, 15.5),
      minPxPerMetreForLabel: 4.5,
    ),
    MapZone(
      kind: MapZoneKind.lockedWing,
      floor: 3,
      points: [
        Offset(6.8, 45.4), Offset(87.1, 45.4), Offset(87.3, 51.2), //
        Offset(113.2, 53.4), Offset(112.5, 59.6), Offset(114.9, 60.0), //
        Offset(112.6, 68.4), Offset(80.0, 60.1), Offset(0.0, 59.9), //
        Offset(1.2, 45.4), //
      ],
      label: 'Research wing · keycard',
      labelAt: Offset(58, 53),
      minPxPerMetreForLabel: 4.5,
    ),
    MapZone(
      kind: MapZoneKind.corridor,
      floor: 3,
      points: [
        Offset(46.0, 27.2), Offset(85.8, 27.2), Offset(85.8, 44.2), //
        Offset(46.0, 44.2), //
      ],
    ),
    MapZone(
      kind: MapZoneKind.studyLoft,
      floor: 3,
      points: [
        Offset(50.4, 28.4), Offset(58.0, 28.4), Offset(58.0, 43.4), //
        Offset(50.4, 43.4), //
      ],
      label: 'Parvi T1',
      labelAt: Offset(54.2, 41.6),
      translateLabel: false,
      minPxPerMetreForLabel: 8,
    ),
    MapZone(
      kind: MapZoneKind.atriumVoid,
      floor: 3,
      points: [
        Offset(58.0, 29.0), Offset(84.0, 29.0), Offset(84.0, 42.4), //
        Offset(58.0, 42.4), //
      ],
      label: 'Open to the lobby below',
      labelAt: Offset(71, 35.7),
      minPxPerMetreForLabel: 4,
    ),
  ];

  // ---------------------------------------------------------------------------
  // Places (facilities, call pods, "You are here" QR spots)
  // ---------------------------------------------------------------------------

  static const String _liftText =
      'Lift in the main lobby next to the restaurant\'s dining line. Serves all floors; an accessible toilet is right next to it on the 1st floor.';
  static const String _callPodText =
      'Walk-in single-person phone booths built into the brick walls. They cannot be booked on Aalto Space - just step in for a quick call or a job interview.';

  static const List<MapPlace> places = [
    // --- 1st floor ---
    MapPlace(
      id: 'lift_1f',
      floor: 1,
      position: Offset(44.2, 41.2),
      kind: MapPlaceKind.lift,
      label: 'Lift',
      description: _liftText,
      hasQrMarker: true,
    ),
    MapPlace(
      id: 'toilet_accessible_1f',
      floor: 1,
      position: Offset(44.2, 37.0),
      kind: MapPlaceKind.toilet,
      label: 'Accessible toilet',
      description: 'Accessible toilet in the main lobby, next to the lift.',
      minPxPerMetre: 5,
    ),
    MapPlace(
      id: 'stairs_1f',
      floor: 1,
      position: Offset(48.5, 31.0),
      kind: MapPlaceKind.stairs,
      label: 'Main stairs',
      description: 'Main stairs from the lobby up to the 2nd and 3rd floors.',
      minPxPerMetre: 4.5,
    ),
    MapPlace(
      id: 'entrance_main',
      floor: 1,
      position: Offset(98.4, 49.0),
      kind: MapPlaceKind.entrance,
      label: 'Main entrance (A)',
      description:
          'Main entrance from Konemiehentie. The building is open Mon-Thu 7:45-20:00 and Fri 7:45-18:00.',
    ),
    MapPlace(
      id: 'accessible_entrance_1f',
      floor: 1,
      position: Offset(88.0, 20.2),
      kind: MapPlaceKind.accessibleEntrance,
      label: 'Accessible entrance (L)',
      description:
          'Side door on the north side, closest to the back-lot parking. It opens with a button (an Aalto access token is needed).',
      hasQrMarker: true,
    ),
    MapPlace(
      id: 'entrance_west',
      floor: 1,
      position: Offset(2.2, 54.8),
      kind: MapPlaceKind.entrance,
      label: 'West entrance (F)',
      description: 'Side door at the west end of the building, towards TUAS.',
      minPxPerMetre: 6,
    ),
    MapPlace(
      id: 'info_desk',
      floor: 1,
      position: Offset(91.0, 41.6),
      kind: MapPlaceKind.infoDesk,
      label: 'Lobby services',
      description:
          'Lobby services desk (Aulapalvelut) - ask here for directions and help.',
      minPxPerMetre: 6,
    ),
    MapPlace(
      id: 'wardrobe',
      floor: 1,
      position: Offset(94.2, 48.4),
      kind: MapPlaceKind.wardrobe,
      label: 'Wardrobe',
      description: 'Leave heavy winter coats on the racks by the entrance.',
      minPxPerMetre: 7,
    ),
    MapPlace(
      id: 'billiards',
      floor: 1,
      position: Offset(64.0, 39.6),
      kind: MapPlaceKind.billiards,
      label: 'Billiards table',
      description:
          'Free for everyone - borrow cues and balls from a guild room such as Tietokilta (C114).',
      minPxPerMetre: 7,
    ),
    MapPlace(
      id: 'parking_back_lot',
      floor: 1,
      position: Offset(40.0, -11.5),
      kind: MapPlaceKind.parking,
      label: 'Back-lot parking',
      description:
          'Surface parking behind the building, including 3 accessible spaces. The accessible entrance (L) is about 60 m away. Time-disc spots are checked often, so most people come by metro or bike.',
    ),
    MapPlace(
      id: 'metro',
      floor: 1,
      position: Offset(66.0, 73.0),
      kind: MapPlaceKind.transit,
      label: 'Metro (~220 m)',
      description:
          'Aalto-yliopisto metro station is about 220 m south of the building, past Maarintie (Tietotie exit).',
    ),

    // --- 2nd floor ---
    MapPlace(
      id: 'lift_2f',
      floor: 2,
      position: Offset(44.2, 41.2),
      kind: MapPlaceKind.lift,
      label: 'Lift',
      description: _liftText,
      hasQrMarker: true,
    ),
    MapPlace(
      id: 'stairs_2f',
      floor: 2,
      position: Offset(48.5, 31.0),
      kind: MapPlaceKind.stairs,
      label: 'Main stairs',
      description: 'Main stairs landing on the 2nd floor.',
      hasQrMarker: true,
      minPxPerMetre: 4.5,
    ),
    MapPlace(
      id: 'skybridge_2f',
      floor: 2,
      position: Offset(8.8, 44.0),
      kind: MapPlaceKind.skybridge,
      label: 'Skybridge to TUAS',
      description:
          'Heated indoor bridge to TUAS (Maarintie 8) - no coat needed. Follow the "Passage to Maarintie 8" signs.',
      hasQrMarker: true,
    ),
    MapPlace(
      id: 'call_pods_2f',
      floor: 2,
      position: Offset(54.2, 25.6),
      kind: MapPlaceKind.callPod,
      label: 'Call pods',
      description: _callPodText,
      hasQrMarker: true,
    ),
    MapPlace(
      id: 'call_pod_2f_east',
      floor: 2,
      position: Offset(85.0, 33.5),
      kind: MapPlaceKind.callPod,
      label: 'Call pod',
      description: _callPodText,
    ),

    // --- 3rd floor ---
    MapPlace(
      id: 'lift_3f',
      floor: 3,
      position: Offset(44.2, 41.2),
      kind: MapPlaceKind.lift,
      label: 'Lift',
      description: _liftText,
      hasQrMarker: true,
    ),
    MapPlace(
      id: 'stairs_3f',
      floor: 3,
      position: Offset(48.5, 31.0),
      kind: MapPlaceKind.stairs,
      label: 'Main stairs',
      description: 'Main stairs landing on the 3rd floor.',
      hasQrMarker: true,
      minPxPerMetre: 4.5,
    ),
    MapPlace(
      id: 'call_pods_3f',
      floor: 3,
      position: Offset(54.2, 25.6),
      kind: MapPlaceKind.callPod,
      label: 'Call pods',
      description: _callPodText,
      hasQrMarker: true,
    ),
    MapPlace(
      id: 'call_pod_3f_east',
      floor: 3,
      position: Offset(85.0, 31.5),
      kind: MapPlaceKind.callPod,
      label: 'Call pod',
      description: _callPodText,
    ),
  ];

  // ---------------------------------------------------------------------------
  // Tour stations (ids from assets/stations_data.json)
  // ---------------------------------------------------------------------------

  static const Map<String, StationMapPlacement> stationPlacements = {
    'lobby': StationMapPlacement(
      position: Offset(79.0, 38.5),
      shortLabel: 'Lobby',
      icon: Icons.flag_rounded,
    ),
    'greenhouse': StationMapPlacement(
      position: Offset(30.0, 29.0),
      shortLabel: 'Greenhouse',
      icon: Icons.local_florist_rounded,
    ),
    'guilds': StationMapPlacement(
      position: Offset(36.0, 52.0),
      shortLabel: 'Guild rooms',
      icon: Icons.groups_rounded,
    ),
    'portraits': StationMapPlacement(
      position: Offset(68.0, 47.5),
      shortLabel: 'Portraits',
      icon: Icons.portrait_rounded,
    ),
    'canteen': StationMapPlacement(
      position: Offset(57.5, 27.0),
      shortLabel: 'Lunch & Subway',
      icon: Icons.restaurant_rounded,
    ),
    'tuas_bridge': StationMapPlacement(
      position: Offset(10.0, 50.5),
      shortLabel: 'TUAS shortcut',
      icon: Icons.alt_route_rounded,
    ),
    'computers': StationMapPlacement(
      position: Offset(28.0, 41.0),
      shortLabel: 'Retro computers',
      icon: Icons.computer_rounded,
    ),
    'locked_corridors': StationMapPlacement(
      position: Offset(66.0, 19.8),
      shortLabel: 'Research wings',
      icon: Icons.science_rounded,
    ),
    'study_places': StationMapPlacement(
      position: Offset(54.2, 35.5),
      shortLabel: 'Study loft',
      icon: Icons.menu_book_rounded,
    ),
  };

  // ---------------------------------------------------------------------------
  // Lookups
  // ---------------------------------------------------------------------------

  static MapPlace? placeById(String id) {
    for (final place in places) {
      if (place.id == id) return place;
    }
    return null;
  }

  /// Places that have a printed "You are here" QR sticker.
  static Iterable<MapPlace> get qrMarkers => places.where((p) => p.hasQrMarker);

  static MapPlace? markerById(String id) {
    final place = placeById(id.trim());
    return (place != null && place.hasQrMarker) ? place : null;
  }

  static Iterable<MapPlace> placesOnFloor(int floor) =>
      places.where((p) => p.floor == floor);

  static Iterable<MapZone> zonesOnFloor(int floor) =>
      zones.where((z) => z.isOnFloor(floor));

  /// Pin placement for a station. Stations added later by teammates still get
  /// a pin: their `normalizedX/Y` from `stations_data.json` is mapped onto the
  /// building's bounding box.
  static StationMapPlacement placementFor(StationSpec station) {
    final known = stationPlacements[station.id];
    if (known != null) return known;
    return StationMapPlacement(
      position: Offset(
        station.normalizedX * buildingSize.width,
        station.normalizedY * buildingSize.height,
      ),
      shortLabel: station.title,
      icon: Icons.place_rounded,
    );
  }

  /// Floor a station is drawn on, clamped to the floors this map has.
  static int floorFor(StationSpec station) {
    final floor = placementFor(station).floor ?? station.floor;
    return floor.clamp(floors.first, floors.last);
  }
}

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/controllers.dart';
import '../../core/models.dart';
import 'cs_building_map_data.dart';
import 'map_models.dart';

/// What a scanned QR code means for the map.
sealed class MapScanTarget {
  const MapScanTarget();
}

/// A tour station QR (`?station=<id>` or `cs-guide://point/<id>`).
final class StationScanTarget extends MapScanTarget {
  const StationScanTarget(this.stationId);
  final String stationId;
}

/// A map-only "You are here" QR (`?map=<id>` or `cs-guide://map/<id>`).
final class MarkerScanTarget extends MapScanTarget {
  const MarkerScanTarget(this.place);
  final MapPlace place;
}

/// Turns raw QR text into a [MapScanTarget], or `null` if the code is not a
/// CS Explorer location. Pure and synchronous, so it is easy to unit test.
abstract final class MapCodeResolver {
  static const String markerScheme = 'cs-guide://map/';

  static MapScanTarget? resolve(
    String raw, {
    required StationCatalogRepository catalog,
  }) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    final markerId = markerIdFromRaw(trimmed);
    if (markerId != null) {
      final place = CsBuildingMapData.markerById(markerId);
      if (place != null) return MarkerScanTarget(place);
    }

    final stationId = catalog.resolveStationFromRawCode(trimmed);
    if (stationId != null) return StationScanTarget(stationId);
    return null;
  }

  /// Extracts the marker id from `cs-guide://map/<id>` or from an http(s) URL
  /// carrying `?map=<id>` (also inside a `#/...?map=<id>` fragment).
  static String? markerIdFromRaw(String raw) {
    if (raw.startsWith(markerScheme)) {
      final id = raw.substring(markerScheme.length).trim();
      return id.isEmpty ? null : id;
    }

    final uri = Uri.tryParse(raw);
    if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
      return null;
    }
    final direct = uri.queryParameters['map']?.trim();
    if (direct != null && direct.isNotEmpty) return direct;

    if (uri.fragment.isNotEmpty) {
      final fragment = uri.fragment.startsWith('/')
          ? uri.fragment
          : '/${uri.fragment}';
      final fromFragment = Uri.tryParse(fragment)?.queryParameters['map'];
      if (fromFragment != null && fromFragment.trim().isNotEmpty) {
        return fromFragment.trim();
      }
    }
    return null;
  }
}

/// Remembers the last "You are here" marker scanned on the map.
///
/// The marker is stored together with the station that was current at scan
/// time. As soon as the visitor reaches a *different* station (via any
/// scanner, a deep link, or opening a guide), the station is newer
/// information and wins again.
class MapPositionStore {
  MapPositionStore(this._prefs)
    : _markerId = _prefs?.getString(_keyMarker),
      _stationAtScan = _prefs?.getString(_keyStationAtScan);

  static const String _keyMarker = 'cs_map_marker_id';
  static const String _keyStationAtScan = 'cs_map_marker_station_at_scan';

  final SharedPreferences? _prefs;
  String? _markerId;
  String? _stationAtScan;

  String? get markerId => _markerId;
  String? get stationAtScan => _stationAtScan;

  void setMarker(String markerId, {required String stationAtScan}) {
    _markerId = markerId;
    _stationAtScan = stationAtScan;
    unawaited(_prefs?.setString(_keyMarker, markerId));
    unawaited(_prefs?.setString(_keyStationAtScan, stationAtScan));
  }

  void clear() {
    _markerId = null;
    _stationAtScan = null;
    unawaited(_prefs?.remove(_keyMarker));
    unawaited(_prefs?.remove(_keyStationAtScan));
  }
}

/// Where the visitor currently is on the map.
sealed class UserMapPosition {
  const UserMapPosition();

  int get floor;
  Offset get position;
  String get label;
}

/// Positioned at the last station they scanned (Red station).
final class StationUserPosition extends UserMapPosition {
  const StationUserPosition(this.station);
  final StationSpec station;

  @override
  int get floor => CsBuildingMapData.floorFor(station);

  @override
  Offset get position => CsBuildingMapData.placementFor(station).position;

  @override
  String get label => station.title;
}

/// Positioned at a map-only QR spot (lift, stairs, call pods…).
final class MarkerUserPosition extends UserMapPosition {
  const MarkerUserPosition(this.place);
  final MapPlace place;

  @override
  int get floor => place.floor;

  @override
  Offset get position => place.position;

  @override
  String get label => place.label;
}

/// Decides between the stored marker and the shared current station.
UserMapPosition? resolveUserMapPosition({
  required TourProgressController progress,
  required MapPositionStore store,
}) {
  final currentStationId = progress.currentStationId.value;

  final markerId = store.markerId;
  if (markerId != null && store.stationAtScan == currentStationId) {
    final place = CsBuildingMapData.markerById(markerId);
    if (place != null) return MarkerUserPosition(place);
  }

  final station = progress.catalog.findById(currentStationId);
  return station == null ? null : StationUserPosition(station);
}

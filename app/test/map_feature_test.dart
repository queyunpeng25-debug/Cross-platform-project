import 'dart:io';

import 'package:cs_building_guide/core/controllers.dart';
import 'package:cs_building_guide/features/map/building_map_screen.dart';
import 'package:cs_building_guide/features/map/cs_building_map_data.dart';
import 'package:cs_building_guide/features/map/map_models.dart';
import 'package:cs_building_guide/features/map/map_pins.dart';
import 'package:cs_building_guide/features/map/map_positioning.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zenify/zenify.dart';

const String _base = 'https://queyunpeng25-debug.github.io/Cross-platform-project/';

Finder _stationPin(String caption) => find.byWidgetPredicate(
  (w) => w is StationMapPin && w.caption == caption,
);

Finder _placePin(String id) => find.byWidgetPredicate(
  (w) => w is PlaceMapPin && w.place.id == id,
);

Finder _floorSelected(int floor) => find.byWidgetPredicate(
  (w) => w is SegmentedButton<int> && w.selected.contains(floor),
);

/// The header shows "Locate me" as text, or as an icon with a tooltip on
/// very narrow screens.
Finder _locateMeButton() {
  final labelled = find.text('Locate me');
  return labelled.evaluate().isNotEmpty
      ? labelled
      : find.byTooltip('Locate me (scan a QR code)');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StationCatalogRepository catalog;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Zen.init();
    catalog = await StationCatalogRepository.loadFromAssets();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    Zen.reset();
  });

  group('Map data', () {
    test('every station has a hand-placed pin inside the building', () {
      final building = Offset.zero & CsBuildingMapData.buildingSize;
      for (final station in catalog.stations) {
        expect(
          CsBuildingMapData.stationPlacements.containsKey(station.id),
          isTrue,
          reason: '${station.id} has no map position',
        );
        final placement = CsBuildingMapData.placementFor(station);
        expect(building.contains(placement.position), isTrue, reason: station.id);
        expect(
          CsBuildingMapData.floors,
          contains(CsBuildingMapData.floorFor(station)),
        );
      }
    });

    test('places and zones stay inside the visible plan', () {
      final plan = CsBuildingMapData.planBounds;
      for (final place in CsBuildingMapData.places) {
        expect(plan.contains(place.position), isTrue, reason: place.id);
        expect(CsBuildingMapData.floors, contains(place.floor), reason: place.id);
      }
      for (final zone in CsBuildingMapData.zones) {
        expect(zone.points.length, greaterThanOrEqualTo(3));
        for (final p in zone.points) {
          expect(plan.inflate(0.01).contains(p), isTrue, reason: '${zone.label} $p');
        }
      }
    });

    test('ids are unique and QR marker ids are safe to print', () {
      final ids = CsBuildingMapData.places.map((p) => p.id).toList();
      expect(ids.toSet().length, ids.length);

      final keywords = catalog.textTriggerKeywords.keys
          .map((k) => k.toLowerCase())
          .toList();
      for (final marker in CsBuildingMapData.qrMarkers) {
        expect(RegExp(r'^[a-z0-9_]+$').hasMatch(marker.id), isTrue, reason: marker.id);
        // The main Scan tab treats some words as sign keywords (and "subway"
        // opens the Subway menu), so marker URLs must never contain them.
        final url = '$_base?map=${marker.id}'.toLowerCase();
        expect(url.contains('subway'), isFalse, reason: marker.id);
        for (final keyword in keywords) {
          expect(url.contains(keyword), isFalse, reason: '${marker.id} vs "$keyword"');
        }
      }
    });

    test('call pods are lit up on the 2nd and 3rd floors', () {
      final floors = CsBuildingMapData.places
          .where((p) => p.kind == MapPlaceKind.callPod)
          .map((p) => p.floor)
          .toSet();
      expect(floors, {2, 3});
    });

    test('every QR marker has a printable PNG in demo_qr/map', () {
      for (final marker in CsBuildingMapData.qrMarkers) {
        final file = File('../demo_qr/map/map_${marker.id}.png');
        expect(file.existsSync(), isTrue, reason: file.path);
      }
    });
  });

  group('QR resolver', () {
    MapScanTarget? resolve(String raw) =>
        MapCodeResolver.resolve(raw, catalog: catalog);

    test('map marker URLs and the custom scheme resolve to places', () {
      final lift = resolve('$_base?map=lift_2f');
      expect(lift, isA<MarkerScanTarget>());
      expect((lift as MarkerScanTarget).place.floor, 2);

      final pods = resolve('cs-guide://map/call_pods_3f');
      expect((pods as MarkerScanTarget).place.kind, MapPlaceKind.callPod);

      final fragment = resolve('https://example.org/app/#/?map=stairs_3f');
      expect((fragment as MarkerScanTarget).place.id, 'stairs_3f');
    });

    test('station QR codes still work on the map', () {
      final online = resolve('$_base?station=computers');
      expect((online as StationScanTarget).stationId, 'computers');

      final legacy = resolve('cs-guide://point/canteen');
      expect((legacy as StationScanTarget).stationId, 'canteen');
    });

    test('unknown or non-marker codes are rejected', () {
      expect(resolve(''), isNull);
      expect(resolve('hello world'), isNull);
      expect(resolve('cs-guide://map/'), isNull);
      expect(resolve('$_base?map=does_not_exist'), isNull);
      // Facilities without a printed sticker cannot be scanned.
      expect(resolve('$_base?map=toilet_accessible_1f'), isNull);
      expect(resolve('https://evil.example.com/?x=1'), isNull);
    });
  });

  group('User position', () {
    test('a scanned marker wins until a different station becomes current', () async {
      final prefs = await SharedPreferences.getInstance();
      final progress = TourProgressController(catalog: catalog, prefs: prefs);
      final store = MapPositionStore(prefs);

      final start = resolveUserMapPosition(progress: progress, store: store);
      expect((start as StationUserPosition).station.id, 'lobby');

      store.setMarker('lift_2f', stationAtScan: progress.currentStationId.value);
      final atLift = resolveUserMapPosition(progress: progress, store: store);
      expect((atLift as MarkerUserPosition).place.id, 'lift_2f');
      expect(atLift.floor, 2);

      // Survives an app restart.
      final reloaded = MapPositionStore(prefs);
      expect(reloaded.markerId, 'lift_2f');

      // Reaching another station is newer information.
      progress.unlockAndSetCurrentStation('computers');
      final atStation = resolveUserMapPosition(progress: progress, store: store);
      expect((atStation as StationUserPosition).station.id, 'computers');
    });
  });

  group('Map screen', () {
    Future<TourProgressController> pumpMap(
      WidgetTester tester, {
      Size size = const Size(390, 844),
      double textScale = 1.0,
      bool demo = false,
      MapScanLauncher? launcher,
      ValueChanged<String>? onOpenStation,
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final prefs = await SharedPreferences.getInstance();
      final progress = TourProgressController(catalog: catalog, prefs: prefs);
      final settings = AppSettingsController(prefs: prefs);
      if (demo) settings.setDemoUnlockAll(true);

      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
            ),
            child: child!,
          ),
          home: CsBuildingMapScreen(
            progress: progress,
            settings: settings,
            onOpenStation: onOpenStation ?? (_) {},
            onBackToLobby: () {},
            scanLauncher: launcher,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      return progress;
    }

    testWidgets('phone layout shows floors, the lobby pin and You are here', (tester) async {
      await pumpMap(tester);

      expect(find.text('CS Building Map'), findsOneWidget);
      for (final label in ['1F', '2F', '3F']) {
        expect(find.text(label), findsWidgets);
      }
      expect(_floorSelected(1), findsOneWidget);
      expect(_stationPin('Lobby'), findsOneWidget);
      expect(_stationPin('Retro computers'), findsNothing); // that one is on 2F
      expect(find.text('You are here'), findsOneWidget);
      expect(find.textContaining('OpenStreetMap'), findsOneWidget);
    });

    testWidgets('switching floor shows its stations and lit-up call pods', (tester) async {
      await pumpMap(tester);

      await tester.tap(find.text('2F'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(_floorSelected(2), findsOneWidget);
      expect(_stationPin('Retro computers'), findsOneWidget);
      expect(_stationPin('Research wings'), findsOneWidget);
      expect(_placePin('call_pods_2f'), findsOneWidget);
      // The visitor is still on 1F, so the map offers a way back.
      expect(find.text('You are on'), findsOneWidget);
    });

    testWidgets('locked stations explain how to unlock them', (tester) async {
      await pumpMap(tester);

      await tester.tap(_stationPin('Greenhouse'));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Learning Hub Greenhouse'), findsOneWidget);
      expect(find.text('Locked'), findsOneWidget);
      expect(find.text('Scan a QR code'), findsOneWidget);
      expect(find.text('Open guide'), findsNothing);
      expect(find.text('Puzzle piece hidden here'), findsOneWidget);
    });

    testWidgets('demo mode lets the details card open the station guide', (tester) async {
      String? opened;
      await pumpMap(tester, demo: true, onOpenStation: (id) => opened = id);

      await tester.tap(_stationPin('Greenhouse'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Open guide'));
      await tester.pump();

      expect(opened, 'greenhouse');
    });

    testWidgets('Locate me with a "You are here" QR jumps to that spot', (tester) async {
      final progress = await pumpMap(
        tester,
        launcher: (context, resolve) async => resolve('$_base?map=lift_2f'),
      );

      await tester.tap(_locateMeButton());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(_floorSelected(2), findsOneWidget);
      expect(find.text('Lift'), findsWidgets);
      expect(find.text('You are here'), findsWidgets);
      // Position is remembered, but the shared tour state is untouched.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('cs_map_marker_id'), 'lift_2f');
      expect(progress.currentStationId.value, 'lobby');
    });

    testWidgets('Locate me with a station QR unlocks it like the main scanner', (tester) async {
      final progress = await pumpMap(
        tester,
        launcher: (context, resolve) async => resolve('$_base?station=computers'),
      );

      await tester.tap(_locateMeButton());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(progress.currentStationId.value, 'computers');
      expect(progress.isStationUnlocked('computers'), isTrue);
      expect(_floorSelected(2), findsOneWidget);
      expect(find.text('Open guide'), findsOneWidget);
    });

    testWidgets('an unknown code changes nothing', (tester) async {
      final progress = await pumpMap(
        tester,
        launcher: (context, resolve) async => resolve('not a cs explorer code'),
      );

      await tester.tap(_locateMeButton());
      await tester.pump(const Duration(milliseconds: 400));

      expect(_floorSelected(1), findsOneWidget);
      expect(progress.currentStationId.value, 'lobby');
    });

    testWidgets('wide layout shows the side panel', (tester) async {
      await pumpMap(tester, size: const Size(1200, 820));

      expect(find.text('Your position'), findsOneWidget);
      expect(find.text('On this floor'), findsOneWidget);
      expect(find.text('Locate me'), findsOneWidget);

      // The legend sits at the bottom of the side panel list.
      await tester.scrollUntilVisible(
        find.text('Map legend'),
        200,
        scrollable: find.descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        ),
      );
      expect(find.text('Map legend'), findsOneWidget);
      expect(find.text('Call pods: walk-in, not bookable'), findsOneWidget);
    });

    testWidgets('small phone with large text renders without overflow', (tester) async {
      await pumpMap(tester, size: const Size(320, 640), textScale: 1.4);
      await tester.tap(_stationPin('Lobby'));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Open guide'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

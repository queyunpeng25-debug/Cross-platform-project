import 'package:cs_building_guide/computer_exhibit.dart';
import 'package:cs_building_guide/core/controllers.dart';
import 'package:cs_building_guide/core/device_capabilities.dart';
import 'package:cs_building_guide/core/models.dart';
import 'package:cs_building_guide/core/translation_service.dart';
import 'package:cs_building_guide/features/canteen/canteen_menu_service.dart';
import 'package:cs_building_guide/features/map/default_map_slot.dart';
import 'package:cs_building_guide/features/minigames/ar_tabletop_puzzle_screen.dart';
import 'package:cs_building_guide/features/minigames/default_minigame_slot.dart';
import 'package:cs_building_guide/features/minigames/spatial_minigame_engine.dart';
import 'package:cs_building_guide/features/canteen/default_canteen_slot.dart';
import 'package:cs_building_guide/main.dart';
import 'package:cs_building_guide/ui/app_shell.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zenify/zenify.dart';

class _InstantTranslationService implements TranslationService {
  @override
  String? cachedOrImmediate(String englishText, {required String targetLang}) =>
      targetLang == 'en' ? englishText : '[$targetLang] $englishText';

  @override
  Future<String> translate(
    String englishText, {
    required String targetLang,
  }) async => cachedOrImmediate(englishText, targetLang: targetLang)!;

  @override
  void close() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StationCatalogRepository sharedCatalog;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Zen.init();
    sharedCatalog = await StationCatalogRepository.loadFromAssets();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    Zen.reset();
    DeviceCapabilities.debugExperienceOverride = null;
    debugDefaultTargetPlatformOverride = null;
  });

  tearDown(() {
    DeviceCapabilities.debugExperienceOverride = null;
    debugDefaultTargetPlatformOverride = null;
  });

  test('Language catalog follows exact priority order and translation labels', () {
    const langs = SupportedLanguage.orderedCatalog;
    expect(langs[0].code, 'en');
    expect(langs[0].hasDirectLanguageFile, isTrue);
    expect(langs[0].translationProviderNote, isEmpty);

    expect(langs[1].code, 'fi');
    expect(langs[1].hasDirectLanguageFile, isFalse);
    expect(langs[1].translationProviderNote, contains('Google Translate'));

    expect(langs[2].code, 'sv');
    expect(langs[2].hasDirectLanguageFile, isFalse);

    final remainingNames = langs.skip(3).map((e) => e.englishName).toList();
    final sortedNames = [...remainingNames]..sort();
    expect(remainingNames, equals(sortedNames));
  });

  test('Hybrid QR and visual sign triggers resolve deterministically', () {
    expect(sharedCatalog.stations.length, 9);

    expect(
      sharedCatalog.resolveStationFromRawCode(
        'https://queyunpeng25-debug.github.io/Cross-platform-project/?station=lobby',
      ),
      'lobby',
    );
    expect(
      sharedCatalog.resolveStationFromRawCode(
        'https://queyunpeng25-debug.github.io/Cross-platform-project/?station=tuas_bridge',
      ),
      'tuas_bridge',
    );
    expect(
      sharedCatalog.resolveStationFromRawCode('cs-guide://point/computers'),
      'computers',
    );
    expect(
      sharedCatalog.resolveStationFromRawCode('https://evil.example.com/?x=1'),
      isNull,
    );

    final greenhouseMatch = sharedCatalog.evaluateVisualOrTextSample(
      'Learning Hub',
    );
    expect(greenhouseMatch, isA<ScanMatchedStation>());
    expect((greenhouseMatch as ScanMatchedStation).stationId, 'greenhouse');

    final subwayMatch = sharedCatalog.evaluateVisualOrTextSample('SUBWAY logo');
    expect(subwayMatch, isA<ScanExternalLink>());
  });

  test('TourProgressController enforces Scan-to-Unlock and Red/Green/Blue states', () {
    final progress = TourProgressController(catalog: sharedCatalog);

    expect(progress.statusFor('lobby'), StationVisitStatus.current);
    expect(progress.isStationUnlocked('lobby'), isTrue);
    expect(progress.statusFor('greenhouse'), StationVisitStatus.unvisited);
    expect(progress.isStationUnlocked('greenhouse'), isFalse);

    progress.unlockAndSetCurrentStation('greenhouse');
    expect(progress.statusFor('greenhouse'), StationVisitStatus.current);
    expect(progress.statusFor('lobby'), StationVisitStatus.visited);
    expect(progress.isStationUnlocked('greenhouse'), isTrue);
    expect(progress.isFinalPuzzleReady(), isFalse);

    for (final s in sharedCatalog.stations) {
      progress.unlockAndSetCurrentStation(s.id);
      if (s.hasPuzzlePiece) {
        progress.markPuzzlePieceCollected(s.id);
      }
    }
    expect(progress.isFinalPuzzleReady(), isTrue);
  });

  testWidgets(
    'First launch shows language dialog, renders expanded side menu & DEMO MODE badge',
    (tester) async {
      tester.view.physicalSize = const Size(1024, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        CsExplorerRootApp(
          catalog: sharedCatalog,
          translationService: _InstantTranslationService(),
          canteenMenuRepository: CanteenMenuRepository(),
          showFirstLaunchPrompt: true,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // First-launch language dialog shows English, Finnish, and Swedish.
      expect(find.textContaining('English'), findsWidgets);
      expect(find.textContaining('Suomi'), findsWidgets);
      expect(find.textContaining('Svenska'), findsWidgets);

      // Confirm language dialog -> Lobby & expanded side menu with DEMO MODE visible.
      await tester.tap(find.text('Continue'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.textContaining('DEMO MODE'), findsWidgets);
      expect(find.textContaining('CS Explorer'), findsWidgets);
      expect(find.textContaining('CS Building Lobby'), findsWidgets);
    },
  );

  testWidgets(
    'Side menu lets visitors revisit unlocked stations and current station with Demo Mode off',
    (tester) async {
      DeviceCapabilities.debugExperienceOverride = DeviceExperience.nativeMobile;
      tester.view.physicalSize = const Size(1024, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        CsExplorerRootApp(
          catalog: sharedCatalog,
          translationService: _InstantTranslationService(),
          canteenMenuRepository: CanteenMenuRepository(),
          showFirstLaunchPrompt: false,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final progress = Zen.find<TourProgressController>();
      expect(Zen.find<AppSettingsController>().demoUnlockAll.value, isFalse);

      // Scan Greenhouse, then move on to Computers so Greenhouse is visited (not current).
      progress.unlockAndSetCurrentStation('greenhouse');
      progress.unlockAndSetCurrentStation('computers');
      await tester.pump();

      // Reopen previously visited Greenhouse from the side menu.
      await tester.tap(find.text('Learning Hub Greenhouse'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Play Greenhouse Activity'), findsOneWidget);
      expect(
        find.text('Scan the dedicated QR code on-site to switch to this area.'),
        findsNothing,
      );

      // Navigate away to Settings, then tap the current station (Greenhouse) to return.
      await tester.tap(find.text('Settings'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('App & Menu Language'), findsOneWidget);

      await tester.tap(find.text('Learning Hub Greenhouse'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Play Greenhouse Activity'), findsOneWidget);

      // Locked stations remain non-clickable while Demo Mode is off.
      await tester.tap(find.text('Student Guild Rooms'));
      await tester.pump();
      expect(find.text('Play Greenhouse Activity'), findsOneWidget);
      expect(find.text('Student Guild Channels & Links'), findsNothing);
    },
  );

  test('SpatialPreflightService.requestCameraPermission handles non-mobile and plugin errors safely', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    expect(await SpatialPreflightService.requestCameraPermission(), isTrue);

    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(await SpatialPreflightService.requestCameraPermission(), isFalse);
  });

  testWidgets(
    'Lobby displays guide introduction and collapsed-by-default route instructions',
    (tester) async {
      DeviceCapabilities.debugExperienceOverride = DeviceExperience.nativeMobile;
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        CsExplorerRootApp(
          catalog: sharedCatalog,
          translationService: _InstantTranslationService(),
          canteenMenuRepository: CanteenMenuRepository(),
          showFirstLaunchPrompt: false,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Guide intro card and mobile quick actions are visible.
      expect(find.text('How This Guide Works'), findsOneWidget);
      expect(find.text('Follow the Map'), findsOneWidget);
      expect(find.text('Open Building Map'), findsOneWidget);
      expect(find.text('Start Scanning'), findsOneWidget);

      // Suggested route card starts compact / collapsed.
      final routeToggle = find.text('Suggested Route · 1F → 3F');
      expect(routeToggle, findsOneWidget);
      expect(find.text('Start here · Main Level'), findsNothing);

      // Scroll toggle into view if needed and expand route instructions.
      await tester.ensureVisible(routeToggle);
      await tester.tap(routeToggle);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Start here · Main Level'), findsOneWidget);
      expect(find.text('Main stairs or lift'), findsOneWidget);
      expect(find.text('Top floor'), findsOneWidget);

      // Tap again to collapse back to compact default.
      await tester.tap(routeToggle);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Start here · Main Level'), findsNothing);

      // Quick action navigates straight to the interactive Building Map.
      await tester.ensureVisible(find.text('Open Building Map'));
      await tester.tap(find.text('Open Building Map'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('CS Building Map'), findsOneWidget);
    },
  );

  testWidgets(
    'Lobby intro adapts to laptop mode by hiding Start Scanning',
    (tester) async {
      DeviceCapabilities.debugExperienceOverride = DeviceExperience.laptop;
      tester.view.physicalSize = const Size(1280, 820);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        CsExplorerRootApp(
          catalog: sharedCatalog,
          translationService: _InstantTranslationService(),
          canteenMenuRepository: CanteenMenuRepository(),
          showFirstLaunchPrompt: false,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('How This Guide Works'), findsOneWidget);
      expect(find.text('Explore Every Stop'), findsOneWidget);
      expect(find.text('Open Building Map'), findsOneWidget);
      expect(find.text('Start Scanning'), findsNothing);
      expect(find.text('Suggested Route · 1F → 3F'), findsOneWidget);
      expect(find.text('Start here · Main Level'), findsNothing);
    },
  );

  testWidgets(
    'Cold ?map=<markerId> deep link opens Building Map at that marker floor',
    (tester) async {
      DeviceCapabilities.debugExperienceOverride = DeviceExperience.nativeMobile;
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final prefs = await SharedPreferences.getInstance();
      final canteenRepo = CanteenMenuRepository();
      addTearDown(canteenRepo.dispose);

      CsExplorerAppModule(
        catalog: sharedCatalog,
        translationService: _InstantTranslationService(),
        mapSlot: const DefaultMapFeatureSlot(),
        canteenSlot: DefaultCanteenFeatureSlot(menuRepository: canteenRepo),
        minigameSlot: const DefaultMinigameFeatureSlot(),
        prefs: prefs,
      ).register(Zen.rootScope);

      await tester.pumpWidget(
        const MaterialApp(
          home: CsExplorerShell(
            initialMapQueryParam: 'lift_2f',
            showFirstLaunchPrompt: false,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('CS Building Map'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is SegmentedButton<int> && w.selected.contains(2),
        ),
        findsOneWidget,
      );
      expect(find.text('You are here'), findsOneWidget);
    },
  );

  testWidgets(
    'Bottom dock stays visible on station detail, settings, and team screens',
    (tester) async {
      DeviceCapabilities.debugExperienceOverride = DeviceExperience.nativeMobile;
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        CsExplorerRootApp(
          catalog: sharedCatalog,
          translationService: _InstantTranslationService(),
          canteenMenuRepository: CanteenMenuRepository(),
          showFirstLaunchPrompt: false,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final progress = Zen.find<TourProgressController>();
      progress.unlockAndSetCurrentStation('greenhouse');
      await tester.pump();

      // Open Greenhouse station detail via drawer.
      await tester.tap(find.text('Guide'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Learning Hub Greenhouse'));
      await tester.pumpAndSettle();

      expect(find.text('Play Greenhouse Activity'), findsOneWidget);
      expect(find.text('Infos'), findsOneWidget);
      expect(find.text('Scan'), findsOneWidget);
      expect(find.text('Map'), findsOneWidget);

      // Open Settings via drawer -> dock remains visible.
      await tester.tap(find.bySemanticsLabel('Open building stations menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      expect(find.text('App & Menu Language'), findsOneWidget);
      expect(find.text('Infos'), findsOneWidget);
      expect(find.text('Scan'), findsOneWidget);
      expect(find.text('Map'), findsOneWidget);
    },
  );

  testWidgets(
    'ArTabletopPuzzleScreen omits uninitialized Native AR Plane toggle and ComputerPriceGame omits Preview disclaimer',
    (tester) async {
      final progress = TourProgressController(catalog: sharedCatalog);

      await tester.pumpWidget(
        MaterialApp(
          home: ArTabletopPuzzleScreen(
            progress: progress,
            onBackToLobby: () {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Native AR Plane'), findsNothing);
      expect(find.text('AR Camera On'), findsOneWidget);

      await tester.pumpWidget(const MaterialApp(home: ComputerPriceGame()));
      await tester.pump();
      expect(find.textContaining('Preview game'), findsNothing);
      expect(find.text('Match the Price'), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}

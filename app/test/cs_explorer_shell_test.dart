import 'package:cs_building_guide/core/controllers.dart';
import 'package:cs_building_guide/core/device_capabilities.dart';
import 'package:cs_building_guide/core/models.dart';
import 'package:cs_building_guide/core/translation_service.dart';
import 'package:cs_building_guide/features/minigames/spatial_minigame_engine.dart';
import 'package:cs_building_guide/main.dart';
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
}

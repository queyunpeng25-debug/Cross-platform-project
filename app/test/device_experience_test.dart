import 'package:cs_building_guide/computer_exhibit.dart';
import 'package:cs_building_guide/core/controllers.dart';
import 'package:cs_building_guide/core/device_capabilities.dart';
import 'package:cs_building_guide/core/translation_service.dart';
import 'package:cs_building_guide/features/map/building_map_screen.dart';
import 'package:cs_building_guide/features/map/map_pins.dart';
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

  group('DeviceCapabilities', () {
    test('maps desktop target platforms to laptop mode and mobile to native', () {
      for (final platform in [
        TargetPlatform.windows,
        TargetPlatform.macOS,
        TargetPlatform.linux,
      ]) {
        debugDefaultTargetPlatformOverride = platform;
        expect(DeviceCapabilities.experience, DeviceExperience.laptop);
        expect(DeviceCapabilities.isLaptopMode, isTrue);
        expect(DeviceCapabilities.supportsCameraScan, isFalse);
        expect(DeviceCapabilities.supportsArExperiences, isFalse);
        expect(DeviceCapabilities.supportsNative3dAr, isFalse);
        expect(DeviceCapabilities.autoUnlockStations, isTrue);
      }

      for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
        debugDefaultTargetPlatformOverride = platform;
        expect(DeviceCapabilities.experience, DeviceExperience.nativeMobile);
        expect(DeviceCapabilities.isLaptopMode, isFalse);
        expect(DeviceCapabilities.supportsCameraScan, isTrue);
        expect(DeviceCapabilities.supportsArExperiences, isTrue);
        expect(DeviceCapabilities.supportsNative3dAr, isTrue);
        expect(DeviceCapabilities.autoUnlockStations, isFalse);
      }
    });

    test('mobileWeb enables camera/AR web tour without native 3D AR', () {
      DeviceCapabilities.debugExperienceOverride = DeviceExperience.mobileWeb;

      expect(DeviceCapabilities.isMobileWeb, isTrue);
      expect(DeviceCapabilities.isLaptopMode, isFalse);
      expect(DeviceCapabilities.supportsCameraScan, isTrue);
      expect(DeviceCapabilities.supportsArExperiences, isTrue);
      expect(DeviceCapabilities.supportsNative3dAr, isFalse);
      expect(DeviceCapabilities.autoUnlockStations, isFalse);
    });
  });

  group('Laptop Mode UI', () {
    Future<void> pumpLaptopApp(WidgetTester tester) async {
      DeviceCapabilities.debugExperienceOverride = DeviceExperience.laptop;
      tester.view.physicalSize = const Size(1280, 820);
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
      await tester.pump(const Duration(milliseconds: 400));
    }

    Future<void> scrollSidebarTo(
      WidgetTester tester,
      Finder target, {
      double delta = 120,
    }) async {
      final sidebarScrollable = find
          .descendant(
            of: find.byType(ListView).first,
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        target,
        delta,
        scrollable: sidebarScrollable,
      );
      await tester.ensureVisible(target);
      await tester.pump();
    }

    testWidgets(
      'hides Scan tab & AR puzzle hunt, locks AR/camera activities, keeps desktop guide open',
      (tester) async {
        await pumpLaptopApp(tester);

        // 1. Dock has Infos & Map only — no Scan tab.
        expect(find.text('Infos'), findsOneWidget);
        expect(find.text('Map'), findsOneWidget);
        expect(find.text('Scan'), findsNothing);

        // 2. Sidebar shows Laptop Guide Mode (not Demo Mode) & locked Final AR Puzzle.
        expect(find.text('Laptop Guide Mode'), findsOneWidget);
        expect(find.textContaining('DEMO MODE'), findsNothing);
        expect(find.text('Play for Puzzle Piece'), findsNothing);

        await scrollSidebarTo(tester, find.text('Final AR Puzzle'));
        expect(find.text('Final AR Puzzle'), findsOneWidget);

        // 3. All stations are directly clickable without scanning.
        await scrollSidebarTo(
          tester,
          find.text('CS Pioneers Portrait Gallery'),
        );
        await tester.tap(find.text('CS Pioneers Portrait Gallery'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Open 3D AR Portrait View'), findsOneWidget);
        expect(find.text('Mobile only'), findsWidgets);
        await tester.tap(find.text('Open 3D AR Portrait View'));
        await tester.pump();
        expect(
          find.text('3D AR Portrait View is available on mobile devices.'),
          findsOneWidget,
        );

        // 4. Greenhouse camera activity is locked; AR puzzle CTA is hidden.
        await scrollSidebarTo(
          tester,
          find.text('Learning Hub Greenhouse'),
          delta: -120,
        );
        await tester.tap(find.text('Learning Hub Greenhouse'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.text('Play Greenhouse Activity'), findsOneWidget);
        expect(find.text('Play for Puzzle Piece'), findsNothing);
        await tester.tap(find.text('Play Greenhouse Activity'));
        await tester.pump();
        expect(
          find.text(
            'The Greenhouse camera activity is available on mobile devices.',
          ),
          findsOneWidget,
        );

        // 5. Evolution of Computers & Price Game still opens normally on laptop.
        await scrollSidebarTo(tester, find.text('Evolution of Computers'));
        await tester.tap(find.text('Evolution of Computers'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.text('Explore Retro PCs & Price Game'), findsOneWidget);
        await tester.tap(find.text('Explore Retro PCs & Price Game'));
        await tester.pumpAndSettle();
        expect(find.byType(ComputerExhibit), findsOneWidget);
      },
    );

    testWidgets(
      'Settings shows Laptop Guide experience and hides Demo Mode & Tour Reset',
      (tester) async {
        await pumpLaptopApp(tester);

        await tester.tap(find.text('Settings'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Device Experience'), findsOneWidget);
        expect(
          find.text('Laptop Guide · Camera & AR Mobile-Only'),
          findsOneWidget,
        );
        expect(
          find.text('Demo Mode (Unlock All Stations & Final Puzzle)'),
          findsNothing,
        );
        expect(find.text('Reset Tour Progress'), findsNothing);
      },
    );

    testWidgets(
      'Map hides Locate me & puzzle layer and lets laptop users open any station guide',
      (tester) async {
        DeviceCapabilities.debugExperienceOverride = DeviceExperience.laptop;
        tester.view.physicalSize = const Size(1280, 820);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final prefs = await SharedPreferences.getInstance();
        final progress = TourProgressController(
          catalog: sharedCatalog,
          prefs: prefs,
        );
        final settings = AppSettingsController(prefs: prefs);
        String? openedStationId;

        await tester.pumpWidget(
          MaterialApp(
            home: CsBuildingMapScreen(
              progress: progress,
              settings: settings,
              onOpenStation: (id) => openedStationId = id,
              onBackToLobby: () {},
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.text('Locate me'), findsNothing);
        expect(find.text('Puzzle pieces'), findsNothing);
        expect(find.text('Puzzle pieces collected'), findsNothing);
        expect(find.text('All 9 stations open to browse'), findsOneWidget);

        // Tap Greenhouse on 1F — directly unlocked on laptop!
        await tester.tap(
          find.byWidgetPredicate(
            (w) => w is StationMapPin && w.caption == 'Greenhouse',
          ),
        );
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.text('Scan a QR code'), findsNothing);
        expect(find.text('Open guide'), findsOneWidget);
        await tester.tap(find.text('Open guide'));
        await tester.pump();
        expect(openedStationId, 'greenhouse');
      },
    );
  });

  group('Mobile Web vs Native Mobile', () {
    testWidgets(
      'mobileWeb keeps Scan tab and labels Portrait station for Web Camera',
      (tester) async {
        DeviceCapabilities.debugExperienceOverride = DeviceExperience.mobileWeb;
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
        await tester.pump(const Duration(milliseconds: 400));

        // Mobile Web keeps Scan tab & Demo Mode.
        expect(find.text('Scan'), findsOneWidget);
        expect(find.textContaining('DEMO MODE'), findsWidgets);

        // Enable Demo Mode and inspect Portraits station.
        Zen.find<AppSettingsController>().setDemoUnlockAll(true);
        await tester.pump();

        final sidebarScrollable = find
            .descendant(
              of: find.byType(ListView).first,
              matching: find.byType(Scrollable),
            )
            .first;
        await tester.scrollUntilVisible(
          find.text('CS Pioneers Portrait Gallery'),
          120,
          scrollable: sidebarScrollable,
        );
        await tester.ensureVisible(find.text('CS Pioneers Portrait Gallery'));
        await tester.pump();
        await tester.tap(find.text('CS Pioneers Portrait Gallery'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Scan Portrait (Web Camera)'), findsOneWidget);
      },
    );

    testWidgets(
      'nativeMobile keeps Scan tab and full 3D AR Portrait View button',
      (tester) async {
        DeviceCapabilities.debugExperienceOverride =
            DeviceExperience.nativeMobile;
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
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.text('Scan'), findsOneWidget);
        expect(find.textContaining('DEMO MODE'), findsWidgets);

        Zen.find<AppSettingsController>().setDemoUnlockAll(true);
        await tester.pump();

        final sidebarScrollable = find
            .descendant(
              of: find.byType(ListView).first,
              matching: find.byType(Scrollable),
            )
            .first;
        await tester.scrollUntilVisible(
          find.text('CS Pioneers Portrait Gallery'),
          120,
          scrollable: sidebarScrollable,
        );
        await tester.ensureVisible(find.text('CS Pioneers Portrait Gallery'));
        await tester.pump();
        await tester.tap(find.text('CS Pioneers Portrait Gallery'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Open 3D AR Portrait View'), findsOneWidget);
        expect(find.text('Mobile only'), findsNothing);
      },
    );
  });
}

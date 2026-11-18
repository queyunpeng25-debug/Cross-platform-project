import 'package:cs_building_guide/core/controllers.dart';
import 'package:cs_building_guide/features/minigames/greenhouse_angle_matcher.dart';
import 'package:cs_building_guide/features/minigames/greenhouse_angle_minigame_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('GreenhouseAngleMinigameScreen UI, zoom, and demo mode tests', (tester) async {
    final catalog = await StationCatalogRepository.loadFromAssets();
    final progress = TourProgressController(catalog: catalog);
    final target = kGreenhouseAngleTargets.first;
    final dummyMatcher = GreenhouseAngleMatcher.fromFrames([]);

    // Part A: Normal Mode
    await tester.pumpWidget(
      MaterialApp(
        home: GreenhouseAngleMinigameScreen(
          progress: progress,
          initialTarget: target,
          matcher: dummyMatcher,
          isDemoMode: false,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // 1. Title and header bar present
    expect(find.text('Find the Correct Angle'), findsOneWidget);

    // 2. Thumbnail present in top-left with "Zoom" label
    expect(find.text('Zoom'), findsOneWidget);

    // 3. Shutter button present
    expect(find.byIcon(Icons.camera_alt_rounded), findsOneWidget);

    // 4. Gallery icon is NOT present in photo mode!
    expect(find.byIcon(Icons.photo_library_outlined), findsNothing);

    // 5. Shuffle button is NOT present in normal mode!
    expect(find.byIcon(Icons.shuffle_rounded), findsNothing);

    // 6. Click thumbnail to zoom in
    await tester.tap(find.text('Zoom'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // In zoomed overlay: target title and "Key Objects to Match:" appear
    expect(find.text('Key Objects to Match:'), findsOneWidget);

    // 7. Click the small 'x' button at the corner of the image to dezoom!
    final closeX = find.byIcon(Icons.close_rounded);
    expect(closeX, findsOneWidget);
    await tester.tap(closeX);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Zoomed overlay is dismissed
    expect(find.text('Key Objects to Match:'), findsNothing);

    // Part B: Demo Mode - shuffle button is visible
    await tester.pumpWidget(
      MaterialApp(
        home: GreenhouseAngleMinigameScreen(
          progress: progress,
          initialTarget: target,
          matcher: dummyMatcher,
          isDemoMode: true,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byIcon(Icons.shuffle_rounded), findsOneWidget);

    // Clean teardown
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}

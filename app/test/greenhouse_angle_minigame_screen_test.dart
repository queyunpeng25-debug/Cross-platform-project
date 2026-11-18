import 'package:cs_building_guide/core/controllers.dart';
import 'package:cs_building_guide/core/models.dart';
import 'package:cs_building_guide/features/minigames/greenhouse_angle_matcher.dart';
import 'package:cs_building_guide/features/minigames/greenhouse_angle_minigame_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await GreenhouseAngleMatcher.load();
  });

  testWidgets('GreenhouseAngleMinigameScreen renders thumbnail, zooms in, and dezooms on x click', (tester) async {
    final catalog = await StationCatalogRepository.loadFromAssets();
    final progress = TourProgressController(catalog: catalog);
    final target = kGreenhouseAngleTargets.first;

    await tester.pumpWidget(
      MaterialApp(
        home: GreenhouseAngleMinigameScreen(
          progress: progress,
          initialTarget: target,
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

    // 4. Click thumbnail to zoom in
    await tester.tap(find.text('Zoom'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // In zoomed overlay: target title and "Key Objects to Match:" appear
    expect(find.text('Key Objects to Match:'), findsOneWidget);

    // 5. Click the small 'x' button at the corner of the image to dezoom!
    final closeX = find.byIcon(Icons.close_rounded);
    expect(closeX, findsOneWidget);
    await tester.tap(closeX);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Zoomed overlay is dismissed
    expect(find.text('Key Objects to Match:'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}

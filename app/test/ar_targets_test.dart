import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cs_building_guide/ar_targets.dart';
import 'package:cs_building_guide/content.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'all AR targets have bundled images, panels and matching biographies',
    () async {
      final targets = await ArTarget.load();
      final content = await GuideContent.load();
      for (final target in targets) {
        expect(content.portraits[target.id], isNotNull);
        expect(
          (await rootBundle.load(target.image)).lengthInBytes,
          greaterThan(1000),
        );
        final panel = await rootBundle.load(target.panel);
        expect(panel.getUint32(0, Endian.little), 0x46546c67);
        expect(panel.getUint32(8, Endian.little), panel.lengthInBytes);
      }
    },
  );
  test(
    'panel sits to the right in image coordinates and follows anchor rotation',
    () {
      final target = ArTarget.fromJson({
        'id': 'p',
        'image': 'assets/p.jpg',
        'panel': 'assets/p.glb',
        'physicalWidthMeters': .8,
        'widthIsMeasured': false,
      });
      final local = target.panelTransform;
      // Left edge lies 6% of image width beyond the right edge of the portrait.
      expect(local.getTranslation().x - .5 * .8 * .65, closeTo(.8 * .56, 1e-9));
      expect(local.getTranslation().y, closeTo(.015, 1e-9));
      final wall = Matrix4.identity()..rotateX(1.5707963267948966);
      final world = wall * local;
      expect(world.getTranslation().z, closeTo(.015, 1e-9));
      expect(world.getTranslation().x, closeTo(local.getTranslation().x, 1e-9));
      expect(target.measured, false);
    },
  );
  test('detection confirmation rejects isolated observations and resets on lost image', () {
    final gate = DetectionGate();
    final time = DateTime(2026, 11, 13);
    expect(gate.observe('a', time), false);
    expect(gate.observe('b', time), false);
    expect(
      gate.observe('a', time.add(const Duration(milliseconds: 150))),
      true,
    );
    gate.forget('a');
    expect(gate.observe('a', time.add(const Duration(seconds: 1))), false);
    expect(gate.observe('a', time.add(const Duration(seconds: 3))), false);
    gate.clear();
    expect(
      gate.observe('b', time.add(const Duration(milliseconds: 150))),
      false,
    );
  });
  test('invalid size or a filename that cannot map to its ID is rejected', () {
    for (final width in [0, -1, double.infinity, double.nan, 11]) {
      expect(
        () => ArTarget.fromJson({
          'id': 'p',
          'image': 'assets/p.jpg',
          'panel': 'a.glb',
          'physicalWidthMeters': width,
        }),
        throwsFormatException,
      );
    }
    expect(
      () => ArTarget.fromJson({
        'id': 'p',
        'image': 'assets/other.jpg',
        'panel': 'a.glb',
        'physicalWidthMeters': .8,
      }),
      throwsFormatException,
    );
  });
}

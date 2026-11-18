import 'dart:math' as math;
import 'dart:typed_data';

import 'package:cs_building_guide/features/minigames/greenhouse_angle_matcher.dart';
import 'package:cs_building_guide/features/scanner/place_image_recognizer.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

RawRgbaFrame _simulateCrowdOcclusion(
  RawRgbaFrame src, {
  double bottomOcclusion = 0.25,
}) {
  final out = Uint8List.fromList(src.rgba);
  final startY = (src.height * (1.0 - bottomOcclusion)).round();
  final rng = math.Random(12345);

  // Overwrite bottom region (people standing / walking) with noise / color blobs
  for (var y = startY; y < src.height; y++) {
    for (var x = 0; x < src.width; x++) {
      final p = (y * src.width + x) * 4;
      out[p] = (rng.nextInt(120) + 40).clamp(0, 255);
      out[p + 1] = (rng.nextInt(100) + 20).clamp(0, 255);
      out[p + 2] = (rng.nextInt(80) + 10).clamp(0, 255);
      out[p + 3] = 255;
    }
  }
  return RawRgbaFrame(width: src.width, height: src.height, rgba: out);
}

RawRgbaFrame _adjustLighting(
  RawRgbaFrame src, {
  double gain = 1.0,
  int bias = 0,
}) {
  final out = Uint8List(src.rgba.length);
  for (var i = 0; i < src.rgba.length; i += 4) {
    out[i] = (src.rgba[i] * gain + bias).round().clamp(0, 255);
    out[i + 1] = (src.rgba[i + 1] * gain + bias).round().clamp(0, 255);
    out[i + 2] = (src.rgba[i + 2] * gain + bias).round().clamp(0, 255);
    out[i + 3] = 255;
  }
  return RawRgbaFrame(width: src.width, height: src.height, rgba: out);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GreenhouseAngleMatcher matcher;
  final Map<String, RawRgbaFrame> referenceFrames = {};

  setUpAll(() async {
    matcher = await GreenhouseAngleMatcher.load();

    for (final target in kGreenhouseAngleTargets) {
      final data = await rootBundle.load(target.assetPath);
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      final frame = await RawRgbaFrame.decodeEncoded(bytes, maxDimension: 360);
      expect(frame, isNotNull, reason: 'Failed to decode ${target.assetPath}');
      referenceFrames[target.id] = frame!;
    }
  });

  test('indexes all 5 reference Greenhouse perspective photos', () {
    expect(referenceFrames.length, 5);
    for (final target in kGreenhouseAngleTargets) {
      expect(referenceFrames.containsKey(target.id), isTrue);
    }
  });

  test('matches each reference photo against itself with high confidence', () {
    for (final target in kGreenhouseAngleTargets) {
      final frame = referenceFrames[target.id]!;
      final result = matcher.matchFrame(inputFrame: frame, target: target);

      expect(
        result.isMatch,
        isTrue,
        reason: 'Target ${target.id} should match its own image',
      );
      expect(result.inliers, greaterThanOrEqualTo(10));
      expect(result.confidence, greaterThanOrEqualTo(0.55));
      expect(result.feedbackMessage, 'Congratulations!');
    }
  });

  test('matches successfully even when crowds/people occlude the foreground', () {
    // Test that when bottom 25% has people moving around, the rigid landmarks match
    for (final target in kGreenhouseAngleTargets) {
      final frame = referenceFrames[target.id]!;
      final occluded = _simulateCrowdOcclusion(frame, bottomOcclusion: 0.25);
      final result = matcher.matchFrame(inputFrame: occluded, target: target);

      expect(
        result.isMatch,
        isTrue,
        reason:
            'Target ${target.id} should remain recognizable when lower crowd area is occluded (inliers=${result.inliers}, conf=${result.confidence})',
      );
      expect(result.feedbackMessage, 'Congratulations!');
    }
  });

  test('matches under realistic camera exposure and slight crop variations', () {
    for (final target in kGreenhouseAngleTargets) {
      final frame = referenceFrames[target.id]!;
      // Slightly cropped & lighting shifted
      final modified = _adjustLighting(
        frame.cropNormalized(0.04, 0.04, 0.96, 0.96),
        gain: 0.92,
        bias: 10,
      );
      final result = matcher.matchFrame(inputFrame: modified, target: target);

      expect(
        result.isMatch,
        isTrue,
        reason:
            'Target ${target.id} should match under slight crop and exposure shift',
      );
    }
  });

  test('rejects mismatched perspectives with the exact error message', () {
    // Cross match: angle 1 vs angle 2, angle 3 vs angle 4, etc.
    final targets = kGreenhouseAngleTargets;
    for (var i = 0; i < targets.length; i++) {
      final target = targets[i];
      final wrongTarget = targets[(i + 1) % targets.length];
      final wrongFrame = referenceFrames[wrongTarget.id]!;

      final result = matcher.matchFrame(
        inputFrame: wrongFrame,
        target: target,
      );

      expect(
        result.isMatch,
        isFalse,
        reason:
            'Target ${target.id} should NOT match photo of ${wrongTarget.id} (inliers=${result.inliers})',
      );
      expect(
        result.feedbackMessage,
        'Posizione o immagine non corretta, riprova :( ',
      );
    }
  });

  test('rejects completely unrelated images (computer exhibit, portraits)', () async {
    for (final distractorAsset in [
      'assets/computers/computer_0.jpg',
      'assets/portraits/kaisa_nyberg.jpg',
      'assets/stations/study_3f.jpg',
    ]) {
      final data = await rootBundle.load(distractorAsset);
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      final frame = await RawRgbaFrame.decodeEncoded(bytes, maxDimension: 340);
      expect(frame, isNotNull);

      for (final target in kGreenhouseAngleTargets) {
        final result = matcher.matchFrame(
          inputFrame: frame!,
          target: target,
        );
        expect(
          result.isMatch,
          isFalse,
          reason:
              'Target ${target.id} falsely matched distractor $distractorAsset (inliers=${result.inliers})',
        );
        expect(
          result.feedbackMessage,
          'Posizione o immagine non corretta, riprova :( ',
        );
      }
    }
  });
}

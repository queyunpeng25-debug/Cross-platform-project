import 'dart:math' as math;

import 'package:cs_building_guide/features/scanner/place_image_recognizer.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

RawRgbaFrame _adjustExposureAndContrast(
  RawRgbaFrame src, {
  double gain = 1.0,
  double bias = 0.0,
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

  late PlaceImageRecognizer recognizer;

  setUpAll(() async {
    recognizer = await PlaceImageRecognizer.loadDefault();
  });

  test('loads all registered place targets from assets', () {
    expect(recognizer.targetCount, 13);
  });

  test('matches realistic zoomed, off-center, and lighting-shifted views', () async {
    Future<RawRgbaFrame> loadAssetFrame(String assetPath) async {
      final data = await rootBundle.load(assetPath);
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      final decoded = await RawRgbaFrame.decodeEncoded(bytes, maxDimension: 520);
      expect(decoded, isNotNull, reason: 'Failed to decode $assetPath');
      return decoded!;
    }

    // 1. Greenhouse: full older PDF station photo (different angle & distance!)
    final greenhouseStationPhoto = await loadAssetFrame(
      'assets/stations/greenhouse_1f.jpg',
    );
    final ghMatch = recognizer.recognizeRgba(greenhouseStationPhoto);
    expect(ghMatch, isNotNull, reason: 'Different-day Greenhouse photo should match');
    expect(ghMatch!.stationId, 'greenhouse');

    // 2. Subway: older PDF wide canteen photo containing Subway sign on left!
    final canteenWidePhoto = await loadAssetFrame(
      'assets/stations/canteen_1f.jpg',
    );
    final subWideMatch = recognizer.recognizeRgba(
      canteenWidePhoto.cropNormalized(0.05, 0.08, 0.52, 0.58),
    );
    expect(subWideMatch, isNotNull, reason: 'Subway wall from another angle should match');
    expect(subWideMatch!.stationId, 'canteen');
    expect(subWideMatch.externalUrl, contains('subway.fi'));

    // 3. Guild logos under exposure shift & off-center crop
    for (final asset in <String>[
      'assets/place_targets/guild_tik.jpg',
      'assets/place_targets/guild_athene.jpg',
      'assets/place_targets/guild_dg.jpg',
    ]) {
      final raw = await loadAssetFrame(asset);
      final perturbed = _adjustExposureAndContrast(
        raw.cropNormalized(0.06, 0.05, 0.94, 0.92),
        gain: 0.82,
        bias: 18,
      );
      final m = recognizer.recognizeRgba(perturbed);
      expect(m, isNotNull, reason: 'Perturbed $asset should match guilds');
      expect(m!.stationId, 'guilds');
    }

    // 4. Locked Wing A: both full door AND close-up of just the 'A' plaque
    final fullDoorA = await loadAssetFrame(
      'assets/place_targets/locked_door_a.jpg',
    );
    final doorMatch = recognizer.recognizeRgba(
      _adjustExposureAndContrast(fullDoorA, gain: 1.12, bias: -10),
    );
    expect(doorMatch, isNotNull);
    expect(doorMatch!.stationId, 'locked_corridors');

    final justTheA = fullDoorA.cropNormalized(0.72, 0.03, 0.99, 0.29);
    final aMatch = recognizer.recognizeRgba(justTheA);
    expect(aMatch, isNotNull, reason: 'Close-up of just the A sign should match');
    expect(aMatch!.stationId, 'locked_corridors');

    // 5. TUAS access: both end-of-building SCI door AND postal box
    final tuasAlcove = await loadAssetFrame(
      'assets/place_targets/tuas_door_alcove.jpg',
    );
    final tuasMatch = recognizer.recognizeRgba(
      tuasAlcove.cropNormalized(0.15, 0.18, 0.85, 0.82),
    );
    expect(tuasMatch, isNotNull);
    expect(tuasMatch!.stationId, 'tuas_bridge');

    final postalBox = await loadAssetFrame(
      'assets/place_targets/tuas_postal_box.jpg',
    );
    final boxMatch = recognizer.recognizeRgba(
      _adjustExposureAndContrast(postalBox, gain: 0.9, bias: 8),
    );
    expect(boxMatch, isNotNull);
    expect(boxMatch!.stationId, 'tuas_bridge');
  });

  test('rejects unrelated scenes, portraits, retro PCs, and random noise', () async {
    for (final distractor in <String>[
      'assets/computers/computer_0.jpg',
      'assets/computers/computer_2.jpg',
      'assets/portraits/kaisa_nyberg.jpg',
      'assets/stations/study_3f.jpg',
      'assets/stations/lobby.jpg',
    ]) {
      final data = await rootBundle.load(distractor);
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      final match = await recognizer.recognizeEncodedBytes(bytes);
      expect(
        match,
        isNull,
        reason:
            'Unrelated image $distractor falsely matched ${match?.targetId} (conf=${match?.confidence}, inliers=${match?.inliers}, sim=${match?.structuralSimilarity})',
      );
    }

    // Synthetic structured noise / gradient frame
    final noise = Uint8List(240 * 240 * 4);
    final rng = math.Random(42);
    for (var i = 0; i < noise.length; i += 4) {
      final v = rng.nextInt(256);
      noise[i] = v;
      noise[i + 1] = (v * 0.8).round();
      noise[i + 2] = (255 - v);
      noise[i + 3] = 255;
    }
    final noiseMatch = recognizer.recognizeRgba(
      RawRgbaFrame(width: 240, height: 240, rgba: noise),
    );
    expect(noiseMatch, isNull);
  });
}

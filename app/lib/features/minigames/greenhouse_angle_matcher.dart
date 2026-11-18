import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart';
import '../scanner/place_image_recognizer.dart';

/// Specification for one of the 5 reference perspective photos of the Learning Hub Greenhouse.
class GreenhouseAngleTarget {
  const GreenhouseAngleTarget({
    required this.id,
    required this.title,
    required this.hint,
    required this.assetPath,
    this.keyLandmarks = const <String>[],
  });

  final String id;
  final String title;
  final String hint;
  final String assetPath;
  final List<String> keyLandmarks;
}

/// The 5 reference angle photos uploaded for the Greenhouse "Find the Correct Angle" Minigame.
const List<GreenhouseAngleTarget> kGreenhouseAngleTargets = [
  GreenhouseAngleTarget(
    id: 'sculpture_low',
    title: 'Hanging Sculpture & High Atrium',
    hint: 'Ground floor looking high up at the suspended sculpture, brick wall & green sofa',
    assetPath: 'assets/greenhouse_angles/greenhouse_sculpture_low.jpg',
    keyLandmarks: [
      'Suspended ribbon sculpture',
      'Red brick facade',
      'High rectangular windows',
      'Green seating area',
    ],
  ),
  GreenhouseAngleTarget(
    id: 'palm_screens',
    title: 'Palm Tree & Meeting Pods',
    hint: 'Ground floor with the tall palm tree on the right and meeting pod screens',
    assetPath: 'assets/greenhouse_angles/greenhouse_palm_screens.jpg',
    keyLandmarks: [
      'Indoor palm tree fronds',
      'Tomato meeting pod glass',
      'Suspended ceiling structure',
      'Presentation screens',
    ],
  ),
  GreenhouseAngleTarget(
    id: 'shed_corner',
    title: 'Greenhouse Wooden Cabin Corner',
    hint: 'Front-left corner view of the wooden Greenhouse cabin (C130a) and blue bench',
    assetPath: 'assets/greenhouse_angles/greenhouse_shed_corner.jpg',
    keyLandmarks: [
      'Timber gable roofline',
      'Vertical wooden door & latch',
      'Greenhouse glass panels',
      'Blue bench seating',
    ],
  ),
  GreenhouseAngleTarget(
    id: 'dissertation_shelf',
    title: 'Doctoral Dissertations Bookshelf',
    hint: 'Frontal view of the 3-section bookcase with white PhD theses (Uudet väitöskirjat)',
    assetPath: 'assets/greenhouse_angles/greenhouse_dissertation_shelf.jpg',
    keyLandmarks: [
      '3-section wooden bookcase',
      'Rows of white PhD theses',
      'Top thesis & magazine displays',
      'Poster board',
    ],
  ),
  GreenhouseAngleTarget(
    id: 'mezzanine_chairs',
    title: 'Mezzanine Lounge & Orange Armchairs',
    hint: 'Upper floor mezzanine looking toward sculpture with two orange armchairs',
    assetPath: 'assets/greenhouse_angles/greenhouse_mezzanine_chairs.jpg',
    keyLandmarks: [
      'Two orange armchairs',
      'Round white coffee table',
      'Wooden railing & yellow sign',
      'Upper atrium brickwork',
    ],
  ),
];

/// Result of evaluating a live camera snapshot against a target reference angle.
class GreenhouseAngleMatchResult {
  const GreenhouseAngleMatchResult({
    required this.isMatch,
    required this.confidence,
    required this.inliers,
    required this.scale,
    required this.rotationDegrees,
    required this.spatialSpan,
    required this.structuralSimilarity,
    required this.feedbackMessage,
  });

  final bool isMatch;
  final double confidence;
  final int inliers;
  final double scale;
  final double rotationDegrees;
  final double spatialSpan;
  final double structuralSimilarity;
  final String feedbackMessage;
}

class _AngleKeypoint {
  const _AngleKeypoint({
    required this.x,
    required this.y,
    required this.angleBin,
    required this.scale,
    required this.descriptor,
  });

  final double x;
  final double y;
  final int angleBin;
  final double scale;
  final Uint8List descriptor;
}

class _AnglePutativeMatch {
  const _AnglePutativeMatch({
    required this.query,
    required this.ref,
    required this.distance,
  });

  final _AngleKeypoint query;
  final _AngleKeypoint ref;
  final int distance;
}

class _IndexedAngleTarget {
  const _IndexedAngleTarget({
    required this.target,
    required this.width,
    required this.height,
    required this.keypoints,
    required this.edgeHog,
    required this.appearance,
  });

  final GreenhouseAngleTarget target;
  final int width;
  final int height;
  final List<_AngleKeypoint> keypoints;
  final Float32List edgeHog;
  final Float32List appearance;
}

/// Robust Computer Vision Engine for the "Find the Correct Angle" Minigame.
///
/// Features:
/// 1. Multi-scale spatially bucketed Harris corner keypoints + 256-bit rotation-steered BRIEF descriptors.
/// 2. 2D RANSAC affine consistency verification (scale, rotation, reprojection tolerance, spatial coverage).
/// 3. Robustness to crowds: moving people introduce outliers, but the rigid architectural features of the
///    Greenhouse landmarks (timber cabin, dissertation shelves, chairs, palm, sculpture) provide high-consensus inliers!
class GreenhouseAngleMatcher {
  GreenhouseAngleMatcher._(this._indexedTargets);

  final Map<String, _IndexedAngleTarget> _indexedTargets;

  static GreenhouseAngleMatcher? _instance;

  static GreenhouseAngleMatcher? get instance => _instance;

  /// Loads and indexes all 5 reference angle photos from assets.
  static Future<GreenhouseAngleMatcher> load() async {
    final existing = _instance;
    if (existing != null) return existing;

    final map = <String, _IndexedAngleTarget>{};
    for (final target in kGreenhouseAngleTargets) {
      final data = await rootBundle.load(target.assetPath);
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      final frame = await RawRgbaFrame.decodeEncoded(bytes, maxDimension: 360);
      if (frame != null) {
        map[target.id] = _index(target, frame);
      }
    }
    final matcher = GreenhouseAngleMatcher._(map);
    _instance = matcher;
    return matcher;
  }

  /// Builds an in-memory matcher with pre-decoded frames (convenient for testing).
  static GreenhouseAngleMatcher fromFrames(
    List<(GreenhouseAngleTarget, RawRgbaFrame)> entries,
  ) {
    final map = <String, _IndexedAngleTarget>{};
    for (final (target, frame) in entries) {
      map[target.id] = _index(target, frame.resizeMax(360));
    }
    return GreenhouseAngleMatcher._(map);
  }

  static _IndexedAngleTarget _index(
    GreenhouseAngleTarget target,
    RawRgbaFrame frame,
  ) {
    final keypoints = _extractKeypoints(
      frame,
      scales: const <double>[1.0, 0.70, 0.50],
      maxPerCell: 12,
    );
    final (edgeHog, appearance) = _computeHogAndAppearance(frame);
    return _IndexedAngleTarget(
      target: target,
      width: frame.width,
      height: frame.height,
      keypoints: keypoints,
      edgeHog: edgeHog,
      appearance: appearance,
    );
  }

  /// Evaluates an input camera frame against the specified target angle.
  GreenhouseAngleMatchResult matchFrame({
    required RawRgbaFrame inputFrame,
    required GreenhouseAngleTarget target,
  }) {
    final indexed = _indexedTargets[target.id];
    if (indexed == null || inputFrame.width < 32 || inputFrame.height < 32) {
      return const GreenhouseAngleMatchResult(
        isMatch: false,
        confidence: 0.0,
        inliers: 0,
        scale: 1.0,
        rotationDegrees: 0.0,
        spatialSpan: 0.0,
        structuralSimilarity: 0.0,
        feedbackMessage: 'Incorrect position or angle, try again :(',
      );
    }

    // Pass 1: standard scale
    final queryFrame = inputFrame.resizeMax(340);
    final res1 = _evaluate(queryFrame, indexed);
    if (res1.isMatch) return res1;

    // Pass 2: zoomed center if user is standing slightly further back
    if (math.max(inputFrame.width, inputFrame.height) >= 200) {
      final zoomedCenter = inputFrame
          .cropNormalized(0.12, 0.12, 0.88, 0.88)
          .resizeMax(320);
      final res2 = _evaluate(zoomedCenter, indexed);
      if (res2.isMatch || res2.confidence > res1.confidence) {
        return res2;
      }
    }

    return res1;
  }

  GreenhouseAngleMatchResult _evaluate(
    RawRgbaFrame queryFrame,
    _IndexedAngleTarget target,
  ) {
    final queryKeypoints = _extractKeypoints(
      queryFrame,
      scales: const <double>[1.0, 0.72],
      maxPerCell: 10,
    );

    final (edgeHog, appearance) = _computeHogAndAppearance(queryFrame);
    final structuralSim = _computeCosineSim(target.edgeHog, edgeHog) * 0.70 +
        _computeCosineSim(target.appearance, appearance) * 0.30;

    final ransac = _runRansac(
      queryKeypoints: queryKeypoints,
      queryWidth: queryFrame.width,
      queryHeight: queryFrame.height,
      target: target,
    );

    // Confidence calculation:
    // When people are present, inliers will be 8..30 (static objects),
    // structural similarity will be ~0.40..0.85, span >= 0.16.
    final inliers = ransac.inliers;
    final scale = ransac.scale;
    final rotDeg = ransac.rotationDegrees;
    final span = ransac.spatialSpan;

    var confidence = 0.0;
    if (inliers >= 8) {
      confidence = (0.50 + (inliers - 8) * 0.03 + (structuralSim - 0.40) * 0.35)
          .clamp(0.0, 0.99);
    } else if (inliers >= 5 && structuralSim >= 0.62) {
      confidence = (0.45 + (inliers - 5) * 0.04 + (structuralSim - 0.60) * 0.40)
          .clamp(0.0, 0.85);
    } else {
      confidence = (structuralSim * 0.4).clamp(0.0, 0.49);
    }

    // Matching criteria:
    // - Inliers >= 8 with broad spatial span (features not clustered on a single point)
    // - Realistic scale (user standing roughly at the right distance)
    // - Upright handheld rotation (< 38 degrees)
    // - Or very high inliers >= 14 even under harsh lighting or partial occlusion
    final isMatch = (inliers >= 8 &&
            span >= 0.14 &&
            structuralSim >= 0.35 &&
            scale >= 0.35 &&
            scale <= 2.8 &&
            rotDeg.abs() <= 38.0) ||
        (inliers >= 14 && span >= 0.12 && rotDeg.abs() <= 40.0);

    return GreenhouseAngleMatchResult(
      isMatch: isMatch,
      confidence: confidence,
      inliers: inliers,
      scale: scale,
      rotationDegrees: rotDeg,
      spatialSpan: span,
      structuralSimilarity: structuralSim,
      feedbackMessage: isMatch
          ? 'Congratulations!'
          : 'Incorrect position or angle, try again :(',
    );
  }

  // ---------------------------------------------------------------------------
  // Keypoint extraction (Harris Corner + Steered BRIEF)
  // ---------------------------------------------------------------------------

  static const int _angleBins = 32;
  static const int _patchRadius = 12;
  static const int _borderMargin = 14;

  static final Uint8List _popcount8 = Uint8List.fromList(
    List<int>.generate(256, (v) {
      var x = v;
      var c = 0;
      while (x != 0) {
        x &= x - 1;
        c++;
      }
      return c;
    }),
  );

  static final List<Int8List> _steeredPairs = _buildSteeredBriefTable();

  static List<Int8List> _buildSteeredBriefTable() {
    final basePairs = Int8List(256 * 4);
    var seed = 987654321;
    int nextCoord() {
      seed = (seed * 48271) % 2147483647;
      final u1 = (seed & 0xff) / 255.0;
      seed = (seed * 48271) % 2147483647;
      final u2 = (seed & 0xff) / 255.0;
      final tri = ((u1 + u2) - 1.0) * _patchRadius;
      return tri.round().clamp(-_patchRadius, _patchRadius);
    }

    var idx = 0;
    while (idx < 256) {
      final x1 = nextCoord();
      final y1 = nextCoord();
      final x2 = nextCoord();
      final y2 = nextCoord();
      final dist2 = (x1 - x2) * (x1 - x2) + (y1 - y2) * (y1 - y2);
      if (dist2 < 16) continue;
      basePairs[idx * 4] = x1;
      basePairs[idx * 4 + 1] = y1;
      basePairs[idx * 4 + 2] = x2;
      basePairs[idx * 4 + 3] = y2;
      idx++;
    }

    return List<Int8List>.generate(_angleBins, (bin) {
      final angle = (bin * 2.0 * math.pi) / _angleBins;
      final c = math.cos(angle);
      final s = math.sin(angle);
      final steered = Int8List(256 * 4);
      for (var i = 0; i < 256; i++) {
        final x1 = basePairs[i * 4];
        final y1 = basePairs[i * 4 + 1];
        final x2 = basePairs[i * 4 + 2];
        final y2 = basePairs[i * 4 + 3];
        steered[i * 4] = (x1 * c - y1 * s).round().clamp(-13, 13);
        steered[i * 4 + 1] = (x1 * s + y1 * c).round().clamp(-13, 13);
        steered[i * 4 + 2] = (x2 * c - y2 * s).round().clamp(-13, 13);
        steered[i * 4 + 3] = (x2 * s + y2 * c).round().clamp(-13, 13);
      }
      return steered;
    }, growable: false);
  }

  static List<_AngleKeypoint> _extractKeypoints(
    RawRgbaFrame baseFrame, {
    required List<double> scales,
    required int maxPerCell,
  }) {
    final all = <_AngleKeypoint>[];
    for (final scale in scales) {
      final w = (baseFrame.width * scale).round();
      final h = (baseFrame.height * scale).round();
      if (w < _borderMargin * 2 + 10 || h < _borderMargin * 2 + 10) continue;
      final levelFrame = scale == 1.0 ? baseFrame : baseFrame.resizeExact(w, h);
      all.addAll(
        _extractLevelKeypoints(levelFrame, scale: scale, maxPerCell: maxPerCell),
      );
    }
    return all;
  }

  static List<_AngleKeypoint> _extractLevelKeypoints(
    RawRgbaFrame frame, {
    required double scale,
    required int maxPerCell,
  }) {
    final w = frame.width;
    final h = frame.height;
    final rgba = frame.rgba;

    final rawGray = Uint8List(w * h);
    for (var i = 0, p = 0; i < w * h; i++, p += 4) {
      rawGray[i] =
          (rgba[p] * 77 + rgba[p + 1] * 150 + rgba[p + 2] * 29) >> 8;
    }

    final tmp = Uint16List(w * h);
    for (var y = 0; y < h; y++) {
      final row = y * w;
      tmp[row] = rawGray[row] << 2;
      for (var x = 1; x < w - 1; x++) {
        tmp[row + x] =
            rawGray[row + x - 1] + (rawGray[row + x] << 1) + rawGray[row + x + 1];
      }
      tmp[row + w - 1] = rawGray[row + w - 1] << 2;
    }

    final smooth = Uint8List(w * h);
    for (var x = 0; x < w; x++) {
      smooth[x] = tmp[x] >> 2;
      smooth[(h - 1) * w + x] = tmp[(h - 1) * w + x] >> 2;
    }
    for (var y = 1; y < h - 1; y++) {
      final row = y * w;
      for (var x = 0; x < w; x++) {
        smooth[row + x] =
            (tmp[row - w + x] + (tmp[row + x] << 1) + tmp[row + w + x]) >> 4;
      }
    }

    final gx = Int16List(w * h);
    final gy = Int16List(w * h);
    for (var y = 1; y < h - 1; y++) {
      final r0 = (y - 1) * w;
      final r1 = y * w;
      final r2 = (y + 1) * w;
      for (var x = 1; x < w - 1; x++) {
        final tl = smooth[r0 + x - 1];
        final tr = smooth[r0 + x + 1];
        final ml = smooth[r1 + x - 1];
        final mr = smooth[r1 + x + 1];
        final bl = smooth[r2 + x - 1];
        final br = smooth[r2 + x + 1];
        final tc = smooth[r0 + x];
        final bc = smooth[r2 + x];

        gx[r1 + x] = (tr + (mr << 1) + br) - (tl + (ml << 1) + bl);
        gy[r1 + x] = (bl + (bc << 1) + br) - (tl + (tc << 1) + tr);
      }
    }

    final scores = Float32List(w * h);
    for (var y = _borderMargin; y < h - _borderMargin; y++) {
      final row = y * w;
      for (var x = _borderMargin; x < w - _borderMargin; x++) {
        double sxx = 0, syy = 0, sxy = 0;
        for (var dy = -1; dy <= 1; dy++) {
          final rr = (y + dy) * w + x;
          for (var dx = -1; dx <= 1; dx++) {
            final vx = gx[rr + dx].toDouble();
            final vy = gy[rr + dx].toDouble();
            sxx += vx * vx;
            syy += vy * vy;
            sxy += vx * vy;
          }
        }
        final trace = sxx + syy;
        if (trace < 2600.0) continue;
        final det = sxx * syy - sxy * sxy;
        final resp = det - 0.045 * trace * trace;
        if (resp > 420000.0) {
          scores[row + x] = resp;
        }
      }
    }

    const gridCols = 6;
    const gridRows = 6;
    final buckets = List<List<(int, int, double)>>.generate(
      gridCols * gridRows,
      (_) => <(int, int, double)>[],
      growable: false,
    );

    for (var y = _borderMargin; y < h - _borderMargin; y++) {
      final row = y * w;
      for (var x = _borderMargin; x < w - _borderMargin; x++) {
        final s = scores[row + x];
        if (s <= 0) continue;
        var isMax = true;
        for (var dy = -2; dy <= 2 && isMax; dy++) {
          final nr = (y + dy) * w;
          for (var dx = -2; dx <= 2; dx++) {
            if (dx == 0 && dy == 0) continue;
            if (scores[nr + x + dx] > s) {
              isMax = false;
              break;
            }
          }
        }
        if (!isMax) continue;
        final gxCell = ((x * gridCols) ~/ w).clamp(0, gridCols - 1);
        final gyCell = ((y * gridRows) ~/ h).clamp(0, gridRows - 1);
        buckets[gyCell * gridCols + gxCell].add((x, y, s));
      }
    }

    final invScale = 1.0 / scale;
    final out = <_AngleKeypoint>[];

    for (final bucket in buckets) {
      if (bucket.isEmpty) continue;
      bucket.sort((a, b) => b.$3.compareTo(a.$3));
      final limit = math.min(maxPerCell, bucket.length);
      for (var i = 0; i < limit; i++) {
        final (cx, cy, _) = bucket[i];

        var sumGx = 0.0;
        var sumGy = 0.0;
        for (var dy = -4; dy <= 4; dy++) {
          final rr = (cy + dy) * w + cx;
          for (var dx = -4; dx <= 4; dx++) {
            if (dx * dx + dy * dy > 20) continue;
            sumGx += gx[rr + dx];
            sumGy += gy[rr + dx];
          }
        }
        var angle = math.atan2(sumGy, sumGx);
        if (angle < 0) angle += 2.0 * math.pi;
        final angleBin =
            ((angle / (2.0 * math.pi)) * _angleBins).round() % _angleBins;

        final offsets = _steeredPairs[angleBin];
        final desc = Uint8List(32);
        for (var byteIdx = 0; byteIdx < 32; byteIdx++) {
          var bits = 0;
          final baseBit = byteIdx * 8;
          for (var b = 0; b < 8; b++) {
            final pairOffset = (baseBit + b) * 4;
            final p1 = smooth[
                (cy + offsets[pairOffset + 1]) * w + cx + offsets[pairOffset]];
            final p2 = smooth[
                (cy + offsets[pairOffset + 3]) * w +
                    cx +
                    offsets[pairOffset + 2]];
            if (p1 < p2) {
              bits |= (1 << b);
            }
          }
          desc[byteIdx] = bits;
        }

        out.add(
          _AngleKeypoint(
            x: cx * invScale,
            y: cy * invScale,
            angleBin: angleBin,
            scale: invScale,
            descriptor: desc,
          ),
        );
      }
    }
    return out;
  }

  static int _hamming256(Uint8List a, Uint8List b, int limit) {
    var total = 0;
    for (var i = 0; i < 32; i += 4) {
      total += _popcount8[a[i] ^ b[i]] +
          _popcount8[a[i + 1] ^ b[i + 1]] +
          _popcount8[a[i + 2] ^ b[i + 2]] +
          _popcount8[a[i + 3] ^ b[i + 3]];
      if (total >= limit) return total;
    }
    return total;
  }

  static int _angleBinDistance(int a, int b) {
    final diff = (a - b).abs();
    return diff <= 16 ? diff : 32 - diff;
  }

  // ---------------------------------------------------------------------------
  // 2D RANSAC Geometrical Consistency Check
  // ---------------------------------------------------------------------------

  static ({
    int inliers,
    double scale,
    double rotationDegrees,
    double spatialSpan,
  }) _runRansac({
    required List<_AngleKeypoint> queryKeypoints,
    required int queryWidth,
    required int queryHeight,
    required _IndexedAngleTarget target,
  }) {
    final refKeypoints = target.keypoints;
    if (queryKeypoints.length < 5 || refKeypoints.length < 5) {
      return (inliers: 0, scale: 1.0, rotationDegrees: 0.0, spatialSpan: 0.0);
    }

    final rawMatches = <_AnglePutativeMatch>[];
    for (final q in queryKeypoints) {
      var bestDist = 88;
      var secondDist = 88;
      _AngleKeypoint? bestRef;

      for (final r in refKeypoints) {
        final d = _hamming256(q.descriptor, r.descriptor, secondDist);
        if (d < bestDist) {
          if (bestRef != null &&
              ((bestRef.x - r.x).abs() + (bestRef.y - r.y).abs()) > 7.0) {
            secondDist = bestDist;
          }
          bestDist = d;
          bestRef = r;
        } else if (d < secondDist &&
            bestRef != null &&
            ((bestRef.x - r.x).abs() + (bestRef.y - r.y).abs()) > 7.0) {
          secondDist = d;
        }
      }

      if (bestRef != null &&
          bestDist <= 72 &&
          bestDist * 100 <= secondDist * 86) {
        rawMatches.add(
          _AnglePutativeMatch(query: q, ref: bestRef, distance: bestDist),
        );
      }
    }

    if (rawMatches.length < 5) {
      return (inliers: 0, scale: 1.0, rotationDegrees: 0.0, spatialSpan: 0.0);
    }

    rawMatches.sort((a, b) => a.distance.compareTo(b.distance));
    final dedup = <_AnglePutativeMatch>[];
    for (final m in rawMatches) {
      final duplicate = dedup.any(
        (e) =>
            (e.ref.x - m.ref.x).abs() < 4.0 && (e.ref.y - m.ref.y).abs() < 4.0,
      );
      if (!duplicate) {
        dedup.add(m);
        if (dedup.length >= 90) break;
      }
    }

    if (dedup.length < 5) {
      return (inliers: 0, scale: 1.0, rotationDegrees: 0.0, spatialSpan: 0.0);
    }

    final n = dedup.length;
    final reprojTol = math.max(9.0, 0.052 * math.max(queryWidth, queryHeight));
    final reprojTol2 = reprojTol * reprojTol;
    const maxRotRad = 0.68; // ~39 deg

    var bestInliers = 0;
    var bestScale = 1.0;
    var bestRotDeg = 0.0;
    var bestSpan = 0.0;

    final sampleCount = math.min(n, 42);
    var iterations = 0;

    for (var i = 0; i < sampleCount && iterations < 140; i++) {
      final m1 = dedup[i];
      for (var j = i + 1; j < sampleCount && iterations < 140; j += 2) {
        final m2 = dedup[j];
        final rdx = m2.ref.x - m1.ref.x;
        final rdy = m2.ref.y - m1.ref.y;
        final rDist2 = rdx * rdx + rdy * rdy;
        if (rDist2 < 144.0) continue;

        final qdx = m2.query.x - m1.query.x;
        final qdy = m2.query.y - m1.query.y;
        final qDist2 = qdx * qdx + qdy * qdy;
        if (qDist2 < 100.0) continue;

        iterations++;

        final a = (rdx * qdx + rdy * qdy) / rDist2;
        final b = (rdx * qdy - rdy * qdx) / rDist2;
        final scale = math.sqrt(a * a + b * b);
        if (scale < 0.25 || scale > 3.6) continue;

        final rotAngle = math.atan2(b, a);
        if (rotAngle.abs() > maxRotRad) continue;

        final rotBins =
            ((rotAngle / (2.0 * math.pi)) * _angleBins).round() % _angleBins;
        final tx = m1.query.x - (a * m1.ref.x - b * m1.ref.y);
        final ty = m1.query.y - (b * m1.ref.x + a * m1.ref.y);

        var count = 0;
        var minRx = double.infinity, maxRx = -double.infinity;
        var minRy = double.infinity, maxRy = -double.infinity;

        for (var k = 0; k < n; k++) {
          final mk = dedup[k];
          final px = a * mk.ref.x - b * mk.ref.y + tx;
          final py = b * mk.ref.x + a * mk.ref.y + ty;
          final ex = px - mk.query.x;
          final ey = py - mk.query.y;
          if (ex * ex + ey * ey > reprojTol2) continue;

          final expectedBin =
              (mk.ref.angleBin + rotBins + _angleBins) % _angleBins;
          if (_angleBinDistance(expectedBin, mk.query.angleBin) > 5) continue;

          count++;
          if (mk.ref.x < minRx) minRx = mk.ref.x;
          if (mk.ref.x > maxRx) maxRx = mk.ref.x;
          if (mk.ref.y < minRy) minRy = mk.ref.y;
          if (mk.ref.y > maxRy) maxRy = mk.ref.y;
        }

        if (count > bestInliers && count >= 5) {
          final spanX = (maxRx - minRx) / target.width;
          final spanY = (maxRy - minRy) / target.height;
          final span = math.max(spanX, spanY);
          if (span >= 0.12) {
            bestInliers = count;
            bestScale = scale;
            bestRotDeg = (rotAngle * 180.0 / math.pi);
            bestSpan = span;
          }
        }
      }
    }

    return (
      inliers: bestInliers,
      scale: bestScale,
      rotationDegrees: bestRotDeg,
      spatialSpan: bestSpan,
    );
  }

  // ---------------------------------------------------------------------------
  // Structural Edge HOG + White-Balance Normalized Chroma
  // ---------------------------------------------------------------------------

  static const int _hogGrid = 10;
  static const int _hogBins = 8;

  static (Float32List, Float32List) _computeHogAndAppearance(RawRgbaFrame src) {
    const targetW = 120;
    const targetH = 120;
    final frame = src.resizeExact(targetW, targetH);
    final w = frame.width;
    final h = frame.height;
    final rgba = frame.rgba;

    final gray = Uint8List(w * h);
    final oppRg = Float32List(w * h);
    final oppBy = Float32List(w * h);

    for (var i = 0, p = 0; i < w * h; i++, p += 4) {
      final r = rgba[p];
      final g = rgba[p + 1];
      final b = rgba[p + 2];
      final l = (r * 77 + g * 150 + b * 29) >> 8;
      gray[i] = l;
      final denom = math.max(16.0, (r + g + b).toDouble());
      oppRg[i] = (r - g) / denom;
      oppBy[i] = (2 * b - r - g) / (2.0 * denom);
    }

    final edgeHog = Float32List(_hogGrid * _hogGrid * _hogBins);
    final appearance = Float32List(_hogGrid * _hogGrid * 3);

    final cellW = w / _hogGrid;
    final cellH = h / _hogGrid;
    final invArea = 1.0 / (cellW * cellH);

    for (var gy = 0; gy < _hogGrid; gy++) {
      final y0 = (gy * cellH).floor().clamp(1, h - 2);
      final y1 = ((gy + 1) * cellH).floor().clamp(y0 + 1, h - 1);

      for (var gx = 0; gx < _hogGrid; gx++) {
        final x0 = (gx * cellW).floor().clamp(1, w - 2);
        final x1 = ((gx + 1) * cellW).floor().clamp(x0 + 1, w - 1);

        final hogBase = (gy * _hogGrid + gx) * _hogBins;
        final appBase = (gy * _hogGrid + gx) * 3;

        var sumL = 0.0;
        var sumRg = 0.0;
        var sumBy = 0.0;

        for (var y = y0; y < y1; y++) {
          final row = y * w;
          for (var x = x0; x < x1; x++) {
            final p = row + x;
            sumL += gray[p] / 255.0;
            sumRg += oppRg[p];
            sumBy += oppBy[p];

            final dx = gray[p + 1] - gray[p - 1];
            final dy = gray[p + w] - gray[p - w];
            final mag = math.sqrt(dx * dx + dy * dy);
            if (mag > 12) {
              var theta = math.atan2(dy.toDouble(), dx.toDouble());
              if (theta < 0) theta += math.pi;
              final bin = ((theta / math.pi) * _hogBins).floor() % _hogBins;
              edgeHog[hogBase + bin] += mag;
            }
          }
        }

        appearance[appBase] = sumL * invArea;
        appearance[appBase + 1] = sumRg * invArea * 3.0;
        appearance[appBase + 2] = sumBy * invArea * 3.0;
      }
    }

    _normalizeL2(edgeHog);
    _normalizeL2(appearance);

    return (edgeHog, appearance);
  }

  static void _normalizeL2(Float32List vec) {
    var norm2 = 0.0;
    for (var i = 0; i < vec.length; i++) {
      norm2 += vec[i] * vec[i];
    }
    final norm = math.sqrt(norm2);
    if (norm > 1e-6) {
      for (var i = 0; i < vec.length; i++) {
        vec[i] /= norm;
      }
    }
  }

  static double _computeCosineSim(Float32List a, Float32List b) {
    var dot = 0.0;
    final len = math.min(a.length, b.length);
    for (var i = 0; i < len; i++) {
      dot += a[i] * b[i];
    }
    return dot.clamp(0.0, 1.0);
  }
}

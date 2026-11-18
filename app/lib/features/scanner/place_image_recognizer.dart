import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';

/// Decoded 8-bit RGBA image buffer shared across Web, Android, iOS, and tests.
class RawRgbaFrame {
  const RawRgbaFrame({
    required this.width,
    required this.height,
    required this.rgba,
  });

  final int width;
  final int height;
  final Uint8List rgba;

  /// Crops a normalized rectangle `[x0, y0, x1, y1]` in `[0.0, 1.0]`.
  RawRgbaFrame cropNormalized(double x0, double y0, double x1, double y1) {
    final sx0 = (x0.clamp(0.0, 1.0) * width).floor().clamp(0, width - 1);
    final sy0 = (y0.clamp(0.0, 1.0) * height).floor().clamp(0, height - 1);
    final sx1 = (x1.clamp(0.0, 1.0) * width).ceil().clamp(sx0 + 1, width);
    final sy1 = (y1.clamp(0.0, 1.0) * height).ceil().clamp(sy0 + 1, height);
    final cw = sx1 - sx0;
    final ch = sy1 - sy0;
    final out = Uint8List(cw * ch * 4);
    for (var y = 0; y < ch; y++) {
      final srcRow = ((sy0 + y) * width + sx0) * 4;
      final dstRow = y * cw * 4;
      out.setRange(dstRow, dstRow + cw * 4, rgba, srcRow);
    }
    return RawRgbaFrame(width: cw, height: ch, rgba: out);
  }

  /// Downscales (or returns `this`) so `max(width, height) <= maxDimension`.
  RawRgbaFrame resizeMax(int maxDimension) {
    final longest = math.max(width, height);
    if (longest <= maxDimension || maxDimension <= 0) return this;
    final scale = maxDimension / longest;
    final tw = math.max(1, (width * scale).round());
    final th = math.max(1, (height * scale).round());
    return resizeExact(tw, th);
  }

  /// Bilinear resize to `(targetWidth, targetHeight)`.
  RawRgbaFrame resizeExact(int targetWidth, int targetHeight) {
    if (targetWidth == width && targetHeight == height) return this;
    final out = Uint8List(targetWidth * targetHeight * 4);
    final xRatio = width / targetWidth;
    final yRatio = height / targetHeight;

    for (var ty = 0; ty < targetHeight; ty++) {
      final fy = (ty + 0.5) * yRatio - 0.5;
      final y0 = fy.floor().clamp(0, height - 1);
      final y1 = (y0 + 1).clamp(0, height - 1);
      final wy = (fy - y0).clamp(0.0, 1.0);
      final wy0 = 1.0 - wy;

      for (var tx = 0; tx < targetWidth; tx++) {
        final fx = (tx + 0.5) * xRatio - 0.5;
        final x0 = fx.floor().clamp(0, width - 1);
        final x1 = (x0 + 1).clamp(0, width - 1);
        final wx = (fx - x0).clamp(0.0, 1.0);
        final wx0 = 1.0 - wx;

        final i00 = (y0 * width + x0) * 4;
        final i10 = (y0 * width + x1) * 4;
        final i01 = (y1 * width + x0) * 4;
        final i11 = (y1 * width + x1) * 4;
        final dst = (ty * targetWidth + tx) * 4;

        for (var c = 0; c < 3; c++) {
          final top = rgba[i00 + c] * wx0 + rgba[i10 + c] * wx;
          final bot = rgba[i01 + c] * wx0 + rgba[i11 + c] * wx;
          out[dst + c] = (top * wy0 + bot * wy).round().clamp(0, 255);
        }
        out[dst + 3] = 255;
      }
    }
    return RawRgbaFrame(width: targetWidth, height: targetHeight, rgba: out);
  }

  static Future<RawRgbaFrame?> decodeEncoded(
    Uint8List encodedBytes, {
    int maxDimension = 480,
  }) async {
    if (encodedBytes.isEmpty) return null;
    ui.Codec? codec;
    ui.Image? image;
    try {
      codec = await ui.instantiateImageCodec(encodedBytes);
      final frame = await codec.getNextFrame();
      image = frame.image;
      final byteData = await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      if (byteData == null) return null;
      final raw = RawRgbaFrame(
        width: image.width,
        height: image.height,
        rgba: byteData.buffer.asUint8List(
          byteData.offsetInBytes,
          byteData.lengthInBytes,
        ),
      );
      return raw.resizeMax(maxDimension);
    } catch (_) {
      return null;
    } finally {
      image?.dispose();
      codec?.dispose();
    }
  }
}

class PlaceTargetSpec {
  const PlaceTargetSpec({
    required this.id,
    required this.stationId,
    required this.label,
    required this.asset,
    this.externalUrl,
    this.isCompactEmblem = false,
    this.ignoreRects = const <List<double>>[],
  });

  final String id;
  final String stationId;
  final String label;
  final String asset;
  final String? externalUrl;
  final bool isCompactEmblem;
  final List<List<double>> ignoreRects;

  factory PlaceTargetSpec.fromJson(Map<String, dynamic> json) {
    final rawIgnore = json['ignoreRects'] as List<dynamic>? ?? const [];
    return PlaceTargetSpec(
      id: json['id'] as String,
      stationId: json['stationId'] as String,
      label: json['label'] as String,
      asset: json['asset'] as String,
      externalUrl: json['externalUrl'] as String?,
      isCompactEmblem: json['isCompactEmblem'] == true,
      ignoreRects: rawIgnore
          .map(
            (r) => (r as List<dynamic>)
                .map((v) => (v as num).toDouble())
                .toList(growable: false),
          )
          .toList(growable: false),
    );
  }
}

class PlaceVisualMatch {
  const PlaceVisualMatch({
    required this.targetId,
    required this.stationId,
    required this.label,
    required this.confidence,
    required this.inliers,
    required this.structuralSimilarity,
    this.externalUrl,
  });

  final String targetId;
  final String stationId;
  final String label;
  final double confidence;
  final int inliers;
  final double structuralSimilarity;
  final String? externalUrl;

  bool get isHighConfidence => confidence >= 0.72 || inliers >= 16;
}

class _Keypoint {
  const _Keypoint({
    required this.x,
    required this.y,
    required this.angleBin,
    required this.scale,
    required this.descriptor,
  });

  final double x;
  final double y;
  final int angleBin; // 0..31
  final double scale;
  final Uint8List descriptor; // 32 bytes = 256-bit steered BRIEF (JS-safe)
}

class _PutativeMatch {
  const _PutativeMatch({
    required this.query,
    required this.ref,
    required this.distance,
  });

  final _Keypoint query;
  final _Keypoint ref;
  final int distance;
}

class _StructuralDescriptor {
  const _StructuralDescriptor({
    required this.aspect,
    required this.edgeHog,
    required this.appearance,
    required this.edgeEnergy,
  });

  final double aspect;
  final Float32List edgeHog;
  final Float32List appearance;
  final double edgeEnergy;
}

class _IndexedPlaceTarget {
  const _IndexedPlaceTarget({
    required this.spec,
    required this.width,
    required this.height,
    required this.keypoints,
    required this.structural,
  });

  final PlaceTargetSpec spec;
  final int width;
  final int height;
  final List<_Keypoint> keypoints;
  final _StructuralDescriptor structural;
}

/// Pure-Dart cross-platform visual place & sign recognizer (Web + Android + iOS).
///
/// Combines:
/// 1. Multi-scale spatially bucketed Harris corners + 256-bit rotation-steered
///    binary descriptors + 2D upright similarity RANSAC geometric verification
///    (including an automatic 2x center-viewfinder zoom pass for distant targets).
/// 2. Multi-window 12x12 Oriented Edge HOG + white-balance-invariant Opponent
///    Color verification for compact geometric emblems (e.g. single `'A'` sign,
///    Subway neon logo, guild stickers, and arched mailbox).
class PlaceImageRecognizer {
  PlaceImageRecognizer._(this._targets);

  final List<_IndexedPlaceTarget> _targets;

  static Future<PlaceImageRecognizer>? _sharedLoader;

  static Future<PlaceImageRecognizer> loadDefault() {
    return _sharedLoader ??= _loadFromAssetManifest('assets/place_targets.json');
  }

  static Future<PlaceImageRecognizer> _loadFromAssetManifest(
    String manifestAsset,
  ) async {
    final rawJson = jsonDecode(await rootBundle.loadString(manifestAsset))
        as Map<String, dynamic>;
    final specs = (rawJson['targets'] as List<dynamic>)
        .map((e) => PlaceTargetSpec.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);

    final indexed = <_IndexedPlaceTarget>[];
    for (final spec in specs) {
      final data = await rootBundle.load(spec.asset);
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      final decoded = await RawRgbaFrame.decodeEncoded(bytes, maxDimension: 320);
      if (decoded != null) {
        indexed.add(_indexTarget(spec, decoded));
      }
    }
    return PlaceImageRecognizer._(indexed);
  }

  /// Builds an instance directly from in-memory frames (convenient in unit tests).
  static PlaceImageRecognizer fromFrames(
    List<(PlaceTargetSpec, RawRgbaFrame)> entries,
  ) {
    return PlaceImageRecognizer._(
      entries
          .map((entry) => _indexTarget(entry.$1, entry.$2.resizeMax(320)))
          .toList(growable: false),
    );
  }

  int get targetCount => _targets.length;

  Future<PlaceVisualMatch?> recognizeEncodedBytes(Uint8List encodedBytes) async {
    final frame = await RawRgbaFrame.decodeEncoded(
      encodedBytes,
      maxDimension: 480,
    );
    if (frame == null) return null;
    return recognizeRgba(frame);
  }

  PlaceVisualMatch? recognizeRgba(RawRgbaFrame inputFrame) {
    if (_targets.isEmpty || inputFrame.width < 32 || inputFrame.height < 32) {
      return null;
    }

    // Pass A: Full camera frame (fast match for close & medium distance signs).
    final passAMatch = _evaluateSingleView(inputFrame.resizeMax(300));
    if (passAMatch != null && passAMatch.isHighConfidence) {
      return passAMatch;
    }

    // Pass B: Automatic 2x optical zoom into the central viewfinder region when
    // the user stands further back (e.g. across the atrium from the Greenhouse).
    if (math.max(inputFrame.width, inputFrame.height) >= 220) {
      final zoomedCenter = inputFrame
          .cropNormalized(0.22, 0.20, 0.78, 0.78)
          .resizeMax(280);
      final passBMatch = _evaluateSingleView(zoomedCenter);
      if (passBMatch != null) {
        if (passAMatch == null ||
            passBMatch.confidence > passAMatch.confidence) {
          return passBMatch;
        }
      }
    }

    return passAMatch;
  }

  PlaceVisualMatch? _evaluateSingleView(RawRgbaFrame queryFrame) {
    final queryKeypoints = _extractPyramidKeypoints(
      queryFrame,
      scales: const <double>[1.0, 0.68],
      maxPerCell: 9,
      ignoreRects: const <List<double>>[],
    );

    final queryWindows = _buildQueryHogWindows(queryFrame);
    final subwayDipole = _detectSubwayNeonDipole(queryFrame);
    final bestPerStation = <String, PlaceVisualMatch>{};

    for (final target in _targets) {
      final ransacInliers = _matchRansacInliers(
        queryKeypoints: queryKeypoints,
        queryWidth: queryFrame.width,
        queryHeight: queryFrame.height,
        target: target,
      );

      final (edgeSim, combinedSim) = _bestWindowSimilarity(
        target: target,
        queryWindows: queryWindows,
      );

      var confidence = _computeCombinedConfidence(
        target: target,
        inliers: ransacInliers,
        edgeSim: edgeSim,
        combinedSim: combinedSim,
      );
      if (target.spec.id == 'subway_logo' && subwayDipole >= 0.72) {
        confidence = math.max(confidence, subwayDipole);
      }
      if (confidence < 0.55) continue;

      final candidate = PlaceVisualMatch(
        targetId: target.spec.id,
        stationId: target.spec.stationId,
        label: target.spec.label,
        confidence: confidence,
        inliers: ransacInliers,
        structuralSimilarity: combinedSim,
        externalUrl: target.spec.externalUrl,
      );

      final prev = bestPerStation[target.spec.stationId];
      if (prev == null || candidate.confidence > prev.confidence) {
        bestPerStation[target.spec.stationId] = candidate;
      }
    }

    if (bestPerStation.isEmpty) return null;

    final ranked = bestPerStation.values.toList()
      ..sort((a, b) => b.confidence.compareTo(a.confidence));

    final winner = ranked.first;
    if (ranked.length > 1) {
      final runnerUp = ranked[1];
      final margin = winner.confidence - runnerUp.confidence;
      if (winner.inliers < 15 && margin < 0.06) {
        return null;
      }
      if (winner.inliers >= 15 &&
          runnerUp.inliers >= 15 &&
          winner.inliers < (runnerUp.inliers * 1.20).round() &&
          margin < 0.045) {
        return null;
      }
    }

    return winner;
  }

  static _IndexedPlaceTarget _indexTarget(
    PlaceTargetSpec spec,
    RawRgbaFrame frame,
  ) {
    final keypoints = _extractPyramidKeypoints(
      frame,
      scales: const <double>[1.0, 0.68, 0.46],
      maxPerCell: 10,
      ignoreRects: spec.ignoreRects,
    );
    final structural = _computeStructuralDescriptor(frame);
    return _IndexedPlaceTarget(
      spec: spec,
      width: frame.width,
      height: frame.height,
      keypoints: keypoints,
      structural: structural,
    );
  }

  static double _computeCombinedConfidence({
    required _IndexedPlaceTarget target,
    required int inliers,
    required double edgeSim,
    required double combinedSim,
  }) {
    // 1. Geometric RANSAC score (8+ spatially distributed similarity inliers)
    var ransacScore = 0.0;
    if (inliers >= 8) {
      ransacScore = (0.55 + (inliers - 8) * 0.034).clamp(0.0, 0.98);
      if (combinedSim >= 0.50) {
        ransacScore = (ransacScore + (combinedSim - 0.50) * 0.22).clamp(
          0.0,
          0.99,
        );
      }
    } else if (inliers >= 5 && edgeSim >= 0.60 && combinedSim >= 0.63) {
      ransacScore = (0.54 + (inliers - 5) * 0.05 + (combinedSim - 0.60) * 0.55)
          .clamp(0.0, 0.93);
    }

    // 2. Structural Edge + Appearance emblem score (requires genuine geometric
    // edge alignment >= 0.755 so uniform lighting/color never false-triggers).
    var emblemScore = 0.0;
    final minEdge = target.spec.isCompactEmblem ? 0.750 : 0.795;
    final minCombined = target.spec.isCompactEmblem ? 0.770 : 0.810;
    if (edgeSim >= minEdge && combinedSim >= minCombined) {
      emblemScore = (0.58 + (combinedSim - minCombined) * 2.1).clamp(0.0, 0.95);
      if (inliers >= 3) {
        emblemScore = (emblemScore + inliers * 0.02).clamp(0.0, 0.98);
      }
    }

    return math.max(ransacScore, emblemScore);
  }

  // ---------------------------------------------------------------------------
  // Stage 1: Multi-Scale Salient Keypoints + 256-bit Steered BRIEF + RANSAC
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
    // JS-safe Park-Miller MINSTD PRNG (max intermediate product = 1.03e14 < 2^53).
    final basePairs = Int8List(256 * 4);
    var seed = 135792468;
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

  static List<_Keypoint> _extractPyramidKeypoints(
    RawRgbaFrame baseFrame, {
    required List<double> scales,
    required int maxPerCell,
    required List<List<double>> ignoreRects,
  }) {
    final all = <_Keypoint>[];
    for (final scale in scales) {
      final w = (baseFrame.width * scale).round();
      final h = (baseFrame.height * scale).round();
      if (w < _borderMargin * 2 + 10 || h < _borderMargin * 2 + 10) continue;
      final levelFrame = scale == 1.0 ? baseFrame : baseFrame.resizeExact(w, h);
      all.addAll(
        _extractLevelKeypoints(
          levelFrame,
          scale: scale,
          maxPerCell: maxPerCell,
          ignoreRects: ignoreRects,
        ),
      );
    }
    return all;
  }

  static List<_Keypoint> _extractLevelKeypoints(
    RawRgbaFrame frame, {
    required double scale,
    required int maxPerCell,
    required List<List<double>> ignoreRects,
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
        final tc = smooth[r0 + x];
        final tr = smooth[r0 + x + 1];
        final ml = smooth[r1 + x - 1];
        final mr = smooth[r1 + x + 1];
        final bl = smooth[r2 + x - 1];
        final bc = smooth[r2 + x];
        final br = smooth[r2 + x + 1];

        gx[r1 + x] = (tr + (mr << 1) + br) - (tl + (ml << 1) + bl);
        gy[r1 + x] = (bl + (bc << 1) + br) - (tl + (tc << 1) + tr);
      }
    }

    final scores = Float32List(w * h);
    for (var y = _borderMargin; y < h - _borderMargin; y++) {
      final ny = y / h;
      final row = y * w;
      for (var x = _borderMargin; x < w - _borderMargin; x++) {
        if (ignoreRects.isNotEmpty) {
          final nx = x / w;
          var masked = false;
          for (final r in ignoreRects) {
            if (nx >= r[0] && nx <= r[2] && ny >= r[1] && ny <= r[3]) {
              masked = true;
              break;
            }
          }
          if (masked) continue;
        }

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
        if (trace < 2800.0) continue;
        final det = sxx * syy - sxy * sxy;
        final resp = det - 0.045 * trace * trace;
        if (resp > 500000.0) {
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
    final out = <_Keypoint>[];

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
          _Keypoint(
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

  /// Early-exiting 256-bit Hamming distance (aborts once `total >= limit`).
  static int _hamming256Bounded(Uint8List a, Uint8List b, int limit) {
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

  static int _matchRansacInliers({
    required List<_Keypoint> queryKeypoints,
    required int queryWidth,
    required int queryHeight,
    required _IndexedPlaceTarget target,
  }) {
    final refKeypoints = target.keypoints;
    if (queryKeypoints.length < 6 || refKeypoints.length < 6) return 0;

    final rawMatches = <_PutativeMatch>[];
    for (final q in queryKeypoints) {
      var bestDist = 88;
      var secondDist = 88;
      _Keypoint? bestRef;

      for (final r in refKeypoints) {
        final d = _hamming256Bounded(q.descriptor, r.descriptor, secondDist);
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
          bestDist <= 70 &&
          bestDist * 100 <= secondDist * 84) {
        rawMatches.add(
          _PutativeMatch(query: q, ref: bestRef, distance: bestDist),
        );
      }
    }

    if (rawMatches.length < 5) return 0;

    rawMatches.sort((a, b) => a.distance.compareTo(b.distance));
    final dedup = <_PutativeMatch>[];
    for (final m in rawMatches) {
      final duplicateRef = dedup.any(
        (existing) =>
            (existing.ref.x - m.ref.x).abs() < 4.0 &&
            (existing.ref.y - m.ref.y).abs() < 4.0,
      );
      if (!duplicateRef) {
        dedup.add(m);
        if (dedup.length >= 84) break;
      }
    }

    if (dedup.length < 5) return 0;

    final n = dedup.length;
    final reprojTol = math.max(9.0, 0.05 * math.max(queryWidth, queryHeight));
    final reprojTol2 = reprojTol * reprojTol;
    const maxRotationRad = 0.68; // ~39 deg upright camera constraint

    var bestInliers = 0;
    final sampleCount = math.min(n, 38);
    var iterations = 0;

    for (var i = 0; i < sampleCount && iterations < 120; i++) {
      final m1 = dedup[i];
      for (var j = i + 1; j < sampleCount && iterations < 120; j += 2) {
        final m2 = dedup[j];
        final rdx = m2.ref.x - m1.ref.x;
        final rdy = m2.ref.y - m1.ref.y;
        final rDist2 = rdx * rdx + rdy * rdy;
        if (rDist2 < 169.0) continue;

        final qdx = m2.query.x - m1.query.x;
        final qdy = m2.query.y - m1.query.y;
        final qDist2 = qdx * qdx + qdy * qdy;
        if (qDist2 < 100.0) continue;

        iterations++;

        final a = (rdx * qdx + rdy * qdy) / rDist2;
        final b = (rdx * qdy - rdy * qdx) / rDist2;
        final scale = math.sqrt(a * a + b * b);
        if (scale < 0.14 || scale > 4.2) continue;

        final rotAngle = math.atan2(b, a);
        if (rotAngle.abs() > maxRotationRad) continue;

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
          if (math.max(spanX, spanY) >= 0.14 &&
              math.min(spanX, spanY) >= 0.05) {
            bestInliers = count;
          }
        }
      }
    }

    return bestInliers;
  }

  // ---------------------------------------------------------------------------
  // Stage 2: Multi-Window 12x12 Oriented Edge HOG + White-Balance-Safe Chroma
  // ---------------------------------------------------------------------------

  static const int _hogGrid = 12;
  static const int _hogSampleSize = 48;

  static _StructuralDescriptor _computeStructuralDescriptor(RawRgbaFrame src) {
    final resized = src.resizeExact(_hogSampleSize, _hogSampleSize);
    final rgba = resized.rgba;
    const n = _hogSampleSize;

    final lum = Float32List(n * n);
    final rg = Float32List(n * n);
    final by = Float32List(n * n);

    var meanL = 0.0, meanRg = 0.0, meanBy = 0.0;
    for (var i = 0, p = 0; i < n * n; i++, p += 4) {
      final r = rgba[p].toDouble();
      final g = rgba[p + 1].toDouble();
      final b = rgba[p + 2].toDouble();
      final l = 0.299 * r + 0.587 * g + 0.114 * b;
      final crg = (r - g) / 255.0;
      final cby = (0.5 * (r + g) - b) / 255.0;
      lum[i] = l;
      rg[i] = crg;
      by[i] = cby;
      meanL += l;
      meanRg += crg;
      meanBy += cby;
    }
    const totalPixels = n * n;
    meanL /= totalPixels;
    meanRg /= totalPixels;
    meanBy /= totalPixels;

    var stdL = 0.0;
    for (var i = 0; i < totalPixels; i++) {
      final d = lum[i] - meanL;
      stdL += d * d;
    }
    stdL = math.sqrt(stdL / totalPixels).clamp(12.0, 255.0);

    final edgeHog = Float32List(_hogGrid * _hogGrid * 4);
    final appearance = Float32List(_hogGrid * _hogGrid * 3);
    const cellPx = _hogSampleSize ~/ _hogGrid; // 4
    const invArea = 1.0 / (cellPx * cellPx);

    var totalEdgeMag = 0.0;

    for (var cy = 0; cy < _hogGrid; cy++) {
      for (var cx = 0; cx < _hogGrid; cx++) {
        final cellIndex = cy * _hogGrid + cx;
        final edgeBase = cellIndex * 4;
        final appBase = cellIndex * 3;
        var sumL = 0.0, sumRg = 0.0, sumBy = 0.0;

        for (var py = 0; py < cellPx; py++) {
          final y = cy * cellPx + py;
          for (var px = 0; px < cellPx; px++) {
            final x = cx * cellPx + px;
            final idx = y * n + x;
            sumL += (lum[idx] - meanL) / stdL;
            sumRg += rg[idx] - meanRg;
            sumBy += by[idx] - meanBy;

            if (x > 0 && x < n - 1 && y > 0 && y < n - 1) {
              final dx = lum[idx + 1] - lum[idx - 1];
              final dy = lum[idx + n] - lum[idx - n];
              final mag = math.sqrt(dx * dx + dy * dy) / stdL;
              totalEdgeMag += mag;
              var ang = math.atan2(dy.abs(), dx.abs());
              if (dx * dy < 0) ang = math.pi - ang;
              final bin = ((ang / math.pi) * 4).floor().clamp(0, 3);
              edgeHog[edgeBase + bin] += mag;
            }
          }
        }

        appearance[appBase] = sumL * invArea;
        appearance[appBase + 1] = sumRg * invArea * 3.0;
        appearance[appBase + 2] = sumBy * invArea * 3.0;
      }
    }

    _normalizeL2InPlace(edgeHog);
    _normalizeL2InPlace(appearance);

    return _StructuralDescriptor(
      aspect: src.width / src.height,
      edgeHog: edgeHog,
      appearance: appearance,
      edgeEnergy: totalEdgeMag / totalPixels,
    );
  }

  static void _normalizeL2InPlace(Float32List vec) {
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

  static List<_StructuralDescriptor> _buildQueryHogWindows(RawRgbaFrame frame) {
    final windows = <_StructuralDescriptor>[];

    void addCrop(double x0, double y0, double x1, double y1) {
      final crop = frame.cropNormalized(x0, y0, x1, y1);
      if (crop.width < 20 || crop.height < 20) return;
      final desc = _computeStructuralDescriptor(crop);
      if (desc.edgeEnergy < 0.09) return;
      windows.add(desc);
    }

    // 10 strategic crops covering full frame, central viewfinder, horizontal
    // sign band, and key quadrants/corners:
    addCrop(0.0, 0.0, 1.0, 1.0);
    addCrop(0.06, 0.05, 0.94, 0.92);
    addCrop(0.16, 0.18, 0.84, 0.82);
    addCrop(0.32, 0.28, 0.75, 0.69); // Mid-distance atrium center
    addCrop(0.04, 0.26, 0.96, 0.60); // Wide horizontal sign band (Subway)
    addCrop(0.30, 0.25, 0.86, 0.55); // Off-center wide sign band
    addCrop(0.0, 0.22, 0.56, 0.76);
    addCrop(0.44, 0.22, 1.0, 0.76);
    addCrop(0.22, 0.24, 0.78, 0.76);
    addCrop(0.70, 0.02, 0.99, 0.30); // Top-right plaque zone ('A' sign)
    addCrop(0.18, 0.28, 0.56, 0.58); // Left-door badge zone ('SCI' circle)

    return windows;
  }

  /// Detects the distinctive horizontal `[Yellow "SUB" | Emerald "WAY"]` backlit
  /// 3D sign geometry from arbitrary cafeteria viewing angles.
  static double _detectSubwayNeonDipole(RawRgbaFrame frame) {
    final w = frame.width;
    final h = frame.height;
    final rgba = frame.rgba;

    var yellowCount = 0;
    var greenCount = 0;
    var yellowSumX = 0.0, yellowSumY = 0.0;
    var greenSumX = 0.0, greenSumY = 0.0;

    for (var y = 0; y < h; y++) {
      final row = y * w;
      for (var x = 0; x < w; x++) {
        final p = (row + x) * 4;
        final r = rgba[p];
        final g = rgba[p + 1];
        final b = rgba[p + 2];

        // Backlit yellow 'SUB': high R & G, much lower B
        if (r >= 185 && g >= 170 && b <= 95 && (r - g).abs() <= 55) {
          yellowCount++;
          yellowSumX += x;
          yellowSumY += y;
        }
        // Backlit emerald 'WAY': vivid green channel dominating R
        else if (g >= 175 && (g - r) >= 65 && b <= 165 && g >= b + 20) {
          greenCount++;
          greenSumX += x;
          greenSumY += y;
        }
      }
    }

    final totalPx = w * h;
    final yellowFrac = yellowCount / totalPx;
    final greenFrac = greenCount / totalPx;
    if (yellowCount < 18 ||
        greenCount < 18 ||
        yellowFrac < 0.004 ||
        greenFrac < 0.004) {
      return 0.0;
    }

    // Balanced proportions between 'SUB' and 'WAY'
    final balance = math.min(yellowCount, greenCount) /
        math.max(yellowCount, greenCount);
    if (balance < 0.25) return 0.0;

    final yCx = yellowSumX / yellowCount;
    final yCy = yellowSumY / yellowCount;
    final gCx = greenSumX / greenCount;
    final gCy = greenSumY / greenCount;

    final dx = (gCx - yCx) / w;
    final dy = (gCy - yCy).abs() / h;

    // 'WAY' (green) must sit immediately to the right of 'SUB' (yellow) on
    // roughly the same horizontal baseline.
    if (dx < 0.05 || dx > 0.58 || dy > 0.16) return 0.0;

    return (0.74 + balance * 0.16).clamp(0.0, 0.90);
  }

  static (double, double) _bestWindowSimilarity({
    required _IndexedPlaceTarget target,
    required List<_StructuralDescriptor> queryWindows,
  }) {
    final ref = target.structural;
    if (ref.edgeEnergy < 0.08) return (0.0, 0.0);

    var bestEdge = 0.0;
    var bestCombined = 0.0;

    for (final win in queryWindows) {
      final aspectRatio = win.aspect > ref.aspect
          ? win.aspect / ref.aspect
          : ref.aspect / win.aspect;
      if (aspectRatio > 2.85) continue;

      var edgeDot = 0.0;
      for (var i = 0; i < ref.edgeHog.length; i++) {
        edgeDot += ref.edgeHog[i] * win.edgeHog[i];
      }

      var appDot = 0.0;
      for (var i = 0; i < ref.appearance.length; i++) {
        appDot += ref.appearance[i] * win.appearance[i];
      }

      final combined = 0.72 * edgeDot + 0.28 * appDot;
      if (combined > bestCombined) {
        bestCombined = combined;
        bestEdge = edgeDot;
      }
    }
    return (bestEdge, bestCombined);
  }
}

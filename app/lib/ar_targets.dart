import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:vector_math/vector_math_64.dart';

class ArTarget {
  final String id, image, panel;
  final double width;
  final bool measured;
  ArTarget.fromJson(Map<String, dynamic> json)
    : id = json['id'] as String,
      image = json['image'] as String,
      panel = json['panel'] as String,
      width = (json['physicalWidthMeters'] as num).toDouble(),
      measured = json['widthIsMeasured'] == true {
    if (!width.isFinite ||
        width <= 0 ||
        width > 10 ||
        image.split('/').last.split('.').first != id) {
      throw const FormatException('AR image filename must match its ID and width must be between 0 and 10 metres.');
    }
  }
  // Native AR image coordinates: +X right, +Y out of the image, -Z up.
  // Generated mesh is 1 x 0.75 m. Scale uniformly to 65% of portrait width.
  Matrix4 get panelTransform {
    final panelWidth = width * .65;
    return Matrix4.identity()
      ..setTranslation(
        Vector3(width / 2 + width * .06 + panelWidth / 2, .015, 0),
      )
      ..scaleByVector3(Vector3.all(panelWidth));
  }

  static Future<List<ArTarget>> load() async {
    final list = jsonDecode(
      await rootBundle.loadString('assets/ar_targets.json'),
    ) as List;
    final targets = list
        .map((x) => ArTarget.fromJson(x as Map<String, dynamic>))
        .toList();
    if (targets.isEmpty ||
        targets.map((t) => t.id).toSet().length != targets.length) {
      throw const FormatException('AR references must not be empty or have duplicate IDs.');
    }
    return targets;
  }
}

/// Requires two observations close in time before placing a panel.
/// Render tracking itself stays native, independent of Dart callback frequency.
class DetectionGate {
  final Map<String, DateTime> _last = {};
  bool observe(String id, DateTime now) {
    final previous = _last[id];
    _last[id] = now;
    return previous != null && now.difference(previous).inMilliseconds <= 1500;
  }

  void forget(String id) => _last.remove(id);
  void clear() => _last.clear();
}

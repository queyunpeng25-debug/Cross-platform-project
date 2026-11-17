import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'place_image_recognizer.dart';

Future<RawRgbaFrame?> grabPlatformCameraFrame(
  GlobalKey repaintBoundaryKey, {
  int maxDimension = 360,
}) async {
  final context = repaintBoundaryKey.currentContext;
  if (context == null) return null;
  final renderObject = context.findRenderObject();
  if (renderObject is! RenderRepaintBoundary) return null;

  final size = renderObject.size;
  if (size.isEmpty || size.width < 16 || size.height < 16) return null;

  final longest = math.max(size.width, size.height);
  final pixelRatio = (maxDimension / longest).clamp(0.15, 1.0);

  ui.Image? image;
  try {
    image = await renderObject.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) return null;

    final bytes = byteData.buffer.asUint8List(
      byteData.offsetInBytes,
      byteData.lengthInBytes,
    );

    // Reject uninitialized all-black textures (e.g. before first camera frame).
    var nonBlackSamples = 0;
    final step = math.max(4, (bytes.length ~/ 256) & ~3);
    for (var i = 0; i + 2 < bytes.length; i += step) {
      if (bytes[i] > 10 || bytes[i + 1] > 10 || bytes[i + 2] > 10) {
        nonBlackSamples++;
        if (nonBlackSamples >= 6) break;
      }
    }
    if (nonBlackSamples < 6) return null;

    return RawRgbaFrame(
      width: image.width,
      height: image.height,
      rgba: Uint8List.fromList(bytes),
    );
  } catch (_) {
    return null;
  } finally {
    image?.dispose();
  }
}

import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import 'place_image_recognizer.dart';

@JS('document')
external _JSDocument get _document;

extension type _JSDocument._(JSObject _) implements JSObject {
  external JSNodeList querySelectorAll(String selectors);
  external JSObject createElement(String tagName);
}

extension type JSNodeList._(JSObject _) implements JSObject {
  external int get length;
  external JSObject? item(int index);
}

extension type _JSVideoElement._(JSObject _) implements JSObject {
  external int get videoWidth;
  external int get videoHeight;
  external int get readyState;
  external bool get paused;
}

extension type _JSCanvasElement._(JSObject _) implements JSObject {
  external int get width;
  external set width(int value);
  external int get height;
  external set height(int value);
  external _JSCanvasContext2D? getContext(
    String contextId, [
    JSObject? options,
  ]);
}

extension type _CanvasContextOptions._(JSObject _) implements JSObject {
  external factory _CanvasContextOptions({bool willReadFrequently});
}

extension type _JSCanvasContext2D._(JSObject _) implements JSObject {
  external void drawImage(
    JSObject image,
    num dx,
    num dy,
    num dWidth,
    num dHeight,
  );
  external _JSImageData getImageData(int sx, int sy, int sw, int sh);
}

extension type _JSImageData._(JSObject _) implements JSObject {
  external JSUint8ClampedArray get data;
}

_JSCanvasElement? _sharedCanvas;
_JSCanvasContext2D? _sharedCtx;

Future<RawRgbaFrame?> grabPlatformCameraFrame(
  GlobalKey repaintBoundaryKey, {
  int maxDimension = 360,
}) async {
  try {
    final videos = _document.querySelectorAll('video');
    _JSVideoElement? activeVideo;
    for (var i = 0; i < videos.length; i++) {
      final node = videos.item(i);
      if (node == null) continue;
      final v = _JSVideoElement._(node);
      if (v.readyState >= 2 && v.videoWidth >= 32 && v.videoHeight >= 32) {
        activeVideo = v;
        if (!v.paused) break;
      }
    }
    if (activeVideo == null) return null;

    final vw = activeVideo.videoWidth;
    final vh = activeVideo.videoHeight;
    final longest = math.max(vw, vh);
    final scale = math.min(1.0, maxDimension / longest);
    final tw = math.max(16, (vw * scale).round());
    final th = math.max(16, (vh * scale).round());

    final canvas =
        _sharedCanvas ??= _JSCanvasElement._(_document.createElement('canvas'));
    if (canvas.width != tw) canvas.width = tw;
    if (canvas.height != th) canvas.height = th;

    final ctx = _sharedCtx ??= canvas.getContext(
      '2d',
      _CanvasContextOptions(willReadFrequently: true),
    );
    if (ctx == null) return null;

    ctx.drawImage(activeVideo, 0, 0, tw, th);
    final imgData = ctx.getImageData(0, 0, tw, th);
    final clamped = imgData.data.toDart;

    var nonBlack = 0;
    final step = math.max(4, (clamped.length ~/ 256) & ~3);
    for (var i = 0; i + 2 < clamped.length; i += step) {
      if (clamped[i] > 8 || clamped[i + 1] > 8 || clamped[i + 2] > 8) {
        nonBlack++;
        if (nonBlack >= 6) break;
      }
    }
    if (nonBlack < 6) return null;

    return RawRgbaFrame(
      width: tw,
      height: th,
      rgba: Uint8List.fromList(clamped),
    );
  } catch (_) {
    return null;
  }
}

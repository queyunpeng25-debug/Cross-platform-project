import 'package:flutter/widgets.dart';

import 'live_frame_grabber_stub.dart'
    if (dart.library.js_interop) 'live_frame_grabber_web.dart';
import 'place_image_recognizer.dart';

/// Captures a live RGBA frame from the active camera preview without closing
/// or interrupting `MobileScanner`:
/// - **Web**: samples the active `<video>` DOM stream onto an offscreen canvas.
/// - **Android / iOS**: samples the `Texture`-backed `RepaintBoundary`.
Future<RawRgbaFrame?> grabLiveCameraFrame(
  GlobalKey repaintBoundaryKey, {
  int maxDimension = 640,
}) {
  return grabPlatformCameraFrame(
    repaintBoundaryKey,
    maxDimension: maxDimension,
  );
}

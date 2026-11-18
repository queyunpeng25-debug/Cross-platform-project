import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

/// 3-Tier Spatial Tracking System (Adapter Pattern):
/// - [sensor3DoF]: Sensor & Panoramic 360° Spherical projection over live camera.
/// - [conventional]: View-locked accessible fallback.
enum SpatialTrackingTier {
  native6DoF,
  sensor3DoF,
  conventional,
}

/// A world-locked spatial entity positioned in 3D spherical coordinates around the user.
///
/// [azimuth]: Horizontal heading in degrees (-180° to +180°, 0° = straight ahead, -45° = left, +45° = right).
/// [elevation]: Vertical pitch in degrees (-90° down to +90° up, 0° = eye level).
/// [distance]: Distance from user in meters (typically 1.5m – 2.5m).
class SpatialAnchorItem {
  SpatialAnchorItem({
    required this.id,
    required this.azimuth,
    required this.elevation,
    required this.distance,
    required this.title,
    this.subtitle,
    required this.icon,
    this.accentColor = const Color(0xFFD9CBB8),
    this.isCompleted = false,
    this.data,
  });

  final String id;
  final double azimuth;
  final double elevation;
  final double distance;
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color accentColor;
  bool isCompleted;
  dynamic data;

  /// Converts spherical coordinates to 3D Cartesian Vector3 (X: right, Y: up, Z: backward towards viewer).
  vm.Vector3 toCartesian() {
    final radYaw = azimuth * math.pi / 180.0;
    final radPitch = elevation * math.pi / 180.0;
    final x = distance * math.sin(radYaw) * math.cos(radPitch);
    final y = distance * math.sin(radPitch);
    final z = -distance * math.cos(radYaw) * math.cos(radPitch);
    return vm.Vector3(x, y, z);
  }
}

/// Result of projecting a 3D spherical spatial anchor onto the 2D viewport.
class SpatialProjectionResult {
  const SpatialProjectionResult({
    required this.isInViewport,
    required this.screenPosition,
    required this.scale,
    required this.deltaYaw,
    required this.deltaPitch,
    required this.edgeAngle,
  });

  /// True if the 3D entity is currently within or crossing the camera's visible Field of View.
  final bool isInViewport;

  /// 2D screen coordinate in pixels.
  final Offset screenPosition;

  /// Perspective scale factor based on distance.
  final double scale;

  /// Horizontal angular offset from current camera heading in degrees.
  final double deltaYaw;

  /// Vertical angular offset from current camera pitch in degrees.
  final double deltaPitch;

  /// Polar angle (radians) towards the off-screen entity for edge radar indicators.
  final double edgeAngle;
}

/// Projects world-locked 3D spherical coordinates onto the viewport using true
/// perspective pinhole camera optics.
class SpatialProjectionEngine {
  const SpatialProjectionEngine._();

  // Typical smartphone rear camera horizontal FOV in degrees
  static const double horizontalFov = 62.0;

  static SpatialProjectionResult project({
    required SpatialAnchorItem item,
    required double cameraYaw,
    required double cameraPitch,
    required Size screenSize,
    double pieceRadius = 80.0,
  }) {
    // Calculate normalized horizontal delta (-180° to +180°)
    var deltaYaw = (item.azimuth - cameraYaw) % 360.0;
    if (deltaYaw > 180.0) deltaYaw -= 360.0;
    if (deltaYaw < -180.0) deltaYaw += 360.0;

    final deltaPitch = item.elevation - cameraPitch;

    // Convert FOVs to radians matching screen aspect ratio
    final halfHFovRad = (horizontalFov * 0.5) * math.pi / 180.0;
    final aspectRatio = screenSize.height / (screenSize.width > 0 ? screenSize.width : 1.0);
    final halfVFovRad = math.atan(math.tan(halfHFovRad) * aspectRatio);

    final deltaYawRad = deltaYaw * math.pi / 180.0;
    final deltaPitchRad = deltaPitch * math.pi / 180.0;

    // Tangent pinhole perspective projection:
    // As deltaYaw increases (target to the right), normX is positive -> screenX > W/2
    // As deltaPitch increases (target above camera), normY is positive -> screenY < H/2 (higher on screen)
    final tanYaw = math.tan(deltaYawRad.clamp(-1.45, 1.45));
    final tanPitch = math.tan(deltaPitchRad.clamp(-1.45, 1.45));

    final normX = tanYaw / math.tan(halfHFovRad);
    final normY = tanPitch / math.tan(halfVFovRad);

    final screenX = screenSize.width * 0.5 + normX * (screenSize.width * 0.5);
    final screenY = screenSize.height * 0.5 - normY * (screenSize.height * 0.5);

    // Entity is in front of camera (within 85 degrees)
    final isAhead = deltaYaw.abs() < 85.0 && deltaPitch.abs() < 85.0;

    // Check if the entity's bounding circle intersects the screen bounds
    final isInViewport = isAhead &&
        screenX >= -pieceRadius &&
        screenX <= screenSize.width + pieceRadius &&
        screenY >= -pieceRadius &&
        screenY <= screenSize.height + pieceRadius;

    final scale = (1.9 / item.distance).clamp(0.75, 1.35);

    // Direction vector towards the target for off-screen radar indicators.
    // In Flutter screen coordinates, screen Y points downwards, so vertical 'up' is -deltaPitch.
    final edgeAngle = math.atan2(-deltaPitch, deltaYaw);

    return SpatialProjectionResult(
      isInViewport: isInViewport,
      screenPosition: Offset(screenX, screenY),
      scale: scale,
      deltaYaw: deltaYaw,
      deltaPitch: deltaPitch,
      edgeAngle: edgeAngle,
    );
  }
}

/// Helper for Spatial Safety Preflight & JIT Camera Permissions.
class SpatialPreflightService {
  const SpatialPreflightService._();

  static bool get isNative6DoFSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }
}

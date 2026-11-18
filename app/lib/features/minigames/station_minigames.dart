import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:zenify/zenify.dart';

import '../../core/controllers.dart';
import '../../core/models.dart';
import '../../core/translation_service.dart';
import '../../ui/puzzle_icon.dart';
import 'puzzle_config.dart';
import 'spatial_minigame_engine.dart';

/// Full-Screen AR Spatial Puzzle Hunt Screen.
///
/// Combines a reliable live camera feed with hardware sensor tracking
/// (gyroscope + accelerometer via `sensors_plus`) running on a 60 FPS Ticker loop.
///
/// The 3D puzzle piece is world-locked in the physical room at its designated
/// azimuth, elevation, and distance. As the visitor turns and tilts the phone,
/// the piece glides in and out of the camera view smoothly.
///
/// The piece can ONLY be collected when properly framed inside the center reticle box
/// and captured with the Shutter button.
class ArStationMinigameScreen extends StatefulWidget {
  const ArStationMinigameScreen({
    super.key,
    required this.station,
    required this.progress,
  });

  final StationSpec station;
  final TourProgressController progress;

  @override
  State<ArStationMinigameScreen> createState() => _ArStationMinigameScreenState();
}

class _ArStationMinigameScreenState extends State<ArStationMinigameScreen>
    with SingleTickerProviderStateMixin {
  late final StationPuzzleSpatialOffset _offset;

  // Live filtered camera orientation angles (degrees)
  double _cameraYaw = 0.0; // 0° to 360°
  double _cameraPitch = 0.0; // -90° to +90°

  // Sensor targets for smooth 60 FPS interpolation
  double _targetPitch = 0.0;
  double _pendingYawDelta = 0.0;
  DateTime? _lastGyroTime;
  double _accelX = 0.0;
  double _accelY = -9.8;
  double _accelZ = 0.0;
  bool _hasSensorsActive = false;

  // Manual pan offset (used for desktop/simulators without physical sensors)
  double _manualPanYaw = 0.0;
  double _manualPanPitch = 0.0;

  // Sensor subscriptions & 60 FPS Ticker
  StreamSubscription<GyroscopeEvent>? _gyroSubscription;
  StreamSubscription<AccelerometerEvent>? _accelSubscription;
  late final Ticker _ticker;

  // Camera controller
  MobileScannerController? _cameraController;
  bool _cameraPermissionGranted = true;

  // UI & Capture state
  bool _isCollected = false;
  bool _isCapturing = false;
  bool _showShutterFlash = false;
  bool _showNotFramedWarning = false;
  Timer? _warningTimer;
  final bool _showSafetyPreflight = true;
  bool _hasAcceptedPreflight = false;

  @override
  void initState() {
    super.initState();
    final baseOffset = getStationPuzzleOffset(widget.station.id);
    if (widget.station.id == 'lobby') {
      // Tutorial station: placed straight ahead at eye level with slight natural float
      final rng = math.Random();
      final azJitter = (rng.nextDouble() * 4.0) - 2.0;
      final elJitter = (rng.nextDouble() * 4.0) - 2.0;
      _offset = baseOffset.copyWith(
        azimuth: (baseOffset.azimuth + azJitter).clamp(-6.0, 6.0),
        elevation: (baseOffset.elevation + elJitter).clamp(-4.0, 4.0),
      );
    } else {
      // Exploration stations: dynamically randomize the position across the quadrant
      // so it is NOT visible on startup and requires the visitor to look around.
      final rng = math.Random();
      final azJitter = (rng.nextDouble() * 40.0) - 20.0; // ±20°
      final elJitter = (rng.nextDouble() * 16.0) - 8.0; // ±8°
      final distJitter = (rng.nextDouble() * 0.6) - 0.3; // ±0.3m

      var randAzimuth = baseOffset.azimuth + azJitter;
      // Guarantee that the piece is outside the initial front camera view (|azimuth| >= 45° or |elevation| >= 35°)
      if (randAzimuth.abs() < 45.0 && (baseOffset.elevation + elJitter).abs() < 35.0) {
        randAzimuth = randAzimuth >= 0
            ? 55.0 + rng.nextDouble() * 20.0
            : -55.0 - rng.nextDouble() * 20.0;
      }
      if (randAzimuth > 180.0) randAzimuth -= 360.0;
      if (randAzimuth < -180.0) randAzimuth += 360.0;

      final randElevation = (baseOffset.elevation + elJitter).clamp(-45.0, 58.0);
      final randDistance = (baseOffset.distance + distJitter).clamp(1.5, 3.8);

      _offset = baseOffset.copyWith(
        azimuth: randAzimuth,
        elevation: randElevation,
        distance: double.parse(randDistance.toStringAsFixed(1)),
      );
    }

    _isCollected = widget.progress.hasCollectedPiece(widget.station.id);

    // Camera always begins at user's forward heading (0°) so non-lobby pieces
    // are not immediately in front and the user must physically look around.
    _cameraYaw = 0.0;
    _cameraPitch = 0.0;
    _targetPitch = 0.0;

    _initCamera();
    _initHardwareSensors();

    // 60 FPS Ticker for butter-smooth camera orientation interpolation
    _ticker = createTicker((_) => _onFrameTick())..start();
  }

  Future<void> _initCamera() async {
    final granted = await SpatialPreflightService.requestCameraPermission();
    if (!mounted) return;

    if (!granted) {
      setState(() {
        _cameraPermissionGranted = false;
      });
      return;
    }

    try {
      _cameraController = MobileScannerController(
        autoStart: true,
        detectionSpeed: DetectionSpeed.normal,
      );
      if (mounted) setState(() {});
    } catch (_) {}
  }

  void _initHardwareSensors() {
    // 1. Accelerometer: continuously measures gravity vector to compute pitch without gimbal lock
    try {
      _accelSubscription = accelerometerEventStream(
        samplingPeriod: SensorInterval.gameInterval,
      ).listen(
        (event) {
          _hasSensorsActive = true;
          _accelX = event.x;
          _accelY = event.y;
          _accelZ = event.z;

          final length = math.sqrt(
            event.x * event.x + event.y * event.y + event.z * event.z,
          );
          if (length > 1.5) {
            // When pointing UP towards ceiling, event.z is negative -> -event.z > 0 -> pitch > 0°
            // When pointing DOWN towards floor/desk, event.z is positive -> -event.z < 0 -> pitch < 0°
            final pitchRatio = (-event.z / length).clamp(-1.0, 1.0);
            _targetPitch = math.asin(pitchRatio) * (180.0 / math.pi);
          }
        },
        onError: (_) {},
      );
    } catch (_) {}

    // 2. Gyroscope: continuously measures rotational velocity around the vertical axis
    try {
      _lastGyroTime = DateTime.now();
      _gyroSubscription = gyroscopeEventStream(
        samplingPeriod: SensorInterval.gameInterval,
      ).listen(
        (event) {
          _hasSensorsActive = true;
          final now = DateTime.now();
          final prev = _lastGyroTime ?? now;
          _lastGyroTime = now;

          final dt = now.difference(prev).inMicroseconds / 1000000.0;
          if (dt <= 0.0 || dt > 0.2) return;

          // Compute rotation around the phone's up vector
          final gravLength = math.sqrt(
            _accelX * _accelX + _accelY * _accelY + _accelZ * _accelZ,
          );
          double yawRate;
          if (gravLength > 2.0) {
            // True world vertical axis opposite to gravity
            final upX = _accelX / gravLength;
            final upY = _accelY / gravLength;
            final upZ = _accelZ / gravLength;
            yawRate = (event.x * upX + event.y * upY + event.z * upZ);
          } else {
            yawRate = event.y;
          }

          // Convert to delta degrees (turning right increases yaw heading)
          final deltaDeg = -yawRate * (180.0 / math.pi) * dt;
          _pendingYawDelta += deltaDeg;
        },
        onError: (_) {},
      );
    } catch (_) {}
  }

  void _onFrameTick() {
    if (!mounted) return;

    // Smoothly interpolate pitch towards target pitch
    final newPitch = _cameraPitch * 0.78 + _targetPitch * 0.22;

    // Accumulate pending yaw delta from gyroscope
    var newYaw = (_cameraYaw + _pendingYawDelta) % 360.0;
    if (newYaw < 0) newYaw += 360.0;
    _pendingYawDelta = 0.0;

    // Trigger frame update only when angle changed significantly
    if ((newPitch - _cameraPitch).abs() > 0.04 ||
        (newYaw - _cameraYaw).abs() > 0.04) {
      setState(() {
        _cameraPitch = newPitch;
        _cameraYaw = newYaw;
      });
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _warningTimer?.cancel();
    _gyroSubscription?.cancel();
    _accelSubscription?.cancel();
    _cameraController?.dispose();
    super.dispose();
  }

  /// Recenter the heading so the current physical direction aligns with the piece.
  void _recenterHeading() {
    setState(() {
      _cameraYaw = _offset.azimuth;
      _cameraPitch = _offset.elevation;
      _manualPanYaw = 0.0;
      _manualPanPitch = 0.0;
      _pendingYawDelta = 0.0;
      _targetPitch = _offset.elevation;
    });
    HapticFeedback.selectionClick();
  }

  void _onShutterPressed({required bool isFramed}) {
    if (_isCapturing || _isCollected) return;

    if (!isFramed) {
      // Must frame the piece inside the center box!
      HapticFeedback.lightImpact();
      _warningTimer?.cancel();
      setState(() {
        _showNotFramedWarning = true;
      });
      _warningTimer = Timer(const Duration(milliseconds: 2200), () {
        if (mounted) setState(() => _showNotFramedWarning = false);
      });
      return;
    }

    // Success: piece is framed! Capture with camera flash & sound
    setState(() {
      _isCapturing = true;
      _showShutterFlash = true;
      _showNotFramedWarning = false;
    });

    HapticFeedback.heavyImpact();

    // Shutter flash fades out quickly
    Timer(const Duration(milliseconds: 180), () {
      if (mounted) setState(() => _showShutterFlash = false);
    });

    // Mark collected in TourProgressController
    widget.progress.markPuzzlePieceCollected(widget.station.id);

    Timer(const Duration(milliseconds: 650), () {
      if (!mounted) return;
      setState(() {
        _isCapturing = false;
        _isCollected = true;
      });
      _showCollectionCelebrationSheet();
    });
  }

  void _showCollectionCelebrationSheet() {
    final totalCollected = widget.progress.collectedPuzzleCount;
    final totalNeeded = widget.progress.totalPuzzleStations > 0
        ? widget.progress.totalPuzzleStations
        : 9;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (sheetContext) => AsymmetricTranslucentSheet(
        topLeftRadius: 48,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Glowing 3D celebratory piece
              SizedBox(
                height: 120,
                child: Center(
                  child: Spinning3DPuzzlePiece(
                    tileIndex: _offset.tileIndex,
                    stationTitle: widget.station.title,
                    size: 96,
                    isCollected: true,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const TrText(
                'Puzzle Piece Captured!',
                style: TextStyle(
                  color: Color(0xFFF7F5F0),
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 6),
              TrText(
                'Piece ${_offset.tileIndex + 1} of $totalNeeded · ${widget.station.title}',
                style: const TextStyle(
                  color: Color(0xFFD9CBB8),
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFD9CBB8).withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const PuzzlePieceIcon(
                      collected: true,
                      size: 16,
                      activeColor: Color(0xFFD9CBB8),
                    ),
                    const SizedBox(width: 8),
                    TrText(
                      'Total Collected: $totalCollected / $totalNeeded',
                      style: const TextStyle(
                        color: Color(0xFFF7F5F0),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD9CBB8),
                    foregroundColor: const Color(0xFF141312),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    Navigator.of(context).pop();
                  },
                  child: const TrText(
                    'Continue Tour',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);

    // Combine hardware sensor look angles with any manual fine-tuning
    final effectiveYaw = (_cameraYaw + _manualPanYaw) % 360.0;
    final effectivePitch = (_cameraPitch + _manualPanPitch).clamp(-88.0, 88.0);

    // Project world-locked 3D position onto current 2D screen viewport
    final projection = SpatialProjectionEngine.project(
      item: SpatialAnchorItem(
        id: widget.station.id,
        azimuth: _offset.azimuth,
        elevation: _offset.elevation,
        distance: _offset.distance,
        title: _offset.title,
        icon: Icons.extension_rounded,
      ),
      cameraYaw: effectiveYaw,
      cameraPitch: effectivePitch,
      screenSize: screenSize,
      pieceRadius: 75.0,
    );

    // Check if piece is framed inside the center box (box is 200x200 centered at W/2, H/2)
    final centerX = screenSize.width * 0.5;
    final centerY = screenSize.height * 0.5;
    final deltaFromCenter = (projection.screenPosition - Offset(centerX, centerY));
    final isFramedInCenter = projection.isInViewport &&
        deltaFromCenter.dx.abs() <= 85.0 &&
        deltaFromCenter.dy.abs() <= 85.0;

    return Scaffold(
      backgroundColor: const Color(0xFF141312),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Reliable Full-Screen Live Camera Feed
          _buildCameraBackdrop(),

          // 2. Gesture Detector for manual pan fine-tuning (e.g. desktop/simulator)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanUpdate: (details) {
              setState(() {
                _manualPanYaw =
                    (_manualPanYaw - details.delta.dx * 0.28) % 360.0;
                if (_manualPanYaw < 0) _manualPanYaw += 360.0;
                _manualPanPitch =
                    (_manualPanPitch - details.delta.dy * 0.22)
                        .clamp(-45.0, 45.0);
              });
            },
            child: const SizedBox.expand(),
          ),

          // 3. Center Framing Box / Viewfinder Reticle
          _buildCenterFramingBox(
            isFramed: isFramedInCenter,
            showWarning: _showNotFramedWarning,
          ),

          // 4. World-Locked 3D Rotating Puzzle Piece (When in Viewport)
          if (projection.isInViewport)
            Positioned(
              left: projection.screenPosition.dx - (65.0 * projection.scale),
              top: projection.screenPosition.dy - (65.0 * projection.scale),
              child: AnimatedScale(
                scale: _isCapturing ? 1.5 : 1.0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutBack,
                child: Transform.scale(
                  scale: projection.scale,
                  child: Spinning3DPuzzlePiece(
                    tileIndex: _offset.tileIndex,
                    stationTitle: widget.station.title,
                    size: 130.0,
                    isCollected: _isCollected,
                    onTap: () => _onShutterPressed(isFramed: isFramedInCenter),
                  ),
                ),
              ),
            ),

          // 5. Off-Screen 3D Directional Radar Indicator (When out of Viewport)
          if (!projection.isInViewport)
            _buildOffScreenRadarIndicator(
              screenSize: screenSize,
              edgeAngle: projection.edgeAngle,
              deltaYaw: projection.deltaYaw,
              deltaPitch: projection.deltaPitch,
            ),

          // 6. Camera Shutter Flash Animation Overlay
          if (_showShutterFlash)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: _showShutterFlash ? 0.85 : 0.0,
                  child: const ColoredBox(color: Colors.white),
                ),
              ),
            ),

          // 7. Top Bar: Back, Station Pill, Recenter & Demo Catch
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildTopHeaderBar(),
          ),

          // 8. Warning Banner when pressing Shutter while piece is not centered
          if (_showNotFramedWarning)
            Positioned(
              top: 100,
              left: 20,
              right: 20,
              child: _buildNotFramedWarningBanner(),
            ),

          // 9. Bottom Action Bar with Spatial Anchor Hint & Shutter Capture Button
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomActionBar(
              isFramed: isFramedInCenter,
            ),
          ),

          // 10. Safety Preflight Notice (On launch)
          if (_showSafetyPreflight && !_hasAcceptedPreflight)
            _buildSafetyPreflightOverlay(),
        ],
      ),
    );
  }

  Widget _buildCameraBackdrop() {
    if (_cameraController != null && _cameraPermissionGranted) {
      return MobileScanner(
        controller: _cameraController!,
        fit: BoxFit.cover,
      );
    }

    // Studio simulated backdrop if camera permission denied or on desktop
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1A1918), Color(0xFF0F0E0D)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: _CameraGridPainter(
              yaw: _cameraYaw + _manualPanYaw,
              pitch: _cameraPitch + _manualPanPitch,
            ),
          ),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.touch_app_rounded,
                    size: 16,
                    color: const Color(0xFFD9CBB8).withValues(alpha: 0.8),
                  ),
                  const SizedBox(width: 8),
                  const TrText(
                    'Point camera around you or drag to explore',
                    style: TextStyle(
                      color: Color(0xFFD9CBB8),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCenterFramingBox({
    required bool isFramed,
    required bool showWarning,
  }) {
    final borderColor = isFramed
        ? const Color(0xFF81C784)
        : (showWarning
            ? const Color(0xFFFFB74D)
            : Colors.white.withValues(alpha: 0.35));

    return IgnorePointer(
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            border: Border.all(
              color: borderColor,
              width: isFramed ? 2.5 : 1.5,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: isFramed
                ? [
                    BoxShadow(
                      color: const Color(0xFF81C784).withValues(alpha: 0.35),
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                  ]
                : null,
          ),
          child: Stack(
            children: [
              // Center crosshair tick
              Center(
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: borderColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),

              // Lock-On Status Banner above reticle
              Positioned(
                top: 8,
                left: 0,
                right: 0,
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: isFramed
                          ? const Color(0xFF81C784).withValues(alpha: 0.25)
                          : Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isFramed
                            ? const Color(0xFF81C784)
                            : Colors.white.withValues(alpha: 0.20),
                      ),
                    ),
                    child: TrText(
                      isFramed
                          ? 'TARGET FRAMED · SNAP PHOTO!'
                          : 'FRAME PIECE IN CENTER',
                      style: TextStyle(
                        color: isFramed
                            ? const Color(0xFF81C784)
                            : const Color(0xFFF7F5F0).withValues(alpha: 0.8),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotFramedWarningBanner() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF22201E).withValues(alpha: 0.90),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFFFB74D),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFB74D).withValues(alpha: 0.30),
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Row(
            children: [
              Icon(
                Icons.center_focus_strong_rounded,
                color: Color(0xFFFFB74D),
                size: 22,
              ),
              SizedBox(width: 10),
              Expanded(
                child: TrText(
                  'Center the 3D puzzle piece inside the box before taking the photo!',
                  style: TextStyle(
                    color: Color(0xFFF7F5F0),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOffScreenRadarIndicator({
    required Size screenSize,
    required double edgeAngle,
    required double deltaYaw,
    required double deltaPitch,
  }) {
    final radiusX = screenSize.width * 0.40;
    final radiusY = screenSize.height * 0.36;

    final cx = screenSize.width * 0.5;
    final cy = screenSize.height * 0.5;

    final posX = cx + radiusX * math.cos(edgeAngle);
    final posY = cy + radiusY * math.sin(edgeAngle);

    String directionHint;
    if (deltaYaw.abs() > 40.0) {
      directionHint = deltaYaw > 0
          ? 'Turn right (+${deltaYaw.toInt()}°)'
          : 'Turn left (${deltaYaw.toInt()}°)';
    } else if (deltaPitch > 15.0) {
      directionHint = 'Look up (+${deltaPitch.toInt()}°)';
    } else if (deltaPitch < -15.0) {
      directionHint = 'Look down (${deltaPitch.toInt()}°)';
    } else if (deltaYaw > 0) {
      directionHint = 'Turn right (+${deltaYaw.toInt()}°)';
    } else {
      directionHint = 'Turn left (${deltaYaw.toInt()}°)';
    }

    const pillEstimatedWidth = 175.0;
    const pillEstimatedHeight = 42.0;

    final maxLeft = math.max(16.0, screenSize.width - pillEstimatedWidth - 16.0);
    final clampedLeft = (posX - pillEstimatedWidth * 0.5).clamp(16.0, maxLeft);

    final maxTop = math.max(88.0, screenSize.height - pillEstimatedHeight - 120.0);
    final clampedTop = (posY - pillEstimatedHeight * 0.5).clamp(88.0, maxTop);

    return Positioned(
      left: clampedLeft,
      top: clampedTop,
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF22201E).withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFFD9CBB8).withValues(alpha: 0.65),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFD9CBB8).withValues(alpha: 0.25),
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.rotate(
                angle: edgeAngle,
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  size: 16,
                  color: Color(0xFFD9CBB8),
                ),
              ),
              const SizedBox(width: 6),
              TrText(
                directionHint,
                style: const TextStyle(
                  color: Color(0xFFF7F5F0),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '· ${_offset.distance}m',
                style: TextStyle(
                  color: const Color(0xFFF7F5F0).withValues(alpha: 0.70),
                  fontSize: 10.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopHeaderBar() {
    final settings = Zen.findOrNull<AppSettingsController>();
    final isDemoMode = settings?.demoUnlockAll.value ?? false;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          children: [
            // Close / Back button
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF22201E).withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.16),
                      ),
                    ),
                    child: const Icon(
                      Icons.arrow_back_rounded,
                      color: Color(0xFFF7F5F0),
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Station & Piece Indicator Pill
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF22201E).withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.16),
                      ),
                    ),
                    child: Row(
                      children: [
                        PuzzlePieceIcon(
                          collected: _isCollected,
                          size: 16,
                          activeColor: const Color(0xFFD9CBB8),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TrText(
                                widget.station.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFFF7F5F0),
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              TrText(
                                'Piece ${_offset.tileIndex + 1} of ${widget.progress.totalPuzzleStations > 0 ? widget.progress.totalPuzzleStations : 8} · ${_offset.title}',
                                style: TextStyle(
                                  color: const Color(0xFFD9CBB8)
                                      .withValues(alpha: 0.85),
                                  fontSize: 10.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_hasSensorsActive)
                          Container(
                            margin: const EdgeInsets.only(left: 4),
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF81C784)
                                   .withValues(alpha: 0.20),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.explore_rounded,
                              size: 13,
                              color: Color(0xFF81C784),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (isDemoMode) ...[
              const SizedBox(width: 8),

              // Recenter heading button
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: InkWell(
                    onTap: _recenterHeading,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: const Color(0xFF22201E).withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.16),
                        ),
                      ),
                      child: const Icon(
                        Icons.my_location_rounded,
                        color: Color(0xFFD9CBB8),
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Demo Instant Catch Button
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: InkWell(
                    onTap: () => _onShutterPressed(isFramed: true),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF22201E).withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFD9CBB8).withValues(alpha: 0.35),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.auto_awesome_rounded,
                            size: 14,
                            color: Color(0xFFD9CBB8),
                          ),
                          SizedBox(width: 3),
                          TrText(
                            'Demo',
                            style: TextStyle(
                              color: Color(0xFFD9CBB8),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActionBar({required bool isFramed}) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Camera Shutter Button (Active when isFramed)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () => _onShutterPressed(isFramed: isFramed),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _isCollected
                            ? const Color(0xFF81C784)
                            : (isFramed
                                ? const Color(0xFF81C784)
                                : Colors.white.withValues(alpha: 0.45)),
                        width: 3.5,
                      ),
                      color: _isCapturing
                          ? const Color(0xFFD9CBB8)
                          : (isFramed
                              ? const Color(0xFF81C784).withValues(alpha: 0.22)
                              : Colors.white.withValues(alpha: 0.10)),
                      boxShadow: [
                        BoxShadow(
                          color: (isFramed
                                  ? const Color(0xFF81C784)
                                  : const Color(0xFFD9CBB8))
                              .withValues(alpha: isFramed ? 0.55 : 0.15),
                          blurRadius: isFramed ? 24 : 14,
                          spreadRadius: isFramed ? 3 : 1,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isCollected
                              ? const Color(0xFF81C784)
                              : (isFramed
                                  ? const Color(0xFF81C784)
                                  : (_isCapturing
                                      ? const Color(0xFF141312)
                                      : const Color(0xFFD9CBB8))),
                        ),
                        child: Icon(
                          _isCollected
                              ? Icons.check_rounded
                              : Icons.camera_alt_rounded,
                          size: 28,
                          color: const Color(0xFF141312),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            TrText(
              _isCollected
                  ? 'Piece Already Collected'
                  : (isFramed
                      ? 'Press Shutter to Snap Photo!'
                      : 'Center the 3D piece in the frame to photograph it'),
              style: TextStyle(
                color: isFramed
                    ? const Color(0xFF81C784)
                    : const Color(0xFFF7F5F0).withValues(alpha: 0.8),
                fontSize: 11.5,
                fontWeight: isFramed ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSafetyPreflightOverlay() {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.72),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF22201E).withValues(alpha: 0.90),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: const Color(0xFFD9CBB8).withValues(alpha: 0.35),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.visibility_rounded,
                        size: 40,
                        color: Color(0xFFD9CBB8),
                      ),
                      const SizedBox(height: 14),
                      const TrText(
                        'Stay Aware of Your Surroundings',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFFF7F5F0),
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const TrText(
                        'Stop walking, check around for obstacles and other visitors, and point your camera to discover the world-locked puzzle piece.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFFD9CBB8),
                          fontSize: 13.5,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD9CBB8),
                            foregroundColor: const Color(0xFF141312),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          onPressed: () {
                            setState(() {
                              _hasAcceptedPreflight = true;
                            });
                          },
                          child: const TrText(
                            'I Am Ready — Start AR Hunt',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dynamic 3D Spinning Puzzle Piece Widget.
///
/// Clean, single-card 3D perspective rotation around the Y-axis without
/// negative-Z depth artifacts or Skia glitching.
/// Slices the master artwork cleanly, features smooth continuous rotation,
/// specular glass sheen, and a glowing halo.
class Spinning3DPuzzlePiece extends StatefulWidget {
  const Spinning3DPuzzlePiece({
    super.key,
    required this.tileIndex,
    required this.stationTitle,
    this.masterImageAsset = kPuzzleImageAsset,
    this.size = 130.0,
    this.isCollected = false,
    this.onTap,
  });

  final int tileIndex;
  final String stationTitle;
  final String masterImageAsset;
  final double size;
  final bool isCollected;
  final VoidCallback? onTap;

  @override
  State<Spinning3DPuzzlePiece> createState() => _Spinning3DPuzzlePieceState();
}

class _Spinning3DPuzzlePieceState extends State<Spinning3DPuzzlePiece>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _rotationController,
      builder: (context, _) {
        final animValue = _rotationController.value;
        final angle = animValue * 2.0 * math.pi;

        // Floating vertical bobbing animation
        final bobbingY = math.sin(animValue * 2.0 * math.pi) * 6.0;

        // Subtle 3D dynamic tilt
        final pitchTilt = math.sin(animValue * 4.0 * math.pi) * 0.05;

        // Determine which side is facing the camera
        final isFrontFacing = math.cos(angle) >= 0.0;

        // Matrix4 with perspective distortion along Z-axis
        final transformMatrix = Matrix4.identity()
          ..setEntry(3, 2, 0.0012)
          ..translateByDouble(0.0, bobbingY, 0.0, 1.0)
          ..rotateY(angle)
          ..rotateX(pitchTilt);

        return GestureDetector(
          onTap: widget.onTap,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer glowing aura halo
              Container(
                width: widget.size * 1.15,
                height: widget.size * 1.15,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (widget.isCollected
                              ? const Color(0xFF81C784)
                              : const Color(0xFFD9CBB8))
                          .withValues(alpha: 0.35),
                      blurRadius: 28,
                      spreadRadius: 4,
                    ),
                  ],
                ),
              ),

              // 3D Perspective Rotated Piece
              Transform(
                alignment: Alignment.center,
                transform: transformMatrix,
                child: SizedBox(
                  width: widget.size,
                  height: widget.size,
                  child: isFrontFacing ? _buildFrontFace() : _buildBackFace(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFrontFace() {
    final row = widget.tileIndex ~/ 3;
    final col = widget.tileIndex % 3;
    final fullBoardSize = widget.size * 3.0;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.isCollected
              ? const Color(0xFF81C784)
              : const Color(0xFFD9CBB8),
          width: 2.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.50),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13.5),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Dynamically cropped slice of master artwork
            Positioned(
              left: -col * widget.size,
              top: -row * widget.size,
              width: fullBoardSize,
              height: fullBoardSize,
              child: Image.asset(
                widget.masterImageAsset,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Image.asset(
                  kFallbackPuzzleImageAsset,
                  fit: BoxFit.cover,
                ),
              ),
            ),

            // Diagonal specular glass highlight
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.25),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.white.withValues(alpha: 0.10),
                  ],
                ),
              ),
            ),

            // Number badge on top-left corner
            Positioned(
              top: 6,
              left: 6,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                  ),
                ),
                child: Text(
                  '#${widget.tileIndex + 1}',
                  style: const TextStyle(
                    color: Color(0xFFF7F5F0),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackFace() {
    // Invert horizontal scale so text on the back side is readable and not mirrored
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()..rotateY(math.pi),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFD9CBB8),
            width: 2.5,
          ),
          gradient: const LinearGradient(
            colors: [
              Color(0xFF2C2825),
              Color(0xFF1B1917),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.50),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13.5),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Subtle circuit trace background
              CustomPaint(
                painter: _CircuitBackingPainter(),
              ),

              // Backplate Content
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const PuzzlePieceIcon(
                      collected: true,
                      size: 26,
                      activeColor: Color(0xFFD9CBB8),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'PIECE ${widget.tileIndex + 1}/9',
                      style: const TextStyle(
                        color: Color(0xFFF7F5F0),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        widget.stationTitle,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color:
                              const Color(0xFFD9CBB8).withValues(alpha: 0.85),
                          fontSize: 9.0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Simulated Camera Grid Painter with dynamic yaw/pitch shifting.
class _CameraGridPainter extends CustomPainter {
  const _CameraGridPainter({
    required this.yaw,
    required this.pitch,
  });

  final double yaw;
  final double pitch;

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1.0;

    const step = 48.0;
    final offsetX = (yaw * 3.0) % step;
    final offsetY = (pitch * 3.0) % step;

    for (var x = -step + offsetX; x < size.width + step; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
    for (var y = -step + offsetY; y < size.height + step; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CameraGridPainter oldDelegate) =>
      oldDelegate.yaw != yaw || oldDelegate.pitch != pitch;
}

/// Circuit Trace Painter for the 3D Puzzle Piece's backplate.
class _CircuitBackingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final tracePaint = Paint()
      ..color = const Color(0xFFD9CBB8).withValues(alpha: 0.14)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = const Color(0xFFD9CBB8).withValues(alpha: 0.22)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(size.width * 0.15, size.height * 0.2)
      ..lineTo(size.width * 0.4, size.height * 0.2)
      ..lineTo(size.width * 0.5, size.height * 0.35)
      ..moveTo(size.width * 0.85, size.height * 0.8)
      ..lineTo(size.width * 0.6, size.height * 0.8)
      ..lineTo(size.width * 0.5, size.height * 0.65);

    canvas.drawPath(path, tracePaint);
    canvas.drawCircle(
      Offset(size.width * 0.15, size.height * 0.2),
      2.5,
      dotPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.85, size.height * 0.8),
      2.5,
      dotPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CircuitBackingPainter oldDelegate) => false;
}

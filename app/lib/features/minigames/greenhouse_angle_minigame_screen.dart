// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:zenify/zenify.dart';

import '../../core/controllers.dart';
import '../scanner/live_frame_grabber.dart';
import '../scanner/place_image_recognizer.dart';
import 'greenhouse_angle_matcher.dart';

/// Interactive "Find the Correct Angle" Minigame for the Learning Hub Greenhouse station.
///
/// Workflow:
/// 1. A random perspective photo is selected from the 5 reference photos.
/// 2. Camera opens with the target thumbnail displayed in the top-left corner.
/// 3. Tapping the thumbnail zooms it in fullscreen; clicking the 'x' in the corner zooms out.
/// 4. The user searches for the exact physical spot and perspective, then presses Shutter.
/// 5. Computer Vision engine (Harris corners + 256-bit steered BRIEF + 2D RANSAC) verifies
///    that key architectural objects align physically (robust even if crowds/people are present).
/// 6. Outcome:
///    - If matched: displays "Congratulations!" and awards station progress.
///    - If not matched: displays "Incorrect position or angle, try again :(".
class GreenhouseAngleMinigameScreen extends StatefulWidget {
  const GreenhouseAngleMinigameScreen({
    super.key,
    this.progress,
    this.initialTarget,
    this.isDemoMode,
    this.matcher,
  });

  final TourProgressController? progress;
  final GreenhouseAngleTarget? initialTarget;
  final bool? isDemoMode;
  final GreenhouseAngleMatcher? matcher;

  @override
  State<GreenhouseAngleMinigameScreen> createState() =>
      _GreenhouseAngleMinigameScreenState();
}

class _GreenhouseAngleMinigameScreenState
    extends State<GreenhouseAngleMinigameScreen> {
  final GlobalKey _cameraBoundaryKey = GlobalKey();
  final ImagePicker _imagePicker = ImagePicker();

  MobileScannerController? _cameraController;
  GreenhouseAngleMatcher? _matcher;

  late GreenhouseAngleTarget _currentTarget;
  bool _isZoomed = false;
  bool _isProcessing = false;
  bool _showShutterFlash = false;
  bool _cameraPermissionGranted = true;
  bool _cameraSuspendedForCapture = false;

  GreenhouseAngleMatchResult? _lastResult;
  bool _showResultOverlay = false;

  @override
  void initState() {
    super.initState();
    // 1. Pick a random target from the 5 uploaded reference photos (or initialTarget)
    _selectTarget(widget.initialTarget);

    // 2. Initialize CV matcher and Camera
    _matcher = widget.matcher ?? GreenhouseAngleMatcher.instance;
    if (_matcher == null) {
      unawaited(_initMatcher());
    }
    unawaited(_initCamera());
  }

  void _selectTarget([GreenhouseAngleTarget? specificTarget]) {
    if (specificTarget != null) {
      _currentTarget = specificTarget;
    } else {
      final targets = kGreenhouseAngleTargets;
      final rng = math.Random();
      _currentTarget = targets[rng.nextInt(targets.length)];
    }
  }

  void _rerollAnotherTarget() {
    final remaining = kGreenhouseAngleTargets
        .where((t) => t.id != _currentTarget.id)
        .toList(growable: false);
    final rng = math.Random();
    setState(() {
      _currentTarget = remaining[rng.nextInt(remaining.length)];
      _lastResult = null;
      _showResultOverlay = false;
    });
  }

  Future<void> _initMatcher() async {
    try {
      final m = await GreenhouseAngleMatcher.load();
      if (mounted) {
        setState(() => _matcher = m);
      }
    } catch (e) {
      debugPrint('[GreenhouseMinigame] Failed to load matcher: $e');
    }
  }

  Future<void> _initCamera() async {
    if (WidgetsBinding.instance.runtimeType.toString().contains('Test')) {
      if (mounted) {
        setState(() {
          _cameraPermissionGranted = true;
        });
      }
      return;
    }

    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        if (mounted) setState(() => _cameraPermissionGranted = false);
        return;
      }
    }

    try {
      final controller = MobileScannerController(
        autoStart: true,
        detectionSpeed: DetectionSpeed.normal,
        facing: CameraFacing.back,
      );
      if (mounted) {
        setState(() {
          _cameraController = controller;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _cameraPermissionGranted = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _onShutterPressed() async {
    if (_isProcessing) return;
    HapticFeedback.mediumImpact();

    setState(() {
      _showShutterFlash = true;
      _isProcessing = true;
      _showResultOverlay = false;
    });

    // Brief shutter flash
    Timer(const Duration(milliseconds: 140), () {
      if (mounted) setState(() => _showShutterFlash = false);
    });

    try {
      final matcher = _matcher ?? await GreenhouseAngleMatcher.load();

      // 1. Grab raw RGBA pixels from live camera preview
      var frame = await grabLiveCameraFrame(
        _cameraBoundaryKey,
        maxDimension: 360,
      );

      // 2. Fallback on Android/iOS when GPU SurfaceProducer blocks RepaintBoundary readback:
      // release live preview temporarily and capture a direct hardware camera shot.
      final isWidgetTest = WidgetsBinding.instance.runtimeType
          .toString()
          .contains('Test');
      if (frame == null &&
          !kIsWeb &&
          !isWidgetTest &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS)) {
        try {
          await _cameraController?.stop();
          if (mounted) {
            setState(() => _cameraSuspendedForCapture = true);
          }
          await WidgetsBinding.instance.endOfFrame;
          final shot = await _imagePicker.pickImage(
            source: ImageSource.camera,
            maxWidth: 1080,
            maxHeight: 1080,
          );
          if (shot != null && mounted) {
            final bytes = await shot.readAsBytes();
            frame = await RawRgbaFrame.decodeEncoded(bytes, maxDimension: 360);
          }
        } catch (e) {
          debugPrint('[GreenhouseMinigame] Camera capture fallback error: $e');
        } finally {
          if (mounted) {
            setState(() => _cameraSuspendedForCapture = false);
            try {
              unawaited(_cameraController?.start());
            } catch (_) {}
          }
        }
      }

      if (frame == null) {
        if (mounted) {
          setState(() {
            _isProcessing = false;
            _lastResult = const GreenhouseAngleMatchResult(
              isMatch: false,
              confidence: 0.0,
              inliers: 0,
              scale: 1.0,
              rotationDegrees: 0.0,
              spatialSpan: 0.0,
              structuralSimilarity: 0.0,
              feedbackMessage: 'Incorrect position or angle, try again :(',
            );
            _showResultOverlay = true;
          });
        }
        return;
      }

      // 3. Run Computer Vision Matching against active target angle
      final result = matcher.matchFrame(
        inputFrame: frame,
        target: _currentTarget,
      );

      if (result.isMatch) {
        HapticFeedback.heavyImpact();
      } else {
        HapticFeedback.lightImpact();
      }

      if (mounted) {
        setState(() {
          _isProcessing = false;
          _lastResult = result;
          _showResultOverlay = true;
        });
      }
    } catch (e) {
      debugPrint('[GreenhouseMinigame] Shutter error: $e');
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _lastResult = const GreenhouseAngleMatchResult(
            isMatch: false,
            confidence: 0.0,
            inliers: 0,
            scale: 1.0,
            rotationDegrees: 0.0,
            spatialSpan: 0.0,
            structuralSimilarity: 0.0,
            feedbackMessage: 'Incorrect position or angle, try again :(',
          );
          _showResultOverlay = true;
        });
      }
    }
  }

  bool get _isDemoMode =>
      widget.isDemoMode ??
      (Zen.findOrNull<AppSettingsController>()?.demoUnlockAll.value ?? false);

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final topPadding = media.padding.top;
    final bottomPadding = media.padding.bottom;
    final isDemoMode = _isDemoMode;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Live Camera Preview
          if (!_cameraSuspendedForCapture &&
              _cameraPermissionGranted &&
              _cameraController != null)
            RepaintBoundary(
              key: _cameraBoundaryKey,
              child: MobileScanner(
                controller: _cameraController,
                errorBuilder: (context, error) => _buildCameraFallback(),
              ),
            )
          else
            _buildCameraFallback(),

          // 2. Camera Shutter Flash Overlay
          AnimatedOpacity(
            opacity: _showShutterFlash ? 0.85 : 0.0,
            duration: const Duration(milliseconds: 140),
            child: const ColoredBox(color: Colors.white),
          ),

          // 3. Top Header Bar (Back button, Title, Reroll/Help)
          Positioned(
            top: topPadding + 10,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Back Button
                _CircleIconButton(
                  icon: Icons.arrow_back_rounded,
                  onTap: () => Navigator.of(context).pop(),
                ),

                // Title Pill
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          color: Colors.black.withOpacity(0.55),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.camera_alt_outlined,
                                color: Color(0xFFF3C64F),
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  'Find the Correct Angle',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.95),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.2,
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

                // Reroll Target Button - Only available in Demo Mode
                if (isDemoMode)
                  _CircleIconButton(
                    icon: Icons.shuffle_rounded,
                    tooltip: 'Try Another Photo (Demo Mode)',
                    onTap: _rerollAnotherTarget,
                  )
                else
                  const SizedBox(width: 42),
              ],
            ),
          ),

          // 4. Top-Left Reference Thumbnail (Tap to zoom!)
          Positioned(
            top: topPadding + 64,
            left: 16,
            child: _buildThumbnailCard(),
          ),

          // 5. Instruction Banner (Center Top)
          Positioned(
            top: topPadding + 68,
            left: 140,
            right: 16,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  color: Colors.black.withOpacity(0.60),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _currentTarget.title,
                        style: const TextStyle(
                          color: Color(0xFFF3C64F),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _currentTarget.hint,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 11,
                          height: 1.25,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 6. Viewfinder Framing Reticle
          Center(
            child: IgnorePointer(
              child: Container(
                width: media.size.width * 0.78,
                height: media.size.width * 0.98,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.white.withOpacity(0.24),
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Stack(
                  children: [
                    // Corner accents
                    _ReticleCorner(
                      alignment: Alignment.topLeft,
                      top: true,
                      left: true,
                    ),
                    _ReticleCorner(
                      alignment: Alignment.topRight,
                      top: true,
                      left: false,
                    ),
                    _ReticleCorner(
                      alignment: Alignment.bottomLeft,
                      top: false,
                      left: true,
                    ),
                    _ReticleCorner(
                      alignment: Alignment.bottomRight,
                      top: false,
                      left: false,
                    ),
                    Center(
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.4),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 7. Bottom Controls (Shutter Button, Target Details Helper)
          Positioned(
            bottom: bottomPadding + 24,
            left: 0,
            right: 0,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Center Shutter Button
                GestureDetector(
                  onTap: _isProcessing ? null : _onShutterPressed,
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 4.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF3C64F).withOpacity(0.35),
                          blurRadius: 18,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(5.0),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isProcessing
                              ? Colors.grey.shade600
                              : const Color(0xFFF3C64F),
                        ),
                        child: _isProcessing
                            ? const Padding(
                                padding: EdgeInsets.all(16.0),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.camera_alt_rounded,
                                color: Color(0xFF1A1918),
                                size: 32,
                              ),
                      ),
                    ),
                  ),
                ),

                // Info / Target Key Landmark Details on the right
                Positioned(
                  right: 28,
                  child: _CircleIconButton(
                    icon: Icons.info_outline_rounded,
                    size: 50,
                    iconSize: 22,
                    tooltip: 'View Target Details',
                    onTap: () => setState(() => _isZoomed = true),
                  ),
                ),
              ],
            ),
          ),

          // 8. Zoomed-In Overlay (When user taps thumbnail to zoom!)
          if (_isZoomed) _buildZoomedOverlay(),

          // 9. Match Result Banner / Overlay (Congratulations or Error)
          if (_showResultOverlay && _lastResult != null) _buildResultOverlay(),
        ],
      ),
    );
  }

  /// Top-Left small thumbnail card.
  /// Tapping opens the zoomed modal.
  Widget _buildThumbnailCard() {
    return GestureDetector(
      onTap: () => setState(() => _isZoomed = true),
      child: Container(
        width: 104,
        height: 136,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFF3C64F),
              width: 2.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.55),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  _currentTarget.assetPath,
                  fit: BoxFit.cover,
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 4,
                      horizontal: 4,
                    ),
                    color: Colors.black.withOpacity(0.70),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(
                          Icons.zoom_in_rounded,
                          color: Color(0xFFF3C64F),
                          size: 13,
                        ),
                        SizedBox(width: 3),
                        Text(
                          'Zoom',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
    );
  }

  /// Fullscreen Zoomed View with the 'x' button in the corner to dezoom!
  Widget _buildZoomedOverlay() {
    final media = MediaQuery.of(context);
    return Positioned.fill(
      child: GestureDetector(
        onTap: () => setState(() => _isZoomed = false),
        child: Container(
          color: Colors.black.withOpacity(0.85),
          alignment: Alignment.center,
          padding: const EdgeInsets.all(20),
          child: GestureDetector(
            onTap: () {}, // prevent tap from dismissing if tapped inside card
            child: Stack(
              children: [
                // Card containing enlarged reference image & landmarks
                Container(
                  constraints: BoxConstraints(
                    maxWidth: 420,
                    maxHeight: media.size.height * 0.82,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1D),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: const Color(0xFFF3C64F).withOpacity(0.8),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.7),
                        blurRadius: 24,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Enlarged Image
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: media.size.height * 0.55,
                          ),
                          child: Image.asset(
                            _currentTarget.assetPath,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),

                      // Information & Key Landmarks
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _currentTarget.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _currentTarget.hint,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.82),
                                fontSize: 13,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Key Objects to Match:',
                              style: TextStyle(
                                color: const Color(0xFFF3C64F),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: _currentTarget.keyLandmarks.map((l) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.18),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Text(
                                    l,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.9),
                                      fontSize: 11,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // The small 'X' button in the corner of the enlarged image!
                Positioned(
                  top: 10,
                  right: 10,
                  child: GestureDetector(
                    onTap: () => setState(() => _isZoomed = false),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withOpacity(0.75),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.6),
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Match Result Overlay (Congratulations! or Error)
  Widget _buildResultOverlay() {
    final res = _lastResult!;
    final isSuccess = res.isMatch;

    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.78),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 380),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1D),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSuccess
                  ? const Color(0xFFF3C64F)
                  : const Color(0xFFE57373),
              width: 2.0,
            ),
            boxShadow: [
              BoxShadow(
                color: (isSuccess
                        ? const Color(0xFFF3C64F)
                        : const Color(0xFFE57373))
                    .withOpacity(0.35),
                blurRadius: 28,
                spreadRadius: 2,
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon Header
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSuccess
                      ? const Color(0xFFF3C64F).withOpacity(0.18)
                      : const Color(0xFFE57373).withOpacity(0.18),
                ),
                child: Icon(
                  isSuccess
                      ? Icons.check_circle_rounded
                      : Icons.sentiment_dissatisfied_rounded,
                  color: isSuccess
                      ? const Color(0xFFF3C64F)
                      : const Color(0xFFE57373),
                  size: 42,
                ),
              ),
              const SizedBox(height: 18),

              // Primary Outcome Text
              Text(
                isSuccess ? 'Congratulations!' : res.feedbackMessage,
                style: TextStyle(
                  color: isSuccess
                      ? const Color(0xFFF3C64F)
                      : const Color(0xFFFFB4A9),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),

              // Detail Description
              Text(
                isSuccess
                    ? 'You found the exact spot and matched the perspective of ${_currentTarget.title}!'
                    : 'The camera perspective did not match the reference landmarks. Look at the key objects in the thumbnail and try again from the right position.',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.85),
                  fontSize: 13,
                  height: 1.35,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Action Buttons
              if (isSuccess) ...[
                // Back to Greenhouse
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF3C64F),
                    foregroundColor: const Color(0xFF1A1918),
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Return to Greenhouse',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Play Another Angle
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                      color: Colors.white.withOpacity(0.35),
                      width: 1.2,
                    ),
                    minimumSize: const Size(double.infinity, 44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _rerollAnotherTarget,
                  child: const Text(
                    'Play Another Angle',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ] else ...[
                // Retry Button
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF3C64F),
                    foregroundColor: const Color(0xFF1A1918),
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () => setState(() => _showResultOverlay = false),
                  child: const Text(
                    'Try Again',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Fallback UI if camera stream cannot start
  Widget _buildCameraFallback() {
    return Container(
      color: const Color(0xFF121211),
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.camera_indoor_outlined,
              color: Color(0xFFF3C64F),
              size: 56,
            ),
            const SizedBox(height: 16),
            const Text(
              'Camera Preview',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Point your camera at the target landmark and press the shutter button to match the angle.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 13,
                height: 1.35,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.onTap,
    this.size = 42,
    this.iconSize = 20,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final double iconSize;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    Widget button = ClipRRect(
      borderRadius: BorderRadius.circular(size / 2),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.55),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withOpacity(0.25),
              width: 1.0,
            ),
          ),
          child: IconButton(
            icon: Icon(icon, color: Colors.white, size: iconSize),
            onPressed: onTap,
            splashRadius: size / 2,
          ),
        ),
      ),
    );

    if (tooltip != null) {
      button = Tooltip(message: tooltip!, child: button);
    }
    return button;
  }
}

class _ReticleCorner extends StatelessWidget {
  const _ReticleCorner({
    required this.alignment,
    required this.top,
    required this.left,
  });

  final Alignment alignment;
  final bool top;
  final bool left;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          border: Border(
            top: top
                ? const BorderSide(color: Color(0xFFF3C64F), width: 3.5)
                : BorderSide.none,
            bottom: !top
                ? const BorderSide(color: Color(0xFFF3C64F), width: 3.5)
                : BorderSide.none,
            left: left
                ? const BorderSide(color: Color(0xFFF3C64F), width: 3.5)
                : BorderSide.none,
            right: !left
                ? const BorderSide(color: Color(0xFFF3C64F), width: 3.5)
                : BorderSide.none,
          ),
        ),
      ),
    );
  }
}

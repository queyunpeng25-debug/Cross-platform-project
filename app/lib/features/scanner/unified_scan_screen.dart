import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zenify/zenify.dart';

import '../../ar_portrait_screen.dart';
import '../../computer_exhibit.dart';
import '../../content.dart';
import '../../core/controllers.dart';
import '../../core/device_capabilities.dart';
import '../../core/models.dart';
import '../../core/translation_service.dart';
import 'live_frame_grabber.dart';
import 'place_image_recognizer.dart';

/// Notifier bridged from the parent `FrostedSplitDock` center Shutter button
/// so pressing the dock shutter triggers a deterministic capture/recognition
/// action inside [UnifiedScanScreen].
class ScanShutterController extends ChangeNotifier {
  int _triggerCount = 0;

  int get triggerCount => _triggerCount;

  void triggerShutter() {
    _triggerCount++;
    notifyListeners();
  }
}

class UnifiedScanScreen extends StatefulWidget {
  const UnifiedScanScreen({
    super.key,
    required this.shutterController,
    required this.onBackToLobby,
    required this.onStationMatched,
    required this.onOpenSideMenu,
    this.initialCatchStationId,
  });

  final ScanShutterController shutterController;
  final VoidCallback onBackToLobby;
  final ValueChanged<String> onStationMatched;
  final VoidCallback onOpenSideMenu;
  final String? initialCatchStationId;

  @override
  State<UnifiedScanScreen> createState() => _UnifiedScanScreenState();
}

class _UnifiedScanScreenState extends State<UnifiedScanScreen>
    with SingleTickerProviderStateMixin {
  static const Color _forestAccent = Color(0xFF262523);
  static const Color _goldSparkle = Color(0xFFF3C64F);

  late final AnimationController _floatController;
  final GlobalKey _cameraPreviewBoundaryKey = GlobalKey();
  final ImagePicker _imagePicker = ImagePicker();

  PlaceImageRecognizer? _placeRecognizer;
  Timer? _liveVisionTimer;
  bool _liveVisionBusy = false;
  String? _pendingVisualStationId;
  DateTime _pendingVisualAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastVisualMatchedAt = DateTime.fromMillisecondsSinceEpoch(0);

  int _shutterRequestId = 0;
  bool _shutterBusy = false;
  bool _showShutterFlash = false;
  bool _cameraSuspendedForNativeAr = false;

  late bool _isCatchMode;
  String? _activeCatchStationId;

  DateTime _lastQrProcessedAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastUnrecognizedQrAt = DateTime.fromMillisecondsSinceEpoch(0);

  String _statusMessage =
      'Point at a QR code, door logo, or building sign — or press Shutter to scan.';

  bool get _supportsNativeArPortraits => DeviceCapabilities.supportsNative3dAr;

  @override
  void initState() {
    super.initState();
    _activeCatchStationId = widget.initialCatchStationId;
    _isCatchMode = widget.initialCatchStationId != null;
    if (_isCatchMode) {
      _statusMessage =
          'Floating AR puzzle piece spotted! Press the center Shutter button to catch it.';
    }

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat();

    widget.shutterController.addListener(_onShutterTriggered);
    unawaited(_ensurePlaceRecognizer());
    _liveVisionTimer = Timer.periodic(
      const Duration(milliseconds: 1500),
      (_) => unawaited(_probeLiveVisualPlace()),
    );
  }

  Future<PlaceImageRecognizer?> _ensurePlaceRecognizer() async {
    final existing = _placeRecognizer;
    if (existing != null) return existing;
    try {
      final loaded = await PlaceImageRecognizer.loadDefault();
      if (mounted) {
        _placeRecognizer = loaded;
      }
      return loaded;
    } catch (_) {
      return null;
    }
  }

  @override
  void didUpdateWidget(covariant UnifiedScanScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shutterController != widget.shutterController) {
      oldWidget.shutterController.removeListener(_onShutterTriggered);
      widget.shutterController.addListener(_onShutterTriggered);
    }
    if (widget.initialCatchStationId != oldWidget.initialCatchStationId &&
        widget.initialCatchStationId != null) {
      setState(() {
        _activeCatchStationId = widget.initialCatchStationId;
        _isCatchMode = true;
        _statusMessage =
            'Floating AR puzzle piece spotted! Press the center Shutter button to catch it.';
      });
    }
  }

  @override
  void dispose() {
    _liveVisionTimer?.cancel();
    widget.shutterController.removeListener(_onShutterTriggered);
    _floatController.dispose();
    super.dispose();
  }

  StationCatalogRepository? _catalogOrNull() =>
      Zen.findOrNull<StationCatalogRepository>();

  TourProgressController? _progressOrNull() =>
      Zen.findOrNull<TourProgressController>();

  String _effectiveCatchStationId() {
    final explicit = _activeCatchStationId;
    if (explicit != null && explicit.isNotEmpty) return explicit;
    final progress = _progressOrNull();
    return progress?.currentStationId.value ?? 'lobby';
  }

  void _triggerFlashEffect() {
    if (!mounted) return;
    setState(() => _showShutterFlash = true);
    Timer(const Duration(milliseconds: 160), () {
      if (mounted) {
        setState(() => _showShutterFlash = false);
      }
    });
  }

  void _onShutterTriggered() {
    if (!mounted || _shutterBusy || _cameraSuspendedForNativeAr) return;
    final token = ++_shutterRequestId;
    _triggerFlashEffect();
    unawaited(HapticFeedback.mediumImpact());

    if (_isCatchMode) {
      unawaited(_handleCatchPuzzlePiece(token));
    } else {
      unawaited(_handleVisualSignShutter(token));
    }
  }

  Future<void> _handleCatchPuzzlePiece(int token) async {
    if (_shutterBusy || token != _shutterRequestId) return;
    _shutterBusy = true;
    try {
      final progress = _progressOrNull();
      final catalog = _catalogOrNull();
      final stationId = _effectiveCatchStationId();
      final station = catalog?.findById(stationId);

      progress?.markPuzzlePieceCollected(stationId);
      if (!mounted || token != _shutterRequestId) return;

      setState(() {
        _statusMessage = 'Caught the floating puzzle piece!';
      });

      final collectedCount = progress?.collectedPuzzleCount ?? 1;
      final totalCount = progress?.totalPuzzleStations ?? 1;
      final stationTitle = station?.title ?? 'Campus Station';

      final returnToStation = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _goldSparkle.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.extension_rounded,
                  color: Color(0xFF9E6B00),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: TrText(
                  'Puzzle Piece Caught!',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 19),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TrText(
                stationTitle,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              const TrText(
                'You captured this station’s floating AR puzzle piece and added it to your tour collection.',
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: _forestAccent.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.auto_awesome_rounded,
                      size: 18,
                      color: _forestAccent,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Pieces collected: $collectedCount / $totalCount',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _forestAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 48),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const TrText('Keep Scanning'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: _forestAccent,
                foregroundColor: Colors.white,
                minimumSize: const Size(48, 48),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
              label: const TrText('Open Station'),
            ),
          ],
        ),
      );

      if (!mounted || token != _shutterRequestId) return;
      if (returnToStation == true) {
        widget.onStationMatched(stationId);
      } else {
        setState(() {
          _isCatchMode = false;
          _statusMessage =
              'Piece saved! Point at another QR code or building sign.';
        });
      }
    } finally {
      _shutterBusy = false;
    }
  }

  Future<void> _probeLiveVisualPlace() async {
    if (!mounted ||
        _isCatchMode ||
        _shutterBusy ||
        _liveVisionBusy ||
        _cameraSuspendedForNativeAr) {
      return;
    }
    final now = DateTime.now();
    if (now.difference(_lastVisualMatchedAt) < const Duration(seconds: 3) ||
        now.difference(_lastQrProcessedAt) < const Duration(seconds: 3)) {
      return;
    }
    final recognizer = _placeRecognizer;
    if (recognizer == null) return;

    _liveVisionBusy = true;
    try {
      final frame = await grabLiveCameraFrame(
        _cameraPreviewBoundaryKey,
        maxDimension: 640,
      );
      if (!mounted || frame == null || _isCatchMode || _shutterBusy) return;

      final match = recognizer.recognizeRgba(frame);
      if (!mounted || match == null) {
        if (now.difference(_pendingVisualAt) > const Duration(seconds: 3)) {
          _pendingVisualStationId = null;
        }
        return;
      }

      final confirmed = match.isHighConfidence ||
          (_pendingVisualStationId == match.stationId &&
              now.difference(_pendingVisualAt) <=
                  const Duration(milliseconds: 3200));

      if (confirmed) {
        _pendingVisualStationId = null;
        _lastVisualMatchedAt = DateTime.now();
        await _applyVisualPlaceMatch(match);
      } else {
        _pendingVisualStationId = match.stationId;
        _pendingVisualAt = now;
        setState(() {
          _statusMessage =
              'Spotted ${match.label} — hold steady or press Shutter to open.';
        });
      }
    } finally {
      _liveVisionBusy = false;
    }
  }

  Future<void> _launchExternalUrlSafely(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) return;
    var launched = false;
    try {
      launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      launched = false;
    }
    if (!launched && mounted) {
      ScaffoldMessenger.maybeOf(context)
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: TrText('Could not open external link: $rawUrl')),
        );
    }
  }

  Future<void> _applyVisualPlaceMatch(PlaceVisualMatch match) async {
    if (!mounted) return;
    unawaited(HapticFeedback.selectionClick());
    setState(() {
      _statusMessage = 'Recognised ${match.label}! Opening guide...';
    });

    final externalUrl = match.externalUrl;
    if (externalUrl != null && externalUrl.isNotEmpty) {
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.hideCurrentSnackBar();
      messenger?.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
          content: Text('Recognised ${match.label}'),
          action: SnackBarAction(
            label: 'Subway Menu',
            onPressed: () => unawaited(_launchExternalUrlSafely(externalUrl)),
          ),
        ),
      );
    }

    widget.onStationMatched(match.stationId);
  }

  Future<bool> _scanPhotoFromPicker() async {
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1280,
        maxHeight: 1280,
      );
      if (picked == null || !mounted) return false;

      setState(() {
        _statusMessage = 'Analysing selected photo...';
      });

      final bytes = await picked.readAsBytes();
      final recognizer = await _ensurePlaceRecognizer();
      if (!mounted || recognizer == null) return false;

      final match = await recognizer.recognizeEncodedBytes(bytes);
      if (!mounted) return false;

      if (match != null) {
        _lastVisualMatchedAt = DateTime.now();
        await _applyVisualPlaceMatch(match);
        return true;
      }

      setState(() {
        _statusMessage =
            'No registered place matched that photo. Frame the sign/logo clearly and try again.';
      });
      return false;
    } catch (_) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Unable to read photo. Please try again.';
        });
      }
      return false;
    }
  }

  Future<void> _handleVisualSignShutter(int token) async {
    if (_shutterBusy || token != _shutterRequestId) return;
    _shutterBusy = true;
    try {
      setState(() {
        _statusMessage = 'Analysing live camera frame...';
      });

      final recognizer = await _ensurePlaceRecognizer();
      if (!mounted || token != _shutterRequestId) return;

      final liveFrame = recognizer != null
          ? await grabLiveCameraFrame(
              _cameraPreviewBoundaryKey,
              maxDimension: 680,
            )
          : null;
      if (!mounted || token != _shutterRequestId) return;

      if (recognizer != null && liveFrame != null) {
        final match = recognizer.recognizeRgba(liveFrame);
        if (match != null) {
          _lastVisualMatchedAt = DateTime.now();
          await _applyVisualPlaceMatch(match);
          return;
        }

        // Camera IS active, so do not pop up a manual menu on non-matching shots:
        // keep real camera behavior and point to (i) only if fallback is needed.
        setState(() {
          _statusMessage =
              'No match in ${liveFrame.width}×${liveFrame.height} frame — center the logo/sign inside the box and press Shutter again.';
        });
        return;
      }

      // On Android/iOS devices where SurfaceProducer blocks GPU texture readback,
      // capture a real hardware camera frame via ImagePicker.
      if (!kIsWeb && recognizer != null) {
        try {
          setState(() => _cameraSuspendedForNativeAr = true);
          await WidgetsBinding.instance.endOfFrame;
          final shot = await _imagePicker.pickImage(
            source: ImageSource.camera,
            maxWidth: 1080,
            maxHeight: 1080,
          );
          if (mounted) {
            setState(() => _cameraSuspendedForNativeAr = false);
          }
          if (shot != null && mounted && token == _shutterRequestId) {
            final bytes = await shot.readAsBytes();
            final match = await recognizer.recognizeEncodedBytes(bytes);
            if (!mounted || token != _shutterRequestId) return;
            if (match != null) {
              _lastVisualMatchedAt = DateTime.now();
              await _applyVisualPlaceMatch(match);
              return;
            }
            setState(() {
              _statusMessage =
                  'No registered place matched — move closer to the sign/logo and try again.';
            });
            return;
          }
        } catch (_) {
          if (mounted) {
            setState(() => _cameraSuspendedForNativeAr = false);
          }
        }
      }

      // Only open the fallback/photo sheet when no live camera stream is available.
      setState(() {
        _statusMessage =
            'Live camera frame unavailable — upload a photo or use demo fallback below.';
      });

      final sample = await _showVisualRecognitionSheet(
        title: 'Camera Unavailable · Photo & Demo Scan',
        subtitle:
            'Upload a photo to run real visual recognition, or use a demo preset when testing without a camera:',
      );

      if (!mounted || token != _shutterRequestId) return;
      if (sample == _kPickPhotoSentinel) {
        await _scanPhotoFromPicker();
        return;
      }
      if (sample == null || sample.trim().isEmpty) {
        setState(() {
          _statusMessage =
              'Point at a QR code, door logo, or building sign — or press Shutter to scan.';
        });
        return;
      }

      await _dispatchVisualSample(sample);
    } finally {
      _shutterBusy = false;
    }
  }

  static const String _kPickPhotoSentinel = '__pick_photo_for_visual_scan__';

  Future<void> _dispatchVisualSample(String sample) async {
    final catalog = _catalogOrNull();
    final progress = _progressOrNull();
    if (catalog == null) return;

    final outcome = catalog.evaluateVisualOrTextSample(sample);
    switch (outcome) {
      case ScanMatchedStation(:final stationId, :final triggerMethod):
        if (!mounted) return;
        setState(() {
          _statusMessage = 'Matched via $triggerMethod';
        });
        widget.onStationMatched(stationId);
      case ScanCaughtPuzzlePiece(:final stationId):
        progress?.markPuzzlePieceCollected(stationId);
        if (!mounted) return;
        setState(() {
          _statusMessage = 'Floating puzzle piece collected!';
        });
      case ScanExternalLink(:final title, :final url):
        if (url.toLowerCase().contains('subway')) {
          progress?.unlockAndSetCurrentStation('canteen');
        }
        if (!mounted) return;
        setState(() {
          _statusMessage = 'Opening $title...';
        });
        await _launchExternalUrlSafely(url);
        if (mounted && url.toLowerCase().contains('subway')) {
          widget.onStationMatched('canteen');
        }
      case ScanUnrecognized(:final hint):
        if (!mounted) return;
        setState(() {
          _statusMessage = hint;
        });
    }
  }

  void _onBarcodeDetected(BarcodeCapture capture) {
    if (_shutterBusy || _cameraSuspendedForNativeAr) return;
    final now = DateTime.now();
    if (now.difference(_lastQrProcessedAt) < const Duration(seconds: 2)) {
      return;
    }

    final catalog = _catalogOrNull();
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue?.trim();
      if (raw == null || raw.isEmpty) continue;

      final matchedId = catalog?.resolveStationFromRawCode(raw);
      if (matchedId != null) {
        _lastQrProcessedAt = now;
        unawaited(HapticFeedback.selectionClick());
        setState(() {
          _statusMessage = 'Station QR code recognised! Opening guide...';
        });
        widget.onStationMatched(matchedId);
        return;
      }

      if (raw == computerQr) {
        _lastQrProcessedAt = now;
        unawaited(HapticFeedback.selectionClick());
        unawaited(_openStandaloneComputerExhibit());
        return;
      }

      if (catalog != null) {
        final visualCheck = catalog.evaluateVisualOrTextSample(raw);
        if (visualCheck is ScanExternalLink) {
          _lastQrProcessedAt = now;
          unawaited(_dispatchVisualSample(raw));
          return;
        }
      }
    }

    if (now.difference(_lastUnrecognizedQrAt) >= const Duration(seconds: 2)) {
      _lastUnrecognizedQrAt = now;
      setState(() {
        _statusMessage =
            'Unrecognized QR code. Point at an official CS Explorer marker or sign.';
      });
    }
  }

  Future<void> _openStandaloneComputerExhibit() async {
    setState(() => _cameraSuspendedForNativeAr = true);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const ComputerExhibit()),
    );
    if (!mounted) return;
    setState(() => _cameraSuspendedForNativeAr = false);
  }

  Future<void> _launchNative3dArPortraits() async {
    if (!_supportsNativeArPortraits || _shutterBusy) return;
    _shutterBusy = true;
    try {
      setState(() {
        _cameraSuspendedForNativeAr = true;
        _statusMessage = 'Launching 3D AR Portrait Scanner...';
      });
      // Allow MobileScanner to unmount and release hardware camera before ARView starts.
      await WidgetsBinding.instance.endOfFrame;
      final content = await GuideContent.load();
      if (!mounted) return;

      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => ArPortraitScreen(content: content),
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _statusMessage =
              'Unable to open 3D AR mode on this device. Smart Scanner remains active.';
        });
      }
    } finally {
      _shutterBusy = false;
      if (mounted) {
        setState(() {
          _cameraSuspendedForNativeAr = false;
          _statusMessage =
              'Smart Scanner resumed. Point at a QR code or building sign.';
        });
      }
    }
  }

  List<_VisualPreset> _buildVisualPresets() {
    final catalog = _catalogOrNull();
    final presets = <_VisualPreset>[
      const _VisualPreset(
        label: 'Learning Hub Greenhouse',
        sample: 'Learning Hub',
        icon: Icons.eco_outlined,
      ),
      const _VisualPreset(
        label: '1F End Door to TUAS (SCI / Maarintie 8)',
        sample: 'Maarintie 8',
        icon: Icons.sensor_door_outlined,
      ),
      const _VisualPreset(
        label: 'Guild Logos (TiK / Athene / DG · DATABASE)',
        sample: 'Tietokilta',
        icon: Icons.groups_2_outlined,
      ),
      const _VisualPreset(
        label: "Locked Wing 'A' Door / Plaque",
        sample: 'Wing A',
        icon: Icons.lock_outline_rounded,
      ),
      const _VisualPreset(
        label: 'Subway Campus Sign',
        sample: 'Subway',
        icon: Icons.lunch_dining_outlined,
      ),
      const _VisualPreset(
        label: 'CS Pioneer Portraits (Kaisa Nyberg)',
        sample: 'Kaisa Nyberg',
        icon: Icons.portrait_outlined,
      ),
      const _VisualPreset(
        label: 'Evolution of Computers Display',
        sample: 'Evolution of Computers',
        icon: Icons.computer_outlined,
      ),
    ];

    if (catalog == null || catalog.textTriggerKeywords.isEmpty) {
      return presets;
    }

    // Ensure every station in catalog with a configured visual keyword is reachable.
    final coveredSamples = presets
        .map((p) => p.sample.toLowerCase())
        .toSet();
    final extra = <_VisualPreset>[];
    final seenStations = <String>{};

    for (final entry in catalog.textTriggerKeywords.entries) {
      final matchedPreset = coveredSamples.any(
        (s) => s.contains(entry.key.toLowerCase()) ||
            entry.key.toLowerCase().contains(s),
      );
      if (!matchedPreset && seenStations.add(entry.value)) {
        final spec = catalog.findById(entry.value);
        extra.add(
          _VisualPreset(
            label: spec != null ? '${spec.title} ("${entry.key}")' : entry.key,
            sample: entry.key,
            icon: Icons.center_focus_strong_outlined,
          ),
        );
      }
    }
    return [...presets, ...extra];
  }

  Future<String?> _showVisualRecognitionSheet({
    required String title,
    required String subtitle,
    bool includeScannerGuide = false,
  }) {
    final presets = _buildVisualPresets();
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _VisualRecognitionBottomSheet(
        title: title,
        subtitle: subtitle,
        includeScannerGuide: includeScannerGuide,
        presets: presets,
      ),
    );
  }

  Future<void> _openInfoAndFallbackSheet() async {
    if (_shutterBusy) return;
    _shutterBusy = true;
    try {
      final chosenSample = await _showVisualRecognitionSheet(
        title: 'What Can I Scan?',
        subtitle:
            'Scan physical QR codes or point the camera at registered building places (Greenhouse, Guild logos, Wing A door, 1F SCI/TUAS door, Subway):',
        includeScannerGuide: true,
      );
      if (!mounted || chosenSample == null || chosenSample.trim().isEmpty) {
        return;
      }
      if (chosenSample == _kPickPhotoSentinel) {
        await _scanPhotoFromPicker();
        return;
      }
      await _dispatchVisualSample(chosenSample);
    } finally {
      _shutterBusy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Live Camera Feed (MobileScanner with JIT permission & error fallback)
          if (!_cameraSuspendedForNativeAr)
            RepaintBoundary(
              key: _cameraPreviewBoundaryKey,
              child: MobileScanner(
                onDetect: _onBarcodeDetected,
                errorBuilder: (context, error) => _CameraFallbackPanel(
                  errorCodeName: error.errorCode.name,
                  onOpenVisualSimulation: _openInfoAndFallbackSheet,
                ),
              ),
            )
          else
            const ColoredBox(
              color: Color(0xFF101714),
              child: Center(
                child: CircularProgressIndicator(color: Colors.white70),
              ),
            ),

          // 2. Subtle dark vignette around edges so white/frosted controls stay legible
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.46),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.62),
                  ],
                  stops: const [0.0, 0.22, 0.68, 1.0],
                ),
              ),
            ),
          ),

          // 3. Center Rounded Viewfinder + Floating AR Puzzle Sparkles
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final boxSize = math.min(
                    276.0,
                    math.min(constraints.maxWidth, constraints.maxHeight) * 0.66,
                  );
                  return SizedBox(
                    width: boxSize,
                    height: boxSize,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        IgnorePointer(
                          child: CustomPaint(
                            size: Size.square(boxSize),
                            painter: _RoundedViewfinderPainter(
                              accentColor: _isCatchMode
                                  ? _goldSparkle
                                  : Colors.white.withValues(alpha: 0.92),
                            ),
                          ),
                        ),
                        if (_isCatchMode)
                          IgnorePointer(
                            child: AnimatedBuilder(
                              animation: _floatController,
                              builder: (context, _) {
                                final t = _floatController.value;
                                final bobY = math.sin(t * 2 * math.pi) * 10.0;
                                final tilt = math.cos(t * 2 * math.pi) * 0.06;
                                return Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    CustomPaint(
                                      size: Size.square(boxSize),
                                      painter: _FloatingStarsPainter(
                                        progress: t,
                                      ),
                                    ),
                                    Transform.translate(
                                      offset: Offset(0, bobY),
                                      child: Transform.rotate(
                                        angle: tilt,
                                        child: Container(
                                          width: 92,
                                          height: 92,
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [
                                                Color(0xFFFFE082),
                                                Color(0xFFE5A923),
                                              ],
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(28),
                                            border: Border.all(
                                              color: Colors.white,
                                              width: 2.2,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: _goldSparkle.withValues(
                                                  alpha: 0.55,
                                                ),
                                                blurRadius: 26,
                                                spreadRadius: 4,
                                              ),
                                            ],
                                          ),
                                          child: const Icon(
                                            Icons.extension_rounded,
                                            size: 48,
                                            color: Color(0xFF1F352B),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),

          // 4. Top Controls Bar (< Back + = Menu on Left, i Info on Right, Mode Pills below)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      _FrostedSquircleButton(
                        semanticsLabel: 'Back to Lobby',
                        icon: Icons.chevron_left_rounded,
                        iconSize: 28,
                        onTap: widget.onBackToLobby,
                      ),
                      const SizedBox(width: 10),
                      _FrostedSquircleButton(
                        semanticsLabel: 'Open Tour Stations Menu',
                        icon: Icons.drag_handle_rounded,
                        iconSize: 24,
                        highlighted: true,
                        onTap: widget.onOpenSideMenu,
                      ),
                      const Spacer(),
                      _FrostedSquircleButton(
                        semanticsLabel:
                            'Scanner guide and visual text fallback',
                        icon: Icons.info_outline_rounded,
                        iconSize: 22,
                        onTap: _openInfoAndFallbackSheet,
                      ),
                    ],
                  ),
                  if (_supportsNativeArPortraits) ...[
                    const SizedBox(height: 12),
                    _ScannerModePill(
                      onLaunchNativeAr: _launchNative3dArPortraits,
                    ),
                  ],
                ],
              ),
            ),
          ),

          // 5.Accessible Live Status Pill positioned cleanly above FrostedSplitDock
          Positioned(
            left: 20,
            right: 20,
            bottom: 112,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF15231D).withValues(alpha: 0.82),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ExcludeSemantics(
                            child: Icon(
                              _isCatchMode
                                  ? Icons.auto_awesome_rounded
                                  : Icons.qr_code_scanner_rounded,
                              size: 18,
                              color: _isCatchMode
                                  ? _goldSparkle
                                  : Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Semantics(
                              liveRegion: true,
                              child: TrText(
                                _statusMessage,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w500,
                                  height: 1.3,
                                ),
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

          // 6. Camera Shutter Flash Overlay
          IgnorePointer(
            child: AnimatedOpacity(
              opacity: _showShutterFlash ? 0.78 : 0.0,
              duration: const Duration(milliseconds: 140),
              child: const ColoredBox(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _FrostedSquircleButton extends StatelessWidget {
  const _FrostedSquircleButton({
    required this.semanticsLabel,
    required this.icon,
    required this.onTap,
    this.iconSize = 24,
    this.highlighted = false,
  });

  final String semanticsLabel;
  final IconData icon;
  final VoidCallback onTap;
  final double iconSize;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final bgColor = highlighted
        ? const Color(0xFF262523).withValues(alpha: 0.92)
        : Colors.white.withValues(alpha: 0.88);
    final fgColor = highlighted ? Colors.white : const Color(0xFF262523);

    return Semantics(
      button: true,
      label: semanticsLabel,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Material(
            color: bgColor,
            child: InkWell(
              onTap: onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                child: Center(
                  child: Icon(icon, size: iconSize, color: fgColor),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScannerModePill extends StatelessWidget {
  const _ScannerModePill({required this.onLaunchNativeAr});

  final VoidCallback onLaunchNativeAr;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.56),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                constraints: const BoxConstraints(minHeight: 40),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.bolt_rounded,
                      size: 16,
                      color: Color(0xFF262523),
                    ),
                    SizedBox(width: 4),
                    TrText(
                      'Smart Scan',
                      style: TextStyle(
                        color: Color(0xFF262523),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Semantics(
                button: true,
                label: 'Launch Full 3D AR Portrait Scanner',
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: onLaunchNativeAr,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.view_in_ar_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                            SizedBox(width: 6),
                            TrText(
                              '3D AR Portraits',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
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
}

class _CameraFallbackPanel extends StatelessWidget {
  const _CameraFallbackPanel({
    required this.errorCodeName,
    required this.onOpenVisualSimulation,
  });

  final String errorCodeName;
  final VoidCallback onOpenVisualSimulation;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF121C18),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 120, 28, 148),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.16),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.videocam_off_outlined,
                    size: 40,
                    color: Colors.white70,
                  ),
                  const SizedBox(height: 12),
                  const TrText(
                    'Live Camera Feed Unavailable',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const TrText(
                    'Allow camera access in your browser or system settings to scan QR codes live — or use Visual Sign Input below to unlock stations by sign text.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13.5,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '($errorCodeName)',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 11.5,
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFF3C64F),
                      foregroundColor: const Color(0xFF262523),
                      minimumSize: const Size(double.infinity, 48),
                    ),
                    onPressed: onOpenVisualSimulation,
                    icon: const Icon(Icons.text_fields_rounded, size: 18),
                    label: const TrText('Use Visual Sign / Text Fallback'),
                  ),
                  if (!kIsWeb) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                      ),
                      onPressed: () => unawaited(openAppSettings()),
                      icon: const Icon(Icons.settings_outlined, size: 18),
                      label: const TrText('Open System Settings'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VisualPreset {
  const _VisualPreset({
    required this.label,
    required this.sample,
    required this.icon,
  });

  final String label;
  final String sample;
  final IconData icon;
}

class _VisualRecognitionBottomSheet extends StatefulWidget {
  const _VisualRecognitionBottomSheet({
    required this.title,
    required this.subtitle,
    required this.includeScannerGuide,
    required this.presets,
  });

  final String title;
  final String subtitle;
  final bool includeScannerGuide;
  final List<_VisualPreset> presets;

  @override
  State<_VisualRecognitionBottomSheet> createState() =>
      _VisualRecognitionBottomSheetState();
}

class _VisualRecognitionBottomSheetState
    extends State<_VisualRecognitionBottomSheet> {
  final TextEditingController _textController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _submitText() {
    final value = _textController.text.trim();
    if (value.isEmpty) return;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final sheetBg = isDark
        ? const Color(0xFF1A2420).withValues(alpha: 0.96)
        : const Color(0xFFF7F5EF).withValues(alpha: 0.96);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.84,
            ),
            decoration: BoxDecoration(
              color: sheetBg,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.22,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TrText(
                            widget.title,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Semantics(
                          button: true,
                          label: 'Close sheet',
                          child: IconButton(
                            constraints: const BoxConstraints(
                              minWidth: 48,
                              minHeight: 48,
                            ),
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    TrText(
                      widget.subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        height: 1.4,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.76,
                        ),
                      ),
                    ),
                    if (widget.includeScannerGuide) ...[
                      const SizedBox(height: 16),
                      const _ScanCapabilityRow(
                        icon: Icons.qr_code_2_rounded,
                        title: 'Station QR Codes (Automatic)',
                        detail:
                            'Lobby & 3rd-Floor Loft QR markers unlock immediately when framed.',
                      ),
                      const _ScanCapabilityRow(
                        icon: Icons.center_focus_strong_rounded,
                        title: 'Live Place & Logo Recognition (Auto + Shutter)',
                        detail:
                            'Recognises Greenhouse, Guild logos (TiK, Athene, DG · DATABASE), Locked Wing A door/plaque, 1F SCI / Maarintie 8 door (or mailbox), and Subway.',
                      ),
                      const _ScanCapabilityRow(
                        icon: Icons.view_in_ar_rounded,
                        title: '3D Pioneer Portraits & Floating Puzzle Pieces',
                        detail:
                            'Use 3D AR Portraits on Android/iOS for anchored GLB biography panels, or toggle Floating AR Piece to catch station puzzle pieces.',
                      ),
                    ],
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () => Navigator.of(
                        context,
                      ).pop(_UnifiedScanScreenState._kPickPhotoSentinel),
                      icon: const Icon(Icons.photo_library_outlined, size: 19),
                      label: const TrText(
                        'Recognise Place from Photo / Camera Roll',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TrText(
                      'Type Visible Sign Text (Fallback / Demo)',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _textController,
                            textInputAction: TextInputAction.search,
                            onSubmitted: (_) => _submitText(),
                            decoration: InputDecoration(
                              hintText: 'e.g. Learning Hub, Maarintie 8, Subway',
                              filled: true,
                              fillColor: theme.colorScheme.surface,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 14,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF262523),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(56, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: _submitText,
                          child: const TrText('Match'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    TrText(
                      'Quick Visual Sign Simulation',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final preset in widget.presets)
                          ActionChip(
                            materialTapTargetSize:
                                MaterialTapTargetSize.padded,
                            avatar: Icon(preset.icon, size: 17),
                            label: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: TrText(preset.label),
                            ),
                            onPressed: () =>
                                Navigator.of(context).pop(preset.sample),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScanCapabilityRow extends StatelessWidget {
  const _ScanCapabilityRow({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF262523).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 19, color: const Color(0xFF262523)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TrText(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                TrText(
                  detail,
                  style: theme.textTheme.bodySmall?.copyWith(
                    height: 1.35,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundedViewfinderPainter extends CustomPainter {
  const _RoundedViewfinderPainter({required this.accentColor});

  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    final fullRect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(36),
    );
    canvas.drawRRect(fullRect, borderPaint);

    final cornerPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    const r = 36.0;
    const arm = 26.0;
    final w = size.width;
    final h = size.height;

    // Top-left bracket
    canvas.drawPath(
      Path()
        ..moveTo(0, r + arm)
        ..lineTo(0, r)
        ..arcToPoint(const Offset(r, 0), radius: const Radius.circular(r))
        ..lineTo(r + arm, 0),
      cornerPaint,
    );

    // Top-right bracket
    canvas.drawPath(
      Path()
        ..moveTo(w - r - arm, 0)
        ..lineTo(w - r, 0)
        ..arcToPoint(Offset(w, r), radius: const Radius.circular(r))
        ..lineTo(w, r + arm),
      cornerPaint,
    );

    // Bottom-right bracket
    canvas.drawPath(
      Path()
        ..moveTo(w, h - r - arm)
        ..lineTo(w, h - r)
        ..arcToPoint(Offset(w - r, h), radius: const Radius.circular(r))
        ..lineTo(w - r - arm, h),
      cornerPaint,
    );

    // Bottom-left bracket
    canvas.drawPath(
      Path()
        ..moveTo(r + arm, h)
        ..lineTo(r, h)
        ..arcToPoint(Offset(0, h - r), radius: const Radius.circular(r))
        ..lineTo(0, h - r - arm),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RoundedViewfinderPainter oldDelegate) =>
      oldDelegate.accentColor != accentColor;
}

class _FloatingStarsPainter extends CustomPainter {
  const _FloatingStarsPainter({required this.progress});

  final double progress;

  static const List<Offset> _starAnchors = [
    Offset(0.20, 0.22),
    Offset(0.82, 0.24),
    Offset(0.18, 0.76),
    Offset(0.80, 0.74),
    Offset(0.50, 0.14),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < _starAnchors.length; i++) {
      final anchor = _starAnchors[i];
      final phase = (progress * 2 * math.pi) + (i * 1.25);
      final dy = math.sin(phase) * 7.0;
      final scale = 0.78 + 0.28 * (0.5 + 0.5 * math.cos(phase));
      final center = Offset(size.width * anchor.dx, size.height * anchor.dy + dy);
      final radius = (i.isEven ? 13.0 : 10.0) * scale;

      final paint = Paint()
        ..color = const Color(0xFFFFD86B).withValues(
          alpha: (0.65 + 0.35 * math.sin(phase).abs()).clamp(0.0, 1.0),
        )
        ..style = PaintingStyle.fill;

      final path = Path();
      for (var step = 0; step < 8; step++) {
        final angle = (step * math.pi / 4) - (math.pi / 2);
        final r = step.isEven ? radius : radius * 0.38;
        final px = center.dx + math.cos(angle) * r;
        final py = center.dy + math.sin(angle) * r;
        if (step == 0) {
          path.moveTo(px, py);
        } else {
          path.lineTo(px, py);
        }
      }
      path.close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _FloatingStarsPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

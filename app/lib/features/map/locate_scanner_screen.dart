import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/translation_service.dart';
import 'map_positioning.dart';

/// Full-screen QR scanner used by the map's **Locate me** button.
///
/// It accepts station QR codes and the map's own "You are here" markers, and
/// pops with the recognised [MapScanTarget]. Unknown codes keep the camera
/// open with a hint instead of failing. If the camera cannot start
/// (permission denied, no camera, insecure browser context) a fallback panel
/// explains what to do and offers to pick the position on the map instead.
class MapLocateScannerScreen extends StatefulWidget {
  const MapLocateScannerScreen({super.key, required this.resolve});

  final MapScanTarget? Function(String raw) resolve;

  @override
  State<MapLocateScannerScreen> createState() => _MapLocateScannerScreenState();
}

class _MapLocateScannerScreenState extends State<MapLocateScannerScreen> {
  // Default formats on purpose: restricting to QR codes stopped the web
  // (zxing-wasm) decoder from finding anything in testing, while the default
  // works on web and native. Non-CS Explorer codes are filtered by `resolve`.
  final MobileScannerController _controller = MobileScannerController();

  static const String _defaultHint =
      'Point the camera at a station QR code or a "You are here" sticker.';

  bool _finished = false;
  String _hint = _defaultHint;
  bool _hintIsWarning = false;
  DateTime _lastUnknownAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void dispose() {
    unawaited(_controller.dispose());
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_finished) return;
    var sawCode = false;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null || raw.trim().isEmpty) continue;
      sawCode = true;
      final target = widget.resolve(raw);
      if (target != null) {
        _finished = true;
        unawaited(HapticFeedback.selectionClick());
        Navigator.of(context).pop(target);
        return;
      }
    }

    // The scanner also reports empty captures (e.g. when the camera starts),
    // so only warn when a real code was read but is not ours.
    if (!sawCode) return;
    final now = DateTime.now();
    if (now.difference(_lastUnknownAt) > const Duration(seconds: 2)) {
      _lastUnknownAt = now;
      setState(() {
        _hint =
            'That QR code is not a CS Explorer location. Try a station QR code or a "You are here" sticker.';
        _hintIsWarning = true;
      });
    }
  }

  Future<void> _retry() async {
    try {
      await _controller.start();
      if (mounted) {
        setState(() {
          _hint = _defaultHint;
          _hintIsWarning = false;
        });
      }
    } catch (_) {
      // The error builder shows the reason; nothing else to do here.
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => _ScannerErrorPanel(
              error: error,
              onRetry: _retry,
              onBackToMap: () => Navigator.of(context).pop(),
            ),
          ),
          // Viewfinder and hint only while the camera is working; the error
          // panel above explains what to do otherwise.
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: _controller,
            builder: (context, state, _) {
              if (state.error != null) return const SizedBox.shrink();
              return Stack(
                fit: StackFit.expand,
                children: [
                  IgnorePointer(
                    child: Center(
                      child: Container(
                        width: 236,
                        height: 236,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: Colors.white70, width: 3),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 24 + bottomInset,
                    child: _ScanHint(text: _hint, warning: _hintIsWarning),
                  ),
                ],
              );
            },
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    IconButton.filledTonal(
                      tooltip: 'Back to map',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: TrText(
                        'Locate me',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanHint extends StatelessWidget {
  const _ScanHint({required this.text, required this.warning});

  final String text;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    const amber = Color(0xFFE3A23B);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: warning ? amber : Colors.white24),
      ),
      child: Row(
        children: [
          Icon(
            warning ? Icons.help_outline_rounded : Icons.qr_code_scanner_rounded,
            color: warning ? amber : Colors.white,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TrText(
              text,
              style: const TextStyle(color: Colors.white, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerErrorPanel extends StatelessWidget {
  const _ScannerErrorPanel({
    required this.error,
    required this.onRetry,
    required this.onBackToMap,
  });

  final MobileScannerException error;
  final VoidCallback onRetry;
  final VoidCallback onBackToMap;

  bool get _isNativeMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Widget build(BuildContext context) {
    final (IconData icon, String title, String body) = switch (error.errorCode) {
      MobileScannerErrorCode.permissionDenied => (
        Icons.no_photography_rounded,
        'Camera access is blocked',
        'Allow camera access for CS Explorer in your phone settings (or the browser\'s site settings) and try again. You can also go back, tap a lift, stairs or call-pod marker on the map and choose "I\'m here".',
      ),
      MobileScannerErrorCode.unsupported => (
        Icons.videocam_off_rounded,
        'No camera available',
        'This device or browser cannot open the camera. Go back, tap a marker on the map and choose "I\'m here" instead.',
      ),
      _ => (
        Icons.videocam_off_rounded,
        'The camera could not start',
        'Close other apps that use the camera and try again, or go back and pick your spot on the map.',
      ),
    };

    return ColoredBox(
      color: const Color(0xFF151514),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 72, 28, 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 48, color: Colors.white70),
                  const SizedBox(height: 16),
                  TrText(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TrText(
                    body,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, height: 1.45),
                  ),
                  const SizedBox(height: 22),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      if (error.errorCode != MobileScannerErrorCode.unsupported)
                        FilledButton.icon(
                          onPressed: onRetry,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const TrText('Try again'),
                        ),
                      if (_isNativeMobile &&
                          error.errorCode ==
                              MobileScannerErrorCode.permissionDenied)
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white54),
                          ),
                          onPressed: () => unawaited(openAppSettings()),
                          icon: const Icon(Icons.settings_rounded),
                          label: const TrText('Open settings'),
                        ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white54),
                        ),
                        onPressed: onBackToMap,
                        icon: const Icon(Icons.map_outlined),
                        label: const TrText('Back to map'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:ar_flutter_plugin_plus/datatypes/node_types.dart';
import 'package:ar_flutter_plugin_plus/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin_plus/managers/ar_location_manager.dart';
import 'package:ar_flutter_plugin_plus/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin_plus/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin_plus/models/ar_anchor.dart';
import 'package:ar_flutter_plugin_plus/models/ar_node.dart';
import 'package:ar_flutter_plugin_plus/widgets/ar_view.dart';
import 'package:flutter/material.dart';

import 'ar_targets.dart';
import 'content.dart';
import 'computer_exhibit.dart';
import 'main.dart' show EntryCard;
import 'qr_screen.dart';

class ArPortraitScreen extends StatefulWidget {
  final GuideContent content;
  const ArPortraitScreen({super.key, required this.content});
  @override
  State<ArPortraitScreen> createState() => _ArPortraitScreenState();
}

class _ArPortraitScreenState extends State<ArPortraitScreen>
    with WidgetsBindingObserver {
  final gate = DetectionGate();
  final Map<String, ARNode> nodes = {};
  final Set<String> adding = {};
  final Map<String, int> revisions = {};
  List<ArTarget>? targets;
  ARSessionManager? session;
  ARObjectManager? objects;
  Timer? startupTimer;
  int epoch = 0;
  bool running = true, configured = false;
  String status = 'Loading reference portraits…';
  String? failure;
  bool showingContent = false;
  DateTime qrResumeAt = DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> showQr(String raw) async {
    if (showingContent || DateTime.now().isBefore(qrResumeAt)) return;
    final code = raw.trim();
    final entry = widget.content.findQr(code);
    if (code != computerQr && entry == null) return;
    showingContent = true;
    await pause();
    if (!mounted) return;
    await Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) =>
      code == computerQr ? const ComputerExhibit() : Scaffold(
        appBar: AppBar(title: const Text('Guide information')),
        body: SingleChildScrollView(child: EntryCard(entry: entry!)),
      )));
    if (!mounted) return;
    qrResumeAt = DateTime.now().add(const Duration(seconds: 3));
    showingContent = false;
    await restart();
  }

  Future<void> qrOnly() async {
    if (showingContent) return;
    showingContent = true;
    await pause();
    if (!mounted) return;
    final entry = await Navigator.of(context).push<GuideEntry>(MaterialPageRoute(builder: (_) => QrScreen(content: widget.content)));
    if (!mounted) return;
    if (entry != null) {
      await Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => Scaffold(appBar: AppBar(title: const Text('Guide information')), body: SingleChildScrollView(child: EntryCard(entry: entry)))));
    }
    if (mounted) {
      showingContent = false;
      await restart();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    load();
  }

  Future<void> load() async {
    try {
      final loaded = await ArTarget.load();
      for (final target in loaded) {
        if (!widget.content.portraits.containsKey(target.id)) {
          throw FormatException('Missing portrait information: ${target.id}');
        }
      }
      if (mounted) {
        setState(() {
          targets = loaded;
          status = 'Allow camera access, then point at a portrait or guide QR code.';
        });
      }
    } catch (e) {
      if (mounted) setState(() => failure = 'Unable to load reference images: $e');
    }
  }

  bool valid(int token) => mounted && running && token == epoch;

  ARViewCreatedCallback bindCreated(int token) =>
      (manager, objects, anchors, location) =>
          created(token, manager, objects, anchors, location);

  Future<void> created(
    int token,
    ARSessionManager manager,
    ARObjectManager objectManager,
    ARAnchorManager anchorManager,
    ARLocationManager locationManager,
  ) async {
    if (!valid(token)) {
      await manager.dispose();
      return;
    }
    session = manager;
    objects = objectManager;
    manager.onQrDetected = (raw) {
      if (valid(token) && failure == null) unawaited(showQr(raw));
    };
    manager.onSessionError = (message) {
      if (valid(token)) setState(() => failure = 'AR session error: $message');
    };
    manager.onImageTrackingConfigured = (success) {
      if (!valid(token)) return;
      startupTimer?.cancel();
      setState(() {
        configured = success;
        if (success) {
          status = 'Scanning portraits and guide QR codes. Hold steady.';
        } else {
          failure = 'Reference images could not be configured for AR tracking.';
        }
      });
    };
    manager.onTrackingStateChanged = (state, reason) {
      if (!valid(token)) return;
      setState(
        () => status = state == 'TRACKING'
            ? nodes.isEmpty
                  ? 'Point at a portrait or guide QR code.'
                  : 'Information is anchored beside the portrait. Move slowly.'
            : 'Tracking is limited. Move slowly in good light ($reason).',
      );
    };
    manager.onImageStopped = (id) {
      if (!valid(token)) return;
      revisions[id] = (revisions[id] ?? 0) + 1;
      gate.forget(id);
      final node = nodes.remove(id);
      if (node != null) objectManager.removeNode(node);
      setState(() => status = 'Portrait tracking ended. Scan a portrait or QR code.');
    };
    manager.onImageDetected = (name, transform) {
      if (valid(token) && configured && failure == null) {
        unawaited(detected(name, transform, token));
      }
    };
    startupTimer = Timer(const Duration(seconds: 25), () {
      if (valid(token) && !configured) {
        setState(
          () => failure =
              'AR could not start. Install or update Google Play Services for AR on Android. '
              'A supported ARCore / ARKit device is required. You can still use QR-only scanning.',
        );
      }
    });
    try {
      setState(() => status = 'Starting AR camera…');
      // Assets use real metres on both platforms; disable upstream scale factors.
      await objectManager.onInitialize(
        iosScaleFactor: 1,
        androidScaleFactor: 1,
      ).timeout(const Duration(seconds: 10));
      if (!valid(token)) return;
      await manager
          .onInitialize(
            showAnimatedGuide: false,
            showPlanes: false,
            showFeaturePoints: false,
            showWorldOrigin: false,
            handleTaps: false,
            handlePans: false,
            handleRotation: false,
            trackingImagePaths: targets!.map((target) => target.image).toList(),
            continuousImageTracking: true,
            imageTrackingUpdateIntervalMs: 150,
          )
          .timeout(const Duration(seconds: 20));
    } catch (e) {
      if (valid(token)) setState(() => failure = 'Unable to start AR: $e');
    }
  }

  Future<void> detected(String id, Matrix4 pose, int token) async {
    final matches = targets!.where((target) => target.id == id);
    if (matches.isEmpty ||
        nodes.containsKey(id) ||
        adding.contains(id) ||
        !gate.observe(id, DateTime.now()) ||
        !pose.storage.every((v) => v.isFinite)) {
      return;
    }
    final target = matches.first;
    final revision = revisions[id] ?? 0;
    final objectManager = objects!;
    adding.add(id);
    final node = ARNode(
      type: NodeType.localGLB,
      uri: target.panel,
      name: 'panel_${id}_${token}_$revision',
      transformation: target.panelTransform,
    );
    try {
      // Native bridge creates this image anchor before emitting the detection.
      // Its pose is updated by ARCore/ARKit each frame, NOT by network responses.
      final imageAnchor = ARPlaneAnchor(
        name: '__image_$id',
        transformation: pose,
      );
      final added = await objectManager
          .addNode(node, planeAnchor: imageAnchor)
          .timeout(const Duration(seconds: 12));
      if (!valid(token)) return;
      if ((revisions[id] ?? 0) != revision) {
        objectManager.removeNode(node);
        return;
      }
      if (added != true) {
        objectManager.removeNode(node);
        setState(() => failure = 'Unable to load information panel. Restart scanning. Reference: $id');
        return;
      }
      nodes[id] = node;
      setState(
        () => status = 'Recognised ${widget.content.portraits[id]!.title}. Information is beside the portrait.',
      );
    } catch (e) {
      if (valid(token)) {
        objectManager.removeNode(node);
        setState(() => failure = 'Unable to create information panel: $e');
      }
    } finally {
      if (valid(token)) adding.remove(id);
    }
  }

  Future<void> pause() async {
    epoch++;
    startupTimer?.cancel();
    final previous = session;
    session = null;
    objects = null;
    nodes.clear();
    adding.clear();
    revisions.clear();
    gate.clear();
    if (mounted) {
      setState(() {
        running = false;
        configured = false;
      });
    }
    if (previous != null) {
      try {
        await previous.dispose().timeout(const Duration(seconds: 3));
      } catch (_) {
        /* Native view disposal is the fallback. */
      }
    }
  }

  Future<void> restart() async {
    await pause();
    if (!mounted) return;
    setState(() {
      running = true;
      failure = null;
      status = 'Rebuilding tracking. Point at a portrait or QR code.';
    });
    if (targets == null) await load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !running && !showingContent) {
      unawaited(restart());
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      unawaited(pause());
    }
  }

  @override
  void dispose() {
    epoch++;
    startupTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    final previous = session;
    if (previous != null) unawaited(previous.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('CS Explorer · Scan'),
      actions: [
        IconButton(
          onPressed: restart,
          tooltip: 'Reset tracking',
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: Stack(
      children: [
        if (targets != null && running)
          ARView(
            key: ValueKey(epoch),
            onARViewCreated: bindCreated(epoch),
            permissionPromptDescription: 'Camera access is needed to scan portraits and QR codes.',
            permissionPromptButtonText: 'Allow camera / Open Settings',
            permissionPromptParentalRestriction: 'Camera access is restricted. Check device Settings.',
          ),
        if (!running)
          Center(
            child: FilledButton.icon(
              onPressed: restart,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Resume scanning'),
            ),
          ),
        if (failure != null)
          Positioned.fill(
            child: ColoredBox(
              color: const Color(0xeeffffff),
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.info_outline, size: 40),
                      const SizedBox(height: 16),
                      Text(failure!, textAlign: TextAlign.center),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: restart,
                        child: const Text('Restart scanning'),
                      ),
                      TextButton(
                        onPressed: qrOnly,
                        child: const Text('Use QR-only scanning'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        if (failure == null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 20,
            child: SafeArea(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Semantics(liveRegion: true, child: Text(status)),
                      if (targets?.any((target) => !target.measured) ==
                          true) ...[
                        const SizedBox(height: 8),
                        const Text(
                      'Portrait dimensions are not calibrated. Positioning is approximate.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.deepOrange,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

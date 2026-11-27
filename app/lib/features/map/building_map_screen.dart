import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:zenify/zenify.dart';

import '../../core/controllers.dart';
import '../../core/device_capabilities.dart';
import '../../core/models.dart';
import '../../core/translation_service.dart';
import '../../ui/puzzle_icon.dart';
import '../../ui/theme.dart';
import 'cs_building_map_data.dart';
import 'floor_plan_painter.dart';
import 'locate_scanner_screen.dart';
import 'map_models.dart';
import 'map_panels.dart';
import 'map_pins.dart';
import 'map_positioning.dart';

/// Opens a QR scanner and returns what was recognised (or `null`).
/// Injectable so widget tests can simulate a scan without a camera.
typedef MapScanLauncher =
    Future<MapScanTarget?> Function(
      BuildContext context,
      MapScanTarget? Function(String raw) resolve,
    );

/// Mustafa's interactive CS building map.
///
/// - Floor plans for 1F / 2F / 3F with pinch-zoom and pan.
/// - Tour stations coloured by the shared Red / Green / Blue status, with
///   lock and puzzle-piece badges (where the hidden pieces are).
/// - Call pods "lit up" on 2F and 3F, plus lift, stairs, toilets, entrances
///   and parking.
/// - "You are here" from the last station QR, or from a map-only QR sticker
///   scanned with the **Locate me** button.
class CsBuildingMapScreen extends StatefulWidget {
  const CsBuildingMapScreen({
    super.key,
    required this.progress,
    required this.settings,
    required this.onOpenStation,
    required this.onBackToLobby,
    this.scanLauncher,
  });

  final TourProgressController progress;
  final AppSettingsController settings;
  final ValueChanged<String> onOpenStation;
  final VoidCallback onBackToLobby;
  final MapScanLauncher? scanLauncher;

  @override
  State<CsBuildingMapScreen> createState() => _CsBuildingMapScreenState();
}

/// What the visitor tapped on the map.
@immutable
class _Selection {
  const _Selection.station(this.id) : isStation = true;
  const _Selection.place(this.id) : isStation = false;

  final bool isStation;
  final String id;

  @override
  bool operator ==(Object other) =>
      other is _Selection && other.isStation == isStation && other.id == id;

  @override
  int get hashCode => Object.hash(isStation, id);
}

/// A widget pinned to a plan coordinate on top of the zoomable floor plan.
class _OverlayItem {
  const _OverlayItem({
    required this.id,
    required this.plan,
    required this.size,
    required this.anchor,
    required this.builder,
    this.minPxPerMetre = 0,
  });

  final String id;
  final Offset plan;
  final Size size;

  /// Point inside [size] that sits exactly on [plan].
  final Offset anchor;
  final Widget Function(double pxPerMetre) builder;
  final double minPxPerMetre;
}

class _CsBuildingMapScreenState extends State<CsBuildingMapScreen>
    with SingleTickerProviderStateMixin {
  static const double _wideBreakpoint = 880;
  static const double _captionPxPerMetre = 5.2;
  static const double _maxZoom = 6;
  static const double _boundary = 48;

  late final MapPositionStore _store = MapPositionStore(widget.progress.prefs);
  final TransformationController _transform = TransformationController();
  late final AnimationController _camera = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  )..addListener(_onCameraTick);
  Animation<Matrix4>? _cameraTween;

  late int _floor;
  _Selection? _selection;
  final Set<MapLayer> _layers = {...MapLayer.values};

  bool _isWide = false;
  bool _initialCameraApplied = false;
  String? _lastUserPositionKey;
  Size _viewport = Size.zero;
  PlanProjection? _projection;

  TourProgressController get _progress => widget.progress;
  StationCatalogRepository get _catalog => widget.progress.catalog;
  bool get _supportsCameraScan => DeviceCapabilities.supportsCameraScan;
  bool get _supportsArExperiences => DeviceCapabilities.supportsArExperiences;
  bool get _autoUnlockStations => DeviceCapabilities.autoUnlockStations;

  static String? _positionKey(UserMapPosition? position) => switch (position) {
    MarkerUserPosition(:final place) => 'marker:${place.id}',
    StationUserPosition(:final station) => 'station:${station.id}',
    null => null,
  };

  @override
  void initState() {
    super.initState();
    final initialPosition = resolveUserMapPosition(
      progress: _progress,
      store: _store,
    );
    _lastUserPositionKey = _positionKey(initialPosition);
    _floor = initialPosition?.floor ?? CsBuildingMapData.floors.first;
  }

  @override
  void dispose() {
    _camera.dispose();
    _transform.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Camera (pan / zoom animations)
  // ---------------------------------------------------------------------------

  void _onCameraTick() {
    final tween = _cameraTween;
    if (tween != null) _transform.value = tween.value;
  }

  void _animateCamera(Matrix4 target) {
    _cameraTween = Matrix4Tween(
      begin: _transform.value.clone(),
      end: target,
    ).animate(CurvedAnimation(parent: _camera, curve: Curves.easeOutCubic));
    _camera
      ..reset()
      ..forward();
  }

  Matrix4 _cameraMatrix(double zoom, Offset translation) => Matrix4(
    zoom, 0, 0, 0, //
    0, zoom, 0, 0, //
    0, 0, 1, 0, //
    translation.dx, translation.dy, 0, 1, //
  );

  Offset _clampTranslation(Offset t, double zoom) {
    final minX = _viewport.width * (1 - zoom) - _boundary;
    final minY = _viewport.height * (1 - zoom) - _boundary;
    return Offset(t.dx.clamp(minX, _boundary), t.dy.clamp(minY, _boundary));
  }

  bool get _detailsCoverMap => !_isWide && _selection != null;

  /// Centres [planPoint], zooming in to at least [minPxPerMetre].
  void _centerOn(Offset planPoint, {double minPxPerMetre = 9}) {
    final projection = _projection;
    if (projection == null || _viewport.isEmpty) return;
    final current = _transform.value.getMaxScaleOnAxis();
    final zoom = math
        .max(current, minPxPerMetre / projection.scale)
        .clamp(1.0, _maxZoom);
    final canvasPoint = projection.toCanvas(planPoint);
    final focusY = _detailsCoverMap
        ? _viewport.height * 0.32
        : _viewport.height / 2;
    final translation = Offset(
      _viewport.width / 2 - canvasPoint.dx * zoom,
      focusY - canvasPoint.dy * zoom,
    );
    _animateCamera(_cameraMatrix(zoom, _clampTranslation(translation, zoom)));
  }

  /// Pans only if [planPoint] is hidden (e.g. behind the details card).
  void _ensureVisible(Offset planPoint) {
    final projection = _projection;
    if (projection == null || _viewport.isEmpty) return;
    final screen = MatrixUtils.transformPoint(
      _transform.value,
      projection.toCanvas(planPoint),
    );
    final safeBottom = _detailsCoverMap
        ? _viewport.height * 0.40
        : _viewport.height - 56;
    final safe = Rect.fromLTRB(56, 48, _viewport.width - 56, safeBottom);
    if (!safe.contains(screen)) _centerOn(planPoint, minPxPerMetre: 0);
  }

  void _zoomBy(double factor) {
    if (_viewport.isEmpty) return;
    final zoom = (_transform.value.getMaxScaleOnAxis() * factor).clamp(
      1.0,
      _maxZoom,
    );
    final centre = _viewport.center(Offset.zero);
    final scenePoint = _transform.toScene(centre);
    final translation = centre - scenePoint * zoom;
    _animateCamera(_cameraMatrix(zoom, _clampTranslation(translation, zoom)));
  }

  void _resetView() => _animateCamera(Matrix4.identity());

  /// On phones the whole floor is tiny, so the first view zooms in around
  /// the visitor. Runs once per visit to the map; "Show whole floor" undoes it.
  void _applyInitialCamera(UserMapPosition? position) {
    if (_initialCameraApplied) return;
    _initialCameraApplied = true;
    final projection = _projection;
    if (_isWide || projection == null || _viewport.isEmpty) return;
    final zoom = (4.4 / projection.scale).clamp(1.0, _maxZoom);
    if (zoom <= 1.05) return;
    final focus = position?.position ?? CsBuildingMapData.buildingSize.center(Offset.zero);
    final canvasPoint = projection.toCanvas(focus);
    final translation = _clampTranslation(
      Offset(
        _viewport.width / 2 - canvasPoint.dx * zoom,
        _viewport.height * 0.45 - canvasPoint.dy * zoom,
      ),
      zoom,
    );
    // Set before the first paint so there is no visible jump.
    _transform.value = _cameraMatrix(zoom, translation);
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  void _setFloor(int floor) {
    if (floor == _floor) return;
    setState(() {
      _floor = floor;
      if (!_selectionIsOnFloor(floor)) _selection = null;
    });
  }

  bool _selectionIsOnFloor(int floor) {
    final selection = _selection;
    if (selection == null) return true;
    if (selection.isStation) {
      final station = _catalog.findById(selection.id);
      return station != null && CsBuildingMapData.floorFor(station) == floor;
    }
    return CsBuildingMapData.placeById(selection.id)?.floor == floor;
  }

  void _select(_Selection selection, Offset planPoint) {
    setState(() => _selection = selection);
    _ensureVisible(planPoint);
  }

  void _clearSelection() {
    if (_selection != null) setState(() => _selection = null);
  }

  void _toggleLayer(MapLayer layer, bool visible) {
    setState(() => visible ? _layers.add(layer) : _layers.remove(layer));
  }

  void _showUser(UserMapPosition position) {
    setState(() => _floor = position.floor);
    _centerOn(position.position);
  }

  Future<void> _locateMe() async {
    if (!_supportsCameraScan && widget.scanLauncher == null) return;
    final launcher = widget.scanLauncher ?? _openCameraScanner;
    final target = await launcher(
      context,
      (raw) => MapCodeResolver.resolve(raw, catalog: _catalog),
    );
    if (!mounted || target == null) return;
    _applyScanTarget(target);
  }

  static Future<MapScanTarget?> _openCameraScanner(
    BuildContext context,
    MapScanTarget? Function(String raw) resolve,
  ) {
    return Navigator.of(context).push<MapScanTarget>(
      MaterialPageRoute<MapScanTarget>(
        builder: (_) => MapLocateScannerScreen(resolve: resolve),
      ),
    );
  }

  void _applyScanTarget(MapScanTarget target) {
    switch (target) {
      case StationScanTarget(:final stationId):
        final station = _catalog.findById(stationId);
        if (station == null) return;
        // Same effect as the main scanner: scanning a station QR means the
        // visitor is there, so it is unlocked and becomes the Red station.
        _progress.unlockAndSetCurrentStation(station.id);
        _store.clear();
        _lastUserPositionKey = 'station:${station.id}';
        setState(() {
          _floor = CsBuildingMapData.floorFor(station);
          _selection = _Selection.station(station.id);
        });
        _centerOn(CsBuildingMapData.placementFor(station).position);
        _announce(station.title);
      case MarkerScanTarget(:final place):
        _setMarkerPosition(place);
    }
  }

  void _setMarkerPosition(MapPlace place) {
    _lastUserPositionKey = 'marker:${place.id}';
    _store.setMarker(place.id, stationAtScan: _progress.currentStationId.value);
    setState(() {
      _floor = place.floor;
      _selection = _Selection.place(place.id);
    });
    _centerOn(place.position);
    _announce('${place.label} (${CsBuildingMapData.floorShort(place.floor)})');
  }

  void _announce(String where) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.fromLTRB(
            16,
            0,
            16,
            MediaQuery.paddingOf(context).bottom + 100,
          ),
          content: Row(
            children: [
              const Icon(Icons.my_location_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              const TrText('You are here:'),
              const SizedBox(width: 6),
              Expanded(
                child: TrText(where, maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
      );
  }

  void _showLegendSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: MapLegend(showMobileFeatures: _supportsCameraScan),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: ZenObserver(() {
          // Reading these observables makes the map rebuild whenever the
          // tour state changes anywhere in the app (scans, demo mode…).
          final currentStationId = _progress.currentStationId.value;
          final visitedCount = _progress.visitedStationIds.value.length;
          final collectedCount = _progress.collectedPuzzleIds.value.length;
          final _ = _progress.mapMarkerRevision.value;
          final demoUnlock = widget.settings.demoUnlockAll.value;
          final position = resolveUserMapPosition(
            progress: _progress,
            store: _store,
          );
          final posKey = _positionKey(position);
          if (posKey != null && posKey != _lastUserPositionKey) {
            _lastUserPositionKey = posKey;
            if (position != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _showUser(position);
              });
            }
          }
          final snapshot = _MapSnapshot(
            position: position,
            demoUnlock: demoUnlock,
            currentStationId: currentStationId,
            visitedCount: visitedCount,
            collectedCount: collectedCount,
          );

          return LayoutBuilder(
            builder: (context, constraints) {
              _isWide = constraints.maxWidth >= _wideBreakpoint;
              return _isWide
                  ? _buildWide(context, snapshot, constraints.maxWidth)
                  : _buildNarrow(context, snapshot, constraints.maxWidth);
            },
          );
        }),
      ),
    );
  }

  Widget _buildNarrow(BuildContext context, _MapSnapshot s, double width) {
    final bottomClearance = MediaQuery.paddingOf(context).bottom + 92;
    final selection = _selection;
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 8, 12, bottomClearance),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(context, iconOnlyLocate: width < 380),
          const SizedBox(height: 8),
          _buildPositionStrip(context, s),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: _buildFloorSelector(s)),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: _layerChips()),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => Stack(
                children: [
                  Positioned.fill(child: _buildMapCard(context, s)),
                  if (selection != null)
                    Positioned(
                      left: 8,
                      right: 8,
                      bottom: 8,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: constraints.maxHeight * 0.6,
                        ),
                        child: _buildDetailsCard(
                          context,
                          s,
                          selection,
                          floating: true,
                        ),
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

  Widget _buildWide(BuildContext context, _MapSnapshot s, double width) {
    final bottomClearance = MediaQuery.paddingOf(context).bottom + 92;
    final selection = _selection;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottomClearance),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(context, iconOnlyLocate: false),
          const SizedBox(height: 12),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _buildFloorSelector(s),
                          Wrap(runSpacing: 8, children: _layerChips()),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Expanded(child: _buildMapCard(context, s)),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 330,
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      _buildPositionCard(context, s),
                      const SizedBox(height: 12),
                      if (selection != null) ...[
                        _buildDetailsCard(context, s, selection, floating: false),
                        const SizedBox(height: 12),
                      ],
                      _buildFloorListCard(context, s),
                      const SizedBox(height: 12),
                      _card(
                        context,
                        child: MapLegend(showMobileFeatures: _supportsCameraScan),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(BuildContext context, {required Widget child, bool floating = false}) {
    final theme = Theme.of(context);
    return Card(
      elevation: floating ? 6 : 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
        ),
      ),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }

  Widget _buildHeader(BuildContext context, {required bool iconOnlyLocate}) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Semantics(
          button: true,
          label: 'Back to Lobby',
          excludeSemantics: true,
          child: Material(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: widget.onBackToLobby,
              child: const SizedBox(
                width: 48,
                height: 48,
                child: Icon(Icons.chevron_left_rounded, size: 28),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              TrText(
                'CS Building Map',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              TrText(
                'Schematic plan - positions are approximate',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
                ),
              ),
            ],
          ),
        ),
        if (_supportsCameraScan) ...[
          const SizedBox(width: 8),
          if (iconOnlyLocate)
            IconButton.filled(
              tooltip: 'Locate me (scan a QR code)',
              onPressed: _locateMe,
              icon: const Icon(Icons.qr_code_scanner_rounded),
            )
          else
            FilledButton.icon(
              onPressed: _locateMe,
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: const TrText('Locate me'),
            ),
        ],
      ],
    );
  }

  Widget _buildPositionStrip(BuildContext context, _MapSnapshot s) {
    final theme = Theme.of(context);
    final position = s.position;
    return Material(
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: position == null
            ? (_supportsCameraScan ? _locateMe : null)
            : () => _showUser(position),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.my_location_rounded, color: kYouAreHereRed, size: 18),
              const SizedBox(width: 8),
              if (position == null)
                Expanded(
                  child: TrText(
                    _supportsCameraScan
                        ? 'Scan a QR code to show where you are'
                        : 'Tap a floor or station to explore',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                )
              else ...[
                Text(
                  '${CsBuildingMapData.floorShort(position.floor)} · ',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Expanded(
                  child: TrText(
                    position.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              if (_supportsArExperiences) ...[
                const SizedBox(width: 8),
                Semantics(
                  label:
                      'Puzzle pieces collected: ${_progress.collectedPuzzleCount} of ${_progress.totalPuzzleStations}',
                  excludeSemantics: true,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PuzzlePieceIcon(
                        collected: _progress.collectedPuzzleCount > 0,
                        size: 16,
                        activeColor: kPuzzleGold,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${_progress.collectedPuzzleCount}/${_progress.totalPuzzleStations}',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloorSelector(_MapSnapshot s) {
    return SegmentedButton<int>(
      showSelectedIcon: false,
      segments: [
        for (final floor in CsBuildingMapData.floors)
          ButtonSegment<int>(
            value: floor,
            tooltip: CsBuildingMapData.floorName(floor),
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(CsBuildingMapData.floorShort(floor)),
                if (s.position?.floor == floor) ...[
                  const SizedBox(width: 6),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: kYouAreHereRed,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
      selected: {_floor},
      onSelectionChanged: (selected) => _setFloor(selected.first),
    );
  }

  List<Widget> _layerChips() {
    Widget chip(MapLayer layer, Widget avatar, String label) => Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        avatar: avatar,
        label: TrText(label),
        selected: _layers.contains(layer),
        showCheckmark: false,
        visualDensity: VisualDensity.compact,
        onSelected: (visible) => _toggleLayer(layer, visible),
      ),
    );

    return [
      chip(
        MapLayer.stations,
        const Icon(Icons.place_rounded, size: 16),
        'Stations',
      ),
      if (_supportsArExperiences)
        chip(
          MapLayer.puzzlePieces,
          const PuzzlePieceIcon(collected: true, size: 16, activeColor: kPuzzleGold),
          'Puzzle pieces',
        ),
      chip(
        MapLayer.callPods,
        const Icon(Icons.phone_in_talk_rounded, size: 16, color: kCallPodGlow),
        'Call pods',
      ),
      chip(
        MapLayer.facilities,
        const Icon(Icons.elevator_rounded, size: 16),
        'Facilities',
      ),
    ];
  }

  Widget _buildMapCard(BuildContext context, _MapSnapshot s) {
    final theme = Theme.of(context);
    final palette = MapPalette.of(theme);
    final position = s.position;
    final mutedStyle = theme.textTheme.labelSmall?.copyWith(
      color: palette.mutedLabel,
      fontSize: 9.5,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.site,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(21),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final viewport = constraints.biggest;
            final projection = PlanProjection.fit(
              viewport,
              CsBuildingMapData.planBounds,
            );
            _viewport = viewport;
            _projection = projection;
            _applyInitialCamera(s.position);
            final items = _overlayItems(palette, s);

            return Stack(
              children: [
                Positioned.fill(
                  child: InteractiveViewer(
                    transformationController: _transform,
                    minScale: 1,
                    maxScale: _maxZoom,
                    boundaryMargin: const EdgeInsets.all(_boundary),
                    onInteractionStart: (_) => _camera.stop(),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _clearSelection,
                      child: CustomPaint(
                        size: viewport,
                        painter: FloorPlanPainter(
                          floor: _floor,
                          projection: projection,
                          palette: palette,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: _MapOverlay(
                    transform: _transform,
                    projection: projection,
                    items: items,
                  ),
                ),
                const Positioned(
                  left: 10,
                  top: 10,
                  child: MapCompass(
                    rotationDegrees: CsBuildingMapData.northRotationDegrees,
                  ),
                ),
                Positioned(
                  right: 10,
                  top: 10,
                  child: MapZoomControls(
                    onZoomIn: () => _zoomBy(1.6),
                    onZoomOut: () => _zoomBy(1 / 1.6),
                    onReset: _resetView,
                    onMyLocation: position == null
                        ? null
                        : () => _showUser(position),
                    onLegend: _isWide ? null : _showLegendSheet,
                  ),
                ),
                if (position != null && position.floor != _floor)
                  Positioned(
                    top: 12,
                    left: 56,
                    right: 64,
                    child: Center(
                      child: OffFloorBanner(
                        floor: position.floor,
                        onTap: () => _showUser(position),
                      ),
                    ),
                  ),
                Positioned(
                  left: 12,
                  bottom: 6,
                  child: IgnorePointer(
                    child: Text(
                      'Outline © OpenStreetMap contributors',
                      style: mutedStyle,
                    ),
                  ),
                ),
                Positioned(
                  right: 12,
                  bottom: 6,
                  child: IgnorePointer(
                    child: TrText(
                      CsBuildingMapData.floorName(_floor),
                      style: mutedStyle?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<_OverlayItem> _overlayItems(MapPalette palette, _MapSnapshot s) {
    final items = <_OverlayItem>[];

    // 1. Zone captions ("Main lobby", "Konemiehentie"…).
    for (final zone in CsBuildingMapData.zonesOnFloor(_floor)) {
      final label = zone.label;
      if (label == null) continue;
      final turns = switch (zone.kind) {
        MapZoneKind.road => 1,
        MapZoneKind.neighbourBuilding => 3,
        _ => 0,
      };
      final size = MapZoneLabel.sizeFor(turns);
      items.add(
        _OverlayItem(
          id: 'zone-${zone.kind.name}-$label-${zone.labelAt}',
          plan: zone.labelAt ?? zone.centre,
          size: size,
          anchor: size.center(Offset.zero),
          minPxPerMetre: zone.minPxPerMetreForLabel,
          builder: (_) => MapZoneLabel(
            text: label,
            color: palette.mutedLabel,
            translate: zone.translateLabel,
            quarterTurns: turns,
          ),
        ),
      );
    }

    // 2. Facilities and call pods.
    for (final place in CsBuildingMapData.placesOnFloor(_floor)) {
      if (!_layers.contains(place.layer)) continue;
      final selection = _Selection.place(place.id);
      final selected = _selection == selection;
      final captionAt = place.kind == MapPlaceKind.callPod
          ? _captionPxPerMetre
          : 9.0;
      items.add(
        _OverlayItem(
          id: 'place-${place.id}',
          plan: place.position,
          size: const Size(PlaceMapPin.boxWidth, PlaceMapPin.boxHeight),
          anchor: PlaceMapPin.anchor,
          minPxPerMetre: selected ? 0 : place.minPxPerMetre,
          builder: (px) => PlaceMapPin(
            place: place,
            selected: selected,
            showCaption: px >= captionAt,
            onTap: () => _select(selection, place.position),
          ),
        ),
      );
    }

    // 3. Pulsing "You are here" beacon (under the station pins).
    final position = s.position;
    final here = (position != null && position.floor == _floor) ? position : null;
    if (here != null) {
      items.add(
        _OverlayItem(
          id: 'beacon',
          plan: here.position,
          size: const Size.square(YouAreHereBeacon.size),
          anchor: YouAreHereBeacon.anchor,
          builder: (_) => YouAreHereBeacon(showDot: here is MarkerUserPosition),
        ),
      );
    }

    // 4. Tour stations (with puzzle-piece badges).
    final showStations = _layers.contains(MapLayer.stations);
    final showPuzzle =
        _supportsArExperiences && _layers.contains(MapLayer.puzzlePieces);
    final allowBrowseAll = s.demoUnlock || _autoUnlockStations;
    for (final station in _catalog.stations) {
      if (CsBuildingMapData.floorFor(station) != _floor) continue;
      final placement = CsBuildingMapData.placementFor(station);
      final selection = _Selection.station(station.id);
      final selected = _selection == selection;
      final collected = _progress.hasCollectedPiece(station.id);
      final isHere =
          here is StationUserPosition && here.station.id == station.id;
      void onTap() => _select(selection, placement.position);

      if (showStations) {
        final status = _progress.statusFor(station.id);
        final unlocked = _progress.isStationUnlocked(
          station.id,
          demoUnlockAll: allowBrowseAll,
        );
        final puzzle = (!showPuzzle || !station.hasPuzzlePiece)
            ? PuzzleBadge.none
            : (collected ? PuzzleBadge.collected : PuzzleBadge.hidden);
        items.add(
          _OverlayItem(
            id: 'station-${station.id}',
            plan: placement.position,
            size: const Size(StationMapPin.boxWidth, StationMapPin.boxHeight),
            anchor: StationMapPin.anchor,
            builder: (px) => StationMapPin(
              icon: placement.icon,
              color: CsStatusColors.forStatus(status),
              caption: placement.shortLabel,
              showCaption: px >= _captionPxPerMetre || isHere,
              locked: !unlocked,
              puzzle: puzzle,
              selected: selected,
              semanticLabel: _stationSemantics(station, status, unlocked, collected),
              onTap: onTap,
            ),
          ),
        );
      } else if (showPuzzle && station.hasPuzzlePiece) {
        items.add(
          _OverlayItem(
            id: 'puzzle-${station.id}',
            plan: placement.position,
            size: const Size.square(PuzzleMapMarker.size),
            anchor: PuzzleMapMarker.anchor,
            builder: (_) => PuzzleMapMarker(
              collected: collected,
              semanticLabel:
                  '${placement.shortLabel}: ${collected ? 'puzzle piece collected' : 'puzzle piece still hidden here'}',
              onTap: onTap,
            ),
          ),
        );
      }
    }

    // 5. "You are here" chip on top of everything.
    if (here != null) {
      items.add(
        _OverlayItem(
          id: 'here-chip',
          plan: here.position,
          size: YouAreHereChip.size,
          anchor: YouAreHereChip.anchor,
          builder: (_) => const YouAreHereChip(),
        ),
      );
    }
    return items;
  }

  String _stationSemantics(
    StationSpec station,
    StationVisitStatus status,
    bool unlocked,
    bool collected,
  ) {
    final statusText = switch (status) {
      StationVisitStatus.current => 'current station',
      StationVisitStatus.visited => 'visited',
      StationVisitStatus.unvisited => 'not visited yet',
    };
    final puzzleText = station.hasPuzzlePiece
        ? (collected ? ', puzzle piece collected' : ', puzzle piece still hidden')
        : '';
    return '${station.title}, ${CsBuildingMapData.floorName(CsBuildingMapData.floorFor(station))}, '
        '$statusText, ${unlocked ? 'unlocked' : 'locked'}$puzzleText';
  }

  // ---------------------------------------------------------------------------
  // Side panels / details
  // ---------------------------------------------------------------------------

  Widget _buildDetailsCard(
    BuildContext context,
    _MapSnapshot s,
    _Selection selection, {
    required bool floating,
  }) {
    final content = selection.isStation
        ? _stationDetails(context, s, selection.id)
        : _placeDetails(context, s, selection.id);
    if (content == null) return const SizedBox.shrink();
    if (!floating) return _card(context, child: content);

    final theme = Theme.of(context);
    return Card(
      elevation: 6,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: content,
      ),
    );
  }

  Widget _detailsHeader(
    BuildContext context, {
    required Widget leading,
    required String title,
    required String subtitle,
    bool translateSubtitle = true,
  }) {
    final theme = Theme.of(context);
    final subtitleStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurface.withValues(alpha: 0.64),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        leading,
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TrText(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              translateSubtitle
                  ? TrText(subtitle, style: subtitleStyle)
                  : Text(subtitle, style: subtitleStyle),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Close',
          onPressed: _clearSelection,
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    );
  }

  Widget? _stationDetails(BuildContext context, _MapSnapshot s, String id) {
    final station = _catalog.findById(id);
    if (station == null) return null;
    final theme = Theme.of(context);
    final placement = CsBuildingMapData.placementFor(station);
    final status = _progress.statusFor(station.id);
    final unlocked = _progress.isStationUnlocked(
      station.id,
      demoUnlockAll: s.demoUnlock || _autoUnlockStations,
    );
    final collected = _progress.hasCollectedPiece(station.id);
    final color = CsStatusColors.forStatus(status);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _detailsHeader(
          context,
          leading: MapRoundIcon(icon: placement.icon, color: color),
          title: station.title,
          subtitle: station.floorLabel,
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            MapStatusPill(
              color: color,
              label: switch (status) {
                StationVisitStatus.current => 'Current station',
                StationVisitStatus.visited => 'Visited',
                StationVisitStatus.unvisited => 'Not visited yet',
              },
            ),
            if (!unlocked)
              const MapStatusPill(icon: Icons.lock_rounded, label: 'Locked'),
            if (_supportsArExperiences && station.hasPuzzlePiece)
              MapStatusPill(
                color: collected ? kPuzzleGold : null,
                leading: PuzzlePieceIcon(
                  collected: collected,
                  size: 14,
                  activeColor: kPuzzleGold,
                ),
                label: collected
                    ? 'Puzzle piece collected'
                    : 'Puzzle piece hidden here',
              ),
          ],
        ),
        const SizedBox(height: 10),
        TrText(
          station.subtitle,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            height: 1.4,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 12),
        if (unlocked)
          FilledButton.icon(
            onPressed: () => widget.onOpenStation(station.id),
            icon: const Icon(Icons.menu_book_rounded),
            label: const TrText('Open guide'),
          )
        else ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.qr_code_2_rounded,
                size: 18,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TrText(
                  station.scanHintParenthetical.trim().isEmpty
                      ? 'Scan the marker on site to unlock this station'
                      : 'Scan the marker on site to unlock this station ${station.scanHintParenthetical.trim()}',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
          if (_supportsCameraScan) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _locateMe,
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: const TrText('Scan a QR code'),
            ),
          ],
        ],
      ],
    );
  }

  Widget? _placeDetails(BuildContext context, _MapSnapshot s, String id) {
    final place = CsBuildingMapData.placeById(id);
    if (place == null) return null;
    final theme = Theme.of(context);
    final position = s.position;
    final isHere = position is MarkerUserPosition && position.place.id == place.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _detailsHeader(
          context,
          leading: MapRoundIcon(
            icon: iconForPlace(place.kind),
            color: place.kind == MapPlaceKind.callPod
                ? kCallPodGlow
                : theme.colorScheme.secondary,
          ),
          title: place.label,
          subtitle: CsBuildingMapData.floorName(place.floor),
        ),
        const SizedBox(height: 10),
        TrText(
          place.description,
          style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
        ),
        if (place.hasQrMarker) ...[
          const SizedBox(height: 12),
          if (isHere)
            const MapStatusPill(color: kYouAreHereRed, label: 'You are here')
          else
            OutlinedButton.icon(
              onPressed: () => _setMarkerPosition(place),
              icon: const Icon(Icons.my_location_rounded),
              label: const TrText("I'm here"),
            ),
          if (_supportsCameraScan) ...[
            const SizedBox(height: 8),
            TrText(
              'Tip: scan the "You are here" QR sticker at this spot to update your position automatically.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.64),
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildPositionCard(BuildContext context, _MapSnapshot s) {
    final theme = Theme.of(context);
    final position = s.position;
    final totalStations = _catalog.stations.length;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurface.withValues(alpha: 0.64),
    );

    return _card(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.my_location_rounded, color: kYouAreHereRed, size: 20),
              const SizedBox(width: 8),
              TrText(
                'Your position',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (position == null)
            TrText(
              _supportsCameraScan
                  ? 'Scan any station QR code or a "You are here" sticker to show where you are.'
                  : 'Select any station on the map or sidebar to explore the building.',
            )
          else ...[
            TrText(
              position.label,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Wrap(
              spacing: 6,
              children: [
                TrText(CsBuildingMapData.floorName(position.floor), style: muted),
                Text('·', style: muted),
                TrText(
                  position is MarkerUserPosition
                      ? (_supportsCameraScan
                            ? 'from a "You are here" QR code'
                            : 'selected map spot')
                      : (_supportsCameraScan
                            ? 'last station you scanned'
                            : 'selected station'),
                  style: muted,
                ),
              ],
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => _showUser(position),
              icon: const Icon(Icons.center_focus_strong_rounded),
              label: const TrText('Show on map'),
            ),
          ],
          const Divider(height: 26),
          if (_supportsArExperiences) ...[
            Row(
              children: [
                const PuzzlePieceIcon(
                  collected: true,
                  size: 18,
                  activeColor: kPuzzleGold,
                ),
                const SizedBox(width: 8),
                const Expanded(child: TrText('Puzzle pieces collected')),
                Text(
                  '${_progress.collectedPuzzleCount} / ${_progress.totalPuzzleStations}',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.flag_rounded,
                  size: 18,
                  color: CsStatusColors.visitedGreen,
                ),
                const SizedBox(width: 8),
                const Expanded(child: TrText('Stations visited')),
                Text(
                  '${math.min(s.visitedCount, totalStations)} / $totalStations',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ] else ...[
            Row(
              children: [
                Icon(
                  Icons.explore_outlined,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TrText('All $totalStations stations open to browse'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TrText(
                    'QR scanning & AR puzzle hunt are mobile-only',
                    style: muted,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFloorListCard(BuildContext context, _MapSnapshot s) {
    final theme = Theme.of(context);
    final stations = _catalog.stations
        .where((st) => CsBuildingMapData.floorFor(st) == _floor)
        .toList();
    final spots = CsBuildingMapData.placesOnFloor(_floor)
        .where((p) => p.kind == MapPlaceKind.callPod || p.hasQrMarker)
        .toList();

    Widget tile({
      required Widget leading,
      required String title,
      Widget? trailing,
      required VoidCallback onTap,
      required bool selected,
    }) {
      return ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        visualDensity: VisualDensity.compact,
        selected: selected,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: leading,
        title: TrText(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: trailing,
        onTap: onTap,
      );
    }

    return _card(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TrText(
                  'On this floor',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TrText(CsBuildingMapData.floorName(_floor), style: theme.textTheme.labelMedium),
            ],
          ),
          const SizedBox(height: 6),
          if (stations.isEmpty && spots.isEmpty)
            const TrText('No stations on this floor.'),
          for (final station in stations)
            Builder(
              builder: (context) {
                final placement = CsBuildingMapData.placementFor(station);
                final unlocked = _progress.isStationUnlocked(
                  station.id,
                  demoUnlockAll: s.demoUnlock || _autoUnlockStations,
                );
                final selection = _Selection.station(station.id);
                return tile(
                  leading: Icon(
                    placement.icon,
                    color: CsStatusColors.forStatus(_progress.statusFor(station.id)),
                  ),
                  title: placement.shortLabel,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!unlocked) const Icon(Icons.lock_rounded, size: 16),
                      if (_supportsArExperiences && station.hasPuzzlePiece) ...[
                        const SizedBox(width: 6),
                        PuzzlePieceIcon(
                          collected: _progress.hasCollectedPiece(station.id),
                          size: 16,
                          activeColor: kPuzzleGold,
                        ),
                      ],
                    ],
                  ),
                  selected: _selection == selection,
                  onTap: () {
                    setState(() => _selection = selection);
                    _centerOn(placement.position);
                  },
                );
              },
            ),
          if (stations.isNotEmpty && spots.isNotEmpty) const Divider(height: 14),
          for (final place in spots)
            tile(
              leading: Icon(
                iconForPlace(place.kind),
                color: place.kind == MapPlaceKind.callPod ? kCallPodGlow : null,
              ),
              title: place.label,
              trailing: _supportsCameraScan && place.hasQrMarker
                  ? Tooltip(
                      message: 'Has a "You are here" QR sticker',
                      child: Icon(
                        Icons.qr_code_2_rounded,
                        size: 18,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    )
                  : null,
              selected: _selection == _Selection.place(place.id),
              onTap: () {
                setState(() => _selection = _Selection.place(place.id));
                _centerOn(place.position);
              },
            ),
        ],
      ),
    );
  }
}

/// Values read from the shared controllers for one build.
class _MapSnapshot {
  const _MapSnapshot({
    required this.position,
    required this.demoUnlock,
    required this.currentStationId,
    required this.visitedCount,
    required this.collectedCount,
  });

  final UserMapPosition? position;
  final bool demoUnlock;
  final String currentStationId;
  final int visitedCount;
  final int collectedCount;
}

/// Positions pins and labels on top of the zoomable plan. Rebuilds on every
/// pan/zoom frame, so pins keep a constant on-screen size.
class _MapOverlay extends StatelessWidget {
  const _MapOverlay({
    required this.transform,
    required this.projection,
    required this.items,
  });

  final TransformationController transform;
  final PlanProjection projection;
  final List<_OverlayItem> items;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: transform,
      builder: (context, _) {
        final matrix = transform.value;
        final pxPerMetre = projection.scale * matrix.getMaxScaleOnAxis();
        final children = <Widget>[];
        for (final item in items) {
          if (pxPerMetre < item.minPxPerMetre) continue;
          final point = MatrixUtils.transformPoint(
            matrix,
            projection.toCanvas(item.plan),
          );
          children.add(
            Positioned(
              key: ValueKey<String>(item.id),
              left: point.dx - item.anchor.dx,
              top: point.dy - item.anchor.dy,
              width: item.size.width,
              height: item.size.height,
              child: item.builder(pxPerMetre),
            ),
          );
        }
        return Stack(clipBehavior: Clip.hardEdge, children: children);
      },
    );
  }
}

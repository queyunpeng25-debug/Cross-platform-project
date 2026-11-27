import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zenify/zenify.dart';

import '../ar_portrait_screen.dart';
import '../computer_exhibit.dart';
import '../content.dart';
import '../core/controllers.dart';
import '../core/device_capabilities.dart';
import '../core/models.dart';
import '../core/translation_service.dart';
import '../features/map/cs_building_map_data.dart';
import '../features/map/map_positioning.dart';
import '../features/scanner/unified_scan_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/stations/lobby_home_screen.dart';
import '../features/stations/station_detail_screen.dart';
import '../features/team/team_screen.dart';
import 'frosted_dock.dart';
import 'language_dialog.dart';
import 'side_menu_drawer.dart';

/// XCI Part 2 adaptive layout constants (`Adaptive list and details` contract).
const double kExpandedLayoutBreakpoint = 840.0;
const double kSideMenuRailWidth = 280.0;

enum ShellDestination {
  lobby,
  stationDetail,
  scan,
  map,
  canteen,
  settings,
  team,
  finalPuzzle,
}

class CsExplorerShell extends StatefulWidget {
  const CsExplorerShell({
    super.key,
    this.initialStationQueryParam,
    this.initialMapQueryParam,
    this.showFirstLaunchPrompt = true,
  });

  final String? initialStationQueryParam;
  final String? initialMapQueryParam;
  final bool showFirstLaunchPrompt;

  @override
  State<CsExplorerShell> createState() => _CsExplorerShellState();
}

class _CsExplorerShellState extends State<CsExplorerShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ScanShutterController _shutterController = ScanShutterController();

  ShellDestination _destination = ShellDestination.lobby;
  String _selectedStationId = 'lobby';
  String? _activeCatchStationId;
  bool _promptScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _applyInitialStationDeepLink();
      _maybeShowFirstLaunchLanguageDialog();
    });
  }

  @override
  void didUpdateWidget(covariant CsExplorerShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialStationQueryParam != oldWidget.initialStationQueryParam ||
        widget.initialMapQueryParam != oldWidget.initialMapQueryParam) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _applyInitialStationDeepLink();
      });
    }
  }

  @override
  void dispose() {
    _shutterController.dispose();
    super.dispose();
  }

  void _applyInitialStationDeepLink() {
    final rawMapParam =
        widget.initialMapQueryParam ??
        Uri.base.queryParameters['map'] ??
        MapCodeResolver.markerIdFromRaw(Uri.base.toString());
    if (rawMapParam != null && rawMapParam.trim().isNotEmpty) {
      final place = CsBuildingMapData.markerById(rawMapParam.trim());
      if (place != null) {
        final progress = Zen.find<TourProgressController>();
        MapPositionStore(progress.prefs).setMarker(
          place.id,
          stationAtScan: progress.currentStationId.value,
        );
        setState(() {
          _activeCatchStationId = null;
          _destination = ShellDestination.map;
        });
        return;
      }
    }

    final rawParam =
        widget.initialStationQueryParam ?? Uri.base.queryParameters['station'];
    if (rawParam == null || rawParam.trim().isEmpty) return;

    final catalog = Zen.find<StationCatalogRepository>();
    final progress = Zen.find<TourProgressController>();
    final station = catalog.findById(rawParam.trim());
    if (station == null) return;

    progress.unlockAndSetCurrentStation(station.id);
    setState(() {
      _activeCatchStationId = null;
      _selectedStationId = station.id;
      _destination = station.id == 'lobby'
          ? ShellDestination.lobby
          : ShellDestination.stationDetail;
    });
  }

  Future<void> _maybeShowFirstLaunchLanguageDialog() async {
    if (!widget.showFirstLaunchPrompt || _promptScheduled) return;
    final settings = Zen.find<AppSettingsController>();
    if (settings.hasCompletedLanguagePrompt.value) return;

    _promptScheduled = true;
    await showLanguageSelectionDialog(
      context,
      settings: settings,
      isFirstLaunch: true,
    );
    settings.markLanguagePromptHandled();
  }

  void _showMobileOnlyNotice(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          content: TrText(message),
        ),
      );
  }

  /// Universal Back rule requested by Andrea:
  /// - From ANY screen other than Lobby -> goes straight to Lobby!
  /// - From Lobby -> closes the app / browser window naturally.
  void _goBackToLobby() {
    if (_destination == ShellDestination.lobby) {
      if (DeviceCapabilities.isNativeMobile) {
        unawaited(SystemNavigator.pop());
      }
      return;
    }
    if (DeviceCapabilities.isLaptopMode) {
      Zen.find<TourProgressController>().setCurrentIfUnlocked(
        'lobby',
        demoUnlockAll: true,
      );
    }
    setState(() {
      _activeCatchStationId = null;
      _selectedStationId = 'lobby';
      _destination = ShellDestination.lobby;
    });
  }

  void _openSideMenu() {
    _scaffoldKey.currentState?.openDrawer();
  }

  void _openStationById(String stationId, {bool fromScanner = false}) {
    final catalog = Zen.find<StationCatalogRepository>();
    final progress = Zen.find<TourProgressController>();
    final settings = Zen.find<AppSettingsController>();
    final station = catalog.findById(stationId);
    if (station == null) return;

    final allowBrowseAll =
        settings.demoUnlockAll.value || DeviceCapabilities.autoUnlockStations;

    if (fromScanner) {
      progress.unlockAndSetCurrentStation(station.id);
    } else {
      if (!progress.isStationUnlocked(
        station.id,
        demoUnlockAll: allowBrowseAll,
      )) {
        return;
      }
      progress.setCurrentIfUnlocked(
        station.id,
        demoUnlockAll: allowBrowseAll,
      );
    }

    ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
    setState(() {
      _activeCatchStationId = null;
      _selectedStationId = station.id;
      _destination = station.id == 'lobby'
          ? ShellDestination.lobby
          : ShellDestination.stationDetail;
    });
  }

  void _openScanner({String? catchStationId}) {
    if (!DeviceCapabilities.supportsCameraScan) {
      _showMobileOnlyNotice(
        'Camera scanning is available on mobile devices.',
      );
      return;
    }
    setState(() {
      _activeCatchStationId = catchStationId;
      _destination = ShellDestination.scan;
    });
  }

  void _openFinalPuzzle() {
    if (!DeviceCapabilities.supportsArExperiences) {
      _showMobileOnlyNotice(
        'The Final AR Puzzle requires collecting AR pieces on a mobile device.',
      );
      return;
    }
    setState(() => _destination = ShellDestination.finalPuzzle);
  }

  Future<void> _triggerCatchPuzzleForStation(StationSpec station) async {
    if (!DeviceCapabilities.supportsArExperiences) {
      _showMobileOnlyNotice(
        'The AR puzzle piece hunt is available on mobile devices.',
      );
      return;
    }
    final progress = Zen.find<TourProgressController>();
    final minigameSlot = Zen.find<MinigameFeatureSlot>();
    await minigameSlot.launchFloatingPuzzleCatch(
      context,
      station: station,
      progress: progress,
    );
  }

  Future<void> _runSecondaryStationAction(StationSpec station) async {
    final kind = station.secondaryActionKind;
    if (kind == null) return;

    switch (kind) {
      case SecondaryActionKind.openScanner:
        _openScanner();
      case SecondaryActionKind.greenhouseMinigame:
        if (!DeviceCapabilities.supportsArExperiences) {
          _showMobileOnlyNotice(
            'The Greenhouse camera activity is available on mobile devices.',
          );
          return;
        }
        final progress = Zen.find<TourProgressController>();
        final minigameSlot = Zen.find<MinigameFeatureSlot>();
        await minigameSlot.launchGreenhouseActivity(
          context,
          progress: progress,
        );
      case SecondaryActionKind.retroPcExhibit:
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(builder: (_) => const ComputerExhibit()),
        );
      case SecondaryActionKind.portraitArScanner:
        if (DeviceCapabilities.isLaptopMode) {
          _showMobileOnlyNotice(
            '3D AR Portrait View is available on mobile devices.',
          );
          return;
        }
        if (DeviceCapabilities.supportsNative3dAr) {
          final guideContent = await GuideContent.load();
          if (!mounted) return;
          await Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => ArPortraitScreen(content: guideContent),
            ),
          );
        } else {
          _openScanner();
        }
      case SecondaryActionKind.canteenMenuAndReviews:
        setState(() {
          _destination = ShellDestination.canteen;
        });
    }
  }

  ActiveDockTab get _currentDockTab {
    switch (_destination) {
      case ShellDestination.scan:
        return ActiveDockTab.scan;
      case ShellDestination.map:
        return ActiveDockTab.map;
      case ShellDestination.lobby:
      case ShellDestination.stationDetail:
      case ShellDestination.canteen:
      case ShellDestination.settings:
      case ShellDestination.team:
      case ShellDestination.finalPuzzle:
        return ActiveDockTab.infos;
    }
  }

  bool get _showsFloatingDock => true;

  Widget _buildActivePane({required bool isExpandedLayout}) {
    final catalog = Zen.find<StationCatalogRepository>();
    final progress = Zen.find<TourProgressController>();
    final settings = Zen.find<AppSettingsController>();
    final translator = Zen.find<TranslationService>();
    final mapSlot = Zen.find<MapFeatureSlot>();
    final canteenSlot = Zen.find<CanteenFeatureSlot>();
    final minigameSlot = Zen.find<MinigameFeatureSlot>();

    switch (_destination) {
      case ShellDestination.lobby:
        return LobbyHomeScreen(
          showMenuButton: !isExpandedLayout,
          onOpenSideMenu: _openSideMenu,
          onOpenScan: _openScanner,
          onOpenMap: () => setState(() => _destination = ShellDestination.map),
          onOpenStation: (id) => _openStationById(id),
          onCatchLobbyPuzzle: () =>
              _triggerCatchPuzzleForStation(catalog.lobby),
        );

      case ShellDestination.stationDetail:
        final station = catalog.findById(_selectedStationId) ?? catalog.lobby;
        return StationDetailScreen(
          key: ValueKey<String>('station-detail-${station.id}'),
          station: station,
          showMenuButton: !isExpandedLayout,
          reserveBottomDockSpace: true,
          onBackToLobby: _goBackToLobby,
          onOpenSideMenu: _openSideMenu,
          onCatchPuzzlePiece: () => _triggerCatchPuzzleForStation(station),
          onRunSecondaryAction: station.secondaryActionKind != null
              ? () => _runSecondaryStationAction(station)
              : null,
        );

      case ShellDestination.scan:
        if (!DeviceCapabilities.supportsCameraScan) {
          return LobbyHomeScreen(
            showMenuButton: !isExpandedLayout,
            onOpenSideMenu: _openSideMenu,
            onOpenScan: _openScanner,
            onOpenMap: () => setState(() => _destination = ShellDestination.map),
            onOpenStation: (id) => _openStationById(id),
            onCatchLobbyPuzzle: () =>
                _triggerCatchPuzzleForStation(catalog.lobby),
          );
        }
        return UnifiedScanScreen(
          key: ValueKey<String>('scan-${_activeCatchStationId ?? "general"}'),
          shutterController: _shutterController,
          initialCatchStationId: _activeCatchStationId,
          onBackToLobby: _goBackToLobby,
          onOpenSideMenu: _openSideMenu,
          onStationMatched: (id) => _openStationById(id, fromScanner: true),
          onMapMarkerMatched: (_) {
            setState(() {
              _activeCatchStationId = null;
              _destination = ShellDestination.map;
            });
          },
        );

      case ShellDestination.map:
        return mapSlot.buildMapScreen(
          context,
          progress: progress,
          settings: settings,
          onOpenStation: (id) => _openStationById(id),
          onBackToLobby: _goBackToLobby,
        );

      case ShellDestination.canteen:
        final canteenSpec = catalog.findById('canteen') ?? catalog.lobby;
        return canteenSlot.buildCanteenScreen(
          context,
          translator: translator,
          settings: settings,
          onBackToLobby: _goBackToLobby,
          onCatchPuzzlePiece: () => _triggerCatchPuzzleForStation(canteenSpec),
        );

      case ShellDestination.settings:
        return SettingsScreen(
          onBackToLobby: _goBackToLobby,
          onOpenTeam: () => setState(() => _destination = ShellDestination.team),
        );

      case ShellDestination.team:
        return TeamScreen(onBackToLobby: _goBackToLobby);

      case ShellDestination.finalPuzzle:
        if (!DeviceCapabilities.supportsArExperiences) {
          return LobbyHomeScreen(
            showMenuButton: !isExpandedLayout,
            onOpenSideMenu: _openSideMenu,
            onOpenScan: _openScanner,
            onOpenMap: () => setState(() => _destination = ShellDestination.map),
            onOpenStation: (id) => _openStationById(id),
            onCatchLobbyPuzzle: () =>
                _triggerCatchPuzzleForStation(catalog.lobby),
          );
        }
        return minigameSlot.buildFinalPuzzleScreen(
          context,
          progress: progress,
          onBackToLobby: _goBackToLobby,
        );
    }
  }

  Widget _buildPaneWithDock({required bool isExpandedLayout}) {
    return Stack(
      children: [
        Positioned.fill(
          child: _buildActivePane(isExpandedLayout: isExpandedLayout),
        ),
        if (_showsFloatingDock)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: SafeArea(
              top: false,
              child: FrostedSplitDock(
                activeTab: _currentDockTab,
                shutterPulse: _activeCatchStationId != null,
                showScanTab: DeviceCapabilities.supportsCameraScan,
                onSelectInfos: () {
                  if (_destination != ShellDestination.lobby) {
                    _goBackToLobby();
                  }
                },
                onSelectScanOrShutter: () {
                  if (_destination == ShellDestination.scan) {
                    _shutterController.triggerShutter();
                  } else {
                    _openScanner();
                  }
                },
                onSelectMap: () {
                  setState(() {
                    _activeCatchStationId = null;
                    _destination = ShellDestination.map;
                  });
                },
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAtRootLobby = _destination == ShellDestination.lobby;

    return PopScope<void>(
      canPop: isAtRootLobby,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !isAtRootLobby) {
          _goBackToLobby();
        }
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isExpanded = constraints.maxWidth >= kExpandedLayoutBreakpoint;

          final sideMenu = SideMenuPanel(
            inDrawer: !isExpanded,
            onSelectStation: (id) => _openStationById(id),
            onOpenSettings: () =>
                setState(() => _destination = ShellDestination.settings),
            onOpenTeam: () =>
                setState(() => _destination = ShellDestination.team),
            onOpenFinalPuzzle: _openFinalPuzzle,
          );

          return Scaffold(
            key: _scaffoldKey,
            drawer: isExpanded ? null : Drawer(width: 316, child: sideMenu),
            body: SizedBox.expand(
              child: isExpanded
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: kSideMenuRailWidth,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              border: Border(
                                right: BorderSide(
                                  color: Theme.of(
                                    context,
                                  ).dividerColor.withValues(alpha: 0.18),
                                ),
                              ),
                            ),
                            child: sideMenu,
                          ),
                        ),
                        Expanded(
                          child: _buildPaneWithDock(isExpandedLayout: true),
                        ),
                      ],
                    )
                  : _buildPaneWithDock(isExpandedLayout: false),
            ),
          );
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:zenify/zenify.dart';

import '../../core/controllers.dart';
import 'station_detail_screen.dart';

/// The CS Lobby root screen now uses the exact same full-screen photograph +
/// asymmetric one-side-curved translucent glass overlay as every other station,
/// while reserving bottom clearance for the floating `FrostedSplitDock`.
class LobbyHomeScreen extends StatelessWidget {
  const LobbyHomeScreen({
    super.key,
    required this.onOpenSideMenu,
    required this.onOpenScan,
    required this.onOpenMap,
    required this.onOpenStation,
    required this.onCatchLobbyPuzzle,
    this.showMenuButton = true,
  });

  final VoidCallback onOpenSideMenu;
  final VoidCallback onOpenScan;
  final VoidCallback onOpenMap;
  final ValueChanged<String> onOpenStation;
  final VoidCallback onCatchLobbyPuzzle;
  final bool showMenuButton;

  @override
  Widget build(BuildContext context) {
    final catalog = Zen.find<StationCatalogRepository>();
    return StationDetailScreen(
      station: catalog.lobby,
      isRootLobbyView: true,
      reserveBottomDockSpace: true,
      showMenuButton: showMenuButton,
      onBackToLobby: () {},
      onOpenSideMenu: onOpenSideMenu,
      onCatchPuzzlePiece: onCatchLobbyPuzzle,
      onRunSecondaryAction: onOpenScan,
    );
  }
}

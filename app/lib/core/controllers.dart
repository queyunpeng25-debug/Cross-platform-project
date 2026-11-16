import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zenify/zenify.dart';

import 'models.dart';
import 'translation_service.dart';

/// Application repository holding the static catalog of stations & triggers.
/// Owned at application scope (XCI Part 3: borrowed by feature scopes, never
/// disposed by individual views).
class StationCatalogRepository {
  StationCatalogRepository({
    required this.stations,
    required this.qrMappings,
    required this.textTriggerKeywords,
  }) : _byId = {for (final s in stations) s.id: s};

  final List<StationSpec> stations;
  final Map<String, StationSpec> _byId;

  /// Maps canonical QR code payloads or station query IDs to a [StationSpec.id].
  final Map<String, String> qrMappings;

  /// Maps lowercase sign/plaque substrings (OCR or simulated visual labels)
  /// to a [StationSpec.id] or external URL.
  final Map<String, String> textTriggerKeywords;

  StationSpec get lobby => _byId['lobby'] ?? stations.first;

  StationSpec? findById(String id) => _byId[id.trim()];

  /// Resolves both legacy `cs-guide://point/<id>` codes AND online HTTPS QR
  /// URLs (`https://<host>/Cross-platform-project/?station=<id>`).
  String? resolveStationFromRawCode(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    final direct = qrMappings[trimmed];
    if (direct != null && _byId.containsKey(direct)) {
      return direct;
    }

    if (trimmed.startsWith('cs-guide://point/')) {
      final slug = trimmed.substring('cs-guide://point/'.length).trim();
      if (qrMappings.containsKey(trimmed)) return qrMappings[trimmed];
      if (_byId.containsKey(slug)) return slug;
    }

    final uri = Uri.tryParse(trimmed);
    if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http')) {
      final stationParam = uri.queryParameters['station']?.trim();
      if (stationParam != null && _byId.containsKey(stationParam)) {
        return stationParam;
      }
      // Also support hash-based query params (`.../#/lobby?station=...`).
      if (uri.fragment.isNotEmpty) {
        final fragUri = Uri.tryParse(
          uri.fragment.startsWith('/') ? uri.fragment : '/${uri.fragment}',
        );
        final fragStation = fragUri?.queryParameters['station']?.trim();
        if (fragStation != null && _byId.containsKey(fragStation)) {
          return fragStation;
        }
      }
    }
    return null;
  }

  /// Evaluates sign/plaque text or visual target tag against configured triggers.
  ScanOutcome evaluateVisualOrTextSample(String rawSample) {
    final normalized = rawSample.trim().toLowerCase();
    if (normalized.isEmpty) {
      return const ScanUnrecognized(
        hint: 'Center a sign, door logo, portrait, or QR code and try again.',
      );
    }

    if (normalized.contains('subway')) {
      return const ScanExternalLink(
        title: 'Subway Campus Menu',
        url: 'https://www.subway.fi/en/menu',
      );
    }

    for (final entry in textTriggerKeywords.entries) {
      if (normalized.contains(entry.key.toLowerCase())) {
        final stationId = entry.value;
        if (_byId.containsKey(stationId)) {
          return ScanMatchedStation(
            stationId: stationId,
            triggerMethod: 'Visual / Sign Recognition ("${entry.key}")',
          );
        }
      }
    }

    return const ScanUnrecognized(
      hint: 'No registered station marker matched. Try getting closer to the sign or QR code.',
    );
  }

  static Future<StationCatalogRepository> loadFromAssets() async {
    final stationsRaw = jsonDecode(
      await rootBundle.loadString('assets/stations_data.json'),
    ) as Map<String, dynamic>;
    final triggersRaw = jsonDecode(
      await rootBundle.loadString('assets/scan_triggers.json'),
    ) as Map<String, dynamic>;

    final stationList = (stationsRaw['stations'] as List<dynamic>)
        .map((e) => StationSpec.fromJson(e as Map<String, dynamic>))
        .toList();

    final qrMap = (triggersRaw['qrMappings'] as Map<String, dynamic>).map(
      (k, v) => MapEntry(k, v.toString()),
    );
    final keywordMap = (triggersRaw['visualKeywords'] as Map<String, dynamic>)
        .map((k, v) => MapEntry(k, v.toString()));

    return StationCatalogRepository(
      stations: stationList,
      qrMappings: qrMap,
      textTriggerKeywords: keywordMap,
    );
  }
}

/// Global settings controller (XCI Part 3 `ZenController`):
/// - Light / Dark theme mode
/// - Selected language code + first-launch language dialog tracking
/// - Demo Mode unlock toggle (allows testing locked stations during oral exam)
class AppSettingsController extends ZenController {
  AppSettingsController({this.prefs}) {
    _hydrate();
  }

  static const String _keyTheme = 'cs_theme_mode';
  static const String _keyLang = 'cs_lang_code';
  static const String _keyFirstLaunchDone = 'cs_first_lang_prompt_done';
  static const String _keyDemoUnlock = 'cs_demo_unlock_all';

  final SharedPreferences? prefs;

  late final themeMode = obs<ThemeMode>(ThemeMode.light);
  late final languageCode = obs<String>('en');
  late final hasCompletedLanguagePrompt = obs<bool>(false);
  late final demoUnlockAll = obs<bool>(false);

  void _hydrate() {
    final p = prefs;
    if (p == null) return;

    final savedTheme = p.getString(_keyTheme);
    if (savedTheme == 'dark') {
      themeMode.value = ThemeMode.dark;
    } else if (savedTheme == 'light') {
      themeMode.value = ThemeMode.light;
    }

    final savedLang = p.getString(_keyLang);
    if (savedLang != null && savedLang.isNotEmpty) {
      languageCode.value = savedLang;
    }

    hasCompletedLanguagePrompt.value =
        p.getBool(_keyFirstLaunchDone) ?? false;
    demoUnlockAll.value = p.getBool(_keyDemoUnlock) ?? false;
  }

  void setThemeMode(ThemeMode mode) {
    themeMode.value = mode;
    unawaited(
      prefs?.setString(_keyTheme, mode == ThemeMode.dark ? 'dark' : 'light'),
    );
  }

  void toggleDarkMode() {
    setThemeMode(
      themeMode.value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark,
    );
  }

  void selectLanguage(String code, {bool markFirstLaunchComplete = true}) {
    languageCode.value = code;
    unawaited(prefs?.setString(_keyLang, code));
    if (markFirstLaunchComplete && !hasCompletedLanguagePrompt.value) {
      hasCompletedLanguagePrompt.value = true;
      unawaited(prefs?.setBool(_keyFirstLaunchDone, true));
    }
  }

  void markLanguagePromptHandled() {
    if (!hasCompletedLanguagePrompt.value) {
      hasCompletedLanguagePrompt.value = true;
      unawaited(prefs?.setBool(_keyFirstLaunchDone, true));
    }
  }

  void setDemoUnlockAll(bool enabled) {
    demoUnlockAll.value = enabled;
    unawaited(prefs?.setBool(_keyDemoUnlock, enabled));
  }
}

/// Shared building-tour state controller (`ZenController`):
/// Tracks Red (current), Green (visited), and Blue (locked/unvisited) stations,
/// plus per-station floating AR puzzle piece collection (`🧩`).
///
/// Also acts as the clean, non-invasive API bridge for **Mustafa's Map module**.
class TourProgressController extends ZenController {
  TourProgressController({
    required this.catalog,
    this.prefs,
  }) {
    _hydrate();
  }

  static const String _keyCurrent = 'cs_tour_current_station';
  static const String _keyVisited = 'cs_tour_visited_stations';
  static const String _keyPuzzles = 'cs_tour_collected_puzzles';

  final StationCatalogRepository catalog;
  final SharedPreferences? prefs;

  late final currentStationId = obs<String>('lobby');
  late final visitedStationIds = obs<Set<String>>(<String>{'lobby'});
  late final collectedPuzzleIds = obs<Set<String>>(<String>{});

  void _hydrate() {
    final p = prefs;
    if (p == null) return;

    final savedVisited = p.getStringList(_keyVisited);
    if (savedVisited != null && savedVisited.isNotEmpty) {
      visitedStationIds.value = <String>{'lobby', ...savedVisited};
    }

    final savedCurrent = p.getString(_keyCurrent);
    if (savedCurrent != null && catalog.findById(savedCurrent) != null) {
      currentStationId.value = savedCurrent;
    }

    final savedPuzzles = p.getStringList(_keyPuzzles);
    if (savedPuzzles != null) {
      collectedPuzzleIds.value = savedPuzzles.toSet();
    }
  }

  /// Color/status state for Side Menu & Mustafa's Map:
  /// - Red   -> [StationVisitStatus.current]
  /// - Green -> [StationVisitStatus.visited]
  /// - Blue  -> [StationVisitStatus.unvisited]
  StationVisitStatus statusFor(String stationId) {
    if (currentStationId.value == stationId) {
      return StationVisitStatus.current;
    }
    if (visitedStationIds.value.contains(stationId)) {
      return StationVisitStatus.visited;
    }
    return StationVisitStatus.unvisited;
  }

  bool isStationUnlocked(String stationId, {bool demoUnlockAll = false}) {
    if (demoUnlockAll) return true;
    final spec = catalog.findById(stationId);
    if (spec != null && spec.unlockedByDefault) return true;
    return visitedStationIds.value.contains(stationId);
  }

  bool hasCollectedPiece(String stationId) =>
      collectedPuzzleIds.value.contains(stationId);

  /// Called when the user scans a station's QR/visual marker (or when Mustafa's
  /// map QR updates the user's current building location).
  void unlockAndSetCurrentStation(String stationId) {
    if (catalog.findById(stationId) == null) return;
    final nextVisited = <String>{...visitedStationIds.value, stationId};
    visitedStationIds.value = nextVisited;
    currentStationId.value = stationId;
    unawaited(prefs?.setString(_keyCurrent, stationId));
    unawaited(prefs?.setStringList(_keyVisited, nextVisited.toList()));
  }

  /// Updates active position when revisiting an already-unlocked station.
  void setCurrentIfUnlocked(String stationId, {bool demoUnlockAll = false}) {
    if (!isStationUnlocked(stationId, demoUnlockAll: demoUnlockAll)) return;
    unlockAndSetCurrentStation(stationId);
  }

  /// Marks a station's floating AR puzzle piece as caught (`🧩`).
  void markPuzzlePieceCollected(String stationId) {
    if (collectedPuzzleIds.value.contains(stationId)) return;
    final next = <String>{...collectedPuzzleIds.value, stationId};
    collectedPuzzleIds.value = next;
    unawaited(prefs?.setStringList(_keyPuzzles, next.toList()));
  }

  int get totalPuzzleStations =>
      catalog.stations.where((s) => s.hasPuzzlePiece).length;

  int get collectedPuzzleCount => catalog.stations
      .where((s) => s.hasPuzzlePiece && collectedPuzzleIds.value.contains(s.id))
      .length;

  /// True once all stations with puzzle pieces are unlocked & collected
  /// (or when Demo Mode unlock is toggled in Settings).
  bool isFinalPuzzleReady({bool demoUnlockAll = false}) {
    if (demoUnlockAll) return true;
    for (final station in catalog.stations) {
      if (!isStationUnlocked(station.id)) return false;
      if (station.hasPuzzlePiece && !hasCollectedPiece(station.id)) {
        return false;
      }
    }
    return true;
  }

  Future<void> resetTourProgress() async {
    visitedStationIds.value = <String>{'lobby'};
    currentStationId.value = 'lobby';
    collectedPuzzleIds.value = <String>{};
    await prefs?.remove(_keyCurrent);
    await prefs?.remove(_keyVisited);
    await prefs?.remove(_keyPuzzles);
  }
}

/// Teammate Extension Contract 1: **Mustafa's Map Module**.
/// Kept intentionally minimal so Mustafa has complete freedom over his map UI.
abstract interface class MapFeatureSlot {
  Widget buildMapScreen(
    BuildContext context, {
    required TourProgressController progress,
    required AppSettingsController settings,
    required ValueChanged<String> onOpenStation,
    required VoidCallback onBackToLobby,
  });
}

/// Teammate Extension Contract 2: **Juhani's Canteen & Subway Module**.
abstract interface class CanteenFeatureSlot {
  Widget buildCanteenScreen(
    BuildContext context, {
    required TranslationService translator,
    required AppSettingsController settings,
    required VoidCallback onBackToLobby,
    required VoidCallback onCatchPuzzlePiece,
  });
}

/// Teammate Extension Contract 3: **Nico's AR Catch & Minigames Module**.
abstract interface class MinigameFeatureSlot {
  Future<void> launchFloatingPuzzleCatch(
    BuildContext context, {
    required StationSpec station,
    required TourProgressController progress,
  });

  Future<void> launchGreenhouseActivity(
    BuildContext context, {
    required TourProgressController progress,
  });

  Widget buildFinalPuzzleScreen(
    BuildContext context, {
    required TourProgressController progress,
    required VoidCallback onBackToLobby,
  });
}

/// Root XCI `ZenModule` wiring shared repositories, controllers, and teammate slots.
class CsExplorerAppModule extends ZenModule {
  CsExplorerAppModule({
    required this.catalog,
    required this.translationService,
    required this.mapSlot,
    required this.canteenSlot,
    required this.minigameSlot,
    this.prefs,
  });

  final StationCatalogRepository catalog;
  final TranslationService translationService;
  final MapFeatureSlot mapSlot;
  final CanteenFeatureSlot canteenSlot;
  final MinigameFeatureSlot minigameSlot;
  final SharedPreferences? prefs;

  @override
  String get name => 'CsExplorerAppModule';

  @override
  void register(ZenScope scope) {
    scope.put<StationCatalogRepository>(catalog);
    scope.put<TranslationService>(translationService);
    scope.registerDisposer(translationService.close);

    scope.put<MapFeatureSlot>(mapSlot);
    scope.put<CanteenFeatureSlot>(canteenSlot);
    scope.put<MinigameFeatureSlot>(minigameSlot);

    scope.putLazy<AppSettingsController>(
      () => AppSettingsController(prefs: prefs),
    );
    scope.putLazy<TourProgressController>(
      () => TourProgressController(
        catalog: scope.require<StationCatalogRepository>(),
        prefs: prefs,
      ),
    );
  }
}

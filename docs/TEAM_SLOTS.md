# CS Explorer — Team Feature Slots & Integration Guide

CS Explorer uses clean XCI service boundaries (`ZenModule` + typed slot interfaces in `app/lib/core/controllers.dart`) so every teammate owns an independent module without merge conflicts in `main.dart`.

---

## Architecture Overview

At app startup, `CsExplorerAppModule` registers shared application-scoped services and teammate slots inside `ZenScope`:

| Shared Service / Slot | File | Purpose |
| :--- | :--- | :--- |
| `StationCatalogRepository` | `app/lib/core/controllers.dart` | Station metadata (`assets/stations_data.json`) + QR & visual keyword triggers (`assets/scan_triggers.json`). |
| `TourProgressController` | `app/lib/core/controllers.dart` | Reactive Red / Green / Blue station states, current location, and collected puzzle pieces (`🧩`). |
| `AppSettingsController` | `app/lib/core/controllers.dart` | Light/Dark theme, active language code (`17` languages), and Demo Mode unlock toggle. |
| `TranslationService` & `TrText` | `app/lib/core/translation_service.dart` | Cached Google Translate bridge with request coalescing and automatic English fallback. |
| `MapFeatureSlot` | `app/lib/features/map/default_map_slot.dart` | **Mustafa's** interactive CS building map slot. |
| `CanteenFeatureSlot` | `app/lib/features/canteen/default_canteen_slot.dart` | **Juhani's** daily lunch menu, dish reviews & Subway slot. |
| `MinigameFeatureSlot` | `app/lib/features/minigames/default_minigame_slot.dart` | **Nico's** floating AR puzzle hunt, Greenhouse activity & final jigsaw puzzle. |
| `ArPortraitScreen` & `ComputerExhibit` | `app/lib/ar_portrait_screen.dart`, `app/lib/computer_exhibit.dart` | **Yunpeng's** native ARCore/ARKit 3D portrait tracker & retro computer exhibit/game. |

---

## 1. Mustafa — Interactive Building Map (`MapFeatureSlot`)

- **Interface**: `MapFeatureSlot` (`app/lib/core/controllers.dart`)
- **Default Slot File**: `app/lib/features/map/default_map_slot.dart`

### How to Plug In Your Map
Implement `MapFeatureSlot` (either directly inside `default_map_slot.dart` or in your own file injected into `CsExplorerAppModule.mapSlot`):

```dart
class MustafaBuildingMapSlot implements MapFeatureSlot {
  const MustafaBuildingMapSlot();

  @override
  Widget buildMapScreen(
    BuildContext context, {
    required TourProgressController progress,
    required AppSettingsController settings,
    required ValueChanged<String> onOpenStation,
    required VoidCallback onBackToLobby,
  }) {
    return ZenObserver(() {
      // Automatically rebuilds whenever station status or Demo Mode changes!
      final stations = progress.catalog.stations;
      // Render your custom floor plan & markers here...
      return YourCustomMapWidget(...);
    });
  }
}
```

### Live State & Positioning Methods Available
- **Station List & Coordinates**: `progress.catalog.stations` gives each `StationSpec` with `id`, `title`, `floor`, `floorLabel`, and normalized floor coordinates `normalizedX` / `normalizedY` (`0.0` to `1.0`).
- **Three-Color Marker Status**: `progress.statusFor(station.id)` returns `StationVisitStatus`:
  - `StationVisitStatus.current` → **Red** (user's active / most recently scanned station)
  - `StationVisitStatus.visited` → **Green** (previously visited & unlocked)
  - `StationVisitStatus.unvisited` → **Blue** (not yet scanned)
- **Unlock Check**: `progress.isStationUnlocked(station.id, demoUnlockAll: settings.demoUnlockAll.value)`
- **Update Position from Map QR**: `progress.unlockAndSetCurrentStation(stationId)` marks the station visited, sets it as the **Red** current marker, and persists to `SharedPreferences`.
- **Puzzle Badge Check**: `progress.hasCollectedPiece(station.id)` (`bool`)
- **Open Station Guide**: Call `onOpenStation(station.id)` when a user taps an unlocked marker.

---

## 2. Juhani — Canteen Menu, Dish Reviews & Subway (`CanteenFeatureSlot`)

- **Interface**: `CanteenFeatureSlot` (`app/lib/core/controllers.dart`)
- **Default Slot File**: `app/lib/features/canteen/default_canteen_slot.dart`

### Automatic Multi-Language Menu Translation
 Global translation is already wired across all 17 languages (`English` default, `Finnish`, `Swedish`, plus alphabetical `A–Z`):
1. **Declarative Widget**: Wrap any English UI string or dish description in `TrText('Creamy Salmon Soup')` — it automatically re-translates and caches whenever `settings.languageCode.value` changes.
2. **Programmatic Scraper Translation**: Inside your canteen controller/service, use the injected `TranslationService translator`:
   ```dart
   final lang = settings.languageCode.value;
   final translatedDish = await translator.translate(
     rawDishTitleInEnglish,
     targetLang: lang,
   );
   ```
   `GoogleFreeTranslationService` coalesces duplicate concurrent requests, caches results in memory + `SharedPreferences`, and falls back cleanly to English if offline.

### Subway Logo Trigger & Station Puzzle Hook
- **Subway Trigger**: `StationCatalogRepository.evaluateVisualOrTextSample` in `app/lib/core/controllers.dart` already matches `'subway'` to `ScanExternalLink(title: 'Subway Campus Menu', url: 'https://www.subway.fi/en/menu')`, which `UnifiedScanScreen` opens via `url_launcher`.
- **Floating Puzzle CTA**: Keep a button calling `onCatchPuzzlePiece` so visitors can catch the Canteen station's floating AR puzzle piece!

---

## 3. Nico — Floating AR Puzzle Hunt, Greenhouse & Final Puzzle (`MinigameFeatureSlot`)

- **Interface**: `MinigameFeatureSlot` (`app/lib/core/controllers.dart`)
- **Default Slot File**: `app/lib/features/minigames/default_minigame_slot.dart`

### Three Extension Hooks
1. `launchFloatingPuzzleCatch(context, {required station, required progress})`
   - Invoked when the user taps **`✨ Hunt the Floating Puzzle Piece!`** on any station page.
   - You can customize the AR capture minigame or route into `UnifiedScanScreen(initialCatchStationId: station.id, ...)` and call `progress.markPuzzlePieceCollected(station.id)` on capture.
2. `launchGreenhouseActivity(context, {required progress})`
   - Invoked from the 2nd-floor **Greenhouse (Learning Hub)** secondary action button (`SecondaryActionKind.greenhouseMinigame`).
   - Ready for your community AR plant-care / 4-object scan quest (`book`, `velvet chair`, `stairs`, `power outlet`).
3. `buildFinalPuzzleScreen(context, {required progress, required onBackToLobby})`
   - Invoked from the Side Menu's **`🏆 Final Puzzle`** entry once `progress.isFinalPuzzleReady(demoUnlockAll: settings.demoUnlockAll.value)` is `true`.
   - Useful helpers on `progress`:
     - `progress.collectedPuzzleIds.value` (`Set<String>`)
     - `progress.collectedPuzzleCount` / `progress.totalPuzzleStations`
     - `progress.hasCollectedPiece(stationId)`

---

## 4. Yunpeng — Native 3D AR Portrait Scanner & Evolution of Computers

- **Untouched Core Files**:
  - `app/lib/ar_portrait_screen.dart` (`ArPortraitScreen`)
  - `app/lib/ar_targets.dart` (`ArTarget`, `DetectionGate`)
  - `app/lib/computer_exhibit.dart` (`ComputerExhibit`, `ComputerPriceGame`)
  - `app/lib/qr_screen.dart` (`QrScreen`)

### How They Are Wired into the Unified Shell
1. **Inside `UnifiedScanScreen` (`app/lib/features/scanner/unified_scan_screen.dart`)**:
   - Opens instantaneously in **Smart Scan** mode (`MobileScanner` live QR + Shutter visual recognition) on Web, Android, and iOS so standard QR/sign scans never wait on ARCore startup.
   - On Android & iOS, a top **`3D AR Portraits`** mode pill unmounts `MobileScanner` cleanly (releasing hardware camera ownership first), loads `GuideContent.load()`, and pushes `ArPortraitScreen(content: content)` so native ARCore/ARKit continuous image tracking + 3D `.glb` biography panels work at full fidelity.
   - Scanning `cs-guide://point/computers` opens `ComputerExhibit` directly or unlocks the corresponding station.
2. **Inside Station Detail Pages**:
   - The **CS Pioneer Portraits** station secondary action (`SecondaryActionKind.portraitArScanner`) launches `ArPortraitScreen`.
   - The **Evolution of Computers** station secondary action (`SecondaryActionKind.retroPcExhibit`) launches `ComputerExhibit` and its `ComputerPriceGame`.

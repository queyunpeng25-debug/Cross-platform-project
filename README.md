# CS Explorer — Interactive Cross-Platform Guide to Aalto's CS Building

**CS Explorer** is a cross-platform **Flutter** application (**Android, iOS, Mobile Web PWA, and Laptop/Desktop Browser**) providing an interactive visitor and student guide to Aalto University's Computer Science building (*Tietotekniikan talo* / *"T-talo"*, `Konemiehentie 2`).

---

## Prerequisites

- **Flutter SDK:** `3.47+` (Dart SDK `^3.13.2`, matching `app/pubspec.yaml`)
- **Web testing:** Chrome or another modern browser
- **Native Android (ARCore):** Android Studio, Android SDK/NDK, and a physical ARCore-supported Android device
- **Native iOS (ARKit):** macOS with Xcode, CocoaPods (`iOS 15.0+` target), and a physical ARKit-supported iPhone/iPad
- *(Optional)* **Python `3.10+`** only if regenerating printable QR PNGs (`tools/`) or running the legacy `backend/` prototype

---

## Quick Start — Run Locally (Web)

From the repository root, fetch dependencies and launch the app on port `8080`:

```powershell
cd app
flutter pub get
flutter run -d chrome --web-port 8080
```

*(Or run `flutter run -d web-server --web-port 8080` and open **http://localhost:8080** in your browser.)*

### 3-Tier Adaptive Device Experience (`DeviceCapabilities`)

CS Explorer intentionally adapts its capabilities to the host device so every platform delivers a clean, non-broken experience:

| Device Tier | Detected On | What Is Enabled |
| :--- | :--- | :--- |
| **Laptop Guide** | Desktop / laptop browsers (Windows, macOS, Linux) | All **9 building stations** auto-unlock for remote reading, plus the **interactive 3-floor CS Building Map**, **Canteen info & Subway link**, and **Retro PC Price-Matching Game**. Camera scanning, AR puzzle hunt, and Demo Mode are hidden, and mobile-only camera/AR buttons display a clear `Mobile only` lock. |
| **Mobile Web (PWA)** | Phone / tablet browsers (e.g., scanning the hosted GitHub Pages QR code) | **Scan-to-Unlock** flow, live **QR + 15-target Visual Sign/Logo Scanner**, **Map `Locate me` QR scanner**, **Greenhouse 5-angle CV camera challenge**, **8-station 3DoF sensor AR puzzle hunt**, **Tabletop AR `3×3` Sliding Puzzle**, and the **`DEMO MODE · Prototype Build`** toggle in the **Guide** menu and **Settings**. |
| **Native Android & iOS** | Native mobile builds (`flutter run` / APK / Xcode) | Everything in Mobile Web, **plus** **native 6DoF ARCore / ARKit 3D portrait tracking** (`.glb` biography panels anchored beside portraits + in-AR ZXing/Vision QR decoding) and **live Kanttiinit daily lunch menu fetching** (bypasses browser CORS). |

> **Tip for evaluators testing from a laptop:** Opening `http://localhost:8080` normally enters **Laptop Guide** mode (all 9 stations readable immediately, no Demo Mode toggle). To preview the full **Mobile Web** experience — including **Scan**, **AR Puzzle Hunt**, **Greenhouse Camera Quest**, **Final Tabletop AR Puzzle**, and **`DEMO MODE · Prototype Build`** — either:
> 1. Open Chrome DevTools (`F12`), enable **Device Toolbar** (`Ctrl+Shift+M`), pick a mobile preset (e.g., *Pixel 7* or *iPhone 14*), and reload (`F5`), **or**
> 2. Open the live HTTPS PWA on your phone at **https://queyunpeng25-debug.github.io/Cross-platform-project/** (and switch on **`DEMO MODE · Prototype Build`** at the bottom of the top-left **Guide (`=`)** menu to preview all stops and the Final Puzzle without physical markers).

---

## Project Overview & 5-Stage Experience Flow

Visitors arriving at T-talo can scan the physical **Lobby QR code** with their phone's native camera to open the hosted Web PWA immediately (`?station=lobby`), scan any map sticker (`?map=<marker_id>`) to jump straight to their spot on the building map, or run the native **Android / iOS** app for full 6DoF ARCore/ARKit tracking.

All five required course interaction stages are covered across **9 building stops**:

1. **Starting Point — CS Building Lobby (`lobby`):** Features an interactive **"How This Guide Works"** introduction (adapting to Mobile vs Laptop mode), a collapsible **Suggested Route (`1F → 3F`)** with direct **`Open Building Map`** and **`Start Scanning`** quick actions, and campus lore covering *T-talo* (Finland's *1998 Steel Structure of the Year*), George W. Hart's twin mathematical ceiling orbs (*"Aalto"*), the `A?` glass emblem, directional signs to halls `T1`–`T8`, the free billiards table, wardrobe racks, *Aalto Space* room-booking tablets, and a tutorial floating AR puzzle piece straight ahead at eye level.
2. **Information Points (`greenhouse`, `guilds`, `locked_corridors`, `study_places`, `tuas_bridge`, `canteen`):** Full-screen location photography paired with asymmetric translucent frosted-glass overlays sharing building-specific tips — including the 2012 student-built **Learning Hub Greenhouse (`C130a`)** & public PhD dissertations, **Student Guild Rooms** (*Tietokilta*, *Athene's* `PALLASKATU` & live `OLOcam`, and *Data Guild's* `DATABASE` with a built-in Linktree/Telegram/Instagram hub), the **Locked Research Wings & 2nd-Floor PCB Mural** (*FCAI*, *HIIT*, *ELLIS*), the **3rd-Floor Quiet Loft (`Parvi T1`) & Unbookable Walk-In Call Pods**, and the heated **2nd-Floor Skybridge to TUAS (`Maarintie 8`)**.
3. **Interactive Points (`computers`, `greenhouse`, `canteen`, + 8-station AR hunt):**
   - **Evolution of Computers (`2F`):** Five historic machines (*Moomin Laptop*, *iMac G3*, *SGI O2*, *NeXTstation*, *IBM PC/AT*) paired with a playable launch-price matching quiz.
   - **Learning Hub Greenhouse (`1F`):** *"Find the Correct Angle"* interactive computer-vision minigame powered by multi-scale Harris corners, 256-bit rotation-steered BRIEF descriptors, and 2D RANSAC geometric verification across 5 reference perspective photos (timber cabin corner, PhD dissertations shelf, mezzanine armchairs, palm & pods, ceiling sculpture) with tap-to-zoom thumbnail and a native mobile camera fallback.
   - **Canteen & Campus Subway (`1F`):** Fetches and parses the daily *Tietotekniikantalo* lunch menu and dietary labels live from **Kanttiinit** at startup on Android/iOS (with a clear Web CORS notice + one-tap Kanttiinit link), auto-translates dishes into the active language, provides Kela lunch & Subway tips, and includes a dish rating demo box.
   - **8-Station Floating AR Puzzle Hunt:** 60 FPS 3DoF gyroscope + accelerometer spherical projection hides a floating 3D puzzle piece around each station for visitors to locate and capture.
4. **Spatial AR & Multi-Modal Recognition (`portraits` + Unified Scanner):**
   - **Continuous 6DoF 3D AR Portrait Gallery (Android ARCore / iOS ARKit):** Point the camera at *Kaisa Nyberg*, *Erkki Oja*, *Hans Andersin*, or *Teuvo Kohonen* (`0.8 m` calibrated targets) to anchor real-scale `.glb` 3D biography panels beside each portrait while simultaneously decoding guide QR codes (Android ZXing / iOS Vision) on the same camera stream.
   - **Hybrid Camera Scanner (`UnifiedScanScreen`):** Combines live QR scanning (`?station=<id>`, `cs-guide://point/<id>`) with **on-device 15-target visual spot & logo recognition** (Greenhouse facade/sign, TiK/Athene/DG guild emblems, Locked Wing `A` door/plaque, `1F` SCI/TUAS door & postal box, and Subway sign/logo), plus photo-upload and fallback simulation when no camera is available.
5. **Final Point — Tabletop AR Sliding-Tile Puzzle (`Assemble the Final Puzzle`):** Collecting all 8 station pieces (or toggling Demo Mode on mobile) unlocks a 3D-tilted tabletop `3×3` sliding-tile puzzle featuring the **A? Aalto University School of Science** emblem over a live camera (or Studio tabletop) backdrop, complete with move counter, Shuffle, Hint Move, and an animated 9th corner piece reveal upon solving.

---

## Additional Features & Architecture Highlights

- **Interactive 3-Floor CS Building Map (`1F` / `2F` / `3F`):** OpenStreetMap-derived vector floor plans with smooth pinch-zoom/pan, wide split panel on large screens (`880 px`), Red/Green/Blue station progress markers, hidden puzzle piece pins, lit-up walk-in call pods on `2F` and `3F`, facility icons (lifts, stairs, accessible entrance/toilet, wardrobe, billiards, parking), an in-app **`Locate me`** QR scanner, 9 printable map QR stickers in `demo_qr/map/`, and cold URL deep-linking (`?map=<marker_id>`).
- **Adaptive Phone, Tablet & Desktop Layout:** `LayoutBuilder` (`840 px` shell breakpoint) transitions seamlessly between a slide-out mobile drawer and a persistent `280 px` side rail without losing state; side menu lets visitors freely revisit any previously unlocked station.
- **Global 17-Language Auto-Translation & Light/Dark Mode:** First-launch and Settings language picker (**English** default, **Finnish**, **Swedish**, plus **A–Z** languages via cached Google Translate with offline English fallback) shared across UI, stations, and canteen dishes, paired with full Light (*AMuse Warm Ivory*) and Dark (*Museum Night*) themes.
- **Predictable Navigation & Hardened Error Handling:** Back from any screen returns cleanly to the Lobby; camera permission denials, missing ARCore/ARKit hardware (25 s timeout + QR-only fallback), offline translation, Web CORS limits, and external URL launch failures all degrade gracefully.

---

## Repository Structure

| Path | Purpose |
| :--- | :--- |
| `app/lib/main.dart` | App entry point, `Zenify` root module wiring, startup Kanttiinit menu refresh, and `GoRouter` deep links (`?station=<id>`, `?map=<id>`, `/station/:id`) |
| `app/lib/core/` | Data models & team profiles (`models.dart`), `ZenController` state & slot contracts (`controllers.dart`), 3-tier `DeviceCapabilities` (`device_capabilities.dart`), and cached `TranslationService` / `TrText` (`translation_service.dart`) |
| `app/lib/ui/` | Light/Dark themes (`theme.dart`), asymmetric frosted sheet & vector puzzle icon (`puzzle_icon.dart`), `FrostedSplitDock` (`frosted_dock.dart`), `SideMenuPanel` (`side_menu_drawer.dart`), language modal (`language_dialog.dart`), and adaptive `CsExplorerShell` (`app_shell.dart`) |
| `app/lib/features/stations/` | Full-screen photo + translucent frosted-glass views for Lobby and all 9 stations (`lobby_home_screen.dart`, `station_detail_screen.dart`) |
| `app/lib/features/scanner/` | `UnifiedScanScreen`, on-device 15-target visual recognizer (`place_image_recognizer.dart`), and cross-platform live frame grabbers (`live_frame_grabber*.dart`) |
| `app/lib/features/map/` | Interactive 3-floor vector map (`building_map_screen.dart`, `cs_building_map_data.dart`, `floor_plan_painter.dart`, `map_pins.dart`, `map_panels.dart`, `map_positioning.dart`, `locate_scanner_screen.dart`) |
| `app/lib/features/canteen/` | Live Kanttiinit HTML menu fetcher (`canteen_menu_service.dart`) and multi-language Canteen & Subway view (`default_canteen_slot.dart`) |
| `app/lib/features/minigames/` | 3DoF floating AR piece hunt (`station_minigames.dart`, `spatial_minigame_engine.dart`, `puzzle_config.dart`), Greenhouse 5-angle CV challenge (`greenhouse_angle_matcher.dart`, `greenhouse_angle_minigame_screen.dart`), and Final Tabletop `3×3` sliding puzzle (`ar_tabletop_puzzle_screen.dart`) |
| `app/lib/features/settings/` & `team/` | Appearance, language, device tier info, Demo Mode & tour reset (`settings_screen.dart`), and *Meet the Team* profiles (`team_screen.dart`) |
| `app/lib/ar_portrait_screen.dart`, `ar_targets.dart`, `qr_screen.dart` | Native 6DoF ARCore/ARKit continuous portrait tracking, `.glb` panel anchoring, and QR-only fallback |
| `app/lib/computer_exhibit.dart` | 2nd-floor *Evolution of Computers* exhibit and launch-price matching game |
| `app/packages/ar_flutter_plugin_plus/` | Locally patched cross-platform ARCore/ARKit + native frame QR plugin (Android ZXing & iOS Vision — required for mobile builds) |
| `app/assets/` | `stations_data.json`, `scan_triggers.json`, `place_targets.json`, `ar_targets.json`, station photos, portrait targets & `.glb` panels, Greenhouse reference photos, and `puzzle_master.png` |
| `demo_qr/` & `demo_qr/map/` | Printable online station QR codes (`online_*.png`), legacy codes, and 9 map `"You are here"` QR stickers (`map_*.png`) |
| `tools/` | Zero-dependency QR generators (`generate_qr_codes.py`, `generate_map_qr_codes.py`) and 3D `.glb` AR panel builder (`build_ar_panels.py`) |
| `.github/workflows/deploy_web.yml` | Automatic CI/CD deployment of the Flutter Web PWA to **GitHub Pages** over HTTPS |
| `docs/` | Teammate integration contracts (`TEAM_SLOTS.md`), GitHub Pages setup (`GITHUB_PAGES_SETUP.md`), and unified AR scanner notes (`unified-scanner.md`) |
| `backend/` | Optional legacy Python FastAPI ORB + RANSAC photo-matching prototype |

---

## Online Deployment (GitHub Pages) & Printable QR Codes

Mobile browsers require **HTTPS** for camera access (`getUserMedia`). Pushing to `main` runs [`.github/workflows/deploy_web.yml`](.github/workflows/deploy_web.yml) and deploys the Flutter Web PWA automatically:

- **Live Base URL:** `https://queyunpeng25-debug.github.io/Cross-platform-project/`
- **Lobby Physical QR URL:** `https://queyunpeng25-debug.github.io/Cross-platform-project/?station=lobby`
- **TUAS Shortcut QR URL:** `https://queyunpeng25-debug.github.io/Cross-platform-project/?station=tuas_bridge`
- **Map Location Sticker URL (example):** `https://queyunpeng25-debug.github.io/Cross-platform-project/?map=lift_2f`

See **[docs/GITHUB_PAGES_SETUP.md](docs/GITHUB_PAGES_SETUP.md)** for deployment settings. To regenerate the printable QR PNGs (optionally passing `--base-url`):

```powershell
python tools/generate_qr_codes.py
python tools/generate_map_qr_codes.py
```

---

## Running on Android & iOS Devices (Full Native 3D AR)

While Mobile Web supports the full tour, QR + visual spot scanning, map positioning, Greenhouse CV challenge, 3DoF puzzle hunt, and Tabletop puzzle, **spatially anchored 6DoF 3D portrait panels (`ar_flutter_plugin_plus`)** and **live Kanttiinit menu fetching** run natively on physical Android and iOS devices.

### Android (Physical ARCore Device)
1. Install Android Studio with Android SDK Platform, Build-Tools, Platform-Tools, and NDK/CMake, then accept licenses (`flutter doctor --android-licenses`).
2. Enable **USB Debugging** on an ARCore-supported phone (Android `minSdk 24+`) and run:
   ```powershell
   cd app
   flutter pub get
   flutter devices
   flutter run -d YOUR_DEVICE_ID --release
   ```
3. To build a standalone release APK (`app/build/app/outputs/flutter-apk/app-release.apk`):
   ```powershell
   cd app
   flutter build apk --release
   ```

### iOS (macOS + Physical ARKit iPhone/iPad)
1. On a Mac with Xcode and CocoaPods installed (`iOS 15.0+` target):
   ```bash
   cd app
   flutter pub get
   cd ios && pod install && cd ..
   ```
2. Open `app/ios/Runner.xcworkspace` in Xcode, select your signing **Team** and a unique Bundle Identifier, then run on a connected iPhone/iPad:
   ```bash
   flutter run -d YOUR_IOS_DEVICE_ID --release
   ```

---

## Verification & Testing

Run static analysis, the full unit/widget test suite (11 test files covering AR targets, canteen menu parsing, QR allowlists, shell navigation, 3-tier device capabilities, Greenhouse CV matching & UI, responsive layouts, 3-floor map & QR stickers, 15-target visual spot recognition, and team profiles), and a production Web compile check:

```powershell
cd app
flutter analyze
flutter test
flutter build web --release --base-href "/Cross-platform-project/"
```

*(Optional)* Legacy Python ORB prototype check in `backend/`:

```powershell
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r backend\requirements.txt
.\.venv\Scripts\python.exe -m pytest backend -q
.\start_backend.ps1
```

---

## Team & Personal Contributions

CS Explorer was developed collaboratively by five Aalto University students using modular feature boundaries (`Zenify` services and typed slots) so each member owned dedicated vertical slices of the application:

- **Andrea Gollo (`@GolAndrea`):** Designed and built the core Flutter application architecture (`Zenify` dependency injection, `GoRouter` deep-linking, adaptive `CsExplorerShell`, `FrostedSplitDock`, `SideMenuPanel`, Light/Dark themes, and the cached 17-language `TranslationService` / `TrText`); authored the Lobby starting point and all 9 building station information overlays, campus content, and Student Guilds Linktree hub (`stations_data.json`, `station_detail_screen.dart`); implemented the hybrid `UnifiedScanScreen` and on-device 15-target visual spot/logo recognizer (`place_image_recognizer.dart`, `place_targets.json`, `live_frame_grabber*.dart`); built the 3-tier adaptive `DeviceCapabilities` system (`Laptop Guide`, `Mobile Web`, `Native Mobile`), `SettingsScreen`, `TeamScreen`, GitHub Pages PWA CI/CD workflow, and branch integration/regression testing.
- **Mustafa Alalawi (`@Mustafa0Alalawi`):** Designed and implemented the interactive 3-floor CS Building Map (`app/lib/features/map/`), including OpenStreetMap-derived vector floor plans (`1F`, `2F`, `3F`), custom canvas rendering (`floor_plan_painter.dart`), pinch-zoom/pan and responsive wide side-panel layout, Red/Green/Blue station pins, hidden puzzle-piece indicators, highlighted walk-in call pods and building facilities, the in-app **`Locate me`** QR scanner (`locate_scanner_screen.dart`, `map_positioning.dart`), the printable map QR generator and 9 stickers (`tools/generate_map_qr_codes.py`, `demo_qr/map/`), and the map test suite (`map_feature_test.dart`).
- **Juhani (`@juhalo`):** Built the live campus lunch integration (`canteen_menu_service.dart`, `default_canteen_slot.dart`), fetching and parsing daily *Tietotekniikantalo* dishes and expanded dietary labels from Kanttiinit on Android and iOS at startup, implementing graceful Web CORS error handling with direct Kanttiinit fallback links, and writing unit/widget tests (`canteen_menu_service_test.dart`).
- **Yunpeng Que (`@queyunpeng25-debug`):** Created the initial cross-platform repository foundation, native 6DoF ARCore (Android) and ARKit (iOS) continuous portrait tracking (`ar_portrait_screen.dart`, `ar_targets.dart`, `ar_targets.json`), and local patches to `ar_flutter_plugin_plus` enabling single-camera simultaneous portrait tracking and native QR decoding (ZXing on Android, Vision on iOS); calibrated portrait reference imagery and built the `.glb` 3D biography panel generator (`tools/build_ar_panels.py`); implemented the 2nd-floor *Evolution of Computers* exhibit and launch-price matching minigame (`computer_exhibit.dart`), QR-only fallback (`qr_screen.dart`), legacy Python ORB backend prototype, and core portrait/content/layout tests.
- **Niccolò Sobrero (`@NiccoloSobrero`):** Designed and implemented the gamified AR and minigame layers, including the 8-station 3DoF floating AR puzzle piece hunt (`station_minigames.dart`, `spatial_minigame_engine.dart`, `puzzle_config.dart` with 60 FPS gyroscope/accelerometer spatial projection), the Learning Hub Greenhouse *"Find the Correct Angle"* computer-vision minigame (`greenhouse_angle_matcher.dart`, `greenhouse_angle_minigame_screen.dart` with multi-scale Harris corners, steered BRIEF, and 2D RANSAC + tests), the Final Tabletop AR `3×3` sliding-tile puzzle (`ar_tabletop_puzzle_screen.dart`) with Aalto University School of Science master artwork, and cross-screen map/UI refinements.

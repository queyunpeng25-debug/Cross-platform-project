# CS Explorer — Interactive Cross-Platform Guide to Aalto's CS Building

**CS Explorer** is a cross-platform **Flutter** application (**Web PWA, Android, and iOS** across phones and tablets) providing an interactive visitor and student guide to Aalto University's Computer Science building (*Tietotekniikan talo* / *"T-talo"*, `Konemiehentie 2`).

---

## Quick Start — Run Locally (Web)

From the repository root, start the local web server on port `8080`:

```powershell
cd app
flutter pub get
flutter run -d web-server --web-port 8080
```

Then open **http://localhost:8080** in your browser *(or run `flutter run -d chrome --web-port 8080` to launch Chrome automatically)*.

> **Tip for local testing:** Stations outside the Lobby use **Scan-to-Unlock**. To preview all 9 stations and the Final Tabletop AR Puzzle immediately from your computer without scanning physical markers, open the top-left **Guide (`=`)** menu and switch on **`DEMO MODE · Prototype Build`** at the bottom.

---

## Project Overview & Experience Flow

Anyone arriving at the CS Building can scan the physical **Lobby QR code** with their phone's native camera to open the hosted **Web App (PWA)** immediately over HTTPS (`?station=lobby`), or install the native **Android / iOS** build for full ARCore / ARKit spatial tracking.

The application covers all five required course interaction stages across **9 building stops**:

1. **Starting Point — CS Building Lobby (`lobby`):** Introduces *T-talo* (winner of Finland's *1998 Steel Structure of the Year*), George W. Hart's twin mathematical ceiling orbs (*"Aalto"*), directional signs to halls `T1`–`T8`, the free billiards table, wardrobe racks, and *Aalto Space* room-booking tablets.
2. **Information Points (`greenhouse`, `guilds`, `locked_corridors`, `study_places`, `tuas_bridge`):** Full-screen location photography paired with translucent asymmetric frosted-glass sheets sharing campus lore — from the 2012 student-built **Learning Hub Greenhouse (`C130a`)** and public PhD dissertations to **Student Guild Rooms** (*Tietokilta*, *Athene's* `PALLASKATU` & live `OLOcam`, and *Data Guild's* `DATABASE`), the **Locked Research Wings & 2nd-Floor PCB Mural** (*FCAI*, *HIIT*, *ELLIS*), the **3rd-Floor Quiet Loft & Walk-In Call Pods**, and the heated **2nd-Floor Skybridge to TUAS (`Maarintie 8`)**.
3. **Interactive Activities (`computers`, `greenhouse`, `canteen`):**
   - **Evolution of Computers (`2F`):** Five historic machines (*IBM PC/AT*, *NeXTstation*, *SGI O2*, *iMac G3*, and *"Moominpappa's"* *Moomin Laptop*) with a playable launch-price matching game.
   - **Learning Hub Greenhouse (`1F`):** Dedicated activity slot for the 4-object scan quest / AR plant activity.
   - **Canteen & Campus Subway (`1F`):** The app refreshes and parses the Tietotekniikantalo lunch menu from Kanttiinit at startup on Android/iOS, with auto-translation, demo dish reviews, Kela meal subsidy tips, and Subway logo recognition. Web refresh is currently unavailable because Kanttiinit does not allow cross-origin browser requests.
4. **Spatial AR & Multi-Modal Recognition (`portraits` + Unified Scanner):**
   - **Continuous 3D AR Portrait Recognition (Android ARCore / iOS ARKit):** Point the camera at *Kaisa Nyberg*, *Erkki Oja*, *Hans Andersin*, or *Teuvo Kohonen* to anchor real-scale `.glb` 3D biography panels beside each frame.
   - **Hybrid Camera Scanner:** Recognizes both online HTTPS QR URLs (`?station=<id>`), `cs-guide://point/<id>` markers, and building signs/door logos via the center shutter button.
5. **Final Point — Tabletop AR Sliding-Tile Puzzle:** Every station hides a collectible floating AR puzzle piece. Collecting all pieces unlocks **`Assemble the Final Puzzle`** in the side menu: a 3D perspective tabletop AR `3×3` sliding-tile puzzle where collected tiles land on the table, slide into the empty corner slot, and reveal the missing 9th corner piece upon completion.

---

## Core UI & Architecture Highlights

- **Adaptive Phone, Tablet & Web Layout:** Uses `LayoutBuilder` (`840 px` breakpoint) to switch seamlessly between a compact mobile drawer layout and a persistent `280 px` side navigation rail on tablets/desktop without losing state on resize.
- **Frosted Split & Shutter Bloom Dock:** Cohesive frosted-glass bottom pill (`[ Infos · Scan · Map ]`) that smoothly splits outward when entering **Scan**, blooming a central camera shutter while keeping `← Infos` and `Map` one tap away.
- **Predictable Navigation:** Pressing Back from any station, scanner, map, or settings view always returns to the **CS Lobby**; pressing Back on the Lobby exits the app/window.
- **Global Multi-Language Support & Dark Mode:** First-launch and Settings language selector (**English** default, **Finnish**, **Swedish**, plus **A–Z** auto-translated languages via Google Translate with local `SharedPreferences` caching) shared across all UI screens and the Canteen menu, alongside full **Light / Dark Mode**.
- **Modular Team Architecture (`Zenify`):** Shared state (`TourProgressController`, `AppSettingsController`, `TranslationService`) and clean `abstract interface class` extension slots so each team member can develop independently — see **[docs/TEAM_SLOTS.md](docs/TEAM_SLOTS.md)**.

---

## Repository Structure

| Path | Purpose |
| :--- | :--- |
| `app/lib/main.dart` | App entry point, `Zenify` root module registration, and `GoRouter` setup (`/` & `?station=<id>`) |
| `app/lib/core/` | Shared models (`models.dart`), `ZenController` state & team contracts (`controllers.dart`), and `TranslationService` / `TrText` (`translation_service.dart`) |
| `app/lib/ui/` | Sober museum Light/Dark themes (`theme.dart`), asymmetric frosted glass & vector puzzle icon (`puzzle_icon.dart`), `FrostedSplitDock` (`frosted_dock.dart`), `SideMenuPanel` (`side_menu_drawer.dart`), language modal (`language_dialog.dart`), and adaptive shell (`app_shell.dart`) |
| `app/lib/features/stations/` | Unified full-screen photo + translucent frosted-glass views for Lobby & building stations |
| `app/lib/features/scanner/` | Rounded `UnifiedScanScreen` with JIT camera permissions, QR/sign shutter, floating AR piece catch, and 3D AR Portrait launcher |
| `app/lib/features/minigames/` | Tabletop AR `3×3` sliding-tile final puzzle (`ar_tabletop_puzzle_screen.dart`) & Nico's minigame hooks |
| `app/lib/features/map/` | Clean `MapFeatureSlot` screen & reactive Red/Green/Blue station API for Mustafa |
| `app/lib/features/canteen/` | `CanteenFeatureSlot` with live multi-language dish translation & demo review box for Juhani |
| `app/lib/features/settings/` & `team/` | Appearance/language/demo settings and *Meet the Team* personal contributions screen |
| `app/lib/ar_portrait_screen.dart` & `ar_targets.dart` | Native ARCore/ARKit continuous portrait tracking and `.glb` 3D panel anchoring |
| `app/lib/computer_exhibit.dart` | 2nd-floor *Evolution of Computers* exhibit and price-matching minigame |
| `app/packages/ar_flutter_plugin_plus/` | Locally patched cross-platform ARCore/ARKit + frame QR plugin (committed with repo) |
| `app/assets/stations_data.json` & `scan_triggers.json` | Station copy, guild links, coordinates, QR allowlist, and visual sign keywords |
| `demo_qr/` & `tools/generate_qr_codes.py` | Printable online HTTPS QR codes (`online_*.png`) and zero-dependency QR generator |
| `.github/workflows/deploy_web.yml` | Automatic CI/CD deployment of the Flutter Web PWA to **GitHub Pages** over HTTPS |
| `docs/TEAM_SLOTS.md` & `docs/GITHUB_PAGES_SETUP.md` | Teammate integration contracts and 5-step GitHub Pages setup guide |
| `backend/` | Optional Python FastAPI ORB + RANSAC image-matching service for legacy photo testing |

---

## Online Deployment (GitHub Pages) & QR Codes

Mobile browsers require **HTTPS** to access the camera (`getUserMedia`). Pushing to `main` triggers [`.github/workflows/deploy_web.yml`](.github/workflows/deploy_web.yml), which builds the Flutter Web PWA and publishes it automatically to GitHub Pages:

- **Live Base URL:** `https://queyunpeng25-debug.github.io/Cross-platform-project/`
- **Lobby Physical QR URL:** `https://queyunpeng25-debug.github.io/Cross-platform-project/?station=lobby`
- **1F TUAS Shortcut QR URL:** `https://queyunpeng25-debug.github.io/Cross-platform-project/?station=tuas_bridge`

See **[docs/GITHUB_PAGES_SETUP.md](docs/GITHUB_PAGES_SETUP.md)** to enable GitHub Actions Pages in repository settings. To regenerate all printable QR PNGs in `demo_qr/` (with an optional custom `--base-url`):

```powershell
python tools/generate_qr_codes.py
```

---

## Running on Android & iOS Devices (Full Native 3D AR)

While the Web build supports the full guide, QR scanning, visual sign matching, and the tabletop sliding puzzle, **spatially anchored 3D portrait panels (`ar_flutter_plugin_plus`)** use native **ARCore (Android)** and **ARKit (iOS)** on physical devices.

### Android (Physical ARCore Device)
1. Install Android Studio + Android SDK Platform, Build-Tools, Platform-Tools, and NDK/CMake, then accept licenses (`flutter doctor --android-licenses`).
2. Enable **USB Debugging** on an ARCore-supported phone and run:
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
2. Open `app/ios/Runner.xcworkspace` in Xcode to select your signing **Team** and unique Bundle Identifier, then run on a connected iPhone/iPad:
   ```bash
   flutter run -d YOUR_IOS_DEVICE_ID --release
   ```

---

## Verification & Testing

Run static analysis, unit/widget tests, and a production Web compile check:

```powershell
cd app
flutter analyze
flutter test
flutter build web --release --base-href "/Cross-platform-project/"
```

*(Optional)* If testing the legacy Python ORB photo-matching backend in `backend/`:

```powershell
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r backend\requirements.txt
.\.venv\Scripts\python.exe -m pytest backend -q
.\start_backend.ps1
```

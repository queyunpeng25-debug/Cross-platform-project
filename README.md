# CS Explorer — Flutter Portrait Recognition and QR Code Guide

The final deliverable is an **Android / iOS Flutter app**. Start in `app/`; this is a mobile app project.

The two assigned modules have been implemented:

1. **Continuous portrait recognition and AR information panels**: Open the AR camera → automatically recognize registered portraits on the phone → anchor a 3D information panel to the right of the portrait → update the perspective as the phone moves. Android uses ARCore and iOS uses ARKit. No computer-hosted service is required.
2. **QR code guide**: Scan a QR code in real time → look up the app's local content table → display the corresponding introduction. QR scanning does not depend on a server.

Four portrait reference images are currently provided: Kaisa Nyberg, Erkki Oja, Hans Andersin, and Teuvo Kohonen. Names were registered using the plaques below the photographs. The plaque in the first new photograph reads “Eikki Oja”; the project uses the official spelling “Erkki Oja” from academic sources. Biographical information comes from public Aalto and researcher webpages; identities were not inferred from faces.

**Updated workflow**: Read the [continuous recognition and AR guide](docs/持续识别与AR.md) first. The portraits measure approximately **75–85 cm** across; all four are currently configured with the midpoint width of **0.80 meters**. If precise measurements become available, update each entry in `app/assets/ar_targets.json`. Use a physical device that supports ARCore / ARKit. Native builds and on-device stability validation have not yet been completed.

**Scope**: This project implements two modules, rather than the complete five-station experience. Real image anchors and 3D information panels are now included, but the team still needs to supply the lobby route text and integrate the interactive quiz and final mini-game. The legacy “Photo Matching Test” remains available for debugging; only that entry point requires the Python service.

## Project Files

| File | Purpose |
| --- | --- |
| `app/lib/main.dart` | App home screen, photo capture, result cards, and server settings |
| `app/lib/ar_portrait_screen.dart` | Continuous recognition, image anchors, and AR session lifecycle |
| `app/lib/ar_targets.dart` | Target configuration, recognition confirmation, and relative panel positioning |
| `app/assets/ar_targets.json` | Physical portrait widths and mappings between reference images and 3D panels |
| `app/assets/ar_panels/` | GLB 3D information panels with text textures and preview images |
| `app/packages/ar_flutter_plugin_plus/` | Locally patched AR plugin for both platforms; must be committed with the code |
| `tools/build_ar_panels.py` | Regenerate 3D information panels from the biography JSON data |
| `app/lib/qr_screen.dart` | Real-time camera scanning, unknown-code handling, and duplicate-scan protection |
| `app/lib/content.dart` | Load local introductions and match QR codes against the allowlist |
| `app/lib/portrait_service.dart` | Photo uploads, URL validation, and a 15-second timeout |
| `app/assets/content.json` | Edit introductions for people and locations |
| `backend/recognizer.py` | ORB feature matching and RANSAC geometric verification |
| `backend/main.py` | `/health` and `/recognize` HTTP endpoints |
| `backend/references.json` | Mapping between reference images and person IDs |
| `backend/references/kaisa_nyberg.jpg` | Reference portrait cropped and perspective-corrected from the supplied image |
| `demo_qr/` | Printable test QR codes |


## Step 1: Prepare the Android Development Environment

The current computer already has Flutter 3.47.2 / Dart 3.13.2 and Python installed. At the time of inspection, no Android SDK was detected and no Android / iOS phone was connected, so an APK has not yet been produced and on-device validation has not been completed.

1. Install [Android Studio](https://developer.android.com/studio).
2. Open Android Studio → More Actions → SDK Manager. Install an Android SDK Platform and the Command-line Tools, Build-Tools, and Platform-Tools under SDK Tools. Install NDK / CMake as required by Flutter build messages.
3. If the SDK is installed in a custom directory, run `flutter config --android-sdk "YOUR_ACTUAL_SDK_DIRECTORY"`.
4. Run the following commands in a terminal, review and accept the SDK licenses, and resolve any remaining Android toolchain issues.

```powershell
flutter doctor --android-licenses
flutter doctor -v
```

5. Enable Developer options and USB debugging on the Android phone, connect it to the computer with a USB cable, and allow debugging on the phone.
6. Run `flutter devices` and confirm that the phone appears in the list. Select an Android / iOS device; Chrome and Windows are not the target platforms for this project.

For detailed instructions, see the [official Flutter Android setup guide](https://docs.flutter.dev/platform-integration/android/setup).

## Step 2 (Optional): Start the Legacy Photo Test Service

**Continuous AR recognition and QR scanning do not require this service or a shared Wi-Fi network. To try only the new workflow, skip directly to Step 4.**

In PowerShell, navigate to the project root:

```powershell
cd D:\Crossplatform\Project
```

Dependencies are already installed in `.venv` on the current machine. On another computer, or when reinstalling:

```powershell
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r backend\requirements-lock.txt
```

`requirements-lock.txt` records the exact versions used in the validated environment. If installation fails with a different Python version, use the version ranges in `requirements.txt` and rerun the tests. Python 3.13 is recommended to match this environment.

Start the service and keep the terminal open:

```powershell
.\.venv\Scripts\python.exe -m uvicorn backend.main:app --host 0.0.0.0 --port 8000
```

You can also run `./start_backend.ps1`. If PowerShell blocks the script, use the Python command above directly.

Open the [health check](http://127.0.0.1:8000/health) in the computer's browser. It should display `{"status":"ok","references":1}`. Interactive endpoint testing is available in the [API documentation](http://127.0.0.1:8000/docs).

## Step 3 (Legacy Photo Test Only): Connect the Phone and Computer

1. Connect the phone and computer to the same Wi-Fi network, with communication between devices allowed.
2. Run `ipconfig` on the computer and find the current Wi-Fi IPv4 address, for example `192.168.1.23`.
3. Open `http://192.168.1.23:8000/health` in the phone's browser. The app's portrait requests can succeed only if this page is reachable.
4. If it is unreachable, check whether Windows Firewall allows this Python service to communicate on private networks. Campus Wi-Fi may block communication between devices; try a personal hotspot. Do not disable the entire firewall.

The address above is an example; replace it with your computer's actual IP address. `0.0.0.0` is the service's listening address, not the address to enter in the app. On a phone, `localhost` refers to the phone itself.

## Step 4: Run the App

Open another terminal:

```powershell
cd D:\Crossplatform\Project\app
flutter pub get
flutter devices
flutter run -d YOUR_PHONE_DEVICE_ID --release
```

Replace the device ID with the actual value. Continuous AR recognition requires no server configuration. Use `--release` on a physical device to evaluate tracking stability and avoid ARCore tracking issues that affect some devices in debug mode.

For the legacy photo test, add `--dart-define=API_BASE_URL=http://YOUR_COMPUTER_IP:8000`, or open settings in the top-right corner of the app and enter the base URL. Changes made in settings apply only to the current app run.

The default address for the Android emulator is `http://10.0.2.2:8000`. Do not use it on a physical phone.

After launching the app:

1. Tap “Scan QR Code” and point the camera at `demo_qr/computers.png` to view the introduction to the five computers.
2. Scan `demo_qr/portrait_kaisa.png` to view the portrait station introduction.
3. Tap “Continuous Portrait Recognition · AR Introduction”, allow camera access, point the camera at the entire portrait, and move the phone slowly. Once recognized, an information panel appears to the right of the portrait.
4. Move slowly from side to side, closer, and farther away to check that the panel stays beside the portrait. Moving the app to the background pauses the camera. When returning, tap “Resume AR Recognition” to relocalize.
5. When outside the building, print a reference image at a known width and update the corresponding width in `ar_targets.json` for AR testing. The legacy photo matching test cannot validate AR tracking.

The QR codes are not ordinary website links. Scan them with this app; the system camera is not expected to open a webpage.

## Running on iOS

Windows cannot compile an iOS app. Share the project with a teammate who has a Mac and install compatible versions of Flutter, Xcode, and the required tools. The project's current minimum Android API level is 24, and its iOS deployment target is 15.0.

1. Run `flutter pub get` in the `app/` directory on the Mac.
2. Configure Xcode, signing, and Developer Mode using the [official Flutter iOS setup guide](https://docs.flutter.dev/platform-integration/ios/setup).
3. Open `ios/Runner.xcworkspace` in Xcode, select your Team, and change the Bundle Identifier if necessary.
4. Connect an iPhone, trust the computer, and use `flutter devices` to find the device.
5. The local AR plugin uses CocoaPods. Run `cd ios`, then `pod install`. Return to `app/` and run `flutter run -d YOUR_DEVICE_ID --release`. The project already includes a Podfile, the camera permission macro, and Pods configuration references.
6. On an ARKit-compatible iPhone, allow camera access and follow the same AR and QR acceptance steps as on Android.

For the legacy photo entry point, the Python service can continue running on the Windows computer. The new Android / iOS implementation shares Dart workflows, content, dimensions, and panels, but uses each platform's native AR engine. Real-device behavior must be validated separately on each platform.

## Testing and Packaging

```powershell
cd D:\Crossplatform\Project
.\.venv\Scripts\python.exe -m pytest backend -q
cd app
flutter analyze
flutter test
```

After installing the Android SDK, build a release APK for demonstration:

```powershell
flutter build apk --release
```

The output is `app/build/app/outputs/flutter-apk/app-release.apk`. This file has not yet been generated. The template's release build still uses development signing and is intended only for a course demonstration. Store distribution requires production signing. HTTP access for the legacy network test entry point is enabled for local-network demonstrations.

## Troubleshooting

| Symptom | What to Check |
| --- | --- |
| QR scanning works, but portrait recognition does not | QR scanning needs no service; check whether the phone can access `/health` |
| Portrait does not match | Take the photo straight on, fill most of the frame with the portrait, avoid reflections, and confirm that the reference image matches the portrait on site |
| A newly added person never appears | JSON IDs must match; restart both the Python service and the app |
| Camera permission was denied | Re-enable it in the phone's system settings, then reopen scanning / photo capture |
| Photo request returns 400 | Use JPEG/PNG; convert HEIC images first |
| An unfamiliar QR code is scanned | This is expected: only registered project content is displayed |
| iPhone cannot access the service | Check local network permission, network connectivity, and the server address |

This prototype service is intended for course demonstrations on a trusted local network. It does not include user authentication, public internet deployment, or high-traffic protection. Recognition requests do not save uploaded photos to disk. The reference image library is registered in advance and retained as part of the project.

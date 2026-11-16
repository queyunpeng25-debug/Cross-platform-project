# GitHub Pages HTTPS Deployment & Physical QR Setup (5 Steps)

CS Explorer builds and deploys automatically as a Progressive Web App (PWA) to:
**`https://queyunpeng25-debug.github.io/Cross-platform-project/`**

Serving over **HTTPS** on `github.io` is essential so mobile browsers (Safari on iOS and Chrome on Android) permit `getUserMedia` camera access inside `UnifiedScanScreen` without installing an APK/IPA.

---

## 5-Step Quick Setup Guide

### Step 1 — Verify the Workflow File on `main`
Ensure `.github/workflows/deploy_web.yml` is committed on the `main` branch. On every push to `main` (or manual run), it:
1. Installs Flutter stable (`subosito/flutter-action@v2`) and runs `flutter pub get` inside `app/`.
2. Builds the release web bundle with the repository base path:
   ```bash
   flutter build web --release --base-href "/Cross-platform-project/"
   cp build/web/index.html build/web/404.html
   ```
   *(Copying `index.html` to `404.html` ensures deep links and refreshes resolve cleanly on GitHub Pages.)*
3. Uploads `app/build/web` and deploys via `actions/deploy-pages@v4`.

### Step 2 — Enable GitHub Actions as the Pages Source
1. Open the repository on GitHub: `https://github.com/queyunpeng25-debug/Cross-platform-project`.
2. Navigate to **Settings → Pages**.
3. Under **Build and deployment → Source**, select **`GitHub Actions`** (instead of *Deploy from a branch*).

### Step 3 — Trigger & Confirm the First Deployment
1. Push to `main` or open the **Actions** tab → **Deploy CS Explorer Web App to GitHub Pages** → click **Run workflow**.
2. Wait ~2 minutes for the `build` and `deploy` jobs to turn green.
3. Open `https://queyunpeng25-debug.github.io/Cross-platform-project/` on any phone or laptop to verify the Lobby guide loads over HTTPS.

### Step 4 — Generate Physical Station QR Codes
Encode full HTTPS URLs with the `?station=<id>` query parameter so **both** a phone's native camera app **and** the in-app `UnifiedScanScreen` work seamlessly:

| Physical Location | Recommended QR Payload URL |
| :--- | :--- |
| **Main Lobby (Floor 1)** | `https://queyunpeng25-debug.github.io/Cross-platform-project/?station=lobby` |
| **TUAS Skyway Bridge** | `https://queyunpeng25-debug.github.io/Cross-platform-project/?station=tuas_bridge` |

*(Legacy offline payloads such as `cs-guide://point/lobby` or `cs-guide://point/computers` also continue to resolve inside `StationCatalogRepository.resolveStationFromRawCode`.)*

### Step 5 — Test End-to-End with Any Phone Camera
1. **Cold Scan (No App Installed)**: Point an iPhone or Android native camera at the Lobby QR code → tap the HTTPS banner → CS Explorer opens directly in the mobile browser with `?station=lobby` unlocked and set as your **Red** active station.
2. **In-App Scan**: Tap **Scan** in the bottom dock → allow browser camera permission when prompted → frame the TUAS Bridge QR code (or press the center **Shutter** button on a building sign like `"Learning Hub"`) to unlock the next station and hunt its floating AR puzzle piece!

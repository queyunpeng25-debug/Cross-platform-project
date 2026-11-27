import 'package:flutter/foundation.dart';

/// Three intentional cross-platform experience tiers for CS Explorer:
/// 1. [nativeMobile] — Native Android / iOS app with full ARCore / ARKit 3D
///    portrait tracking, camera QR/sign scanning, and spatial AR minigames.
/// 2. [mobileWeb] — Phone / tablet Web PWA (e.g. cold QR scan) with live
///    camera QR/sign scanning, map positioning, and browser minigames.
/// 3. [laptop] — Desktop / laptop browser or desktop OS with all 9 stations,
///    interactive 3-floor map, canteen menu, and Retro PC exhibit unlocked to
///    browse, while camera & AR-only features are cleanly hidden or locked.
enum DeviceExperience {
  nativeMobile,
  mobileWeb,
  laptop,
}

/// Central capability resolver shared across shell, dock, stations, map, and
/// settings so platform rules live in one testable place.
class DeviceCapabilities {
  const DeviceCapabilities._();

  /// Test-only override to simulate any [DeviceExperience] deterministically.
  @visibleForTesting
  static DeviceExperience? debugExperienceOverride;

  /// Resolves the active [DeviceExperience] based on OS platform and web host.
  ///
  /// Uses [defaultTargetPlatform] rather than viewport width so tablets in
  /// landscape (`>= 840 px`) keep mobile camera/AR features while laptops
  /// (Windows, macOS, Linux) always get the laptop guide experience.
  static DeviceExperience get experience {
    final override = debugExperienceOverride;
    if (override != null) return override;

    final isMobilePlatform =
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;

    if (!isMobilePlatform) {
      return DeviceExperience.laptop;
    }
    return kIsWeb
        ? DeviceExperience.mobileWeb
        : DeviceExperience.nativeMobile;
  }

  static bool get isLaptopMode => experience == DeviceExperience.laptop;
  static bool get isMobileWeb => experience == DeviceExperience.mobileWeb;
  static bool get isNativeMobile => experience == DeviceExperience.nativeMobile;

  /// Live camera QR / visual sign scanning (`UnifiedScanScreen`, map `Locate me`).
  static bool get supportsCameraScan => !isLaptopMode;

  /// Mobile camera & motion-sensor AR experiences (floating AR puzzle hunt,
  /// Greenhouse angle quest, final tabletop AR puzzle).
  static bool get supportsArExperiences => !isLaptopMode;

  /// Native ARCore (Android) / ARKit (iOS) 3D portrait tracking.
  static bool get supportsNative3dAr => isNativeMobile;

  /// On laptops, visitors browse remotely rather than walking around T-talo
  /// scanning physical QR codes, so all stations open directly for reading.
  static bool get autoUnlockStations => isLaptopMode;

  static String get experienceLabel => switch (experience) {
    DeviceExperience.nativeMobile => 'Native Mobile · Full 3D AR',
    DeviceExperience.mobileWeb => 'Mobile Web · On-Site Camera Tour',
    DeviceExperience.laptop => 'Laptop Guide · Camera & AR Mobile-Only',
  };

  static String get experienceDescription => switch (experience) {
    DeviceExperience.nativeMobile =>
      'All features enabled, including native ARCore/ARKit 3D portrait tracking, live QR/sign scanning, and AR puzzle hunt.',
    DeviceExperience.mobileWeb =>
      'On-site browser tour active with live QR/sign scanning, Greenhouse camera quest, and AR puzzle hunt. Use the native Android/iOS app for 3D ARCore/ARKit portraits.',
    DeviceExperience.laptop =>
      'All 9 building stations, the interactive 3-floor map, canteen menu, and Retro PC price game are open to browse. Camera scanning and AR activities are available on mobile devices.',
  };
}

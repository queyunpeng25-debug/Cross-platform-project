# Unified camera scanning

The mobile app loads local content and opens the AR camera automatically. First use still requires camera permission.

Android decodes QR codes from ARCore CPU camera images using ZXing. iOS uses Vision on ARKit camera frames. Neither starts a second camera while AR is active. Decoding is throttled to roughly one frame every 600 ms.

Registered portraits continue to use native image anchors. Recognised guide QR codes open local content; arbitrary URLs are ignored. Opening content disposes the AR session, and returning recreates it with a three-second QR cooldown. The computer exhibit uses `cs-guide://point/computers`.

If AR cannot start, the error screen offers QR-only scanning. Unsupported devices cannot provide spatially anchored portrait content. Browser preview remains `flutter run -d chrome -t lib/preview.dart` and opens the exhibit directly.

Validation still required on Android and iOS hardware: initial permissions, portrait tracking, QR detection in each orientation, return from exhibit/game, app background/resume, unknown codes, denied permissions, and unsupported AR devices. Native builds and device behaviour have not yet been verified for this change.

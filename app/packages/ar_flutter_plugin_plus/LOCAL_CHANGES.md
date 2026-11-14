# CS Explorer local fork

Upstream: ar_flutter_plugin_plus 1.1.3, https://github.com/FranzGraaf/ar_flutter_plugin_plus.
MIT license retained in LICENSE. This is vendored application source, not the global pub cache.

Changes used by this app:

- Both native platforms read physical widths from `assets/ar_targets.json`; image database cache keys include the widths. No hardcoded 20 cm images.
- Android creates an `AugmentedImage.createAnchor` named `__image_<id>` before notifying Dart. iOS already stores its real `ARImageAnchor` under that name. Dart attaches a local GLB child to these native image anchors; it does not create a new anchor for each callback.
- iOS allows up to four tracked images, checks `isTracked` before new detections, emits camera tracking / session error / removed-image events, and checks platform support.
- Android also emits removed-image events and hides its Filament overlay while camera tracking is unavailable. iOS hides the image anchor nodes in the same condition.
- iOS local node addition checks for an existing SceneKit anchor node before reporting success.
- Session error and removed-image callbacks are exposed to Dart. Object initialization is awaitable. Disposal is idempotent and detaches the Dart session handler; native dispose / removal calls now acknowledge completion.
- Permission callbacks check widget lifetime. Unused Android location permission and legacy manifest package attribute removed.
- Android session initialization catches unsupported-device/runtime failures with codec-safe error details.
- Android shared scene maps are concurrent; iOS image-anchor bookkeeping is serialized on the main queue. Late iOS database callbacks cannot restart a disposed camera session.

The app explicitly sets both model scale factors to 1.0; its GLB coordinates are metres. Unchanged upstream cloud-anchor code is not used and requires no API key for this app. The upstream iOS podspec still includes its cloud-anchor-related libraries; no cloud service is started.

Native compilation and physical tracking need Android SDK / an ARCore phone and Mac/Xcode / an ARKit phone. Dart tests do not prove native compilation or real-world stability. Upstream files are excluded from application lint rules, but imported Dart code is compiled by the app tests.

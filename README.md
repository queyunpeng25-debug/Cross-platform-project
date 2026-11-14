# CS Explorer — Flutter 肖像识别与二维码导览

最终版本是 **Android / iOS Flutter App**。从 `app/` 开始，不是网页项目。

你负责的两个模块已经实现：

1. **持续画像识别与 AR 介绍板**：打开 AR 相机 → 手机本地自动识别已登记画像 → 将三维人物介绍板附着在画像右侧 → 随手机移动更新视角。Android 使用 ARCore，iOS 使用 ARKit，不需要电脑服务。
2. **二维码导览**：手机实时扫码 → 查询 App 内的内容表 → 显示对应介绍。二维码功能不依赖服务器。

目前提供四张画像参考图：Kaisa Nyberg、Erkki Oja、Hans Andersin 和 Teuvo Kohonen。姓名依据照片下方铭牌登记；第一张新照片的铭牌写作 “Eikki Oja”，项目按学术资料采用正式拼写 “Erkki Oja”。人物资料来自公开的 Aalto/研究者主页，不是通过面部推断身份。

**新版说明**：先阅读 [持续识别与 AR 使用教程](docs/持续识别与AR.md)。画像本身实测约 **75–85 cm**，当前按中间值 **0.80 米** 配置四幅画像；如之后取得每幅的精确尺寸，可分别更新 `app/assets/ar_targets.json`。使用支持 ARCore / ARKit 的真机。尚未完成原生构建和真机稳定性验证。

**范围**：这是两个模块，不是完整五站项目。现在加入了真实图像锚点与三维介绍板，但大厅路线文字仍需小组补充，互动答题和最终小游戏仍需整合。旧的“照片匹配测试”保留为调试入口，只有该入口需要 Python 服务。

## 文件在哪里

| 文件 | 用途 |
| --- | --- |
| `app/lib/main.dart` | App 首页、拍照、结果卡片、服务器设置 |
| `app/lib/ar_portrait_screen.dart` | 持续识别、图像锚点、AR 会话生命周期 |
| `app/lib/ar_targets.dart` | 目标配置、识别确认、介绍板的相对位置 |
| `app/assets/ar_targets.json` | 画像物理宽度、参考图片与三维面板的对应关系 |
| `app/assets/ar_panels/` | 包含文字贴图的 GLB 三维介绍板与预览图 |
| `app/packages/ar_flutter_plugin_plus/` | 本地修补的双平台 AR 插件，必须随代码提交 |
| `tools/build_ar_panels.py` | 从人物 JSON 重新生成三维介绍板 |
| `app/lib/qr_screen.dart` | 相机实时扫码、未知标记处理、重复扫码保护 |
| `app/lib/content.dart` | 读取本地介绍，二维码白名单匹配 |
| `app/lib/portrait_service.dart` | 上传照片、地址校验、15 秒超时 |
| `app/assets/content.json` | 修改人物、地点介绍 |
| `backend/recognizer.py` | ORB 特征匹配与 RANSAC 几何验证 |
| `backend/main.py` | `/health` 和 `/recognize` HTTP 接口 |
| `backend/references.json` | 参考图片与人物 ID 对照表 |
| `backend/references/kaisa_nyberg.jpg` | 从你提供的图片中裁切并校正的参考画像 |
| `demo_qr/` | 可打印的测试二维码 |
| `docs/学习与答辩.md` | 原理、增加画像、队友整合与答辩 |
| `docs/真机验收.md` | Android / iOS 现场检查表 |

## 第一步：准备 Android 开发环境

当前电脑已有 Flutter 3.47.2 / Dart 3.13.2 与 Python。检查时未检测到 Android SDK，也没有连接 Android / iOS 手机，因此还没有产出 APK 或完成真机验证。

1. 安装 [Android Studio](https://developer.android.com/studio)。
2. 打开 Android Studio → More Actions → SDK Manager。安装 Android SDK Platform，以及 SDK Tools 中的 Command-line Tools、Build-Tools、Platform-Tools；根据 Flutter 构建提示补齐 NDK / CMake。
3. 如果 SDK 装在自定义目录，执行 `flutter config --android-sdk "你的实际SDK目录"`。
4. 在终端运行下面两条命令，阅读并处理 SDK 许可，直到 Android toolchain 通过。

```powershell
flutter doctor --android-licenses
flutter doctor -v
```

5. Android 手机上开启开发者选项和 USB 调试，用数据线连接电脑，在手机上允许调试。
6. 执行 `flutter devices`，确认列表中出现手机。不要选择 Chrome 或 Windows，本项目面向 Android / iOS。

详细步骤见 [Flutter 官方 Android 设置](https://docs.flutter.dev/platform-integration/android/setup)。

## 第二步（可选）：启动旧版照片测试服务

**新版持续 AR 识别与二维码均不需要此服务，也不需要同一 Wi-Fi。只体验新版时，直接跳到第四步。**

在 PowerShell 中进入项目根目录：

```powershell
cd D:\Crossplatform\Project
```

当前机器的 `.venv` 已安装依赖。若换电脑或重新安装：

```powershell
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r backend\requirements-lock.txt
```

`requirements-lock.txt` 记录本次验证环境的精确版本；如不同 Python 版本无法安装，使用 `requirements.txt` 的版本范围并重新运行测试。推荐 Python 3.13，与本次环境一致。

启动并保持终端打开：

```powershell
.\.venv\Scripts\python.exe -m uvicorn backend.main:app --host 0.0.0.0 --port 8000
```

也可运行 `./start_backend.ps1`；若 PowerShell 阻止脚本，直接使用上面的 Python 命令即可。

在电脑浏览器打开 [服务检查](http://127.0.0.1:8000/health)，应显示 `{"status":"ok","references":1}`。接口调试页面为 [API 文档](http://127.0.0.1:8000/docs)。

## 第三步（仅旧版照片测试）：连接手机与电脑

1. 手机和电脑连接同一个可互通的 Wi-Fi。
2. 电脑执行 `ipconfig`，找到当前 Wi-Fi 的 IPv4，例如 `192.168.1.23`。
3. 手机上用浏览器访问 `http://192.168.1.23:8000/health`。只有这个页面可访问，App 的画像请求才会成功。
4. 若不通，检查 Windows 防火墙是否允许此 Python 服务在私有网络通信。校园 Wi-Fi 可能禁止设备互访，可尝试自己的热点。不要直接关闭整个防火墙。

这里的地址是示例，必须换成你电脑实际的 IP。`0.0.0.0` 是服务监听地址，不是 App 应填写的地址；手机上的 `localhost` 指手机自己。

## 第四步：运行 App

再打开一个终端：

```powershell
cd D:\Crossplatform\Project\app
flutter pub get
flutter devices
flutter run -d 你的手机设备ID --release
```

把设备 ID 换成真实值。持续 AR 识别无需服务器设置。建议真机使用 `--release` 检验跟踪稳定性，避免部分设备在 debug 模式中的 ARCore 跟踪问题。

如需旧版照片测试，可加 `--dart-define=API_BASE_URL=http://你的电脑IP:8000`，或点击 App 右上角设置填写根地址；设置页修改仅在当前运行有效。

Android 模拟器默认地址为 `http://10.0.2.2:8000`，真机不要使用它。

App 启动后：

1. 点击「扫描二维码」，对准 `demo_qr/computers.png`，看到五台电脑介绍。
2. 扫描 `demo_qr/portrait_kaisa.png`，看到画像站介绍。
3. 点击「持续识别肖像 · AR 介绍」，允许相机权限，对准整幅画像并缓慢移动手机。识别后介绍板出现在画像右侧。
4. 缓慢左右移动、靠近或后退，检查介绍板是否保持在画像旁。回到后台会暂停相机，返回后点「恢复 AR 识别」重新定位。
5. 不在楼内时，可按已知宽度打印参考图，并同步修改 `ar_targets.json` 的宽度进行 AR 测试。旧版照片匹配测试不能验证 AR 跟踪。

二维码文件不是普通网站链接。请使用本 App 扫描，而不是期待系统相机打开网页。

## iOS 如何运行

Windows 无法编译 iOS App。把项目交给有 Mac 的队友，在 Mac 安装兼容的 Flutter、Xcode 和其要求的工具。本工程当前最低 Android API 24，iOS 工程目标为 15.0。

1. 在 Mac 的 `app/` 目录执行 `flutter pub get`。
2. 按 [Flutter 官方 iOS 设置](https://docs.flutter.dev/platform-integration/ios/setup) 配置 Xcode、签名和开发者模式。
3. 在 Xcode 中打开 `ios/Runner.xcworkspace`，选择自己的 Team，必要时更改 Bundle Identifier。
4. 连接 iPhone，允许信任电脑，用 `flutter devices` 查到设备。
5. 本地 AR 插件使用 CocoaPods；`cd ios` 后执行 `pod install`，再返回 `app/` 执行 `flutter run -d 设备ID --release`。工程已添加 Podfile、相机权限宏与 Pods 配置引用。
6. 在支持 ARKit 的 iPhone 上允许相机权限，执行与 Android 相同的 AR 和二维码验收步骤。

如果使用旧版照片入口，Python 服务可以继续运行在 Windows 电脑上。新版 Android / iOS 共用 Dart 流程、内容、尺寸与面板，但使用各自原生 AR 引擎，真实表现必须分别验证。

## 测试与打包

```powershell
cd D:\Crossplatform\Project
.\.venv\Scripts\python.exe -m pytest backend -q
cd app
flutter analyze
flutter test
```

安装好 Android SDK 后生成可演示的 release APK：

```powershell
flutter build apk --release
```

输出在 `app/build/app/outputs/flutter-apk/app-release.apk`。当前没有生成该文件；模板的 release 仍使用开发签名，仅用于课程演示。发布商店前需要正式签名；旧版网络测试入口的 HTTP 放行是为局域网演示设置的。

## 常见问题

| 现象 | 排查 |
| --- | --- |
| QR 能扫，画像不行 | QR 不需要服务；检查手机访问 `/health` 是否成功 |
| 画像未匹配 | 正对拍摄，画像占据大部分画面，避反光；确认参考图片与现场是同一幅 |
| 新增人物一直不显示 | JSON ID 必须一致；重启 Python 服务并重启 App |
| 拒绝了相机权限 | 在手机系统设置中重新允许，再进入扫码 / 拍照 |
| 照片返回 400 | 使用 JPEG/PNG，HEIC 请先转换 |
| 扫到陌生二维码 | 这是预期行为：只显示已登记的项目内容 |
| iPhone 无法访问服务 | 检查本地网络权限、同一网络和服务器地址 |

本原型服务用于可信局域网课程演示，不包含用户登录、公开互联网部署或大流量防护。识别请求不落盘保存照片；参考图库是预先登记并随项目保留的资源。

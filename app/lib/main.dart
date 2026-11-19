import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zenify/zenify.dart';

import 'content.dart';
import 'core/controllers.dart';
import 'core/translation_service.dart';
import 'features/canteen/default_canteen_slot.dart';
import 'features/canteen/canteen_menu_service.dart';
import 'features/map/default_map_slot.dart';
import 'features/minigames/default_minigame_slot.dart';
import 'ui/app_shell.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Zen.init();

  SharedPreferences? prefs;
  try {
    prefs = await SharedPreferences.getInstance();
  } catch (_) {
    prefs = null;
  }

  final catalog = await StationCatalogRepository.loadFromAssets();
  final nativeEn = await GoogleFreeTranslationService.loadBundledEnglishAsset();
  final translationService = GoogleFreeTranslationService(
    prefs: prefs,
    nativeEnglishStrings: nativeEn,
  );
  final canteenMenuRepository = CanteenMenuRepository();
  unawaited(canteenMenuRepository.refresh());

  runApp(
    CsExplorerRootApp(
      catalog: catalog,
      translationService: translationService,
      canteenMenuRepository: canteenMenuRepository,
      prefs: prefs,
    ),
  );
}

class CsExplorerRootApp extends StatefulWidget {
  const CsExplorerRootApp({
    super.key,
    required this.catalog,
    required this.translationService,
    required this.canteenMenuRepository,
    this.prefs,
    this.showFirstLaunchPrompt = true,
  });

  final StationCatalogRepository catalog;
  final TranslationService translationService;
  final CanteenMenuRepository canteenMenuRepository;
  final SharedPreferences? prefs;
  final bool showFirstLaunchPrompt;

  @override
  State<CsExplorerRootApp> createState() => _CsExplorerRootAppState();
}

class _CsExplorerRootAppState extends State<CsExplorerRootApp> {
  late final GoRouter _router = GoRouter(
    initialLocation: '/',
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (context, state) => CsExplorerShell(
          initialStationQueryParam: state.uri.queryParameters['station'],
          showFirstLaunchPrompt: widget.showFirstLaunchPrompt,
        ),
      ),
      GoRoute(
        path: '/station/:id',
        builder: (context, state) => CsExplorerShell(
          initialStationQueryParam: state.pathParameters['id'],
          showFirstLaunchPrompt: widget.showFirstLaunchPrompt,
        ),
      ),
    ],
  );

  @override
  void initState() {
    super.initState();
    CsExplorerAppModule(
      catalog: widget.catalog,
      translationService: widget.translationService,
      mapSlot: const DefaultMapFeatureSlot(),
      canteenSlot: DefaultCanteenFeatureSlot(
        menuRepository: widget.canteenMenuRepository,
      ),
      minigameSlot: const DefaultMinigameFeatureSlot(),
      prefs: widget.prefs,
    ).register(Zen.rootScope);
  }

  @override
  void dispose() {
    _router.dispose();
    widget.canteenMenuRepository.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = Zen.find<AppSettingsController>();
    return ZenObserver(
      () => MaterialApp.router(
        title: 'CS Explorer',
        debugShowCheckedModeBanner: false,
        theme: CsAppTheme.light(),
        darkTheme: CsAppTheme.dark(),
        themeMode: settings.themeMode.value,
        routerConfig: _router,
      ),
    );
  }
}

/// Preserved reusable entry card used by Yunpeng's portrait recognition views
/// (`ar_portrait_screen.dart` & `test/layout_test.dart`).
class EntryCard extends StatelessWidget {
  final GuideEntry entry;
  const EntryCard({super.key, required this.entry});

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    color: Colors.white,
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entry.subtitle,
            style: const TextStyle(fontSize: 12, color: Color(0xff627761)),
          ),
          const SizedBox(height: 12),
          Text(
            entry.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: const Color(0xff1e2d27),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            entry.body,
            style: const TextStyle(height: 1.9, color: Color(0xff1e2d27)),
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: const Color(0xfff1f3e9),
            child: Text(
              entry.task,
              style: const TextStyle(height: 1.7, color: Color(0xff1e2d27)),
            ),
          ),
          if (entry.source != null) ...[
            const SizedBox(height: 18),
            const Text(
              'Source (hold to copy)',
              style: TextStyle(fontSize: 11, color: Colors.black87),
            ),
            SelectableText(
              entry.source!,
              style: const TextStyle(fontSize: 11, color: Colors.black54),
            ),
          ],
        ],
      ),
    ),
  );
}

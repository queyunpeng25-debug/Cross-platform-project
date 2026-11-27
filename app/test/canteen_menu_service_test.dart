import 'package:cs_building_guide/core/controllers.dart';
import 'package:cs_building_guide/core/translation_service.dart';
import 'package:cs_building_guide/features/canteen/canteen_menu_service.dart';
import 'package:cs_building_guide/features/canteen/default_canteen_slot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zenify/zenify.dart';

class _NoopTranslationService implements TranslationService {
  @override
  String? cachedOrImmediate(String englishText, {required String targetLang}) =>
      englishText;

  @override
  Future<String> translate(
    String englishText, {
    required String targetLang,
  }) async => englishText;

  @override
  void close() {}
}

void main() {
  test('Parser reads restaurant dishes and expands dietary labels', () {
    const page = '''
      <li id="computer-science-building" class="restaurant">
        <h3>Computer Science Building</h3>
        <ul>
          <li>Plant-based Potato Hash (<abbr title="gluten-free">G</abbr>,
            <abbr title="milk-free">M</abbr>, <abbr title="vegan">VV</abbr>)</li>
          <li>Fish &amp; Chips (<abbr title="lactose-free">L</abbr>)</li>
        </ul>
      </li>
      <li><ul><li>Not the canteen</li></ul></li>
    ''';

    expect(CanteenMenuService.parseMenu(page), [
      'Plant-based Potato Hash (gluten-free, milk-free, vegan)',
      'Fish & Chips (lactose-free)',
    ]);
  });

  test(
    'Service fetches the source page and reports missing restaurants',
    () async {
      final service = CanteenMenuService(
        client: MockClient((request) async {
          expect(
            request.url.toString(),
            'https://folio.kanttiinit.fi/en/area/1',
          );
          return http.Response(
            '<li id="computer-science-building"><ul><li>Soup</li></ul></li>',
            200,
          );
        }),
      );

      expect(await service.fetchMenu(), ['Soup']);
      expect(
        () => CanteenMenuService.parseMenu('<html></html>'),
        throwsA(isA<CanteenMenuException>()),
      );
    },
  );

  testWidgets(
    'Canteen screen and dish review stars render without overflow on compact phones',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await Zen.init();
      Zen.reset();
      addTearDown(Zen.reset);

      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = CanteenMenuRepository(
        service: CanteenMenuService(
          client: MockClient(
            (_) async => http.Response(
              '<li id="computer-science-building"><ul>'
              '<li>Chili Con Carne, Tortillas &amp; Jalapenos, French Sour Cream &amp; Rice '
              '(<abbr title="lactose-free">L</abbr>)</li>'
              '<li>Fruit Quark (<abbr title="gluten-free">G</abbr>)</li>'
              '</ul></li>',
              200,
            ),
          ),
        ),
      );
      addTearDown(repo.dispose);
      await repo.refresh();

      final settings = AppSettingsController();
      final translator = _NoopTranslationService();
      Zen.put<AppSettingsController>(settings);
      Zen.put<TranslationService>(translator);

      final slot = DefaultCanteenFeatureSlot(menuRepository: repo);

      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(1.2),
            ),
            child: child!,
          ),
          home: Builder(
            builder: (context) => slot.buildCanteenScreen(
              context,
              translator: translator,
              settings: settings,
              onBackToLobby: () {},
              onCatchPuzzlePiece: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final submitBtn = find.text('Submit Demo Review');
      await tester.scrollUntilVisible(
        submitBtn,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();

      expect(tester.takeException(), isNull);

      await tester.ensureVisible(find.byIcon(Icons.star_rounded).at(3));
      await tester.tap(find.byIcon(Icons.star_rounded).at(3));
      await tester.pump();
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pump();

      expect(find.textContaining('Verified Student Demo Review'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

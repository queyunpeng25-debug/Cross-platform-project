import 'package:cs_building_guide/features/canteen/canteen_menu_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

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
}

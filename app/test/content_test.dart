import 'package:flutter_test/flutter_test.dart';
import 'package:cs_building_guide/content.dart';
import 'package:cs_building_guide/portrait_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'QR allowlist resolves registered codes and rejects unknown URLs',
    () async {
      final content = await GuideContent.load();
      expect(content.findQr('cs-guide://point/lobby'), isNull);
      expect(content.findQr('  cs-guide://point/portrait_kaisa\n'), isNotNull);
      expect(content.findQr('https://example.com'), isNull);
      expect(content.findQr('cs-guide://point/unknown'), isNull);
      expect(content.portraits['kaisa_nyberg'], isNotNull);
    },
  );
  test(
    'server address rejects unsafe schemes and accidental endpoint paths',
    () {
      expect(
        PortraitService.validateAddress('http://192.168.1.2:8000').host,
        '192.168.1.2',
      );
      expect(
        PortraitService.validateAddress('https://example.com/').scheme,
        'https',
      );
      for (final value in [
        'file:///tmp',
        'hello',
        'http://host/recognize',
        'http://user:pass@host',
        'http://host?x=1',
      ]) {
        expect(
          () => PortraitService.validateAddress(value),
          throwsFormatException,
        );
      }
    },
  );
}

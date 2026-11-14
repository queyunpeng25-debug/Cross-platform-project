import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class PortraitService {
  final String baseUrl;
  PortraitService(this.baseUrl);

  static Uri validateAddress(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/')) {
      throw const FormatException('Enter a server URL, such as http://192.168.1.23:8000');
    }
    return uri;
  }

  Future<String?> recognize(XFile photo) async {
    final root = validateAddress(baseUrl);
    if (await photo.length() > 8 * 1024 * 1024) {
      throw const FormatException('Image must be smaller than 8 MB.');
    }
    final client = http.Client();
    try {
      final request = http.MultipartRequest('POST', root.resolve('/recognize'));
      request.files.add(await http.MultipartFile.fromPath('file', photo.path));
      final response = await (() async => http.Response.fromStream(
        await client.send(request),
      ))().timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw FormatException('Server returned ${response.statusCode}. Check the image format and service.');
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['matched'] == true ? data['id'] as String : null;
    } finally {
      client.close();
    }
  }
}

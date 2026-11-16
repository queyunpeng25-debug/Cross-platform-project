import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zenify/zenify.dart';

import 'controllers.dart';

/// XCI Part 4 typed service boundary for full-app & Canteen menu translation.
/// Base language is English ('en'). Teammates (e.g. Juhani's Canteen module)
/// can resolve `Zen.find<TranslationService>()` or use [TrText] directly.
abstract interface class TranslationService {
  Future<String> translate(String englishText, {required String targetLang});

  String? cachedOrImmediate(String englishText, {required String targetLang});

  void close();
}

class GoogleFreeTranslationService implements TranslationService {
  GoogleFreeTranslationService({
    required this.prefs,
    http.Client? httpClient,
    Map<String, String>? nativeEnglishStrings,
  }) : _client = httpClient ?? http.Client(),
       _ownsClient = httpClient == null,
       _nativeEn = nativeEnglishStrings ?? const {};

  static const String _cachePrefix = 'cs_tr_v1_';

  final SharedPreferences? prefs;
  final http.Client _client;
  final bool _ownsClient;
  final Map<String, String> _nativeEn;

  final Map<String, String> _memoryCache = <String, String>{};
  final Map<String, Future<String>> _inFlight = <String, Future<String>>{};
  bool _closed = false;

  static Future<Map<String, String>> loadBundledEnglishAsset() async {
    try {
      final raw = await rootBundle.loadString('assets/i18n/en.json');
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, v.toString()));
    } catch (_) {
      return const {};
    }
  }

  String _resolveBaseEnglish(String keyOrText) =>
      _nativeEn[keyOrText] ?? keyOrText;

  String _cacheKey(String lang, String source) =>
      '$_cachePrefix${lang}_${source.hashCode}_${source.length}';

  @override
  String? cachedOrImmediate(String englishText, {required String targetLang}) {
    final resolved = _resolveBaseEnglish(englishText);
    if (resolved.trim().isEmpty || targetLang == 'en') {
      return resolved;
    }
    final key = _cacheKey(targetLang, resolved);
    final mem = _memoryCache[key];
    if (mem != null) return mem;
    final disk = prefs?.getString(key);
    if (disk != null && disk.isNotEmpty) {
      _memoryCache[key] = disk;
      return disk;
    }
    return null;
  }

  @override
  Future<String> translate(
    String englishText, {
    required String targetLang,
  }) async {
    final resolved = _resolveBaseEnglish(englishText);
    final immediate = cachedOrImmediate(resolved, targetLang: targetLang);
    if (immediate != null) return immediate;
    if (_closed) return resolved;

    final key = _cacheKey(targetLang, resolved);
    // XCI Part 5: Coalesce duplicate concurrent requests for the same phrase.
    final existing = _inFlight[key];
    if (existing != null) return existing;

    final future = _fetchGoogleFreeTranslation(
      resolved,
      targetLang: targetLang,
      cacheKey: key,
    );
    _inFlight[key] = future;
    try {
      return await future;
    } finally {
      _inFlight.remove(key);
    }
  }

  Future<String> _fetchGoogleFreeTranslation(
    String text, {
    required String targetLang,
    required String cacheKey,
  }) async {
    try {
      final uri = Uri.https(
        'translate.googleapis.com',
        '/translate_a/single',
        <String, String>{
          'client': 'gtx',
          'sl': 'en',
          'tl': targetLang,
          'dt': 't',
          'q': text,
        },
      );
      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return text;

      final dynamic payload = jsonDecode(utf8.decode(response.bodyBytes));
      if (payload is! List || payload.isEmpty || payload.first is! List) {
        return text;
      }
      final segments = payload.first as List<dynamic>;
      final buffer = StringBuffer();
      for (final segment in segments) {
        if (segment is List && segment.isNotEmpty && segment.first != null) {
          buffer.write(segment.first.toString());
        }
      }
      final translated = buffer.toString().trim();
      if (translated.isEmpty) return text;

      _memoryCache[cacheKey] = translated;
      unawaited(prefs?.setString(cacheKey, translated));
      return translated;
    } catch (_) {
      // Graceful offline fallback: always keep English readable.
      return text;
    }
  }

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    if (_ownsClient) {
      _client.close();
    }
  }
}

/// Reactive text widget that automatically translates its English [text]
/// whenever `AppSettingsController.languageCode` changes, using an XCI Part 5
/// sequence token (`_requestEpoch`) so out-of-order responses are ignored.
class TrText extends StatefulWidget {
  const TrText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  State<TrText> createState() => _TrTextState();
}

class _TrTextState extends State<TrText> {
  int _requestEpoch = 0;
  String? _activeLang;
  String? _activeSource;
  String _displayed = '';

  void _ensureTranslation(
    TranslationService service,
    String targetLang,
  ) {
    if (_activeLang == targetLang && _activeSource == widget.text) return;
    _activeLang = targetLang;
    _activeSource = widget.text;
    final token = ++_requestEpoch;

    final immediate = service.cachedOrImmediate(
      widget.text,
      targetLang: targetLang,
    );
    if (immediate != null) {
      _displayed = immediate;
      return;
    }

    // Show English base text immediately while fetching, avoiding blank flicker.
    _displayed = widget.text;
    unawaited(
      service.translate(widget.text, targetLang: targetLang).then((result) {
        if (mounted && token == _requestEpoch && result != _displayed) {
          setState(() {
            _displayed = result;
          });
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = Zen.findOrNull<AppSettingsController>();
    final service = Zen.findOrNull<TranslationService>();
    if (settings == null || service == null) {
      return Text(
        widget.text,
        style: widget.style,
        textAlign: widget.textAlign,
        maxLines: widget.maxLines,
        overflow: widget.overflow,
      );
    }

    return ZenObserver(() {
      final lang = settings.languageCode.value;
      _ensureTranslation(service, lang);
      return Text(
        _displayed,
        style: widget.style,
        textAlign: widget.textAlign,
        maxLines: widget.maxLines,
        overflow: widget.overflow,
      );
    });
  }
}

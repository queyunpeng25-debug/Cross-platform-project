import 'dart:convert';

import 'package:flutter/services.dart';

class GuideEntry {
  final String title, subtitle, body, task;
  final String? source;
  const GuideEntry({
    required this.title,
    required this.subtitle,
    required this.body,
    required this.task,
    this.source,
  });
  factory GuideEntry.fromJson(Map<String, dynamic> value) => GuideEntry(
    title: value['title'] as String,
    subtitle: value['subtitle'] as String,
    body: value['body'] as String,
    task: value['task'] as String,
    source: value['source'] as String?,
  );
}

class GuideContent {
  final Map<String, GuideEntry> portraits, qr;
  GuideContent(this.portraits, this.qr);
  factory GuideContent.fromJson(Map<String, dynamic> json) {
    Map<String, GuideEntry> parse(String key) =>
        (json[key] as Map<String, dynamic>).map(
          (id, data) =>
              MapEntry(id, GuideEntry.fromJson(data as Map<String, dynamic>)),
        );
    return GuideContent(parse('portraits'), parse('qr'));
  }
  static Future<GuideContent> load() async => GuideContent.fromJson(
    jsonDecode(await rootBundle.loadString('assets/content.json'))
        as Map<String, dynamic>,
  );
  // Exact allowlist: arbitrary QR URLs are never opened or executed.
  GuideEntry? findQr(String raw) => qr[raw.trim()];
}

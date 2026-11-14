import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cs_building_guide/main.dart';
import 'package:cs_building_guide/content.dart';

void main() {
  testWidgets('result card fits a small phone with enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: EntryCard(
                entry: GuideEntry(
                  title: 'Kaisa Nyberg',
                  subtitle: '密码学 · Cryptography',
                  body: '人物介绍。' * 40,
                  task: '观察画像并思考。',
                  source: 'https://users.ics.aalto.fi/knyberg/',
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Kaisa Nyberg'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

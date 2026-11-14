import 'package:flutter/material.dart';
import 'computer_exhibit.dart';

// Browser preview of the exhibit and game; no camera or AR required.
void main() => runApp(const ExhibitPreview());

class ExhibitPreview extends StatelessWidget {
  const ExhibitPreview({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'CS Explorer — Computer Exhibit',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff214b3c)),
      scaffoldBackgroundColor: const Color(0xfff5f5ee),
    ),
    home: const ComputerExhibit(),
  );
}

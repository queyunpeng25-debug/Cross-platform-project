
import 'package:flutter/material.dart';

import 'content.dart';
import 'ar_portrait_screen.dart';

void main() => runApp(const GuideApp());

class GuideApp extends StatelessWidget {
  const GuideApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'CS Explorer',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff214b3c)),
      scaffoldBackgroundColor: const Color(0xfff5f5ee),
      appBarTheme: const AppBarTheme(backgroundColor: Color(0xfff5f5ee)),
    ),
    home: const GuideHome(),
  );
}

class GuideHome extends StatefulWidget {
  const GuideHome({super.key});
  @override
  State<GuideHome> createState() => _GuideHomeState();
}

class _GuideHomeState extends State<GuideHome> {
  GuideContent? content;
  bool loading = true;
  @override
  void initState() { super.initState(); load(); }
  Future<void> load() async {
    setState(() => loading = true);
    try {
      final loaded = await GuideContent.load();
      if (mounted) setState(() { content = loaded; loading = false; });
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }
  @override
  Widget build(BuildContext context) {
    if (content != null) return ArPortraitScreen(content: content!);
    return Scaffold(
      appBar: AppBar(title: const Text('CS Explorer')),
      body: Center(child: loading
        ? const Column(mainAxisSize: MainAxisSize.min, children: [
            CircularProgressIndicator(), SizedBox(height: 16), Text('Preparing scanner…'),
          ])
        : Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Unable to load guide content.'),
            TextButton(onPressed: load, child: const Text('Try again')),
          ])),
    );
  }
}

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
          Text(entry.title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          Text(entry.body, style: const TextStyle(height: 1.9)),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: const Color(0xfff1f3e9),
            child: Text(entry.task, style: const TextStyle(height: 1.7)),
          ),
          if (entry.source != null) ...[
            const SizedBox(height: 18),
            const Text('Source (hold to copy)', style: TextStyle(fontSize: 11)),
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

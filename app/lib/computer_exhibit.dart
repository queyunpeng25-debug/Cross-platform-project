import 'package:flutter/material.dart';

const computerQr = 'cs-guide://point/computers';

class ComputerExhibit extends StatelessWidget {
  const ComputerExhibit({super.key});
  static const names = ['Moomin Laptop', 'iMac G3', 'SGI O2', 'NeXTstation', 'IBM PC/AT'];
  static const descriptions = [
    'A playful educational toy with a Finnish alphabet keyboard and Moomin characters. The exhibit label credits Moominpappa and describes fictional software. These are part of the exhibit humour, not verified technical specifications.',
    'Apple’s colourful all-in-one computer family, introduced in 1998. The exhibit lists Mac OS 8, Mac OS 9 and Mac OS X, optical-disc storage and 32–512 MB of memory across the family. The photographed machine is a later slot-loading variant.',
    'Introduced by Silicon Graphics in 1996, the O2 was a Unix workstation for research, teaching and 3D modelling. The exhibit lists IRIX, CD-ROM storage and 256 MB–1 GB of memory. The large screen is a separate monitor.',
    'Introduced in 1990, the NeXTstation was nicknamed “the slab”. It ran NeXTSTEP, whose technology later contributed to Apple’s Mac OS X. The exhibit lists a 2.88 MB floppy drive and 8–32 MB of memory.',
    'IBM introduced the PC/AT in 1984. According to this exhibit, these machines were among the CS department’s first desktop Unix systems, running XENIX. The display pairs the IBM computer with an Osborne monitor.',
  ];
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Evolution of Computers')),
    body: ListView(padding: const EdgeInsets.all(20), children: [
      const Text('Five exhibits. Five different ideas about computing.', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
      const SizedBox(height: 16),
      for (var i = 0; i < names.length; i++) Card(child: Padding(
        padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Image.asset('assets/computers/computer_$i.jpg', height: 230, width: double.infinity, fit: BoxFit.contain),
          const SizedBox(height: 12), Text(names[i], style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8), Text(descriptions[i]),
        ]))),
      const SizedBox(height: 20),
      FilledButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ComputerPriceGame())), child: const Text('Play the price-matching game')),
    ]),
  );
}

class ComputerPriceGame extends StatefulWidget {
  const ComputerPriceGame({super.key});
  @override
  State<ComputerPriceGame> createState() => _ComputerPriceGameState();
}

class _ComputerPriceGameState extends State<ComputerPriceGame> {
  // Provisional game data: replace with documented launch configurations before release.
  static const prices = ['€27', '€1,172', '€6,768', '€4,508', '€3,610'];
  final choices = List<int?>.filled(5, null);
  late List<int> order;
  bool submitted = false;
  @override
  void initState() { super.initState(); order = List.generate(5, (i) => i)..shuffle(); }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Match the Price')),
    body: ListView(padding: const EdgeInsets.all(20), children: [
      const Text('Preview game: historical prices are still being verified. The Moomin price is a supplied estimate. All amounts are rounded euro equivalents using the ECB rate on 12 November 2026 (1 EUR = 1.1081 USD), without inflation adjustment. These are not original euro launch prices.', style: TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      const Text('Assign each price once. Choosing a price already assigned to another computer moves it here. Submit all five matches to see your results.'),
      if (submitted) Padding(padding: const EdgeInsets.symmetric(vertical: 20), child: Text('Score: ${List.generate(5, (i) => i).where((i) => choices[i] == i).length} / 5', style: Theme.of(context).textTheme.headlineMedium)),
      for (var i = 0; i < 5; i++) Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Image.asset('assets/computers/computer_$i.jpg', height: 180, width: double.infinity, fit: BoxFit.contain),
        Text(ComputerExhibit.names[i], style: Theme.of(context).textTheme.titleLarge),
        Wrap(spacing: 8, children: [for (final p in order) ChoiceChip(label: Text(prices[p]), selected: choices[i] == p, onSelected: submitted ? null : (_) => setState(() {
          for (var j = 0; j < 5; j++) { if (choices[j] == p) choices[j] = null; }
          choices[i] = p;
        }))]),
        if (submitted) Text('${choices[i] == i ? "Correct" : "Incorrect"} — Answer: ${prices[i]}', style: TextStyle(color: choices[i] == i ? Colors.green.shade800 : Colors.red.shade800, fontWeight: FontWeight.bold)),
      ]))),
      FilledButton(onPressed: !submitted && choices.every((p) => p != null) ? () => setState(() => submitted = true) : null, child: const Text('Submit matches')),
      if (submitted) OutlinedButton(onPressed: () => setState(() { choices.fillRange(0, 5, null); order.shuffle(); submitted = false; }), child: const Text('Play again')),
    ]),
  );
}

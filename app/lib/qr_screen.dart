import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'content.dart';
import 'computer_exhibit.dart';

class QrScreen extends StatefulWidget {
  final GuideContent content;
  const QrScreen({super.key, required this.content});
  @override
  State<QrScreen> createState() => _QrScreenState();
}

class _QrScreenState extends State<QrScreen> {
  bool finished = false;
  String message = 'Place the complete guide QR code inside the frame';
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(title: const Text('Scan QR Code')),
    body: Stack(
      children: [
        // The widget owns its controller and handles lifecycle pause/resume.
        MobileScanner(
          onDetect: (capture) {
            if (finished) return;
            for (final code in capture.barcodes) {
              final raw = code.rawValue;
              if (raw == null) continue;
              if (raw.trim() == computerQr) {
                finished = true;
                Navigator.of(context).pushReplacement(MaterialPageRoute<GuideEntry>(builder: (_) => const ComputerExhibit()));
                return;
              }
              final entry = widget.content.findQr(raw);
              if (entry != null) {
                finished = true;
                Navigator.of(context).pop(entry);
                return;
              }
            }
            if (message != 'Unknown code. Please scan a CS Explorer marker.') {
              setState(() => message = 'Unknown code. Please scan a CS Explorer marker.');
            }
          },
          errorBuilder: (context, error) => Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Text(
                'Camera unavailable. Allow camera access in Settings, '
                'close other camera apps and try again.\n${error.errorCode.name}',
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
        IgnorePointer(
          child: Center(
            child: Container(
              width: 245,
              height: 245,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white70, width: 2),
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
        ),
        Positioned(
          left: 20,
          right: 20,
          bottom: 40,
          child: SafeArea(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Text(message, textAlign: TextAlign.center),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

import 'dart:ui';

import 'package:flutter/material.dart';

/// Drawn vector jigsaw puzzle piece icon (zero emojis).
/// Renders a crisp thin outline when [collected] is `false`, and a solid filled
/// silhouette with subtle inner highlight when [collected] is `true`.
class PuzzlePieceIcon extends StatelessWidget {
  const PuzzlePieceIcon({
    super.key,
    required this.collected,
    this.size = 20,
    this.activeColor,
    this.inactiveColor,
  });

  final bool collected;
  final double size;
  final Color? activeColor;
  final Color? inactiveColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fillOrStroke = collected
        ? (activeColor ?? scheme.secondary)
        : (inactiveColor ?? scheme.onSurface.withValues(alpha: 0.30));

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _JigsawPiecePainter(
          color: fillOrStroke,
          filled: collected,
        ),
      ),
    );
  }
}

class _JigsawPiecePainter extends CustomPainter {
  const _JigsawPiecePainter({
    required this.color,
    required this.filled,
  });

  final Color color;
  final bool filled;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Classic jigsaw piece inside [0..w, 0..h]:
    // Base square [0.14..0.78, 0.22..0.86] with top tab & right tab,
    // plus a subtle bottom indentation.
    final l = w * 0.14;
    final r = w * 0.78;
    final t = h * 0.22;
    final b = h * 0.86;
    final midX = (l + r) * 0.5;
    final midY = (t + b) * 0.5;
    final radius = w * 0.08;
    final knobR = w * 0.125;

    final path = Path()
      ..moveTo(l + radius, t)
      // Top edge with outward puzzle knob
      ..lineTo(midX - knobR * 0.75, t)
      ..cubicTo(
        midX - knobR * 1.15,
        t - knobR * 1.55,
        midX + knobR * 1.15,
        t - knobR * 1.55,
        midX + knobR * 0.75,
        t,
      )
      ..lineTo(r - radius, t)
      ..quadraticBezierTo(r, t, r, t + radius)
      // Right edge with outward puzzle knob
      ..lineTo(r, midY - knobR * 0.75)
      ..cubicTo(
        r + knobR * 1.55,
        midY - knobR * 1.15,
        r + knobR * 1.55,
        midY + knobR * 1.15,
        r,
        midY + knobR * 0.75,
      )
      ..lineTo(r, b - radius)
      ..quadraticBezierTo(r, b, r - radius, b)
      // Bottom edge with inward puzzle blank
      ..lineTo(midX + knobR * 0.72, b)
      ..cubicTo(
        midX + knobR * 0.95,
        b - knobR * 1.20,
        midX - knobR * 0.95,
        b - knobR * 1.20,
        midX - knobR * 0.72,
        b,
      )
      ..lineTo(l + radius, b)
      ..quadraticBezierTo(l, b, l, b - radius)
      // Left straight edge
      ..lineTo(l, t + radius)
      ..quadraticBezierTo(l, t, l + radius, t)
      ..close();

    if (filled) {
      final fillPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill
        ..isAntiAlias = true;
      canvas.drawPath(path, fillPaint);
    } else {
      final strokePaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.55
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true;
      canvas.drawPath(path, strokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _JigsawPiecePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.filled != filled;
}

/// Shared asymmetric translucent frosted-glass overlay sheet matching the
/// *Natural History Museum* reference:
/// - Large sweeping rounded curve on **top-left ONLY** (`Radius.circular(68)`).
/// - Continuous **straight horizontal edge** to the right border (`topRight: Radius.zero`).
/// - True translucent `BackdropFilter` blur over a full-screen background image.
class AsymmetricTranslucentSheet extends StatelessWidget {
  const AsymmetricTranslucentSheet({
    super.key,
    required this.child,
    this.topLeftRadius = 68.0,
  });

  final Widget child;
  final double topLeftRadius;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const shapeRadius = BorderRadius.only(
      topLeft: Radius.circular(68),
    );

    final effectiveRadius = topLeftRadius == 68.0
        ? shapeRadius
        : BorderRadius.only(topLeft: Radius.circular(topLeftRadius));

    // Genuine translucent smoked-stone frost so the full-screen photo shines through.
    final glassTint = isDark
        ? const Color(0xFF171615).withValues(alpha: 0.54)
        : const Color(0xFF332E2A).withValues(alpha: 0.44);

    return ClipRRect(
      borderRadius: effectiveRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: CustomPaint(
          foregroundPainter: _TopAsymmetricBorderPainter(
            topLeftRadius: topLeftRadius,
            color: Colors.white.withValues(alpha: isDark ? 0.16 : 0.26),
          ),
          child: ColoredBox(
            color: glassTint,
            child: child,
          ),
        ),
      ),
    );
  }
}

class _TopAsymmetricBorderPainter extends CustomPainter {
  const _TopAsymmetricBorderPainter({
    required this.topLeftRadius,
    required this.color,
  });

  final double topLeftRadius;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final r = topLeftRadius.clamp(0.0, size.width * 0.5);
    final path = Path()
      ..moveTo(0, r)
      ..arcToPoint(
        Offset(r, 0),
        radius: Radius.circular(r),
        clockwise: true,
      )
      ..lineTo(size.width, 0);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.15
      ..isAntiAlias = true;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TopAsymmetricBorderPainter oldDelegate) =>
      oldDelegate.topLeftRadius != topLeftRadius || oldDelegate.color != color;
}

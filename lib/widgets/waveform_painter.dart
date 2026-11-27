import 'dart:math' as math;
import 'package:flutter/material.dart';

class RibbonWavePainter extends CustomPainter {
  final double phase;
  final double amplitude;
  final Color color;

  const RibbonWavePainter({
    required this.phase,
    required this.amplitude,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6;

    for (int layer = 0; layer < 3; layer++) {
      final path = Path();
      final layerColor = color.withValues(alpha: (0.9 - layer * 0.28).clamp(0.1, 1.0));
      paint.color = layerColor;
      final midY = size.height / 2;

      for (double x = 0; x <= size.width; x += 4) {
        final norm = x / size.width;
        final envelope = math.sin(norm * math.pi);
        final y = midY +
            math.sin(norm * 6 + phase + layer * 1.1) *
                (size.height * 0.36) *
                amplitude *
                envelope;
        if (x == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant RibbonWavePainter old) =>
      old.phase != phase || old.amplitude != amplitude || old.color != color;
}

class WaveformPainter extends CustomPainter {
  final List<double> waveHistory;
  final Color primaryColor;
  final Color accentColor;

  WaveformPainter({
    required this.waveHistory,
    required this.primaryColor,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.round;

    final double centerY = size.height / 2;
    final double width = size.width;
    final int maxBars = waveHistory.length;

    if (maxBars == 0) return;

    final double barSpacing = 4.0;
    final double barWidth = (width - (barSpacing * (maxBars - 1))) / maxBars;

    // Draw gradients for wave bars
    final Rect rect = Rect.fromLTWH(0, 0, size.width, size.height);
    paint.shader = LinearGradient(
      colors: [primaryColor, accentColor],
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
    ).createShader(rect);

    for (int i = 0; i < maxBars; i++) {
      // Scale amplitude to minimum 5px and maximum height of container
      final double amplitude = waveHistory[i];
      final double barHeight = (amplitude * (size.height * 0.8)) + 6.0;

      final double xPos = i * (barWidth + barSpacing);
      final double yPos = centerY - (barHeight / 2);

      final RRect roundedRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(xPos, yPos, barWidth, barHeight),
        const Radius.circular(4),
      );

      canvas.drawRRect(roundedRect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant WaveformPainter oldDelegate) {
    return oldDelegate.waveHistory != waveHistory;
  }
}

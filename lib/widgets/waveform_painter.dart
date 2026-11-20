import 'package:flutter/material.dart';

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

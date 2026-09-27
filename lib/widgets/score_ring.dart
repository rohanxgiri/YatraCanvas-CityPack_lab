import 'dart:math';
import 'package:flutter/material.dart';

class ScoreRing extends StatelessWidget {
  final double score; // 0 to 100
  final double size;
  final double strokeWidth;
  final Color color;
  final String? label;

  const ScoreRing({
    super.key,
    required this.score,
    this.size = 80,
    this.strokeWidth = 8,
    required this.color,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _RingPainter(
              progress: (score / 100.0).clamp(0.0, 1.0),
              color: color,
              strokeWidth: strokeWidth,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${score.round()}',
                style: TextStyle(
                  fontSize: size * 0.32,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              if (label != null)
                Text(
                  label!,
                  style: TextStyle(
                    fontSize: size * 0.12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  _RingPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final bgPaint = Paint()
      ..color = color.withAlpha(35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, bgPaint);

    final sweepAngle = 2 * pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      sweepAngle,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class SeasonChartPainter extends CustomPainter {
  final List<int?> gamesBySeason;

  static const double _maxYAxis = 250;
  static const double _leftPadding = 24;
  static const double _rightPadding = 24;
  static const double _bottomPadding = 32;

  SeasonChartPainter(this.gamesBySeason);

  @override
  void paint(Canvas canvas, Size size) {
    final chartWidth = size.width - _leftPadding - _rightPadding;
    final chartHeight = size.height - _bottomPadding;
    final widthStep = chartWidth / (gamesBySeason.length - 1);

    final gridPaint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1;

    final axisPaint = Paint()
      ..color = Colors.grey
      ..strokeWidth = 2;

    final linePaint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()..color = Colors.red;

    const ySteps = [0, 50, 100, 150, 200, 250];

    // Horizontal grid lines
    for (final value in ySteps) {
      final y = chartHeight - chartHeight * (value / _maxYAxis);
      canvas.drawLine(
        Offset(_leftPadding, y),
        Offset(size.width - _rightPadding, y),
        gridPaint,
      );
    }

    // Axes
    canvas.drawLine(
        Offset(_leftPadding, 0), Offset(_leftPadding, chartHeight), axisPaint);
    canvas.drawLine(Offset(_leftPadding, chartHeight),
        Offset(size.width - _rightPadding, chartHeight), axisPaint);

    // Compute point positions (null where player didn't play)
    final points = List<Offset?>.generate(gamesBySeason.length, (i) {
      final g = gamesBySeason[i];
      if (g == null) return null;
      final x = _leftPadding + i * widthStep;
      final clamped = g.clamp(0, _maxYAxis.toInt()).toDouble();
      final y = chartHeight - chartHeight * (clamped / _maxYAxis);
      return Offset(x, y);
    });

    // Line segments between consecutive non-null points
    for (int i = 0; i < points.length - 1; i++) {
      final start = points[i];
      final end = points[i + 1];
      if (start != null && end != null) {
        canvas.drawLine(start, end, linePaint);
      }
    }

    // Dots
    for (final pt in points) {
      if (pt != null) {
        canvas.drawCircle(pt, 4, dotPaint);
      }
    }

    // Text labels
    final textPainter = TextPainter(textDirection: ui.TextDirection.ltr);

    // X axis: season IDs where player played
    for (int i = 0; i < gamesBySeason.length; i++) {
      if (gamesBySeason[i] != null) {
        final x = _leftPadding + i * widthStep;
        textPainter.text = TextSpan(
          text: '$i',
          style: const TextStyle(color: Colors.grey, fontSize: 9),
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(x - textPainter.width / 2, chartHeight + 6),
        );
      }
    }

    // Y axis labels
    for (final value in ySteps) {
      final y = chartHeight - chartHeight * (value / _maxYAxis);
      textPainter.text = TextSpan(
        text: '$value',
        style: const TextStyle(color: Colors.grey, fontSize: 9),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(_leftPadding - textPainter.width - 4, y - textPainter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(SeasonChartPainter old) => false;
}

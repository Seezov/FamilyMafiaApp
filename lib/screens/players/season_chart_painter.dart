import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class SeasonChartPainter extends CustomPainter {
  final List<int?> gamesBySeason;
  final int? selectedIndex;

  static const double leftPadding = 24;
  static const double rightPadding = 24;
  static const double bottomPadding = 32;
  static const double maxYAxis = 250;

  SeasonChartPainter(this.gamesBySeason, {this.selectedIndex});

  @override
  void paint(Canvas canvas, Size size) {
    final chartWidth = size.width - leftPadding - rightPadding;
    final chartHeight = size.height - bottomPadding;
    final widthStep = chartWidth / (gamesBySeason.length - 1);

    final gridPaint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1;

    final axisPaint = Paint()
      ..color = Colors.grey
      ..strokeWidth = 2;

    final linePaint = Paint()
      ..color = const Color(0xFFE53935)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()..color = const Color(0xFFE53935);

    const ySteps = [0, 50, 100, 150, 200, 250];

    // Horizontal grid lines
    for (final value in ySteps) {
      final y = chartHeight - chartHeight * (value / maxYAxis);
      canvas.drawLine(
        Offset(leftPadding, y),
        Offset(size.width - rightPadding, y),
        gridPaint,
      );
    }

    // Axes
    canvas.drawLine(
        Offset(leftPadding, 0), Offset(leftPadding, chartHeight), axisPaint);
    canvas.drawLine(Offset(leftPadding, chartHeight),
        Offset(size.width - rightPadding, chartHeight), axisPaint);

    // Compute point positions
    final points = List<Offset?>.generate(gamesBySeason.length, (i) {
      final g = gamesBySeason[i];
      if (g == null) return null;
      final x = leftPadding + i * widthStep;
      final clamped = g.clamp(0, maxYAxis.toInt()).toDouble();
      final y = chartHeight - chartHeight * (clamped / maxYAxis);
      return Offset(x, y);
    });

    // Line segments
    for (int i = 0; i < points.length - 1; i++) {
      final start = points[i];
      final end = points[i + 1];
      if (start != null && end != null) {
        canvas.drawLine(start, end, linePaint);
      }
    }

    // Selected vertical highlight line
    if (selectedIndex != null && points[selectedIndex!] != null) {
      final selX = points[selectedIndex!]!.dx;
      canvas.drawLine(
        Offset(selX, 0),
        Offset(selX, chartHeight),
        Paint()
          ..color = const Color(0xFFE53935).withValues(alpha: 0.25)
          ..strokeWidth = 1.5,
      );
    }

    // Dots
    for (int i = 0; i < points.length; i++) {
      final pt = points[i];
      if (pt == null) continue;
      final isSelected = i == selectedIndex;
      canvas.drawCircle(
        pt,
        isSelected ? 6 : 4,
        dotPaint
          ..color = isSelected
              ? const Color(0xFFB71C1C)
              : const Color(0xFFFFCDD2),
      );
    }

    // Text labels
    final textPainter = TextPainter(textDirection: ui.TextDirection.ltr);

    // X axis: season IDs where player played
    for (int i = 0; i < gamesBySeason.length; i++) {
      if (gamesBySeason[i] != null) {
        final x = leftPadding + i * widthStep;
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
      final y = chartHeight - chartHeight * (value / maxYAxis);
      textPainter.text = TextSpan(
        text: '$value',
        style: const TextStyle(color: Colors.grey, fontSize: 9),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(leftPadding - textPainter.width - 4, y - textPainter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(SeasonChartPainter old) =>
      old.selectedIndex != selectedIndex || old.gamesBySeason != gamesBySeason;
}

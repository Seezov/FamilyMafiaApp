import 'dart:ui' as ui;

import 'package:family_mafia_app/providers/app_providers.dart';
import 'package:family_mafia_app/screens/hall_of_fame/hall_of_fame_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HallOfFameScreen extends ConsumerWidget {
  const HallOfFameScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataState = ref.watch(appDataProvider);

    return dataState.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        body: Center(child: Text('Error loading data: $e')),
      ),
      data: (_) => const _HallOfFameContent(),
    );
  }
}

class _HallOfFameContent extends ConsumerWidget {
  const _HallOfFameContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(seasonGamesProvider);

    return Scaffold(
      body: SafeArea(
        child: entries.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
                itemCount: entries.length,
                itemBuilder: (context, i) =>
                    _SeasonGamesItem(entry: entries[i]),
              ),
      ),
    );
  }
}

class _SeasonGamesItem extends StatelessWidget {
  final SeasonGamesEntry entry;

  const _SeasonGamesItem({required this.entry});

  @override
  Widget build(BuildContext context) {
    // Build a list of nullable game counts indexed 0..28
    final gamesBySeason = List<int?>.generate(29, (i) {
      final match = entry.seasonData.where((e) => e.seasonId == i);
      return match.isEmpty ? null : match.first.games;
    });

    final total = entry.seasonData.fold(0, (s, e) => s + e.games);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${entry.name}  ($total games)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 220,
            child: CustomPaint(
              painter: _SeasonChartPainter(gamesBySeason),
            ),
          ),
          const SizedBox(height: 8),
          const Divider(),
        ],
      ),
    );
  }
}

class _SeasonChartPainter extends CustomPainter {
  final List<int?> gamesBySeason;

  static const double _maxYAxis = 200;
  static const double _leftPadding = 48;
  static const double _bottomPadding = 32;

  _SeasonChartPainter(this.gamesBySeason);

  @override
  void paint(Canvas canvas, Size size) {
    final chartWidth = size.width - _leftPadding;
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

    const ySteps = [0, 50, 100, 150, 200];

    // Horizontal grid lines
    for (final value in ySteps) {
      final y = chartHeight - chartHeight * (value / _maxYAxis);
      canvas.drawLine(
        Offset(_leftPadding, y),
        Offset(size.width, y),
        gridPaint,
      );
    }

    // Axes
    canvas.drawLine(
        Offset(_leftPadding, 0), Offset(_leftPadding, chartHeight), axisPaint);
    canvas.drawLine(Offset(_leftPadding, chartHeight),
        Offset(size.width, chartHeight), axisPaint);

    // Compute point positions (null where player didn't play)
    final points = List<Offset?>.generate(gamesBySeason.length, (i) {
      final g = gamesBySeason[i];
      if (g == null) return null;
      final x = _leftPadding + i * widthStep;
      final clamped = g.clamp(0, _maxYAxis.toInt());
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
  bool shouldRepaint(_SeasonChartPainter old) => false;
}

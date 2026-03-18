part of '../player_profile_screen.dart';

// ---------------------------------------------------------------------------
// Interactive season chart
// ---------------------------------------------------------------------------

class _SeasonChart extends StatefulWidget {
  final List<int?> gamesBySeason;

  const _SeasonChart({required this.gamesBySeason});

  @override
  State<_SeasonChart> createState() => _SeasonChartState();
}

class _SeasonChartState extends State<_SeasonChart> {
  int? _selectedIndex;

  static const _chartHeight = 220.0;

  int? _findNearest(Offset local, double width) {
    final chartWidth =
        width - SeasonChartPainter.leftPadding - SeasonChartPainter.rightPadding;
    final widthStep = chartWidth / (widget.gamesBySeason.length - 1);

    int? closest;
    double minDist = double.infinity;
    for (int i = 0; i < widget.gamesBySeason.length; i++) {
      if (widget.gamesBySeason[i] == null) continue;
      final px = SeasonChartPainter.leftPadding + i * widthStep;
      final dist = (local.dx - px).abs();
      if (dist < minDist) {
        minDist = dist;
        closest = i;
      }
    }
    return (closest != null && minDist < widthStep) ? closest : null;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return TapRegion(
          onTapOutside: (_) => setState(() => _selectedIndex = null),
          child: GestureDetector(
          onTapUp: (d) {
            final idx = _findNearest(d.localPosition, width);
            setState(() => _selectedIndex = idx == _selectedIndex ? null : idx);
          },
          onPanUpdate: (d) {
            final idx = _findNearest(d.localPosition, width);
            setState(() => _selectedIndex = idx);
          },
          child: Stack(
            children: [
              SizedBox(
                width: double.infinity,
                height: _chartHeight,
                child: CustomPaint(
                  painter: SeasonChartPainter(
                    widget.gamesBySeason,
                    selectedIndex: _selectedIndex,
                  ),
                ),
              ),
              if (_selectedIndex != null) _buildTooltip(_selectedIndex!, width),
            ],
          ),
        ),
        );
      },
    );
  }

  Widget _buildTooltip(int index, double width) {
    final chartWidth =
        width - SeasonChartPainter.leftPadding - SeasonChartPainter.rightPadding;
    final chartHeight = _chartHeight - SeasonChartPainter.bottomPadding;
    final widthStep = chartWidth / (widget.gamesBySeason.length - 1);

    final games = widget.gamesBySeason[index]!;
    final x = SeasonChartPainter.leftPadding + index * widthStep;
    final clamped = games.clamp(0, SeasonChartPainter.maxYAxis.toInt()).toDouble();
    final y = chartHeight - chartHeight * (clamped / SeasonChartPainter.maxYAxis);

    const tooltipW = 90.0;
    const tooltipH = 32.0;
    const gap = 10.0;

    double left = x - tooltipW / 2;
    if (left < 0) left = 0;
    if (left + tooltipW > width) left = width - tooltipW;
    final top = (y - tooltipH - gap).clamp(0.0, _chartHeight - tooltipH);

    return Positioned(
      left: left,
      top: top,
      child: Container(
        width: tooltipW,
        height: tooltipH,
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(
          'S$index · $games games',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

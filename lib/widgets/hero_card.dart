import 'package:flutter/material.dart';

class HeroCard extends StatelessWidget {
  const HeroCard({
    super.key,
    required this.label,
    required this.title,
    required this.gradientStart,
    required this.gradientEnd,
    required this.statTiles,
  });

  final String label;
  final String title;
  final Color gradientStart;
  final Color gradientEnd;
  final List<HeroStatTile> statTiles;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [gradientStart, gradientEnd],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gradientStart.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 9,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: statTiles
                  .expand((tile) => [
                        Expanded(child: tile),
                        if (tile != statTiles.last) const SizedBox(width: 8),
                      ])
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class HeroStatTile extends StatelessWidget {
  const HeroStatTile({super.key, required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 8,
            ),
          ),
        ],
      ),
    );
  }
}

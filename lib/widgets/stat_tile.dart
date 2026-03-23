import 'package:flutter/material.dart';

enum StatTileVariant { neutral, positive, negative }

class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.value,
    required this.label,
    this.variant = StatTileVariant.neutral,
  });

  final String value;
  final String label;
  final StatTileVariant variant;

  @override
  Widget build(BuildContext context) {
    final (bg, valueColor) = switch (variant) {
      StatTileVariant.neutral => (
          Colors.grey.shade50,
          const Color(0xDD000000),
        ),
      StatTileVariant.positive => (
          const Color(0xFF4CAF50).withValues(alpha: 0.09),
          const Color(0xFF2E7D32),
        ),
      StatTileVariant.negative => (
          const Color(0xFFE53935).withValues(alpha: 0.09),
          const Color(0xFFC62828),
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: valueColor,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.black.withValues(alpha: 0.54),
            ),
          ),
        ],
      ),
    );
  }
}

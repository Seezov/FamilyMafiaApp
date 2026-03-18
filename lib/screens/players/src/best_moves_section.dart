part of '../player_profile_screen.dart';

// ---------------------------------------------------------------------------
// Best Moves
// ---------------------------------------------------------------------------

class _BestMovesSection extends StatelessWidget {
  final BestMoves bm;

  const _BestMovesSection({required this.bm});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final total =
        bm.zeroBlacks + bm.oneBlack + bm.twoBlacks + bm.threeBlacks;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Best Moves', style: tt.titleMedium),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () => showDialog<void>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Best Moves'),
                  content: const Text(
                    'Best moves are only tracked starting from Season 2. '
                    'First kills in Season 0 and Season 1 are not included in this count.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              ),
              child: Icon(
                Icons.info_outline,
                size: 16,
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          '$total best moves total',
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _BlackCard(blacks: 0, count: bm.zeroBlacks, total: total)),
          const SizedBox(width: 8),
          Expanded(child: _BlackCard(blacks: 1, count: bm.oneBlack, total: total)),
          const SizedBox(width: 8),
          Expanded(child: _BlackCard(blacks: 2, count: bm.twoBlacks, total: total)),
          const SizedBox(width: 8),
          Expanded(child: _BlackCard(blacks: 3, count: bm.threeBlacks, total: total)),
        ]),
      ],
    );
  }
}

class _BlackCard extends StatelessWidget {
  final int blacks;
  final int count;
  final int total;

  const _BlackCard(
      {required this.blacks, required this.count, required this.total});

  static const _colors = [
    Color(0xFFBDBDBD), // 0 blacks — light gray
    Color(0xFF757575), // 1 black  — medium gray
    Color(0xFF424242), // 2 blacks — dark gray
    Color(0xFF212121), // 3 blacks — near black
  ];

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final color = _colors[blacks];
    final pct = total > 0 ? (count / total * 100).round() : 0;
    final label = blacks == 1 ? '1 black' : '$blacks blacks';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.6), width: 1.5),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              3,
              (i) => Padding(
                padding: const EdgeInsets.only(right: 2),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < blacks
                        ? color
                        : color.withValues(alpha: 0.2),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text('$count',
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          Text('$pct%',
              style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: 2),
          Text(label,
              style: tt.labelSmall?.copyWith(
                color: Colors.black,
                fontWeight: FontWeight.w600,
              )),
        ],
      ),
    );
  }
}

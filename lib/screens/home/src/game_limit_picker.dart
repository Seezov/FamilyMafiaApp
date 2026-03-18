part of '../home_screen.dart';

class _GameLimitPicker extends ConsumerWidget {
  final int currentLimit;
  final int defaultLimit;

  const _GameLimitPicker({required this.currentLimit, required this.defaultLimit});

  static const _steps = [5, 10, 20, 30, 40, 50, 60];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Card(
        elevation: 0,
        color: cs.tertiaryContainer.withValues(alpha: 0.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'No players with $defaultLimit+ games yet',
                style: tt.bodySmall?.copyWith(color: cs.onTertiaryContainer),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: _steps.map((limit) {
                    final isSelected = limit == currentLimit;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text('$limit+'),
                        selected: isSelected,
                        labelStyle: tt.labelSmall,
                        visualDensity: VisualDensity.compact,
                        onSelected: (_) => ref
                            .read(gameLimitOverrideProvider.notifier)
                            .state = limit,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

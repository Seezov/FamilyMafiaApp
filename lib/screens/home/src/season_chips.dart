part of '../home_screen.dart';

class _SeasonChips extends ConsumerWidget {
  final SeasonConfig? selectedSeason;

  const _SeasonChips({required this.selectedSeason});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configs = ref.watch(loadedSeasonConfigsProvider);

    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: configs.reversed.map((config) {
          final isSelected = config == selectedSeason;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: Text(
                config.title,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? Colors.white
                      : const Color(0xFF00897B),
                ),
              ),
              selected: isSelected,
              selectedColor: const Color(0xFF00897B),
              backgroundColor: const Color(0xFFE0F2F1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              side: BorderSide.none,
              onSelected: (_) {
                ref.read(gameLimitOverrideProvider.notifier).state = null;
                ref.read(selectedSeasonProvider.notifier).state = config;
              },
            ),
          );
        }).toList(),
      ),
    );
  }
}

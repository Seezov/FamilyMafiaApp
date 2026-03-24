part of '../home_screen.dart';

class _GameLimitPicker extends ConsumerWidget {
  final int currentLimit;
  final int defaultLimit;

  const _GameLimitPicker({required this.currentLimit, required this.defaultLimit});

  static const _steps = [5, 10, 20, 30, 40, 50, 60];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _steps.map((limit) {
          final isSelected = limit == currentLimit;
          return Padding(
            padding: const EdgeInsets.only(left: 4),
            child: GestureDetector(
              onTap: () => ref.read(gameLimitOverrideProvider.notifier).state = limit,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF00897B)
                      : const Color(0xFFE0F2F1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$limit+',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : const Color(0xFF00897B),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

part of '../home_screen.dart';

class _LeagueToggle extends ConsumerWidget {
  const _LeagueToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final league = ref.watch(selectedLeagueProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: SegmentedButton<League>(
        segments: const [
          ButtonSegment(value: League.main, label: Text('Основна')),
          ButtonSegment(value: League.small, label: Text('Мала')),
        ],
        selected: {league},
        showSelectedIcon: false,
        onSelectionChanged: (selection) {
          ref.read(selectedLeagueProvider.notifier).state = selection.first;
        },
      ),
    );
  }
}

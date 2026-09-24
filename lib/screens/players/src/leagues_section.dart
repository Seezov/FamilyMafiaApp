part of '../player_profile_screen.dart';

class _LeaguesSection extends ConsumerWidget {
  final Player player;

  const _LeaguesSection({required this.player});

  static const _colors = {
    SeasonLeague.main: Color(0xFF00897B),
    SeasonLeague.small: Color(0xFF80CBC4),
    SeasonLeague.below: Color(0xFFECEFF1),
    SeasonLeague.none: Colors.transparent,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leagues = ref.watch(playerLeaguesProvider(player));
    final main = leagues.values.where((l) => l == SeasonLeague.main).length;
    final small = leagues.values.where((l) => l == SeasonLeague.small).length;
    final configs = ref.watch(loadedSeasonConfigsProvider);

    Widget big(String value, String label, Color bg) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF004D40))),
              Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
            ]),
          ),
        );

    return SectionCard(
      title: 'Leagues',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          big('$main', 'seasons in main league', const Color(0xFFE0F2F1)),
          const SizedBox(width: 8),
          big('$small', 'seasons in small league', const Color(0xFFF1F8F7)),
        ]),
        const SizedBox(height: 12),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            for (final MapEntry(key: season, value: league) in leagues.entries)
              GestureDetector(
                onTap: league == SeasonLeague.none
                    ? null
                    : () {
                        final config = configs.where((c) => c.id == season).firstOrNull;
                        if (config == null) return;
                        ref.read(selectedSeasonProvider.notifier).state = config;
                        ref.read(selectedTabProvider.notifier).state = 0;
                        Navigator.of(context).popUntil((r) => r.isFirst);
                      },
                child: Container(
                  width: 18,
                  height: 18,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _colors[league],
                    borderRadius: BorderRadius.circular(4),
                    border: league == SeasonLeague.none
                        ? Border.all(color: const Color(0xFFCFD8DC))
                        : null,
                  ),
                  child: Text('$season',
                      style: TextStyle(
                        fontSize: 7,
                        color: league == SeasonLeague.main ? Colors.white : const Color(0xFF90A4AE),
                      )),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        const Wrap(spacing: 12, children: [
          _Legend(color: Color(0xFF00897B), label: 'Main'),
          _Legend(color: Color(0xFF80CBC4), label: 'Small'),
          _Legend(color: Color(0xFFECEFF1), label: 'Played, below threshold'),
          _Legend(color: Colors.transparent, label: "Didn't play", outlined: true),
        ]),
      ]),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  final bool outlined;

  const _Legend({required this.color, required this.label, this.outlined = false});

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 9, height: 9,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
            border: outlined ? Border.all(color: const Color(0xFFCFD8DC)) : null,
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.black54)),
      ]);
}

import 'package:family_mafia_app/models/player.dart';
import 'package:family_mafia_app/models/season_config.dart';
import 'package:family_mafia_app/providers/app_providers.dart';
import 'package:family_mafia_app/screens/home/home_providers.dart';
import 'package:family_mafia_app/screens/players/players_providers.dart';
import 'package:family_mafia_app/site_export/site_table.dart';
import 'package:family_mafia_app/site_export/slugs.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What every export module needs: the loaded container, the players the
/// site has pages for, and their slugs.
class ExportContext {
  ExportContext(this.container)
      : players = _onePerName(container),
        slugs = assignSlugs(_onePerName(container));

  /// players.json has a few display names twice. Stats are keyed by name, so
  /// both entries would show the same numbers on two pages; keep only the
  /// player the app's resolver maps that name to.
  static List<Player> _onePerName(ProviderContainer c) {
    final resolver = c.read(playerResolverProvider);
    return [
      for (final p in c.read(playersListProvider))
        if (resolver.resolve(p.displayName).id == p.id) p
    ];
  }

  final ProviderContainer container;

  /// The players the app lists (junk names excluded), most games first.
  final List<Player> players;
  final Map<int, String> slugs;

  T read<T>(ProviderListenable<T> provider) => container.read(provider);

  /// A player's name, linked when the site has a page for them.
  SiteCell name(Player p) => SiteCell(p.displayName, link: slugs[p.id]);

  /// Sets the providers the Season tab reads, as the user would.
  void select(SeasonConfig season, League league) {
    container.read(selectedSeasonProvider.notifier).state = season;
    container.read(gameLimitOverrideProvider.notifier).state = null;
    container.read(selectedLeagueProvider.notifier).state = league;
  }

  List<SeasonConfig> get seasons =>
      [...read(loadedSeasonConfigsProvider)]..sort((a, b) => a.id.compareTo(b.id));
}

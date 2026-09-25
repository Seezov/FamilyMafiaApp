import 'package:family_mafia_app/models/player.dart';
import 'package:family_mafia_app/models/tournament.dart';

class PlayerAccomplishments {
  final Player player;
  int firsts;
  int seconds;
  int thirds;
  int smallFirsts;
  int smallSeconds;
  int smallThirds;
  int mvp;
  int bestSheriff;
  int bestDon;
  int bestCivilian;
  int bestMafia;

  /// Prize places per tournament type: `[1st, 2nd, 3rd]` counts.
  final Map<TournamentType, List<int>> tournamentPlaces;

  PlayerAccomplishments(
    this.player, {
    this.firsts = 0,
    this.seconds = 0,
    this.thirds = 0,
    this.smallFirsts = 0,
    this.smallSeconds = 0,
    this.smallThirds = 0,
    this.mvp = 0,
    this.bestSheriff = 0,
    this.bestDon = 0,
    this.bestCivilian = 0,
    this.bestMafia = 0,
    Map<TournamentType, List<int>>? tournamentPlaces,
  }) : tournamentPlaces = tournamentPlaces ?? {};

  int tournamentPodiums(TournamentType type) =>
      (tournamentPlaces[type] ?? const [0, 0, 0]).fold(0, (s, n) => s + n);

  int sumOfNominations() =>
      firsts + seconds + thirds +
      smallFirsts + smallSeconds + smallThirds +
      mvp + bestSheriff + bestDon + bestCivilian + bestMafia +
      TournamentType.values.fold(0, (s, t) => s + tournamentPodiums(t));
}

import 'package:family_mafia_app/models/player.dart';

class PlayerAccomplishments {
  final Player player;
  int firsts;
  int seconds;
  int thirds;
  int mvp;
  int bestSheriff;
  int bestDon;
  int bestCivilian;
  int bestMafia;

  PlayerAccomplishments(
    this.player, {
    this.firsts = 0,
    this.seconds = 0,
    this.thirds = 0,
    this.mvp = 0,
    this.bestSheriff = 0,
    this.bestDon = 0,
    this.bestCivilian = 0,
    this.bestMafia = 0,
  });

  int sumOfNominations() =>
      firsts + seconds + thirds + mvp + bestSheriff + bestDon + bestCivilian + bestMafia;
}

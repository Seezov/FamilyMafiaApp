import 'dart:convert';
import 'dart:math';

import 'package:family_mafia_app/constants/season_constants.dart';
import 'package:family_mafia_app/enums/game_values.dart';
import 'package:family_mafia_app/enums/role.dart';
import 'package:family_mafia_app/extensions/list_extensions.dart';
import 'package:family_mafia_app/models/game.dart';
import 'package:family_mafia_app/models/games_data_season.dart';
import 'package:family_mafia_app/models/protocol_entry.dart';
import 'package:family_mafia_app/models/player.dart';
import 'package:family_mafia_app/models/rating_player_stats.dart';
import 'package:family_mafia_app/models/season_stats.dart';
import 'package:family_mafia_app/repositories/games_repository.dart';
import 'package:family_mafia_app/repositories/players_repository.dart';
import 'package:family_mafia_app/repositories/rating_repository.dart';
import 'package:family_mafia_app/repositories/role_percentiles_repository.dart';
import 'package:family_mafia_app/repositories/season_repository.dart';
import 'package:family_mafia_app/services/rating_formulas.dart';
import 'package:flutter/foundation.dart';

part 'src/isolate_io.dart';
part 'src/isolate_functions.dart';
part 'src/data_filtering.dart';
part 'src/game_parsing.dart';
part 'src/player_rating.dart';
part 'src/season_stats.dart';
part 'src/percentiles.dart';

// ── Service ─────────────────────────────────────────────────────────────────

class SeasonLoaderService {
  final PlayersRepository _playersRepo;
  final GamesRepository _gamesRepo;
  final RatingRepository _ratingRepo;
  final SeasonRepository _seasonRepo;
  final RolePercentilesRepository _rolePercRepo;

  SeasonLoaderService(
    this._playersRepo,
    this._gamesRepo,
    this._ratingRepo,
    this._seasonRepo,
    this._rolePercRepo,
  );

  /// [configs] describes every season to load. [playersJson] is the raw
  /// players.json content. [seasonJsons] is parallel to [configs] — the raw
  /// JSON string for each season (already loaded from bundled assets or remote).
  Future<void> loadAll({
    required List<SeasonMeta> metas,
    required String playersJson,
    required List<String> seasonJsons,
  }) async {
    // All CPU work in a background isolate
    final out = await compute(
      _computeAllData,
      _LoadInput(playersJson, seasonJsons, metas),
    );

    // Populate repositories on the main thread
    _playersRepo.addPlayers(out.players);
    _gamesRepo.addGames(out.allGames);
    for (final entry in out.ratingsBySeason.entries) {
      _ratingRepo.addRatings(entry.key, entry.value);
    }
    for (final entry in out.statsBySeason.entries) {
      _seasonRepo.addSeason(entry.key, entry.value);
    }
    _rolePercRepo.setPercentiles(out.percentiles);
  }

  /// Incremental load: computes ratings for the given seasons without percentiles.
  /// Can be called multiple times to add more seasons to the repositories.
  Future<List<Game>> loadSeasons({
    required List<SeasonMeta> metas,
    required String playersJson,
    required List<String> seasonJsons,
  }) async {
    final out = await compute(
      _computePartialData,
      _LoadInput(playersJson, seasonJsons, metas),
    );

    _playersRepo.addPlayers(out.players);
    _gamesRepo.addGames(out.allGames);
    for (final entry in out.ratingsBySeason.entries) {
      _ratingRepo.addRatings(entry.key, entry.value);
    }
    for (final entry in out.statsBySeason.entries) {
      _seasonRepo.addSeason(entry.key, entry.value);
    }
    return out.allGames;
  }

  /// Recomputes role percentiles from raw season data.
  /// Call after all seasons are loaded.
  Future<void> recomputePercentiles({
    required String playersJson,
    required List<String> allSeasonJsons,
    required List<SeasonMeta> allMetas,
  }) async {
    final percentiles = await compute(
      _computePercentilesOnly,
      _PercentilesInput(playersJson, allSeasonJsons, allMetas),
    );
    _rolePercRepo.setPercentiles(percentiles);
  }
}

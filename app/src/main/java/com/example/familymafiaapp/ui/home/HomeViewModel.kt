package com.example.familymafiaapp.ui.home

import androidx.lifecycle.ViewModel
import com.example.familymafiaapp.entities.Player
import com.example.familymafiaapp.enums.Role
import com.example.familymafiaapp.entities.seasons.GamesDataSeason
import com.example.familymafiaapp.entities.RatingUniversal
import com.example.familymafiaapp.entities.Game
import com.example.familymafiaapp.enums.Season
import com.example.familymafiaapp.enums.Values
import com.example.familymafiaapp.extensions.roundTo2Digits
import com.example.familymafiaapp.repository.PlayersRepository
import com.example.familymafiaapp.repository.RatingRepository
import com.google.gson.reflect.TypeToken
import com.google.gson.Gson
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import javax.inject.Inject
import kotlin.collections.filter
import kotlin.math.roundToInt
import kotlin.text.toFloat

@HiltViewModel
class HomeViewModel @Inject constructor(
    private val ratingRepository: RatingRepository,
    private val playersRepository: PlayersRepository,
) : ViewModel() {

    private val _ratings = MutableStateFlow<List<RatingUniversal>>(emptyList())
    val ratings: StateFlow<List<RatingUniversal>> = _ratings

    private val _selectedSeason = MutableStateFlow<Season?>(null)
    val selectedSeason: StateFlow<Season?> = _selectedSeason

    private val _debugText = MutableStateFlow<String>("")
    val debugText: StateFlow<String> = _debugText

    fun displaySeason(season: Season) {
        _ratings.value =
            ratingRepository.getRatingsForSeason(season)
                .filter { it.gamesPlayed >= season.gameLimit }
                .sortedByDescending { it.ratingCoefficient }
    }

    fun loadPlayers(json: String) {
        val players = parseJsonList<Player>(json)
        playersRepository.addPlayers(players)
    }

    fun loadDataBySeason(season: Season, fileContent: String) {
        if (fileContent.isNotEmpty()) {
            when (season) {
                Season.SEASON_0,
                Season.SEASON_1
                    -> loadSeason0and1(season, fileContent)

                Season.SEASON_2,
                Season.SEASON_3,
                Season.SEASON_4,
                Season.SEASON_5,
                Season.SEASON_6,
                Season.SEASON_7,
                Season.SEASON_8,
                Season.SEASON_9,
                Season.SEASON_10,
                Season.SEASON_11,
                Season.SEASON_12,
                Season.SEASON_13,
                Season.SEASON_14,
                Season.SEASON_15,
                Season.SEASON_16,
                    -> loadSeason2to16(season, fileContent)

                Season.SEASON_17,
                Season.SEASON_18,
                Season.SEASON_19,
                Season.SEASON_20,
                Season.SEASON_21,
                Season.SEASON_22,
                Season.SEASON_23,
                Season.SEASON_24,
                Season.SEASON_25,
                    -> loadSeason17Plus(season, fileContent)
            }
        } else {
//            loadDataFromServer()
        }
    }

    private fun loadSeason17Plus(season: Season, fileContent: String) {
        val rawData = parseJsonList<GamesDataSeason>(fileContent)
            .filter { filterRawData(it, season.id) }
        val gamesData = getGamesDataSeason(season.id, rawData).filter { it.isRatingGame() }
        gamesData.forEachIndexed { index, game ->
            if (!game.isNormalGame()) {
                throw Exception("is not normal game #$index ${game.players}")
            }
        }
        val playersList = gamesData.getPlayersList(season)
        val ratings = playersList.map { player ->
            val gamesForPlayer = gamesData.filter { it.players.contains(player) }
            val gamesPlayed = gamesForPlayer.size
            if (gamesPlayed == 0) {
                return@map RatingUniversal(player)
            }
            val firstKilled = gamesForPlayer.filter { it.isFirstKilled(player) }.size
            val firstKilledCityLost =
                gamesForPlayer.filter { it.isFirstKilled(player) && !it.hasPlayerWon(player) }.size
            val fullGamesForRole = Role.entries.map { role ->
                Pair(role.sheetValue.last(), gamesForPlayer.getGamesForRole(player, role))
            }
            val additionalPointsByRole = fullGamesForRole.map {
                Pair(it.first, it.second.map {
                    if (it.isFirstKilled(player)) {
                        it.getPlayerAdditionalPoints(player) + it.bestMovePoints
                    } else {
                        it.getPlayerAdditionalPoints(player)
                    }
                }.sum())
            }
            val gamesAsRed = fullGamesForRole
                .filter { it.first == Role.SHERIFF.sheetValue.last() || it.first == Role.CIVILIAN.sheetValue.last() }
                .sumOf { it.second.size }
            val winByRole = fullGamesForRole.map { gameForRole ->
                Pair(
                    gameForRole.first,
                    gameForRole.second.filter {
                        it.hasPlayerWon(player)
                    }.size
                )
            }
            val additionalPointsByRoleSum = gamesForPlayer
                .map {
                    it.getPlayerAdditionalPoints(player)
                }.sum()
            val bestMovePointsByRoleSum = gamesForPlayer
                .map {
                    if (it.isFirstKilled(player))
                        it.bestMovePoints
                    else 0.0f
                }.sum()
            val penaltyPointsByRoleSum =
                gamesForPlayer.map { it.getPlayerPenaltyPoints(player) }.sum()
            val autoAdditionalPointsByRoleSum =
                gamesForPlayer.map { it.getPlayerAutoAdditionalPoints(player) }.sum()
            val ciForGame =
                calculateCiForGame(firstKilledCityLost, firstKilled, gamesPlayed, season)
            val ci = ciForGame * firstKilledCityLost
            val winPoints =
                additionalPointsByRoleSum + autoAdditionalPointsByRoleSum + penaltyPointsByRoleSum + bestMovePointsByRoleSum + ci
            val mvp =
                ((additionalPointsByRoleSum + bestMovePointsByRoleSum).toFloat() / gamesPlayed).roundTo2Digits()
            val wins = winByRole.sumOf { it.second }
            val winRate = wins.toFloat() / gamesPlayed
            val ratingCoefficient = calculateRatingCoefficient(
                winPoints = winPoints,
                gamesPlayed = gamesPlayed,
                winRate = winRate,
                ci = ci,
                bestMovePointsByRoleSum = bestMovePointsByRoleSum,
                additionalPointsByRoleSum = additionalPointsByRoleSum,
                penaltyPointsByRoleSum = penaltyPointsByRoleSum,
                autoAdditionalPointBySum = autoAdditionalPointsByRoleSum,
                season = season,
            )
            val gamesForRole = fullGamesForRole.map { it.first to it.second.size }
            RatingUniversal(
                player = player,
                ratingCoefficient = ratingCoefficient.toFloat(),
                wins = wins,
                gamesPlayed = gamesPlayed,
                winRate = winRate,
                additionalPoints = additionalPointsByRoleSum,
                penaltyPoints = penaltyPointsByRoleSum,
                bestMovePoints = bestMovePointsByRoleSum,
                firstKilled = firstKilled,
                firstKilledCityLost = firstKilledCityLost,
                percentOfDeath = firstKilled.toFloat() / gamesAsRed,
                mvp = mvp,
                ci = ci,
                ciForGame = ciForGame,
                winByRole = winByRole,
                gamesByRole = gamesForRole,
                additionalPointsByRole = additionalPointsByRole
            )
        }
        ratingRepository.addRatings(season, ratings)
    }

    private fun loadSeason2to16(season: Season, fileContent: String) {
        val rawData = parseJsonList<GamesDataSeason>(fileContent)
            .filter { filterRawData(it, season.id) }
        val gamesData = getGamesDataSeason(season.id, rawData).filter { it.isRatingGame() }
        gamesData.forEachIndexed { index, game ->
            if (!game.isNormalGame()) {
                throw Exception("is not normal game #$index ${game.players}")
            }
        }
        val playersList = gamesData.getPlayersList(season)
        val ratings = playersList.map { player ->
            val gamesForPlayer = gamesData.filter { it.players.contains(player) }
            val gamesPlayed = gamesForPlayer.size
            if (gamesPlayed == 0) {
                return@map RatingUniversal(player)
            }
            val firstKilled = gamesForPlayer.filter { it.isFirstKilled(player) }.size
            val firstKilledCityLost =
                gamesForPlayer.filter { it.isFirstKilled(player) && !it.hasPlayerWon(player) }.size
            val fullGamesForRole = Role.entries.map { role ->
                Pair(role.sheetValue.last(), gamesForPlayer.getGamesForRole(player, role))
            }
            val additionalPointsByRole = fullGamesForRole.map {
                Pair(it.first, it.second.map {
                    if (it.isFirstKilled(player)) {
                        it.getPlayerAdditionalPoints(player) + it.bestMovePoints
                    } else {
                        it.getPlayerAdditionalPoints(player)
                    }
                }.sum())
            }
            val gamesAsRed = fullGamesForRole
                .filter { it.first == Role.SHERIFF.sheetValue.last() || it.first == Role.CIVILIAN.sheetValue.last() }
                .sumOf { it.second.size }
            val winByRole = fullGamesForRole.map { gameForRole ->
                Pair(
                    gameForRole.first,
                    gameForRole.second.filter {
                        it.hasPlayerWon(player)
                    }.size
                )
            }
            val penaltyPointsByRole = fullGamesForRole.map {
                it.first to it.second.sumOf { it.getPlayerPenaltyPoints(player).toInt() }
            }
            val winByRoleSum = winByRole.sumOf {
                calculateWinByRole(season, it.first, it.second)
            }
            val additionalPointsByRoleSum = gamesForPlayer
                .map {
                    it.getPlayerAdditionalPoints(player)
                }.sum()
            val bestMovePointsByRoleSum = gamesForPlayer
                .map {
                    if (it.isFirstKilled(player))
                        it.bestMovePoints
                    else 0.0f
                }.sum()
            val penaltyPointsByRoleSum = penaltyPointsByRole.sumOf {
                it.second
            }.toFloat()
            val winPoints =
                winByRoleSum + additionalPointsByRoleSum + bestMovePointsByRoleSum - if (season == Season.SEASON_2 || season == Season.SEASON_3) {
                    penaltyPointsByRoleSum
                } else 0F
            val mvp =
                ((additionalPointsByRoleSum + bestMovePointsByRoleSum).toFloat() / gamesPlayed).roundTo2Digits()
            val wins = winByRole.sumOf { it.second }
            val winRate = wins.toFloat() / gamesPlayed
            val ratingCoefficient =
                calculateRatingCoefficient(
                    winPoints = winPoints,
                    gamesPlayed = gamesPlayed,
                    winRate = winRate,
                    season = season
                )
            val gamesForRole = fullGamesForRole.map { it.first to it.second.size }
            RatingUniversal(
                player = player,
                ratingCoefficient = ratingCoefficient,
                wins = wins,
                gamesPlayed = gamesPlayed,
                winRate = winRate,
                additionalPoints = additionalPointsByRoleSum,
                penaltyPoints = penaltyPointsByRoleSum,
                bestMovePoints = bestMovePointsByRoleSum,
                firstKilled = firstKilled,
                firstKilledCityLost = firstKilledCityLost,
                percentOfDeath = firstKilled.toFloat() / gamesAsRed,
                mvp = mvp,
                winByRole = winByRole,
                gamesByRole = gamesForRole,
                additionalPointsByRole = additionalPointsByRole,
            )
        }
        ratingRepository.addRatings(season, ratings)
    }

    private fun loadSeason0and1(season: Season, fileContent: String) {
        val rawData = parseJsonList<GamesDataSeason>(fileContent)
            .filter { filterRawData(it, season.id) }
        val gamesData = getGamesDataSeason(season.id, rawData)
        val playersList = gamesData.getPlayersList(season)
        val ratings = playersList.map { player ->
            val gamesForPlayer = gamesData.filter { it.players.contains(player) }
            val gamesPlayed = gamesForPlayer.size
            val firstKilled = gamesForPlayer.filter { it.isFirstKilled(player) }.size
            val firstKilledCityLost =
                gamesForPlayer.filter { it.isFirstKilled(player) && !it.hasPlayerWon(player) }.size
            val fullGamesForRole = Role.entries.map { role ->
                Pair(role.sheetValue.last(), gamesForPlayer.getGamesForRole(player, role))
            }
            val gamesAsRed = fullGamesForRole
                .filter { it.first == Role.SHERIFF.sheetValue.last() || it.first == Role.CIVILIAN.sheetValue.last() }
                .sumOf { it.second.size }
            val winByRole = fullGamesForRole.map { gameForRole ->
                Pair(
                    gameForRole.first,
                    gameForRole.second.filter {
                        if (it.isRegularGame()) {
                            it.hasPlayerWon(player)
                        } else {
                            Values.YES.sheetValue.contains(it.wonByPlayer?.get(it.players.indexOf(player)))
                        }
                    }.size
                )
            }
            val loseByRole = fullGamesForRole.map { gameForRole ->
                Pair(
                    gameForRole.first,
                    gameForRole.second.filter {
                        if (it.isRegularGame()) {
                            !it.hasPlayerWon(player)
                        } else {
                            Values.NO.sheetValue.contains(it.wonByPlayer?.get(it.players.indexOf(player)))
                        }
                    }.size
                )
            }
            val penaltyPointsByRole = fullGamesForRole.map {
                it.first to it.second
                    .map { it.getPlayerPenaltyPoints(player) }.sum()
            }
            val winByRoleSum = winByRole.sumOf {
                calculateWinByRole(season, it.first, it.second)
            }
            val loseByRoleSum = loseByRole.sumOf {
                if (playerIsDonOrSheriff(it.first)) {
                    it.second
                } else {
                    0
                }
            }
            val additionalPointsByRoleSum = gamesForPlayer
                .map {
                    if (it.isFirstKilled(player))
                        it.bestMovePoints
                    else 0.0f
                }.sum()
            val penaltyPointsByRoleSum = penaltyPointsByRole
                .map {
                    it.second
                }.sum()
            val winPoints =
                (winByRoleSum - loseByRoleSum - penaltyPointsByRoleSum + additionalPointsByRoleSum)
            val wins = winByRole.sumOf { it.second }
            val mvp = (winPoints / gamesPlayed).roundTo2Digits()
            val winRate = wins.toFloat() / gamesPlayed
            val ratingCoefficient =
                calculateRatingCoefficient(
                    winPoints = winPoints,
                    gamesPlayed = gamesPlayed,
                    winRate = winRate,
                    season = season
                )

            val gamesForRole = fullGamesForRole.map { it.first to it.second.size }
            RatingUniversal(
                player = player,
                ratingCoefficient = ratingCoefficient,
                wins = wins,
                gamesPlayed = gamesPlayed,
                winRate = winRate,
                additionalPoints = additionalPointsByRoleSum,
                penaltyPoints = penaltyPointsByRoleSum,
                firstKilled = firstKilled,
                firstKilledCityLost = firstKilledCityLost,
                percentOfDeath = firstKilled.toFloat() / gamesAsRed,
                mvp = mvp,
                winByRole = winByRole,
                gamesByRole = gamesForRole,
                additionalPointsByRole = emptyList(),
            )
        }
        ratingRepository.addRatings(season, ratings)
    }

    private fun filterRawData(
        dataSeason: GamesDataSeason,
        seasonId: Int
    ) = when (seasonId) {
        in 0..16 -> dataSeason.a.toIntOrNull() != null
        else -> dataSeason.a != "" && dataSeason.c != ""
    }

    private fun calculateCiForGame(
        firstKilledCityLost: Int,
        firstKilled: Int,
        gamesPlayed: Int,
        season: Season
    ): Float {
        return when (season) {
            Season.SEASON_17, Season.SEASON_18 -> 0.1
            Season.SEASON_19, Season.SEASON_20 -> {
                val firstKilledToGamesPlayed = firstKilled.toFloat() / gamesPlayed
                if (firstKilledToGamesPlayed > 0.399) {
                    0.4 * firstKilledCityLost
                } else {
                    firstKilledToGamesPlayed * 5 / 2 * 0.4
                }
            }

            Season.SEASON_21, Season.SEASON_22, Season.SEASON_23, Season.SEASON_24, Season.SEASON_25 -> {
                val firstKilledToGamesPlayed = firstKilled.toFloat() / gamesPlayed
                if (firstKilledToGamesPlayed > 0.399) {
                    0.5
                } else {
                    firstKilledToGamesPlayed * 1.25
                }
            }

            else -> 0F
        }.toFloat()
    }

    private fun calculateRatingCoefficient(
        winPoints: Float,
        gamesPlayed: Int,
        winRate: Float,
        ci: Float = 0F,
        bestMovePointsByRoleSum: Float = 0F,
        additionalPointsByRoleSum: Float = 0F,
        penaltyPointsByRoleSum: Float = 0F,
        autoAdditionalPointBySum: Float = 0F,
        season: Season
    ) = when (season) {
        Season.SEASON_0,
        Season.SEASON_1 -> {
            (winPoints / gamesPlayed).roundTo2Digits() * 100 + gamesPlayed * season.gamesMultiplier
        }

        Season.SEASON_2,
        Season.SEASON_3 -> {
            winPoints / gamesPlayed + gamesPlayed * season.gamesMultiplier
        }

        Season.SEASON_4 -> {
            (winPoints / gamesPlayed + gamesPlayed * season.gamesMultiplier) * 100
        }

        Season.SEASON_5,
        Season.SEASON_6,
        Season.SEASON_7,
        Season.SEASON_8,
        Season.SEASON_9,
        Season.SEASON_10,
        Season.SEASON_11,
        Season.SEASON_12,
        Season.SEASON_13,
        Season.SEASON_14,
        Season.SEASON_15,
        Season.SEASON_16 -> {
            (winPoints / gamesPlayed + gamesPlayed * (winRate * 100).roundTo2Digits() / 100 * season.gamesMultiplier) * 100
        }

        Season.SEASON_17 -> {
            winRate * 100 + (winPoints / gamesPlayed) + ci + bestMovePointsByRoleSum + autoAdditionalPointBySum + additionalPointsByRoleSum
        }

        Season.SEASON_18, Season.SEASON_19, Season.SEASON_20 -> {
            val gamesWithoutAutoPoints = gamesPlayed - (autoAdditionalPointBySum / 0.3).roundToInt()
            winRate * 100 + (winPoints / gamesPlayed) + ci + bestMovePointsByRoleSum + additionalPointsByRoleSum - gamesWithoutAutoPoints * 0.3F
        }

        Season.SEASON_21, Season.SEASON_22, Season.SEASON_23, Season.SEASON_24, Season.SEASON_25 -> {
            winRate * 100 + (winPoints / gamesPlayed) + ci + bestMovePointsByRoleSum + additionalPointsByRoleSum + penaltyPointsByRoleSum
        }
    }.roundTo2Digits()

    private fun calculateWinByRole(
        season: Season,
        role: String,
        wins: Int
    ) = when (season) {
        Season.SEASON_0,
        Season.SEASON_1 -> {
            if (playerIsDonOrSheriff(role)) {
                wins * 4
            } else {
                wins * 3
            }
        }

        Season.SEASON_2,
        Season.SEASON_3 -> {
            wins * 2
        }

        Season.SEASON_4,
        Season.SEASON_5,
        Season.SEASON_6,
        Season.SEASON_7,
        Season.SEASON_8,
        Season.SEASON_9,
        Season.SEASON_10,
        Season.SEASON_11,
        Season.SEASON_12,
        Season.SEASON_13,
        Season.SEASON_14,
        Season.SEASON_15,
        Season.SEASON_16 -> {
            wins
        }

        else -> 0
    }

    private fun playerIsDonOrSheriff(role: String) =
        Role.findByValue(role)?.sheetValue == Role.DON.sheetValue || Role.findByValue(
            role
        )?.sheetValue == Role.SHERIFF.sheetValue

    private fun getGamesDataSeason(seasonId: Int, rawData: List<GamesDataSeason>) =
        rawData.chunked(
            when(seasonId) {
                in 0..16 -> 10
                else -> 14
            }
        ).map { playersInfo ->
                when (seasonId) {
                    in 0..1 -> {
                        val firstPlayer = playersInfo.first()
                        Game(
                            seasonId = seasonId,
                            players = playersInfo.map { it.b },
                            roles = playersInfo.map { it.c },
                            cityWon = if (Role.findByValue(firstPlayer.c)!!.isBlack) {
                                !Values.YES.sheetValue.contains(firstPlayer.d)
                            } else {
                                Values.YES.sheetValue.contains(firstPlayer.d)
                            },
                            firstKilled = playersInfo.find { Values.YES.sheetValue.contains(firstPlayer.f) }?.a?.toInt()
                                ?: 0,
                            bestMovePoints = playersInfo.find { it.g.isNotEmpty() }?.g?.toFloat()
                                ?: 0.0F,
                            wonByPlayer = playersInfo.map { it.d },
                            penaltyPoints = playersInfo.map { if (Values.YES.sheetValue.contains(firstPlayer.e)) 1F else 0f },
                            // TODO: IMPLEMENT PARSING
                            bestMove = emptyList()
                        )
                    }
                    in 2..16 -> {
                        Game(
                            seasonId = seasonId,
                            players = playersInfo.map { it.g },
                            roles = playersInfo.map { it.h },
                            cityWon = getVictoryTeam(playersInfo[0].c),
                            firstKilled = playersInfo[1].c.toIntOrNull() ?: 0,
                            bestMovePoints = playersInfo[1].c.toIntOrNull()?.let { firstKilled ->
                                if (firstKilled == 0) {
                                    0f
                                } else {
                                    try {
                                        playersInfo.map { it.j }[firstKilled - 1].toFloat()
                                    } catch (e: Exception) {
                                        0f
                                    }
                                }
                            } ?: 0F,
                            penaltyPoints = playersInfo.map {
                                if (it.f.toIntOrNull() == 4)
                                    1F
                                else
                                    0F
                            },
                            bestMove = listOf(
                                playersInfo[3].c.toIntOrNull() ?: 0,
                                playersInfo[3].d.toIntOrNull() ?: 0,
                                playersInfo[3].e.toIntOrNull() ?: 0,
                            ),
                            additionalPoints = playersInfo.map { it.i.toFloatOrNull() ?: 0F }
                        )
                    }
                    else -> {
                        Game(
                            seasonId = seasonId,
                            players = playersInfo.subList(2, 12).map { it.b },
                            roles = playersInfo.subList(2, 12).map { it.c },
                            cityWon = getVictoryTeam(playersInfo.last().c),
                            firstKilled = playersInfo[12].b.toIntOrNull() ?: 0,
                            bestMovePoints = playersInfo[12].b.toIntOrNull()?.let { firstKilled ->
                                if (firstKilled == 0) {
                                    0f
                                } else {
                                    try {
                                        playersInfo.map { it.i }[firstKilled + 1].toFloat()
                                    } catch (e: Exception) {
                                        0f
                                    }
                                }
                            } ?: 0F,
                            bestMove = listOf(
                                playersInfo[12].d.toIntOrNull() ?: 0,
                                playersInfo[12].e.toIntOrNull() ?: 0,
                                playersInfo[12].f.toIntOrNull() ?: 0,
                            ),
                            additionalPoints = playersInfo.subList(2, 12)
                                .map { it.j.toFloatOrNull() ?: 0F },
                            autoAdditionalPoints = if (seasonId in 17..20) {
                                playersInfo.subList(2, 12)
                                    .map { it.h.toFloatOrNull() ?: 0F }
                            } else {
                                null
                            },
                            penaltyPoints = if (seasonId !in 17..20) {
                                playersInfo.subList(2, 12)
                                    .map { it.h.toFloatOrNull() ?: 0F }
                            } else {
                                null
                            }
                        )
                    }
                }

            }

    private fun getVictoryTeam(string: String): Boolean? = when {
        Values.MAFIA_WON.sheetValue.contains(string) -> false
        Values.CITY_WON.sheetValue.contains(string) -> true
        else -> null
    }

    inline fun <reified T> parseJsonList(json: String): List<T> {
        return try {
            val type = object : TypeToken<List<T>>() {}.type
            Gson().fromJson(json, type)
        } catch (e: Exception) {
            emptyList()
        }
    }

//    private fun loadDataFromServer() {
//        viewModelScope.launch {
//            service.fetchData()
//        }
//    }

    companion object {
        const val TAG: String = "HomeViewModel"
    }
}

fun List<Game>.getGamesForRole(
    player: String,
    role: Role
) = filter {
    role.sheetValue.contains(it.getPlayerRole(player))
}

fun List<Game>.getPlayersList(
    season: Season
) = flatMap {
    it.players
}.toSet().filter {
    when (season) {
        // Рауль had excluded himself from the 0th season
        Season.SEASON_0 -> it != "Рауль"
        // Рауль and Остин had excluded themself from the 8th season
        Season.SEASON_8 -> it != "Рауль" && it != "Остин"
        // Рауль had excluded himself from the 9th season
        Season.SEASON_9 -> it != "Рауль"
        else -> true
    }
}
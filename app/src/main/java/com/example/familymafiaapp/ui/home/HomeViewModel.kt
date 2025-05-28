package com.example.familymafiaapp.ui.home

import androidx.lifecycle.ViewModel
import com.example.familymafiaapp.enums.Role
import com.example.familymafiaapp.entities.seasons.season0And1.GameSeason0And1
import com.example.familymafiaapp.entities.seasons.season0And1.PlayerDataSeason0And1
import com.example.familymafiaapp.entities.seasons.season2to16.PlayerDataSeason2to16
import com.example.familymafiaapp.entities.RatingUniversal
import com.example.familymafiaapp.entities.seasons.GameSeason
import com.example.familymafiaapp.entities.seasons.season17to20.GameSeason17to20
import com.example.familymafiaapp.entities.seasons.season17to20.PlayerDataSeason17to20
import com.example.familymafiaapp.entities.seasons.season21Plus.GameSeason21Plus
import com.example.familymafiaapp.entities.seasons.season21Plus.PlayerDataSeason21Plus
import com.example.familymafiaapp.entities.seasons.season2to16.GameSeason2to16
import com.example.familymafiaapp.enums.Season
import com.example.familymafiaapp.enums.Values
import com.example.familymafiaapp.extensions.roundTo2Digits
import com.google.gson.reflect.TypeToken
import com.google.gson.Gson
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlin.math.roundToInt

class HomeViewModel : ViewModel() {

    private val _ratings = MutableStateFlow<List<RatingUniversal>>(emptyList())
    val ratings: StateFlow<List<RatingUniversal>> = _ratings

    private val _selectedSeason = MutableStateFlow<Season?>(null)
    val selectedSeason: StateFlow<Season?> = _selectedSeason

    private val _debugText = MutableStateFlow<String>("")
    val debugText: StateFlow<String> = _debugText

//    private val service = GoogleSheetService.create()

    fun loadDataBySeason(season: Season, fileContent: String) {
        _selectedSeason.value = season
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
                Season.SEASON_20
                    -> loadSeason17to20(season, fileContent)
                Season.SEASON_21,
                Season.SEASON_22
                    -> loadSeason21Plus(season, fileContent)
            }
        } else {
//            loadDataFromServer()
        }
    }

    private fun loadSeason21Plus(season: Season, fileContent: String) {
        val rawData = parseJsonList<PlayerDataSeason21Plus>(fileContent)
            .filter { it.a != "" && it.c != "" }
        val gamesData = getGamesDataSeason21Plus(rawData).filter { it.isRatingGame() }
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
            val penaltyPointsByRoleSum = gamesForPlayer.map { it.getPlayerPenaltyPoints(player) }.sum()
            val ciForGame = calculateCiForGame(firstKilledCityLost, firstKilled, gamesPlayed, season)
            val ci = ciForGame*firstKilledCityLost
            val winPoints = additionalPointsByRoleSum + penaltyPointsByRoleSum + bestMovePointsByRoleSum + ci
            val mvp =
                ((additionalPointsByRoleSum + bestMovePointsByRoleSum).toFloat() / gamesPlayed).roundTo2Digits()
            val wins = winByRole.sumOf { it.second }
            val winRate = wins.toFloat() / gamesPlayed
            val ratingCoefficient = calculateRatingCoefficient(winPoints, gamesPlayed, winRate, ci, bestMovePointsByRoleSum, additionalPointsByRoleSum, penaltyPointsByRoleSum, season)
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
                additionalPointsByRole = additionalPointsByRole,
            )
    }
        _ratings.value = ratings.filter { it.gamesPlayed >= season.gameLimit }
            .sortedByDescending { it.ratingCoefficient }
    }

    private fun loadSeason17to20(season: Season, fileContent: String) {
        val rawData = parseJsonList<PlayerDataSeason17to20>(fileContent)
            .filter { it.a != "" && it.c != "" }
        val gamesData = getGamesDataSeason17to20(rawData).filter { it.isRatingGame() }
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
            val autoAdditionalPointsByRoleSum = gamesForPlayer.map { it.getPlayerAutoAdditionalPoints(player) }.sum()
            val ci = calculateCi(firstKilledCityLost, firstKilled, gamesPlayed, season)
            val ciForGame = calculateCiForGame(firstKilledCityLost, firstKilled, gamesPlayed, season)
            val winPoints = additionalPointsByRoleSum + autoAdditionalPointsByRoleSum + bestMovePointsByRoleSum + ci
            val mvp =
                ((additionalPointsByRoleSum + bestMovePointsByRoleSum).toFloat() / gamesPlayed).roundTo2Digits()
            val wins = winByRole.sumOf { it.second }
            val winRate = wins.toFloat() / gamesPlayed
            val ratingCoefficient = calculateRatingCoefficient(winPoints, gamesPlayed, winRate, ci, bestMovePointsByRoleSum, additionalPointsByRoleSum, autoAdditionalPointsByRoleSum, season, )
            val gamesForRole = fullGamesForRole.map { it.first to it.second.size }
            RatingUniversal(
                player = player,
                ratingCoefficient = ratingCoefficient.toFloat(),
                wins = wins,
                gamesPlayed = gamesPlayed,
                winRate = winRate,
                additionalPoints = additionalPointsByRoleSum,
                penaltyPoints = 0F,
                bestMovePoints = bestMovePointsByRoleSum,
                firstKilled = firstKilled,
                firstKilledCityLost = firstKilledCityLost,
                percentOfDeath = firstKilled.toFloat() / gamesAsRed,
                mvp = mvp,
                ci = ci,
                ciForGame = ciForGame,
                winByRole = winByRole,
                gamesByRole = gamesForRole,
                additionalPointsByRole = additionalPointsByRole,
            )
    }
        _ratings.value = ratings.filter { it.gamesPlayed >= season.gameLimit }
            .sortedByDescending { it.ratingCoefficient }
    }

    private fun calculateCi(
        firstKilledCityLost: Int,
        firstKilled: Int,
        gamesPlayed: Int,
        season: Season
    ): Float {
        return when (season) {
            Season.SEASON_17, Season.SEASON_18 -> firstKilledCityLost * 0.1.toFloat()
            Season.SEASON_19, Season.SEASON_20 -> {
                val firstKilledToGamesPlayed = firstKilled.toFloat()/gamesPlayed
                if (firstKilledToGamesPlayed > 0.399) {
                    0.4 * firstKilledCityLost
                } else {
                    firstKilledToGamesPlayed * firstKilledCityLost
                }
            }
            else -> 0F
        }.toFloat()
    }

    private fun calculateCiForGame(
        firstKilledCityLost: Int,
        firstKilled: Int,
        gamesPlayed: Int,
        season: Season
    ): Float {
        return when (season) {
            Season.SEASON_17, Season.SEASON_18 -> firstKilledCityLost * 0.1.toFloat()/gamesPlayed
            Season.SEASON_19, Season.SEASON_20 -> {
                val firstKilledToGamesPlayed = firstKilled.toFloat()/gamesPlayed
                if (firstKilledToGamesPlayed > 0.399) {
                    0.4 * firstKilledCityLost
                } else {
                    firstKilledToGamesPlayed * 5/2*0.4
                }
            }
            Season.SEASON_21, Season.SEASON_22 -> {
                val firstKilledToGamesPlayed = firstKilled.toFloat()/gamesPlayed
                if (firstKilledToGamesPlayed > 0.399) {
                    0.5
                } else {
                    firstKilledToGamesPlayed * 1.25
                }
            }
            else -> 0F
        }.toFloat()
    }

    private fun loadSeason2to16(season: Season, fileContent: String) {
        val rawData = parseJsonList<PlayerDataSeason2to16>(fileContent)
            .filter { it.number.toIntOrNull() != null }
        val gamesData = getGamesDataSeason2to16(rawData).filter { it.isRatingGame() }
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
                gamesForPlayer.filter { it.isFirstKilled(player) && !it.hasPlayerWon(player)  }.size
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
                it.first to it.second.map { if (it.getPlayerFouls(player) == 4) 1 else 0 }.sum()
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
        _ratings.value = ratings.filter { it.gamesPlayed >= season.gameLimit }
            .sortedByDescending { it.ratingCoefficient }
    }

    private fun loadSeason0and1(season: Season, fileContent: String) {
        val rawData = parseJsonList<PlayerDataSeason0And1>(fileContent)
            .filter { it.number.toIntOrNull() != null }
        val gamesData = getGamesDataSeason0And1(rawData)
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
                        if (it.isNormalGame()) {
                            it.hasPlayerWon(player)
                        } else {
                            Values.YES.sheetValue.contains(it.wonByPlayer[it.players.indexOf(player)])
                        }
                    }.size
                )
            }
            val loseByRole = fullGamesForRole.map { gameForRole ->
                Pair(
                    gameForRole.first,
                    gameForRole.second.filter {
                        if (it.isNormalGame()) {
                            !it.hasPlayerWon(player)
                        } else {
                            Values.NO.sheetValue.contains(it.wonByPlayer[it.players.indexOf(player)])
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
        _ratings.value = ratings.filter { it.gamesPlayed >= season.gameLimit }
            .sortedByDescending { it.ratingCoefficient }
    }


    private fun calculateRatingCoefficient(
        winPoints: Float,
        gamesPlayed: Int,
        winRate: Float,
        ci: Float = 0F,
        bestMovePointsByRoleSum: Float = 0F,
        additionalPointsByRoleSum: Float = 0F,
        extraPointsByRoleSum: Float = 0F,
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
            winRate * 100 + (winPoints/gamesPlayed) + ci + bestMovePointsByRoleSum + extraPointsByRoleSum + additionalPointsByRoleSum
        }
        Season.SEASON_18, Season.SEASON_19, Season.SEASON_20 -> {
            val gamesWithoutAutoPoints = gamesPlayed - (extraPointsByRoleSum / 0.3).roundToInt()
            winRate * 100 + (winPoints / gamesPlayed) + ci + bestMovePointsByRoleSum + additionalPointsByRoleSum - gamesWithoutAutoPoints * 0.3F
         }
        Season.SEASON_21, Season.SEASON_22 -> {
            winRate * 100 + (winPoints/gamesPlayed) + ci + bestMovePointsByRoleSum + extraPointsByRoleSum + additionalPointsByRoleSum
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

    private fun getGamesDataSeason0And1(rawData: List<PlayerDataSeason0And1>) = rawData.chunked(10)
        .map { playersInfo ->
            val firstPlayer = playersInfo.first()
            GameSeason0And1(
                playersInfo.map { it.player },
                playersInfo.map { it.role },
                if (Role.findByValue(firstPlayer.role)!!.isBlack) {
                     !Values.YES.sheetValue.contains(firstPlayer.won)
                } else {
                    Values.YES.sheetValue.contains(firstPlayer.won)
                },
                playersInfo.find { Values.YES.sheetValue.contains(firstPlayer.firstKilled) }?.number?.toInt() ?: 0,
                playersInfo.find { it.bestMovePoints.isNotEmpty() }?.bestMovePoints?.toFloat()
                    ?: 0.0F,
                playersInfo.map { it.won },
                playersInfo.map { if (Values.YES.sheetValue.contains(firstPlayer.eliminated)) 1F else 0f }
            )
        }

    private fun getGamesDataSeason2to16(rawData: List<PlayerDataSeason2to16>) = rawData.chunked(10)
        .map { playersInfo ->
            GameSeason2to16(
                players = playersInfo.map { it.player },
                roles = playersInfo.map { it.role },
                cityWon = getVictoryTeam(playersInfo[0].c),
                firstKilled = playersInfo[1].c.toIntOrNull() ?: 0,
                bestMovePoints = playersInfo[1].c.toIntOrNull()?.let { firstKilled ->
                    if (firstKilled == 0) {
                        0f
                    } else {
                        try {
                            playersInfo.map { it.bestMovePoints }[firstKilled - 1].toFloat()
                        } catch (e: Exception) {
                            0f
                        }
                    }
                } ?: 0F,
                fouls = playersInfo.map { it.fouls },
                bestMove = listOf(
                    playersInfo[3].c.toIntOrNull() ?: 0,
                    playersInfo[3].d.toIntOrNull() ?: 0,
                    playersInfo[3].e.toIntOrNull() ?: 0,
                ),
                additionalPoints = playersInfo.map { it.additionalPoints.toFloatOrNull() ?: 0F }
            )
        }

    private fun getGamesDataSeason17to20(rawData: List<PlayerDataSeason17to20>) =
        rawData.chunked(14)
            .map { playersInfo ->
                GameSeason17to20(
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
                    autoAdditionalPoints = playersInfo.subList(2, 12)
                        .map { it.h.toFloatOrNull() ?: 0F }
                )
            }

    private fun getGamesDataSeason21Plus(rawData: List<PlayerDataSeason21Plus>) =
        rawData.chunked(14)
            .map { playersInfo ->
                GameSeason21Plus(
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
                    penaltyPoints = playersInfo.subList(2, 12)
                        .map { it.h.toFloatOrNull() ?: 0F }
                )
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

fun <T : GameSeason> List<T>.getGamesForRole(
    player: String,
    role: Role
) = filter {
    role.sheetValue.contains(it.getPlayerRole(player))
}

fun <T : GameSeason> List<T>.getPlayersList(
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



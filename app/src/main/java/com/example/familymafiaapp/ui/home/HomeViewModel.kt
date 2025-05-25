package com.example.familymafiaapp.ui.home

import android.util.Log
import androidx.lifecycle.ViewModel
import com.example.familymafiaapp.enums.Role
import com.example.familymafiaapp.entities.seasons.season0And1.GameSeason0And1
import com.example.familymafiaapp.entities.seasons.season0And1.PlayerDataSeason0And1
import com.example.familymafiaapp.entities.seasons.season2And3.PlayerDataSeason2And3
import com.example.familymafiaapp.entities.RatingUniversal
import com.example.familymafiaapp.entities.seasons.GameSeason
import com.example.familymafiaapp.entities.seasons.season2And3.GameSeason2And3
import com.example.familymafiaapp.enums.Season
import com.example.familymafiaapp.enums.Values
import com.example.familymafiaapp.extensions.roundTo2Digits
import com.google.gson.reflect.TypeToken
import com.google.gson.Gson
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

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
                Season.SEASON_0, Season.SEASON_1 -> loadSeason0and1(season, fileContent)
                Season.SEASON_2,
                Season.SEASON_3,
                Season.SEASON_4,
                Season.SEASON_5,
                Season.SEASON_6,
                Season.SEASON_7,
                Season.SEASON_8,
                Season.SEASON_9,
                    -> loadSeason2And3(season, fileContent)
            }
        } else {
//            loadDataFromServer()
        }
    }

    private fun loadSeason2And3(season: Season, fileContent: String) {
        val rawData = parseJsonList<PlayerDataSeason2And3>(fileContent)
            .filter { it.number.toIntOrNull() != null }
        val gamesData = getGamesDataSeason2(rawData).filter { it.isRatingGame() }
        gamesData.forEachIndexed { index, game ->
            if (!game.isNormalGame()) {
                throw Exception("is not normal game #$index ${game.players}")
            }
        }
        val playersList = getPlayersList(rawData, season)
        val ratings = playersList.map { player ->
            val gamesForPlayer = gamesData.filter { it.players.contains(player) }
            val gamesPlayed = gamesForPlayer.size
            if (gamesPlayed == 0) {
                return@map RatingUniversal(player)
            }
            val firstKilled = gamesForPlayer.filter { it.isFirstKilled(player) }.size
            val firstKilledCityLost =
                gamesForPlayer.filter { it.isFirstKilled(player) && it.cityWon != true }.size
            val fullGamesForRole = Role.entries.map { role ->
                Pair(role.sheetValue, gamesForPlayer.getGamesForRole(player, role))
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
                .filter { it.first == Role.SHERIFF.sheetValue || it.first == Role.CIVILIAN.sheetValue }
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
                winByRoleSum + additionalPointsByRoleSum + bestMovePointsByRoleSum - penaltyPointsByRoleSum
            val mvp =
                ((additionalPointsByRoleSum + bestMovePointsByRoleSum).toFloat() / gamesPlayed).roundTo2Digits()
            val wins = winByRole.sumOf { it.second }
            val winRate = wins.toFloat() / gamesPlayed
            val ratingCoefficient =
                calculateRatingCoefficient(winPoints, gamesPlayed, winRate, season)
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

    private fun calculateRatingCoefficient(
        winPoints: Float,
        gamesPlayed: Int,
        winRate: Float,
        season: Season
    ) = when (season) {
        Season.SEASON_0, Season.SEASON_1 -> {
            (winPoints / gamesPlayed).roundTo2Digits() * 100 + gamesPlayed * season.gamesMultiplier
        }

        Season.SEASON_2, Season.SEASON_3 -> {
            winPoints / gamesPlayed + gamesPlayed * season.gamesMultiplier
        }

        Season.SEASON_4 -> {
            (winPoints / gamesPlayed + gamesPlayed * season.gamesMultiplier) * 100
        }

        Season.SEASON_5, Season.SEASON_6, Season.SEASON_7, Season.SEASON_8, Season.SEASON_9 -> {
            (winPoints / gamesPlayed + gamesPlayed * (winRate * 100).roundTo2Digits() / 100 * season.gamesMultiplier) * 100
        }
    }.roundTo2Digits()

    private fun calculateWinByRole(
        season: Season,
        role: String,
        wins: Int
    ) = when (season) {
        Season.SEASON_0, Season.SEASON_1 -> {
            if (playerIsDonOrSheriff(role)) {
                wins * 4
            } else {
                wins * 3
            }
        }

        Season.SEASON_2, Season.SEASON_3 -> {
            wins * 2
        }

        Season.SEASON_4, Season.SEASON_5, Season.SEASON_6, Season.SEASON_7, Season.SEASON_8, Season.SEASON_9 -> {
            wins
        }
    }

    private fun loadSeason0and1(season: Season, fileContent: String) {
        val rawData = parseJsonList<PlayerDataSeason0And1>(fileContent)
            .filter { it.number.toIntOrNull() != null }
        val gamesData = getGamesDataSeason0And1(rawData)
        val playersList = getPlayersListSeason0(rawData, season)
        val ratings = playersList.map { player ->
            val gamesForPlayer = gamesData.filter { it.players.contains(player) }
            val gamesPlayed = gamesForPlayer.size
            val firstKilled = gamesForPlayer.filter { it.isFirstKilled(player) }.size
            val firstKilledCityLost =
                gamesForPlayer.filter { it.isFirstKilled(player) && it.cityWon != true }.size
            val fullGamesForRole = Role.entries.map { role ->
                Pair(role.sheetValue, gamesForPlayer.getGamesForRole(player, role))
            }
            val gamesAsRed = fullGamesForRole
                .filter { it.first == Role.SHERIFF.sheetValue || it.first == Role.CIVILIAN.sheetValue }
                .sumOf { it.second.size }
            val winByRole = fullGamesForRole.map { gameForRole ->
                Pair(
                    gameForRole.first,
                    gameForRole.second.filter {
                        if (it.isNormalGame()) {
                            it.hasPlayerWon(player)
                        } else {
                            it.wonByPlayer[it.players.indexOf(player)] == Values.YES.sheetValue
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
                            it.wonByPlayer[it.players.indexOf(player)] == Values.NO.sheetValue
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
                calculateRatingCoefficient(winPoints, gamesPlayed, winRate, season)

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

    private fun playerIsDonOrSheriff(role: String) =
        Role.findByValue(role)?.sheetValue == Role.DON.sheetValue || Role.findByValue(
            role
        )?.sheetValue == Role.SHERIFF.sheetValue

    private fun getPlayersListSeason0(rawData: List<PlayerDataSeason0And1>, season: Season) =
        rawData
            // Рауль had excluded himself from the 0th season
            .filter { if (season == Season.SEASON_8) it.player != "Рауль" else true }
            .groupBy { it.player }.keys

    private fun getPlayersList(rawData: List<PlayerDataSeason2And3>, season: Season) = rawData
        .filter {
            when (season) {
                // Рауль had excluded himself from the 0th season
                Season.SEASON_0 -> it.player != "Рауль"
                // Рауль and Остин had excluded themself from the 8th season
                Season.SEASON_8 -> it.player != "Рауль" && it.player != "Остин"
                Season.SEASON_9 -> it.player != "Рауль"
                else -> true
            }
        }
        .groupBy { it.player }.keys

    private fun getGamesDataSeason0And1(rawData: List<PlayerDataSeason0And1>) = rawData.chunked(10)
        .map { playersInfo ->
            val firstPlayer = playersInfo.first()
            GameSeason0And1(
                playersInfo.map { it.player },
                playersInfo.map { it.role },
                if (Role.findByValue(firstPlayer.role)!!.isBlack) {
                    firstPlayer.won != Values.YES.sheetValue
                } else {
                    firstPlayer.won == Values.YES.sheetValue
                },
                playersInfo.find { it.firstKilled == Values.YES.sheetValue }?.number?.toInt() ?: 0,
                playersInfo.find { it.bestMovePoints.isNotEmpty() }?.bestMovePoints?.toFloat()
                    ?: 0.0F,
                playersInfo.map { it.won },
                playersInfo.map { if (it.eliminated == Values.YES.sheetValue) 1F else 0f }
            )
        }

    private fun getGamesDataSeason2(rawData: List<PlayerDataSeason2And3>) = rawData.chunked(10)
        .map { playersInfo ->
            GameSeason2And3(
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
                            val a = 1
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

    private fun getVictoryTeam(string: String): Boolean? = when (string) {
        Values.MAFIA_WON.sheetValue -> false
        Values.CITY_WON.sheetValue -> true
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
    it.getPlayerRole(player) == role.sheetValue
}


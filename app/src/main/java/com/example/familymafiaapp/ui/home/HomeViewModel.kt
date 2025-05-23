package com.example.familymafiaapp.ui.home

import android.util.Log
import androidx.lifecycle.ViewModel
import com.example.familymafiaapp.R
import com.example.familymafiaapp.enums.Role
import com.example.familymafiaapp.entities.seasons.season0And1.GameSeason0And1
import com.example.familymafiaapp.entities.seasons.season0And1.PlayerDataSeason0And1
import com.example.familymafiaapp.entities.seasons.season2.PlayerDataSeason2
import com.example.familymafiaapp.entities.RatingUniversal
import com.example.familymafiaapp.entities.seasons.GameSeason
import com.example.familymafiaapp.entities.seasons.season2.GameSeason2
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

    private val _debugText = MutableStateFlow<String>("")
    val debugText: StateFlow<String> = _debugText

//    private val service = GoogleSheetService.create()

    fun loadDataBySeason(season: Season, fileContent: String) {
        if (fileContent.isNotEmpty()) {
            when (season) {
                Season.SEASON_0 -> loadSeason0and1(season, fileContent)
                Season.SEASON_1 -> loadSeason0and1(season, fileContent)
                Season.SEASON_2 -> loadSeason2(season, fileContent)
            }
        } else {
//            loadDataFromServer()
        }
    }

    private fun loadSeason2(season: Season, fileContent: String) {
        val rawData = parseJsonList<PlayerDataSeason2>(fileContent)
            .filter { it.number.toIntOrNull() != null }
        val gamesData = getGamesDataSeason2(rawData).filter { it.isRatingGame() }
        val playersList = getPlayersListSeason2(rawData)
        val ratings = playersList.map { player ->
            val gamesForPlayer = gamesData.filter { it.players.contains(player) }
            val gamesPlayed = gamesForPlayer.size
            if (gamesPlayed == 0) {
                return@map RatingUniversal(player)
            }
            val firstKilled = gamesForPlayer.filter { it.isFirstKilled(player) }.size
            val firstKilledCityLost = gamesForPlayer.filter { it.isFirstKilled(player) && it.cityWon != true }.size
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
                it.second * 2
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
            val winPoints = winByRoleSum + additionalPointsByRoleSum + bestMovePointsByRoleSum - penaltyPointsByRoleSum
            Log.d(TAG, player)
            val mvp = ((additionalPointsByRoleSum + bestMovePointsByRoleSum).toFloat() / gamesPlayed).roundTo2Digits()
            val ratingCoefficient = (winPoints/gamesPlayed + gamesPlayed * 0.02F).roundTo2Digits()

            val wins = winByRole.sumOf { it.second }

            val gamesForRole = fullGamesForRole.map { it.first to it.second.size }
            RatingUniversal(
                player = player,
                ratingCoefficient = ratingCoefficient,
                wins = wins,
                gamesPlayed = gamesPlayed,
                winRate = wins.toFloat()/gamesPlayed,
                additionalPoints = additionalPointsByRoleSum,
                penaltyPoints = penaltyPointsByRoleSum,
                bestMovePoints = bestMovePointsByRoleSum,
                firstKilled = firstKilled,
                firstKilledCityLost = firstKilledCityLost,
                percentOfDeath = firstKilled.toFloat()/gamesAsRed,
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
        val playersList = if (season.jsonFileRes == R.raw.season0) {
            getPlayersListSeason0(rawData)
        } else {
            getPlayersListSeason1(rawData)
        }
        val ratings = playersList.map { player ->
            val gamesForPlayer = gamesData.filter { it.players.contains(player) }
            val gamesPlayed = gamesForPlayer.size
            val firstKilled = gamesForPlayer.filter { it.isFirstKilled(player) }.size
            val firstKilledCityLost = gamesForPlayer.filter { it.isFirstKilled(player) && it.cityWon != true }.size
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
                if (playerIsDonOrSheriff(it.first)) {
                    it.second * 4
                } else {
                    it.second * 3
                }
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

            val mvp = (winPoints / gamesPlayed).roundTo2Digits()
            val ratingCoefficient = (mvp * 100 + gamesPlayed * 0.25F).roundTo2Digits()

            val wins = winByRole.sumOf { it.second }

            val gamesForRole = fullGamesForRole.map { it.first to it.second.size }
            RatingUniversal(
                player = player,
                ratingCoefficient = ratingCoefficient,
                wins = wins,
                gamesPlayed = gamesPlayed,
                winRate = wins.toFloat()/gamesPlayed,
                additionalPoints = additionalPointsByRoleSum,
                penaltyPoints = penaltyPointsByRoleSum,
                firstKilled = firstKilled,
                firstKilledCityLost = firstKilledCityLost,
                percentOfDeath = firstKilled.toFloat()/gamesAsRed,
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

    private fun getPlayersListSeason0(rawData: List<PlayerDataSeason0And1>) = rawData
        // Рауль had excluded himself from the 0th season
        .filter { it.player != "Рауль" }
        .groupBy { it.player }.keys

    private fun getPlayersListSeason1(rawData: List<PlayerDataSeason0And1>) = rawData
        .groupBy { it.player }.keys

    private fun getPlayersListSeason2(rawData: List<PlayerDataSeason2>) = rawData
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

    private fun getGamesDataSeason2(rawData: List<PlayerDataSeason2>) = rawData.chunked(10)
        .map { playersInfo ->
            GameSeason2(
                playersInfo.map { it.player },
                playersInfo.map { it.role },
                getVictoryTeam(playersInfo[0].c),
                playersInfo[1].c.toIntOrNull() ?: 0,

                playersInfo[1].c.toIntOrNull()?.let { firstKilled ->
                    if (firstKilled == 0) {
                        0f
                    } else {
                        playersInfo.map { it.bestMovePoints }[firstKilled-1].toFloat()
                    }
                } ?: 0F,
                playersInfo.map { it.fouls },
                listOf(
                    playersInfo[3].c.toIntOrNull() ?: 0,
                    playersInfo[3].d.toIntOrNull() ?: 0,
                    playersInfo[3].e.toIntOrNull() ?: 0,
                ),
                playersInfo.map { it.additionalPoints.toFloatOrNull() ?: 0F }
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


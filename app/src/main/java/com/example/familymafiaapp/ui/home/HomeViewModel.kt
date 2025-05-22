package com.example.familymafiaapp.ui.home

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.familymafiaapp.enums.Role
import com.example.familymafiaapp.entities.GameSeason0
import com.example.familymafiaapp.entities.PlayerData
import com.example.familymafiaapp.entities.Rating
import com.example.familymafiaapp.enums.Values
import com.example.familymafiaapp.extensions.roundTo2Digits
import com.example.familymafiaapp.network.GoogleSheetService
import com.google.gson.reflect.TypeToken
import com.google.gson.Gson
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

class HomeViewModel : ViewModel() {

    private val _ratings = MutableStateFlow<List<Rating>>(emptyList())
    val ratings: StateFlow<List<Rating>> = _ratings

    private val service = GoogleSheetService.create()

    fun loadDataBySeason(fileContent: String) {
        if (fileContent.isNotEmpty()) {
            val rawData = loadDataFromFile(fileContent)
                .filter { it.number.toIntOrNull() != null }
            val gamesData = getGamesData(rawData)
            val playersList = getPlayersList(rawData)
            val ratings = playersList.map { player ->
                val gamesForPlayer = gamesData.filter { it.players.contains(player) }
                val gamesPlayed = gamesForPlayer.size
                val firstKilled = gamesForPlayer.filter { it.isFirstKilled(player) }.size
                val winByRole = Role.entries.map { role ->
                    Pair(
                        role.sheetValue,
                        getGamesForRole(gamesForPlayer, player, role).filter {
                            if (it.isNormalGame()) {
                                it.hasPlayerWon(player)
                            } else {
                                it.wonByPlayer[it.players.indexOf(player)] == Values.YES.sheetValue
                            }
                        }.size
                    )
                }
                val loseByRole = Role.entries.map { role ->
                    Pair(
                        role.sheetValue,
                        getGamesForRole(gamesForPlayer, player, role).filter {
                                if (it.isNormalGame()) {
                                    !it.hasPlayerWon(player)
                                } else {
                                    it.wonByPlayer[it.players.indexOf(player)] == Values.NO.sheetValue
                                }
                            }.size
                    )
                }
                val penaltyPointsByRole = Role.entries.map { role ->
                    role.sheetValue to getGamesForRole(gamesForPlayer, player, role)
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
                val penaltyPointsByRoleSum =  penaltyPointsByRole
                    .map {
                        it.second
                    }.sum()
                val winPoints = (winByRoleSum - loseByRoleSum - penaltyPointsByRoleSum + additionalPointsByRoleSum).toInt()

                val mvp = (winPoints.toFloat() / gamesPlayed).roundTo2Digits()
                val ratingCoefficient = Math.round(mvp * 100 + gamesPlayed * 0.25F)
                Rating(
                    player = player,
                    ratingCoefficient = ratingCoefficient,
                    winPoints = winPoints,
                    gamesPlayed = gamesPlayed,
                    firstKilled = firstKilled,
                    mvp = mvp,
                    winByRole = winByRole,
                    additionalPointsByRole = emptyList(),
                )
            }
            _ratings.value = ratings.filter { it.gamesPlayed >= 10 }
                .sortedByDescending { it.ratingCoefficient }
        } else {
            loadDataFromServer()
        }
    }

    private fun playerIsDonOrSheriff(role: String) = Role.findByValue(role)?.sheetValue == Role.DON.sheetValue || Role.findByValue(
        role
    )?.sheetValue == Role.SHERIFF.sheetValue

    private fun getGamesForRole(gamesForPlayer: List<GameSeason0>, player: String, role: Role) = gamesForPlayer.filter {
        it.getPlayerRole(player) == role.sheetValue
    }

    private fun getPlayersList(rawData: List<PlayerData>) = rawData
        // Рауль had excluded himself from the 0th season
        .filter { it.player != "Рауль" }
        .groupBy { it.player }.keys

    private fun getGamesData(rawData: List<PlayerData>) = rawData.chunked(10)
        .map { playersInfo ->
            val firstPlayer = playersInfo.first()
            GameSeason0(
                playersInfo.map { it.player },
                playersInfo.map { it.role },
                playersInfo.map { it.won },
                if (Role.findByValue(firstPlayer.role)!!.isBlack) {
                    firstPlayer.won != Values.YES.sheetValue
                } else {
                    firstPlayer.won == Values.YES.sheetValue
                },
                playersInfo.find { it.firstKilled ==  Values.YES.sheetValue }?.number?.toInt() ?: 0,
                playersInfo.find { it.bestMovePoints.isNotEmpty() }?.bestMovePoints?.toFloat()
                    ?: 0.0F,
                playersInfo.map { if (it.eliminated ==  Values.YES.sheetValue) 1F else 0f }
            )
        }

    private fun loadDataFromFile(fileContent: String): List<PlayerData> = try {
        val listType = object : TypeToken<List<PlayerData>>() {}.type
        val players = Gson().fromJson<List<PlayerData>>(fileContent, listType)
        players
    } catch (e: Exception) {
        emptyList()
    }

    private fun loadDataFromServer() {
        viewModelScope.launch {
            service.fetchData()
        }
    }

    companion object {
        const val TAG: String = "HomeViewModel"
    }
}
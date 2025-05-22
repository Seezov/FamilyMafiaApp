package com.example.familymafiaapp.ui.home

import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.familymafiaapp.enums.Role
import com.example.familymafiaapp.entities.GameSeason0
import com.example.familymafiaapp.entities.PlayerData
import com.example.familymafiaapp.entities.Rating
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

    fun loadData(fileContent: String) {
        if (fileContent.isNotEmpty()) {
            val rawData = loadDataFromFile(fileContent)
                .filter { it.number.toIntOrNull() != null }
            // 10 players per game
            val gamesData = rawData.chunked(10)
                .map { playersInfo ->
                    val firstPlayer = playersInfo.first()
                    GameSeason0(
                        playersInfo.map { it.player },
                        playersInfo.map { it.role },
                        playersInfo.map { it.won },
                        if (Role.findByValue(firstPlayer.role)!!.isBlack) {
                            firstPlayer.won != "Да"
                        } else {
                            firstPlayer.won == "Да"
                        },
                        playersInfo.find { it.firstKilled == "Да" }?.number?.toInt() ?: 0,
                        playersInfo.find { it.bestMovePoints.isNotEmpty() }?.bestMovePoints?.toFloat()
                            ?: 0.0F,
                        playersInfo.map { if (it.eliminated == "Да") 1F else 0f }
                    )
                }
            val playersList = rawData
                // Рауль had excluded himself from the 0th season
                .filter { it.player != "Рауль" }
                .groupBy { it.player }.keys
            val ratings = playersList.map { player ->
                val gamesForPlayer = gamesData.filter { it.players.contains(player) }
                val gamesPlayed = gamesForPlayer.size
                val firstKilled =
                    gamesForPlayer.filter { it.isFirstKilled(player) }.size
                val winByRole = Role.entries.map { role ->
                    Pair(
                        role.sheetValue,
                        gamesForPlayer.filter {
                            it.getPlayerRole(player) == role.sheetValue
                        }.filter {
                            if (player == "V") {
                                val won = if (it.isNormalGame()) {
                                    it.hasPlayerWon(player)
                                } else {
                                    it.wonByPlayer[it.players.indexOf(player)] == "Да"
                                }
                                Log.d(TAG, "$player normal game ${it.isNormalGame()}, $role cityWon ${it.cityWon}, won act $won")

                            }

                            if (it.isNormalGame()) {
                                it.hasPlayerWon(player)
                            } else {
                                it.wonByPlayer[it.players.indexOf(player)] == "Да"
                            }
                        }.size
                    )
                }
                if (player == "V") {
                    Log.d(TAG, winByRole.toString())
                }
                val loseByRole = Role.entries.map { role ->
                    Pair(
                        role.sheetValue,
                        gamesForPlayer.filter { it.getPlayerRole(player) == role.sheetValue }
                            .filter {
                                if (it.isNormalGame()) {
                                    !it.hasPlayerWon(player)
                                } else {
                                    it.wonByPlayer[it.players.indexOf(player)] == "Нет"
                                }
                            }.size
                    )
                }
                val penaltyPointsByRole = Role.entries.map { role ->
                    role.sheetValue to gamesForPlayer.filter { it.getPlayerRole(player) == role.sheetValue }
                        .map { it.getPlayerPenaltyPoints(player) }.sum()
                }
                val winByRoleSum = winByRole.sumOf {
                    if (Role.findByValue(it.first)?.sheetValue == Role.DON.sheetValue || Role.findByValue(
                            it.first
                        )?.sheetValue == Role.SHERIFF.sheetValue
                    ) {
                        it.second * 4
                    } else {
                        it.second * 3
                    }
                }
                val loseByRoleSum = loseByRole.sumOf {
                    if (Role.findByValue(it.first)?.sheetValue == Role.DON.sheetValue || Role.findByValue(
                            it.first
                        )?.sheetValue == Role.SHERIFF.sheetValue
                    ) {
                        it.second
                    } else {
                        0
                    }
                }
                val additionalPointsByRoleSum = gamesForPlayer.map { if(it.isFirstKilled(player)) it.bestMovePoints else 0.0f }.sum()
                val penaltyPointsByRoleSum =  penaltyPointsByRole.map { it.second }.sum()
                val winPoints = winByRoleSum - loseByRoleSum - penaltyPointsByRoleSum + additionalPointsByRoleSum

                val mvp = winPoints / gamesPlayed
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
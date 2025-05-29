package com.example.familymafiaapp.entities.seasons.season0And1

import com.example.familymafiaapp.entities.seasons.GameSeason
import com.example.familymafiaapp.enums.Values

class GameSeason0And1(
    seasonId: Int,
    players: List<String>,
    roles: List<String>,
    cityWon: Boolean?,
    firstKilled: Int,
    bestMovePoints: Float,
    val bestMove: List<Int>,
    val wonByPlayer: List<String>,
    val penaltyPoints: List<Float>,
    val additionalPoints: List<Float>? = null
): GameSeason(seasonId, players, roles, cityWon, firstKilled, bestMovePoints) {
    fun getPlayerPenaltyPoints(player: String): Float = penaltyPoints[players.indexOf(player)]

    fun isRegularGame(): Boolean = wonByPlayer.contains(Values.NO.sheetValue.first()) && wonByPlayer.contains(
        Values.YES.sheetValue.first())
}
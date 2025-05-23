package com.example.familymafiaapp.entities.seasons.season0And1

import com.example.familymafiaapp.entities.seasons.GameSeason
import com.example.familymafiaapp.enums.Values

class GameSeason0And1(
    players: List<String>,
    roles: List<String>,
    cityWon: Boolean?,
    firstKilled: Int,
    bestMovePoints: Float,
    val wonByPlayer: List<String>,
    val penaltyPoints: List<Float>
): GameSeason(players, roles, cityWon, firstKilled, bestMovePoints) {
    fun getPlayerPenaltyPoints(player: String): Float = penaltyPoints[players.indexOf(player)]

    fun isNormalGame(): Boolean = wonByPlayer.contains(Values.NO.sheetValue) && wonByPlayer.contains(
        Values.YES.sheetValue)
}
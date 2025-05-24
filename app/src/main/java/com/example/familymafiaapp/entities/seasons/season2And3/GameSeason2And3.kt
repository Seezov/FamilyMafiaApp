package com.example.familymafiaapp.entities.seasons.season2And3

import com.example.familymafiaapp.entities.seasons.GameSeason
import com.example.familymafiaapp.enums.Role

class GameSeason2And3(
    players: List<String>,
    roles: List<String>,
    cityWon: Boolean?,
    firstKilled: Int,
    bestMovePoints: Float,
    val fouls: List<String>,
    val bestMove: List<Int>,
    val additionalPoints: List<Float>,
): GameSeason(players, roles, cityWon, firstKilled, bestMovePoints)  {
    fun getPlayerAdditionalPoints(player: String): Float =
        additionalPoints[players.indexOf(player)]

    fun getPlayerFouls(player: String): Int =
        fouls[players.indexOf(player)].toIntOrNull() ?: 0

    fun isNormalGame(): Boolean = roles.containsAll(Role.entries.map { it.sheetValue })
}
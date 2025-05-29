package com.example.familymafiaapp.entities.seasons.season2to16

import com.example.familymafiaapp.entities.seasons.GameSeason
import com.example.familymafiaapp.enums.Role

class GameSeason2to16(
    seasonId: Int,
    players: List<String>,
    roles: List<String>,
    cityWon: Boolean?,
    firstKilled: Int,
    bestMovePoints: Float,
    val bestMove: List<Int>,
    val penaltyPoints: List<Float>? = null,
    val additionalPoints: List<Float>,
): GameSeason(seasonId, players, roles, cityWon, firstKilled, bestMovePoints)  {
    fun getPlayerAdditionalPoints(player: String): Float =
        additionalPoints[players.indexOf(player)]

    fun getPlayerPenaltyPoints(player: String): Float =
        penaltyPoints?.get(players.indexOf(player)) ?: 0F

    fun isNormalGame(): Boolean =
        roles.count { Role.MAFIA.sheetValue.contains(it) } == 2 &&
                roles.count { Role.SHERIFF.sheetValue.contains(it) } == 1 &&
                roles.count { Role.DON.sheetValue.contains(it) } == 1 &&
                players.let {
                    val set = it.toSet()
                    it.size == set.size
                }

}
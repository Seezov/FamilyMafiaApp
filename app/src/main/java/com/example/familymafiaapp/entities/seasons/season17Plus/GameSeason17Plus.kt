package com.example.familymafiaapp.entities.seasons.season17Plus

import com.example.familymafiaapp.entities.seasons.GameSeason
import com.example.familymafiaapp.enums.Role

class GameSeason17Plus(
    seasonId: Int,
    players: List<String>,
    roles: List<String>,
    cityWon: Boolean?,
    firstKilled: Int,
    bestMovePoints: Float,
    val bestMove: List<Int>,
    val additionalPoints: List<Float>,
    val autoAdditionalPoints: List<Float>? = null,
    val penaltyPoints: List<Float>? = null,
): GameSeason(seasonId, players, roles, cityWon, firstKilled, bestMovePoints)  {
    fun getPlayerAdditionalPoints(player: String): Float =
        additionalPoints[players.indexOf(player)]

    fun getPlayerAutoAdditionalPoints(player: String): Float =
        autoAdditionalPoints?.get(players.indexOf(player)) ?: 0F

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
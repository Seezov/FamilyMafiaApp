package com.example.familymafiaapp.entities.seasons.season17to24

import com.example.familymafiaapp.entities.seasons.GameSeason
import com.example.familymafiaapp.enums.Role

class GameSeason17to24(
    players: List<String>,
    roles: List<String>,
    cityWon: Boolean?,
    firstKilled: Int,
    bestMovePoints: Float,
    val bestMove: List<Int>,
    val additionalPoints: List<Float>,
    val autoAdditionalPoints: List<Float>,
): GameSeason(players, roles, cityWon, firstKilled, bestMovePoints)  {
    fun getPlayerAdditionalPoints(player: String): Float =
        additionalPoints[players.indexOf(player)]

    fun getPlayerAutoAdditionalPoints(player: String): Float =
        autoAdditionalPoints[players.indexOf(player)]

    fun isNormalGame(): Boolean =
        roles.count { Role.MAFIA.sheetValue.contains(it) } == 2 &&
                roles.count { Role.SHERIFF.sheetValue.contains(it) } == 1 &&
                roles.count { Role.DON.sheetValue.contains(it) } == 1 &&
                players.let {
                    val set = it.toSet()
                    it.size == set.size
                }

}
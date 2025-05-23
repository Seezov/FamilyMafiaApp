package com.example.familymafiaapp.entities.seasons.season2

import com.example.familymafiaapp.enums.Role
import com.example.familymafiaapp.enums.Values

data class GameSeason2(
    val players: List<String>,
    val roles: List<String>,
    val fouls: List<String>,
    // True if city won
    // False if mafia won
    // Null if non rating game
    val cityWon: Boolean?,
    val firstKilled: Int,
    val bestMove: List<Int>,
    val bestMovePoints: Float,
    val additionalPoints: List<Float>?
) {
    fun getPlayerRole(player: String): String = roles[players.indexOf(player)]
    fun getPlayerAdditionalPoints(player: String): Float =
        additionalPoints?.get(players.indexOf(player)) ?: 0F

    fun hasPlayerWon(player: String): Boolean = cityWon?.let {
        if (Role.findByValue(getPlayerRole(player))!!.isBlack) {
            !cityWon
        } else {
            cityWon
        }
    } == true

    fun isFirstKilled(player: String): Boolean = players.indexOf(player) + 1 == firstKilled
}
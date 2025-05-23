package com.example.familymafiaapp.entities.seasons

import com.example.familymafiaapp.enums.Role
import com.example.familymafiaapp.enums.Values

open class GameSeason(
    val players: List<String>,
    val roles: List<String>,
    // True if city won
    // False if mafia won
    // Null if non rating game
    val cityWon: Boolean?,
    val firstKilled: Int,
    val bestMovePoints: Float
) {
    fun getPlayerRole(player: String): String = roles[players.indexOf(player)]
    fun hasPlayerWon(player: String): Boolean = cityWon?.let {
        if (Role.Companion.findByValue(getPlayerRole(player))!!.isBlack) {
            !cityWon
        } else {
            cityWon
        }
    } == true
    fun isFirstKilled(player: String): Boolean = players.indexOf(player) + 1 == firstKilled
    fun isRatingGame() = cityWon != null
}
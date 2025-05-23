package com.example.familymafiaapp.entities.seasons.season0and1

import com.example.familymafiaapp.enums.Role
import com.example.familymafiaapp.enums.Values

data class GameSeason0And1(
    val players: List<String>,
    val roles: List<String>,
    val wonByPlayer: List<String>,
    // True if city won
    // False if mafia won
    // Null if non rating game
    val cityWon: Boolean?,
    val firstKilled: Int,
    val bestMovePoints: Float,
    val penaltyPoints: List<Float>
) {
    fun getPlayerRole(player: String): String = roles[players.indexOf(player)]

    fun getPlayerPenaltyPoints(player: String): Float = penaltyPoints[players.indexOf(player)]
    fun hasPlayerWon(player: String): Boolean = cityWon?.let {
        if (Role.Companion.findByValue(getPlayerRole(player))!!.isBlack) {
            !cityWon
        } else {
            cityWon
        }
    } == true

    fun isFirstKilled(player: String): Boolean = players.indexOf(player) + 1 == firstKilled

    fun isNormalGame(): Boolean = wonByPlayer.contains(Values.NO.sheetValue) && wonByPlayer.contains(
        Values.YES.sheetValue)
}
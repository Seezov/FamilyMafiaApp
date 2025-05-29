package com.example.familymafiaapp.entities

import com.example.familymafiaapp.enums.Role
import com.example.familymafiaapp.enums.Values

data class Game(
    val seasonId: Int,
    val players: List<String>,
    val roles: List<String>,
    // True if city won
    // False if mafia won
    // Null if non rating game
    val cityWon: Boolean?,
    val firstKilled: Int,
    val bestMovePoints: Float,
    val bestMove: List<Int>,
    val additionalPoints: List<Float>? = null,
    val penaltyPoints: List<Float>? = null,
    val autoAdditionalPoints: List<Float>? = null,
    val wonByPlayer: List<String>? = null,
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

    fun getPlayerAdditionalPoints(player: String): Float =
        additionalPoints?.get(players.indexOf(player)) ?: 0F

    fun getPlayerAutoAdditionalPoints(player: String): Float =
        autoAdditionalPoints?.get(players.indexOf(player)) ?: 0F

    fun getPlayerPenaltyPoints(player: String): Float =
        penaltyPoints?.get(players.indexOf(player)) ?: 0F

    // Used to check if game has all the roles and no player duplications
    fun isNormalGame(): Boolean =
        roles.count { Role.MAFIA.sheetValue.contains(it) } == 2 &&
                roles.count { Role.SHERIFF.sheetValue.contains(it) } == 1 &&
                roles.count { Role.DON.sheetValue.contains(it) } == 1 &&
                players.let {
                    val set = it.toSet()
                    it.size == set.size
                }

    // Used to check WinPoints in first seasons
    fun isRegularGame(): Boolean = wonByPlayer?.contains(Values.NO.sheetValue.first()) == true && wonByPlayer.contains(
        Values.YES.sheetValue.first()) == true
}
package com.example.familymafiaapp.entities

import com.example.familymafiaapp.enums.Role


data class GameSeason0(
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
        if (Role.findByValue(getPlayerRole(player))!!.isBlack) {
            !cityWon
        } else {
            cityWon
        }
    } ?: false

    fun isFirstKilled(player: String): Boolean = players.indexOf(player) + 1 == firstKilled

    fun isNormalGame(): Boolean = wonByPlayer.contains("Нет") && wonByPlayer.contains("Да")
}


//data class Game(
//    val players: List<String>,
//    val roles: List<String>,
//    val wonByPlayer: List<String>,
//    // True if city won
//    // False if mafia won
//    // Null if non rating game
//    val cityWon: Boolean?,
//    val firstKilled: Int,
//    val bestMove: List<Int>?,
//    val bestMovePoints: Float,
//    val additionalPoints: List<Float>?,
//    val penaltyPoints: List<Float>
//) {
//    fun getPlayerRole(player: String): String = roles[players.indexOf(player)]
//    fun getPlayerAdditionalPoints(player: String): Float =
//        additionalPoints?.get(players.indexOf(player)) ?: 0F
//
//    fun getPlayerPenaltyPoints(player: String): Float = penaltyPoints[players.indexOf(player)]
//    fun hasPlayerWon(player: String): Boolean = cityWon?.let {
//        if (Role.findByValue(getPlayerRole(player))!!.isBlack) {
//            !cityWon
//        } else {
//            cityWon
//        }
//    } ?: false
//
//    fun isFirstKilled(player: String): Boolean = players.indexOf(player) + 1 == firstKilled
//
//    fun isNormalGame(): Boolean = wonByPlayer.contains("Нет") && wonByPlayer.contains("Да")
//}

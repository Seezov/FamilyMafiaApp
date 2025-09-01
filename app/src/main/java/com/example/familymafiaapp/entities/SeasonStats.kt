package com.example.familymafiaapp.entities

data class SeasonStats(
    val playerStats: List<RatingPlayerStats>,
    val mvpPlayerId: Int,
    val bestSheriffPlayerId: Int,
    val bestDonPlayerId: Int,
    val bestCivilianPlayerId: Int,
    val bestMafiaPlayerId: Int,
    val mostKilledPlayerId: Int,
)

package com.example.familymafiaapp.entities

data class SeasonStats(
    val playerStats: List<RatingPlayerStats>,
    val mvpIndex: Int,
    val bestSheriffIndex: Int,
    val bestDonIndex: Int,
    val bestCivilianIndex: Int,
    val bestMafiaIndex: Int,
    val mostKilledIndex: Int,
)

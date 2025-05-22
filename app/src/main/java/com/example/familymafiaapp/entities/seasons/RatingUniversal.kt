package com.example.familymafiaapp.entities.seasons

data class RatingUniversal(
    val player: String,
    val ratingCoefficient: Int,
    val wins: Int,
    val gamesPlayed: Int,
    val winRate: Float,
    val additionalPoints: Float,
    val penaltyPoints: Float,
    val bestMovePoints: Float,
    val firstKilled: Int,
    val firstKilledCityLost: Int,
    val percentOfDeath: Float,
    val ciForGame: Float,
    val ci: Float,
    val mvp: Float,
    val winByRole: List<Pair<String, Int>>,
    val gamesByRole: List<Pair<String, Int>>,
    val additionalPointsByRole: List<Pair<String, Float>>
)
package com.example.familymafiaapp.entities

data class RatingPlayerStats(
    val seasonId: Int,
    val player: String,
    val ratingCoefficient: Float = 0F,
    val wins: Int = 0,
    val gamesPlayed: Int = 0,
    val winRate: Float = 0F,
    val additionalPoints: Float = 0F,
    val penaltyPoints: Float = 0F,
    val bestMovePoints: Float = 0F,
    val firstKilled: Int = 0,
    val firstKilledCityLost: Int = 0,
    val percentOfDeath: Float = 0F,
    val ciForGame: Float = 0F,
    val ci: Float = 0F,
    val mvp: Float = 0F,
    val winByRole: List<Pair<String, Int>> = emptyList(),
    val gamesForRole: List<Pair<String, Int>> = emptyList(),
    val bestMoveAndAdditionalPointsByRole: List<Pair<String, Float>> = emptyList(),
    val penaltyPointsByRole: List<Pair<String, Float>> = emptyList(),
    val seasonGameLimit: Int = 0,
)
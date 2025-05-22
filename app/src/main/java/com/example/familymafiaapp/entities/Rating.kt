package com.example.familymafiaapp.entities

data class Rating(
    val player: String,
    val ratingCoefficient: Int,
    val winPoints: Float,
    val gamesPlayed: Int,
    val firstKilled: Int,
    val mvp: Float,
    val winByRole: List<Pair<String, Int>>,
    val additionalPointsByRole: List<Pair<String, Float>>
)

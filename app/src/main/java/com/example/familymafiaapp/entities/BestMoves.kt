package com.example.familymafiaapp.entities

data class BestMoves(
    val player: String,
    val isFirstKilled: Int,
    val zeroBlacks: Int,
    val oneBlack: Int,
    val twoBlacks: Int,
    val threeBlacks: Int,
)

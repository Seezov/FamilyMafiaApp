package com.example.familymafiaapp.entities

data class Stats(val playerName: String, val role: String, val gamesPlayed: Int,  val slotToWr: List<Pair<Int, Float>> )

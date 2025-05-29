package com.example.familymafiaapp.entities.seasons.season0And1

import com.google.gson.annotations.SerializedName

data class PlayerDataSeason0And1(
    @SerializedName("Номер") val number: String,
    @SerializedName("Игрок") val player: String,
    @SerializedName("Роль") val role: String,
    @SerializedName("Победил") val won: String,
    @SerializedName("Удаление?") val eliminated: String,
    @SerializedName("Первый убиенный?") val firstKilled: String,
    @SerializedName("Балы за \"Лучший ход\"") val bestMovePoints: String,
    @SerializedName("Лучший ход") val bestMove: String
)
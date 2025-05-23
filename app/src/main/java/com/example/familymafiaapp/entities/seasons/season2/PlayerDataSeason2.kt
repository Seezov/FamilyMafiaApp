package com.example.familymafiaapp.entities.seasons.season2

import com.google.gson.annotations.SerializedName

data class PlayerDataSeason2(
    @SerializedName("Номер") val number: String = "",
    @SerializedName("B") val b: String = "",
    @SerializedName("C") val c: String = "",
    @SerializedName("D") val d: String = "",
    @SerializedName("E") val e: String = "",
    @SerializedName("Фолы") val fouls: String = "",
    @SerializedName("Игрок") val player: String = "",
    @SerializedName("Роль") val role: String = "",
    @SerializedName("Победил") val won: String = "",
    @SerializedName("ЛХ") val bestMove: String = "",
    @SerializedName("ЛИ") val bestMovePoints: String = "",
    @SerializedName("X") val x: String = "",
    @SerializedName("Рейтинг") val rating: String = ""
)
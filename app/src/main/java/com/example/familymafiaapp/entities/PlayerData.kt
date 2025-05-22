package com.example.familymafiaapp.entities

import com.google.gson.annotations.SerializedName

data class PlayerData(
    @SerializedName("Номер")
    val number: String,

    @SerializedName("Игрок")
    val player: String,

    @SerializedName("Роль")
    val role: String,

    @SerializedName("Победил")
    val won: String, // or Boolean if it's strictly "Да" / "Нет"

    @SerializedName("Удаление?")
    val eliminated: String,

    @SerializedName("Первый убиенный?")
    val firstKilled: String,

    @SerializedName("Балы за \"Лучший ход\"")
    val bestMovePoints: String, // can be Int? if consistently numeric

    @SerializedName("Лучший ход")
    val bestMove: String

)
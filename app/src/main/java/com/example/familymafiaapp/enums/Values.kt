package com.example.familymafiaapp.enums

enum class Values(val sheetValue: List<String>) {
    YES(listOf("Да")),
    NO(listOf("Нет")),
    MAFIA_WON(listOf("Мафия", "Мафія")),
    CITY_WON(listOf("Город", "Місто")),
    NON_RATING(listOf("Не рейтинг")),
}
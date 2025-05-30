package com.example.familymafiaapp.enums

enum class Role(val sheetValue: List<String>, val isBlack: Boolean, val chanceToDraw: Float) {
    SHERIFF(listOf("Шериф"), false, 0.1F),
    DON(listOf("Дон"), true, 0.1F),
    CIVILIAN(listOf("Мирный","Мирний"), false, 0.6F),
    MAFIA(listOf("Мафия", "Мафія"), true, 0.2F);

    companion object {
        fun findByValue(sheetValue: String): Role? {
            return entries.find { it.sheetValue.contains(sheetValue)}
        }
    }
}
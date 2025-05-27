package com.example.familymafiaapp.enums

enum class Role(val sheetValue: List<String>, val isBlack: Boolean) {
    SHERIFF(listOf("Шериф"), false),
    DON(listOf("Дон"), true),
    CIVILIAN(listOf("Мирный","Мирний"), false),
    MAFIA(listOf("Мафия", "Мафія"), true);

    companion object {
        fun findByValue(sheetValue: String): Role? {
            return entries.find { it.sheetValue.contains(sheetValue)}
        }
    }
}
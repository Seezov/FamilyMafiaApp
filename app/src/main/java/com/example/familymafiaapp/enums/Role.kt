package com.example.familymafiaapp.enums

enum class Role(val sheetValue: String, val isBlack: Boolean) {
    SHERIFF("Шериф", false),
    DON("Дон", true),
    CIVILIAN("Мирный", false),
    MAFIA("Мафия", true);

    companion object {
        fun findByValue(sheetValue: String): Role? {
            return entries.find { it.sheetValue == sheetValue }
        }
    }
}
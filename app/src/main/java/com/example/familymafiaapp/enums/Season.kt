package com.example.familymafiaapp.enums

import com.example.familymafiaapp.R

enum class Season(
    val title: String,
    val jsonFileRes: Int,
    val gameLimit: Int,
    val gamesMultiplier: Float
) {
    SEASON_0("Season 0", R.raw.season0, 10, 0.25F),
    SEASON_1("Season 1", R.raw.season1, 30, 0.25F),
    SEASON_2("Season 2", R.raw.season2, 50, 0.02F),
    SEASON_3("Season 3", R.raw.season3, 20, 0.015F),
    SEASON_4("Season 4", R.raw.season4, 40, 0.007F),
    SEASON_5("Season 5", R.raw.season5, 50, 0.004F),
    SEASON_6("Season 6", R.raw.season6, 70, 0.004F),
    SEASON_7("Season 7", R.raw.season7, 50, 0.004F),
    SEASON_8("Season 8", R.raw.season8, 30, 0.004F),
    SEASON_9("Season 9", R.raw.season9, 40, 0.004F),
    SEASON_10("Season 10", R.raw.season10, 40, 0.004F),
    SEASON_11("Season 11", R.raw.season11, 45, 0.004F),
    SEASON_12("Season 12", R.raw.season12, 50, 0.004F),
    SEASON_13("Season 13", R.raw.season13, 40, 0.004F),
    SEASON_14("Season 14", R.raw.season14, 58, 0.004F),
    SEASON_15("Season 15", R.raw.season15, 56, 0.004F),
    SEASON_16("Season 16", R.raw.season16, 58, 0.004F),
    SEASON_17("Season 17", R.raw.season17, 60, 0F),
    SEASON_18("Season 18", R.raw.season18, 55, 0F),
    SEASON_19("Season 19", R.raw.season19, 60, 0F),
    SEASON_20("Season 20", R.raw.season20, 60, 0F),
    SEASON_21("Season 21", R.raw.season21, 60, 0F),
    SEASON_22("Season 22", R.raw.season22, 60, 0F),
    SEASON_23("Season 23", R.raw.season23, 60, 0F),
    SEASON_24("Season 24", R.raw.season24, 42, 0F),
    SEASON_25("Season 25", R.raw.season25, 60, 0F),
}
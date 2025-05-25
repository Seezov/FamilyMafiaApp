package com.example.familymafiaapp.enums

import com.example.familymafiaapp.R

enum class Season(val title: String, val jsonFileRes: Int, val gameLimit: Int, val gamesMultiplier: Float) {
    SEASON_0("Season 0", R.raw.season0, 10, 0.25F),
    SEASON_1("Season 1",R.raw.season1, 30, 0.25F),
    SEASON_2("Season 2",R.raw.season2, 50, 0.02F),
    SEASON_3("Season 3",R.raw.season3, 20, 0.015F),
    SEASON_4("Season 4",R.raw.season4, 40, 0.007F),
    SEASON_5("Season 5",R.raw.season5, 50, 0.004F),
    SEASON_6("Season 6",R.raw.season6, 70, 0.004F),
    SEASON_7("Season 7",R.raw.season7, 50, 0.004F),
    SEASON_8("Season 8",R.raw.season8, 30, 0.004F),
    SEASON_9("Season 9",R.raw.season9, 40, 0.004F),
    SEASON_10("Season 10",R.raw.season10, 40, 0.004F),
    SEASON_11("Season 11",R.raw.season11, 45, 0.004F),
    SEASON_12("Season 12",R.raw.season12, 50, 0.004F),
}
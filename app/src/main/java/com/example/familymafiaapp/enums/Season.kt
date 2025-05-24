package com.example.familymafiaapp.enums

import com.example.familymafiaapp.R

enum class Season(val title: String, val jsonFileRes: Int, val gameLimit: Int, val gamesMultiplier: Float) {
    SEASON_0("Season 0", R.raw.season0, 10, 0.25F),
    SEASON_1("Season 1",R.raw.season1, 30, 0.25F),
    SEASON_2("Season 2",R.raw.season2, 50, 0.02F),
    SEASON_3("Season 3",R.raw.season3, 20, 0.015F),
    SEASON_4("Season 4",R.raw.season4, 40, 0.007F),
}
package com.example.familymafiaapp.enums

import com.example.familymafiaapp.R

enum class Season(val title: String, val jsonFileRes: Int, val gameLimit: Int) {
    SEASON_0("Season 0", R.raw.season0, 10),
    SEASON_1("Season 1",R.raw.season1, 30),
}
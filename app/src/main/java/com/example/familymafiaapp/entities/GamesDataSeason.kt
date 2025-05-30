package com.example.familymafiaapp.entities

import com.google.gson.annotations.SerializedName

data class GamesDataSeason(
    @SerializedName("A") val a: String = "",
    @SerializedName("B") val b: String = "",
    @SerializedName("C") val c: String = "",
    @SerializedName("D") val d: String = "",
    @SerializedName("E") val e: String = "",
    @SerializedName("F") val f: String = "",
    @SerializedName("G") val g: String = "",
    @SerializedName("H") val h: String = "",
    @SerializedName("I") val i: String = "",
    @SerializedName("J") val j: String = ""
)
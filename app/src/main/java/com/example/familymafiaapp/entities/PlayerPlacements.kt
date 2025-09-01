package com.example.familymafiaapp.entities

    data class PlayerPlacements(
        val player: Player,
        var firsts: Int = 0,
        var seconds: Int = 0,
        var thirds: Int = 0,
        var mvp: Int = 0,
        var bestSheriff: Int = 0,
        var bestDon: Int = 0,
        var bestCivilian: Int = 0,
        var bestMafia: Int = 0,
    ) {
        fun sumOfNominations(): Int = firsts + seconds + thirds + mvp + bestSheriff + bestDon + bestCivilian + bestMafia
    }
package com.example.familymafiaapp.repository

import com.example.familymafiaapp.entities.Player
import com.example.familymafiaapp.entities.RatingUniversal
import com.example.familymafiaapp.enums.Season
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class PlayersRepository @Inject constructor()  {
    private val _players = mutableListOf<Player>()
    val players: List<Player>
        get() = _players

    fun addPlayer(player: Player) {
        _players.remove(player)
        _players.add(player)
    }

    fun addPlayers(players: List<Player>) {
        _players.removeAll(players)
        _players.addAll(players)
    }

    fun getAllPlayers(): List<Player> {
        return _players
    }

    fun clearPlayers() {
        _players.clear()
    }
}
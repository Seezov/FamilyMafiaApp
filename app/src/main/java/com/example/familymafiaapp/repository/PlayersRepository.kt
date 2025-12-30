package com.example.familymafiaapp.repository

import com.example.familymafiaapp.entities.Player
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class PlayersRepository @Inject constructor() {
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

    fun clearPlayers() {
        _players.clear()
    }

    fun getDisplayName(playerName: String): String = findPlayer(playerName).displayName

    fun findPlayer(playerName: String): Player {
        val player = _players.find {
            if (it.nicknames != null) {
                it.nicknames.contains(playerName)
            } else {
                it.displayName == playerName
            }
        }
        return player ?: throw IllegalArgumentException("Player \"$playerName\" not found")
    }
}
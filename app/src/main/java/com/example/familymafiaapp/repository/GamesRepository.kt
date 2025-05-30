package com.example.familymafiaapp.repository

import com.example.familymafiaapp.entities.Game
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class GamesRepository @Inject constructor()  {
    private val _games = mutableListOf<Game>()
    val games: List<Game>
        get() = _games

    fun addGame(game: Game) {
        _games.remove(game)
        _games.add(game)
    }

    fun addGames(games: List<Game>) {
        _games.removeAll(games)
        _games.addAll(games)
    }

    fun getAllGames(): List<Game> {
        return _games
    }

    fun clearGames() {
        _games.clear()
    }
}
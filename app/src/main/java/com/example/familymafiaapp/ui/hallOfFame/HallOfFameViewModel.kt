package com.example.familymafiaapp.ui.hallOfFame

import android.util.Log
import androidx.lifecycle.LiveData
import androidx.lifecycle.MutableLiveData
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.familymafiaapp.entities.RatingUniversal
import com.example.familymafiaapp.enums.Season
import com.example.familymafiaapp.extensions.roundTo2Digits
import com.example.familymafiaapp.repository.GamesRepository
import com.example.familymafiaapp.repository.PlayersRepository
import com.example.familymafiaapp.repository.RatingRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject
import kotlin.math.sign

@HiltViewModel
class HallOfFameViewModel @Inject constructor(
    private val ratingRepository: RatingRepository,
    private val playersRepository: PlayersRepository,
    private val gamesRepository: GamesRepository,
) : ViewModel() {

    private val _ratings = MutableStateFlow<List<Triple<String, Int, Float>>>(emptyList())
    val ratings: StateFlow<List<Triple<String, Int, Float>>> = _ratings

    private val _debugText = MutableStateFlow<String>("")
    val debugText: StateFlow<String> = _debugText

    init {
        viewModelScope.launch {
            val games = gamesRepository.getAllGames()
            val players = playersRepository.getAllPlayers()
            val playerToNumberOfGames = players.map { player ->
                val gamesForPlayer = games.filter { game ->
                    if (player.nicknames == null) {
                        game.players.contains(player.displayName)
                    } else {
                        player.nicknames.any { game.players.contains(it) }
                    }
                }
                val gamesForPlayerSize = gamesForPlayer.size
                val gamesWon = gamesForPlayer.filter { game ->
                    val nicknameInGame = if (player.nicknames == null) {
                        player.displayName
                    } else {
                        player.nicknames.find { game.players.contains(it) } ?: player.displayName
                    }
                    game.hasPlayerWon(nicknameInGame)
                }.size
                val winRate = (gamesWon.toFloat()/gamesForPlayerSize * 100).roundTo2Digits()
                Triple(player.displayName, gamesForPlayer.size,winRate )
            }.filter { it.second  >= 200 }.sortedBy { it.third }
            _ratings.value = playerToNumberOfGames
        }
    }

    companion object {
        const val TAG: String = "HallOfFameViewModel"
    }
}
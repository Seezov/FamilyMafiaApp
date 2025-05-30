package com.example.familymafiaapp.ui.hallOfFame

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.familymafiaapp.entities.Game
import com.example.familymafiaapp.entities.Player
import com.example.familymafiaapp.enums.Role
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
                val gamesForPlayer = getGamesForPlayer(games, player)
                val gamesForPlayerOnSheriff = gamesForPlayer.filter { game ->
                    val role = game.getPlayerRole(getNicknameInGame(game,player))
                    Role.DON.sheetValue.contains(role)
                }
                val gamesForPlayerOnSheriffSize = gamesForPlayerOnSheriff.size
                val gamesWonOnSheriff = gamesForPlayerOnSheriff.filter { game ->
                    game.hasPlayerWon(getNicknameInGame(game,player))
                }
                val gamesWonOnSheriffSize = gamesWonOnSheriff.size
                if (gamesWonOnSheriffSize > 0 && gamesForPlayerOnSheriffSize > 0) {
                    val winRate = (gamesWonOnSheriffSize.toFloat() / gamesForPlayerOnSheriffSize * 100).roundTo2Digits()
                    Triple(player.displayName, gamesForPlayerOnSheriffSize, winRate)
                } else {
                    Triple(player.displayName, 0, 0F)
                }
            }.filter { it.second >= 10 }.sortedByDescending { it.third }
            _ratings.value = playerToNumberOfGames
        }
    }

    fun getGamesForPlayer(
        games: List<Game>,
        player: Player,
        from: Int = Season.entries.first().id,
        to: Int = Season.entries.last().id
    ) = games.filter {
            it.seasonId in from..to
        }.filter { game ->
            if (player.nicknames == null) {
                game.players.contains(player.displayName)
            } else {
                player.nicknames.any { game.players.contains(it) }
            }
        }

    fun getNicknameInGame(game: Game, player: Player) = if (player.nicknames == null) {
        player.displayName
    } else {
        player.nicknames.find { game.players.contains(it) } ?: player.displayName
    }

    companion object {
        const val TAG: String = "HallOfFameViewModel"
    }
}
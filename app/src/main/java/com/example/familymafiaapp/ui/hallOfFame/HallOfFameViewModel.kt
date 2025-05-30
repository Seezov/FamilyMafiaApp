package com.example.familymafiaapp.ui.hallOfFame

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.familymafiaapp.entities.Game
import com.example.familymafiaapp.entities.Player
import com.example.familymafiaapp.entities.Stats
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

    private val _stats = MutableStateFlow<List<Stats>>(emptyList())
    val stats: StateFlow<List<Stats>> = _stats

    private val _ratings = MutableStateFlow<List<Triple<String, Int, Float>>>(emptyList())
    val ratings: StateFlow<List<Triple<String, Int, Float>>> = _ratings

    private val _playerOnSlot = MutableStateFlow<List<Triple<String, Int, List<Pair<Int, Int>>>>>(emptyList())
    val playerOnSlot: StateFlow<List<Triple<String, Int, List<Pair<Int, Int>>>>> = _playerOnSlot

    private val _debugText = MutableStateFlow<String>("")
    val debugText: StateFlow<String> = _debugText

    init {
        viewModelScope.launch {
            val games = gamesRepository.getAllGames()
            val players = playersRepository.getAllPlayers()
            val playerToNumberOfGames = players.map { player ->
                val gamesForPlayer = getGamesForPlayer(games, player)
                val role = Role.SHERIFF
                val gamesForPlayerOnSheriff = gamesForPlayer.getGamesForRole(player, role)
                val gamesForPlayerOnSheriffSize = gamesForPlayerOnSheriff.size
                if (gamesForPlayerOnSheriffSize > 0) {
                    val slotToGame = gamesForPlayerOnSheriff.groupBy { it.getPlayerSlot(getNicknameInGame(it, player)) }
                    val slotToGameCount = slotToGame.map { it.key to it.value.size }
                    val slotToGameWinCount =  slotToGame.map { it.key to it.value.filter { it.hasPlayerWon(getNicknameInGame(it,player)) }.size }
                    val slotToWr = slotToGame.toSortedMap().map { slot ->
                        val selectedSlotToGameWinCount = slotToGameWinCount.find { entry -> entry.first == slot.key }?.second?.toFloat() ?: 0F
                        val selectedSlotToGameCount = slotToGameCount.find { entry -> entry.first == slot.key }?.second?.toFloat() ?: 0F
                        if (selectedSlotToGameWinCount > 0 && selectedSlotToGameCount > 0) {
                            slot.key to (selectedSlotToGameWinCount/selectedSlotToGameCount * 100).roundTo2Digits()
                        } else {
                            slot.key to 0F
                        }
                    }
                    Stats(player.displayName, role.sheetValue.last(), gamesForPlayer.size, slotToWr)
                } else {
                    Stats(player.displayName, role.sheetValue.last(), 0, emptyList())
                }
            }.sortedByDescending { it.gamesPlayed }
            _stats.value = playerToNumberOfGames
//            }.filter { it.second >= 10 }.sortedByDescending { it.third }
//            _ratings.value = playerToNumberOfGames
        }
    }

    fun List<Game>.getGamesForRole(
        player: Player,
        role: Role
    ) = filter {
        role.sheetValue.contains(it.getPlayerRole(getNicknameInGame(it, player)))
    }

    fun longestWinStreak(results: List<Boolean>): Int {
        var maxStreak = 0
        var currentStreak = 0

        for (result in results) {
            if (result) {
                currentStreak++
                maxStreak = maxOf(maxStreak, currentStreak)
            } else {
                currentStreak = 0
            }
        }

        return maxStreak
    }

 // WR per slot
//    val slotToGame = gamesForPlayer
//        .groupBy { game -> game.getPlayerSlot(getNicknameInGame(game,player)) }.toSortedMap()
//    val slotToGameWr = slotToGame.map { slot ->
//        val gamesWon = slot.value.filter { it.hasPlayerWon(getNicknameInGame(it, player)) }.size
//        slot.key to (gamesWon.toFloat()/slot.value.size*100).toInt()
//    }
//    Triple(player.displayName, gamesForPlayer.size, slotToGameWr)

  // Add points per game last ye
//    if (gamesForPlayer.isEmpty()) {
//        Triple(player.displayName, 0, 0f)
//    } else {
//        val additionalPoints = gamesForPlayer.map { game -> game.getPlayerAdditionalPoints(getNicknameInGame(game,player))}.sum().roundTo2Digits()
//        val bestMovePoints = gamesForPlayer.map { game ->
//            if (game.isFirstKilled(getNicknameInGame(game,player))) {
//                game.bestMovePoints
//            } else {
//                0F
//            }
//        }.sum().roundTo2Digits()
//        Triple(player.displayName, gamesForPlayer.size, ((additionalPoints+bestMovePoints)/gamesForPlayer.size).roundTo2Digits())
//    }

    // Player on slot
//    val gamesForPlayer = getGamesForPlayer(games, player)
//    val slotToGames = gamesForPlayer.groupBy { it.getPlayerSlot(getNicknameInGame(it, player)) }.map { it.key to it.value.size }.sortedBy { it.first }
//    Triple(player.displayName, gamesForPlayer.size, slotToGames)

    // WR on role
//    val gamesForPlayerOnSheriff = gamesForPlayer.filter { game ->
//        val role = game.getPlayerRole(getNicknameInGame(game,player))
//        Role.DON.sheetValue.contains(role)
//    }
//    val gamesForPlayerOnSheriffSize = gamesForPlayerOnSheriff.size
//    val gamesWonOnSheriff = gamesForPlayerOnSheriff.filter { game ->
//        game.hasPlayerWon(getNicknameInGame(game,player))
//    }
//    val gamesWonOnSheriffSize = gamesWonOnSheriff.size
//    if (gamesWonOnSheriffSize > 0 && gamesForPlayerOnSheriffSize > 0) {
//        val winRate = (gamesWonOnSheriffSize.toFloat() / gamesForPlayerOnSheriffSize * 100).roundTo2Digits()
//        Triple(player.displayName, gamesForPlayerOnSheriffSize, winRate)
//    } else {
//        Triple(player.displayName, 0, 0F)
//    }
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
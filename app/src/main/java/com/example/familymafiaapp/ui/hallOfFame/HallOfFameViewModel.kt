package com.example.familymafiaapp.ui.hallOfFame

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.familymafiaapp.entities.BestMoves
import com.example.familymafiaapp.entities.Game
import com.example.familymafiaapp.entities.Player
import com.example.familymafiaapp.entities.PlayerPlacements
import com.example.familymafiaapp.entities.SeasonStats
import com.example.familymafiaapp.entities.SlotStats
import com.example.familymafiaapp.entities.Stats
import com.example.familymafiaapp.enums.Role
import com.example.familymafiaapp.enums.Season
import com.example.familymafiaapp.extensions.roundTo
import com.example.familymafiaapp.extensions.roundTo2Digits
import com.example.familymafiaapp.repository.GamesRepository
import com.example.familymafiaapp.repository.PlayersRepository
import com.example.familymafiaapp.repository.RatingRepository
import com.example.familymafiaapp.repository.SeasonRepository
import com.example.familymafiaapp.ui.home.getPlayersList
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
    private val seasonRepository: SeasonRepository,
) : ViewModel() {

    private val _bestMoves = MutableStateFlow<List<BestMoves>>(emptyList())
    val bestMoves: StateFlow<List<BestMoves>> = _bestMoves

    private val _slotStats = MutableStateFlow<List<SlotStats>>(emptyList())
    val slotStats: StateFlow<List<SlotStats>> = _slotStats

    private val _stats = MutableStateFlow<List<Stats>>(emptyList())
    val stats: StateFlow<List<Stats>> = _stats

    private val _playerPlacements = MutableStateFlow<List<PlayerPlacements>>(emptyList())
    val playerPlacements: StateFlow<List<PlayerPlacements>> = _playerPlacements

    private val _ratings = MutableStateFlow<List<Triple<String, Int, Float>>>(emptyList())
    val ratings: StateFlow<List<Triple<String, Int, Float>>> = _ratings

    private val _playerOnSlot =
        MutableStateFlow<List<Triple<String, Int, List<Pair<Int, Int>>>>>(emptyList())
    val playerOnSlot: StateFlow<List<Triple<String, Int, List<Pair<Int, Int>>>>> = _playerOnSlot

    private val _debugText = MutableStateFlow<String>("")
    val debugText: StateFlow<String> = _debugText

    init {
        viewModelScope.launch {
            val games = gamesRepository.games.filter {
                it.isRatingGame() &&
                        it.isNormalGame() &&
                        it.seasonId in 24..27 }
            val allStarsPlayers = listOf<String>("Seezov", "Залізний", "Аватар", "Kulav", "Валькірія", "Tina", "Малина", "Floppy", "Малишка", "Хоттабич", "Фурія", "Сирник", "Фрау", "Аглая")
            val players = playersRepository.players.filter {
                 allStarsPlayers.contains(it.displayName)
            }
            val player = players.first()
            val gamesByPlayer = games.filter { it.players.contains(player.displayName) }
            _debugText.value = getWinRate(gamesByPlayer, player, Role.MAFIA).toString() + "%"
//            val seasonsStats = seasonRepository.seasons
//            _playerPlacements.value = calculatePlayerPlacements(seasonsStats)
        }
    }

    fun getWinRate(gamesByPlayer: List<Game>, player: Player, role: Role? = null): Float {
        val filteredGames = role?.let {
            gamesByPlayer.filter { Role.Companion.findByValue(it.getPlayerRole(player.displayName)) == role }
        } ?: gamesByPlayer
        return (filteredGames.count { it.hasPlayerWon(player.displayName) }.toFloat() / filteredGames.size * 100).roundTo(2)
    }

    fun calculatePlayerPlacements(seasons: List<SeasonStats>): List<PlayerPlacements> {
        val placementsMap = mutableMapOf<Player, PlayerPlacements>()

        seasons.forEach { season ->
            val stats = season.playerStats

            fun addPlacement(playerName: Player, update: PlayerPlacements.() -> Unit) {
                val placement = placementsMap.getOrPut(playerName) { PlayerPlacements(playerName) }
                placement.update()
            }

            // Top 3
            stats.getOrNull(0)?.player?.let { addPlacement(it) { firsts++ } }
            stats.getOrNull(1)?.player?.let { addPlacement(it) { seconds++ } }
            stats.getOrNull(2)?.player?.let { addPlacement(it) { thirds++ } }

            // Role Awards
            stats.find { it.player.id == season.mvpPlayerId }?.player?.let { addPlacement(it) { mvp++ } }
            stats.find { it.player.id == season.bestSheriffPlayerId}?.player?.let { addPlacement(it) { bestSheriff++ } }
            stats.find { it.player.id == season.bestDonPlayerId}?.player?.let { addPlacement(it) { bestDon++ } }
            stats.find { it.player.id == season.bestCivilianPlayerId}?.player?.let { addPlacement(it) { bestCivilian++ } }
            stats.find { it.player.id == season.bestMafiaPlayerId}?.player?.let { addPlacement(it) { bestMafia++ } }
        }

        return placementsMap.values.toList().sortedWith(
            compareByDescending<PlayerPlacements> { it.firsts }
                .thenByDescending { it.seconds }
                .thenByDescending { it.thirds }
                .thenByDescending { it.sumOfNominations() }
        )
    }

//    val playerToBadBestMoveMap = mutableListOf<BestMoves>()
//    games.forEach { game ->
//        try {
//            val blacks = game.roles.mapIndexedNotNull { index, role ->
//                if (Role.DON.sheetValue.contains(role) || Role.MAFIA.sheetValue.contains(
//                        role
//                    )
//                ) index else null
//            }
//            val numOfBlacksInBestMove = game.bestMove.intersect(blacks).size
//            if (game.firstKilled != 0) {
//                val playerInGameName = game.players[game.firstKilled - 1]
//                val playerDisplayName = players.find {
//                    it.nicknames?.contains(playerInGameName)
//                        ?: (it.displayName == playerInGameName)
//                }!!.displayName
//                var playersBM =
//                    playerToBadBestMoveMap.find { it.player == playerDisplayName }
//                if (playersBM != null) {
//                    playerToBadBestMoveMap.remove(playersBM)
//                }
//                playersBM = playersBM?.copy(isFirstKilled = playersBM.isFirstKilled + 1)
//                    ?: BestMoves(player = playerDisplayName, isFirstKilled = 1, 0, 0, 0, 0)
//                playersBM = when (numOfBlacksInBestMove) {
//                    0 -> playersBM.copy(zeroBlacks = playersBM.zeroBlacks + 1)
//                    1 -> playersBM.copy(oneBlack = playersBM.oneBlack + 1)
//                    2 -> playersBM.copy(twoBlacks = playersBM.twoBlacks + 1)
//                    3 -> playersBM.copy(threeBlacks = playersBM.threeBlacks + 1)
//                    else -> {
//                        throw NullPointerException("lolllll")
//                    }
//                }
//                playerToBadBestMoveMap.add(playersBM)
//            }
//        } catch (e: Exception) {
//            val a = 1
//        }
//    }
//
//    _bestMoves.value = playerToBadBestMoveMap.sortedByDescending { it.isFirstKilled }

//    val gamesWithSheriffDead = games
//        .filter { it.cityWon != null  }
//        .filter { it.players.contains("Don`Tright") }
//        .filter { it.isFirstKilled("Don`Tright") }
//                .filter { Role.SHERIFF.sheetValue.contains(it.getPlayerRole("Don`Tright")) || Role.CIVILIAN.sheetValue.contains(it.getPlayerRole("Don`Tright")) }
//    _debugText.value = "Wr when miss - City: ${gamesWithSheriffDead.filter { it.cityWon!! }.size.toFloat()/gamesWithSheriffDead.size}, Mafia:${gamesWithSheriffDead.filter { !it.cityWon!! }.size.toFloat()/gamesWithSheriffDead.size}"
    //            val slots = listOf(0, 1, 2, 3, 4, 5, 6, 7, 8, 9)
//            val wrForRole = calculateSlotRoleWinrates(games)
//            _slotStats.value = slots.map { slot ->
//                val slotStats = wrForRole[slot]
//                val slotStatResult = SlotStats(slot, Role.entries.map { role ->
//                   val roleStats = slotStats!![role]
//                    role.sheetValue.last() to roleStats!!
//                })
//                slotStatResult
//            }

    fun calculateSlotRoleWinrates(games: List<Game>): Map<Int, Map<Role, Float>> {
        // Map<slotIndex, Map<role, total and wins>>
        val totalBySlotRole = mutableMapOf<Int, MutableMap<Role, Int>>()
        val winsBySlotRole = mutableMapOf<Int, MutableMap<Role, Int>>()

        for (game in games) {
            if (!game.isRatingGame()) continue

            for (i in game.players.indices) {
                val role = Role.findByValue(game.roles[i]) ?: continue
                val player = game.players[i]
                val won = game.hasPlayerWon(player)

                totalBySlotRole.getOrPut(i) { mutableMapOf() }[role] =
                    totalBySlotRole[i]?.getOrDefault(role, 0)?.plus(1) ?: 1

                if (won) {
                    winsBySlotRole.getOrPut(i) { mutableMapOf() }[role] =
                        winsBySlotRole[i]?.getOrDefault(role, 0)?.plus(1) ?: 1
                }
            }
        }

        // Calculate winrate = wins / total
        return totalBySlotRole.mapValues { (slot, roleMap) ->
            roleMap.mapValues { (role, total) ->
                val wins = winsBySlotRole[slot]?.get(role) ?: 0
                if (total > 0) (wins.toFloat() / total * 100).roundTo(2) else 0f
            }
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


// ALL STATS PER PLAYER
//    val playerToNumberOfGames = players.map { player ->
//        val gamesForPlayer = getGamesForPlayer(games, player)
//        val role = Role.DON
//        val gamesForPlayerOnSheriff = gamesForPlayer.getGamesForRole(player, role)
//        val gamesForPlayerOnSheriffSize = gamesForPlayerOnSheriff.size
//        if (gamesForPlayerOnSheriffSize > 0) {
//            val slotToGame = gamesForPlayerOnSheriff.groupBy { it.getPlayerSlot(getNicknameInGame(it, player)) }
//            val slotToGameCount = slotToGame.map { it.key to it.value.size }
//            val slotToGameWinCount =  slotToGame.map { it.key to it.value.filter { it.hasPlayerWon(getNicknameInGame(it,player)) }.size }
//            val slotToWr = slotToGame.toSortedMap().map { slot ->
//                val selectedSlotToGameWinCount = slotToGameWinCount.find { entry -> entry.first == slot.key }?.second ?: 0
//                val selectedSlotToGameCount = slotToGameCount.find { entry -> entry.first == slot.key }?.second ?: 0
//                Triple(slot.key, selectedSlotToGameWinCount, selectedSlotToGameCount)
//            }
//            Stats(player.displayName, role.sheetValue.last(), gamesForPlayer.size, slotToWr)
//        } else {
//            Stats(player.displayName, role.sheetValue.last(), 0, emptyList())
//        }
//    }.sortedByDescending { it.gamesPlayed }
//    _stats.value = playerToNumberOfGames

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
package com.example.familymafiaapp.ui.home

import androidx.lifecycle.ViewModel
import com.example.familymafiaapp.entities.Player
import com.example.familymafiaapp.enums.Role
import com.example.familymafiaapp.entities.GamesDataSeason
import com.example.familymafiaapp.entities.RatingPlayerStats
import com.example.familymafiaapp.entities.Game
import com.example.familymafiaapp.entities.SeasonStats
import com.example.familymafiaapp.enums.Season
import com.example.familymafiaapp.enums.Values
import com.example.familymafiaapp.extensions.roundTo
import com.example.familymafiaapp.repository.GamesRepository
import com.example.familymafiaapp.repository.PlayersRepository
import com.example.familymafiaapp.repository.RatingRepository
import com.example.familymafiaapp.repository.SeasonRepository
import com.google.gson.reflect.TypeToken
import com.google.gson.Gson
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import javax.inject.Inject
import kotlin.collections.filter
import kotlin.math.roundToInt
import kotlin.text.toFloat

@HiltViewModel
class HomeViewModel @Inject constructor(
    private val ratingRepository: RatingRepository,
    private val playersRepository: PlayersRepository,
    private val gamesRepository: GamesRepository,
    private val seasonRepository: SeasonRepository,
) : ViewModel() {

    private val _seasonStats = MutableStateFlow<SeasonStats?>(null)
    val seasonStats: StateFlow<SeasonStats?> = _seasonStats

    private val _selectedSeason = MutableStateFlow<Season?>(null)
    val selectedSeason: StateFlow<Season?> = _selectedSeason

    private val _debugText = MutableStateFlow<String>("")
    val debugText: StateFlow<String> = _debugText

    fun displaySeason(season: Season) {
        _seasonStats.value = seasonRepository.getSeason(season.id)
    }

    private fun generateSeasonStats(ratingPlayerStats: List<RatingPlayerStats>): SeasonStats {
        val mvp = ratingPlayerStats.maxByOrNull { it.mvp }!!
        val mvpIndex = ratingPlayerStats.indexOf(mvp)
        val mostKilled = ratingPlayerStats.maxByOrNull { it.firstKilled }!!
        val mostKilledIndex = ratingPlayerStats.indexOf(mostKilled)
        val bestSheriff = findBestPlayerForRole(ratingPlayerStats, Role.SHERIFF)
        val bestSheriffIndex = ratingPlayerStats.indexOf(bestSheriff)
        val bestDon = findBestPlayerForRole(ratingPlayerStats, Role.DON)
        val bestDonIndex = ratingPlayerStats.indexOf(bestDon)
        val bestCivilian = findBestPlayerForRole(ratingPlayerStats, Role.CIVILIAN)
        val bestCivilianIndex = ratingPlayerStats.indexOf(bestCivilian)
        val bestMafia = findBestPlayerForRole(ratingPlayerStats, Role.MAFIA)
        val bestMafiaIndex = ratingPlayerStats.indexOf(bestMafia)
        return SeasonStats(
            playerStats = ratingPlayerStats,
            mvpIndex = mvpIndex,
            bestSheriffIndex = bestSheriffIndex,
            bestDonIndex = bestDonIndex,
            bestCivilianIndex = bestCivilianIndex,
            bestMafiaIndex = bestMafiaIndex,
            mostKilledIndex = mostKilledIndex,
        )
    }

    fun findBestPlayerForRole(
        players: List<RatingPlayerStats>,
        role: Role
    ): RatingPlayerStats? {
        // Precalculate player stats for the role with filters
        val roleStats = players.mapNotNull { player ->
            val roleKey = role.sheetValue.last()
            val gamesForRole = player.gamesForRole.find { it.first == roleKey }?.second ?: 0
            val winsForRole = player.winByRole.find { it.first == roleKey }?.second ?: 0
            val pointsForRole = player.bestMoveAndAdditionalPointsByRole.find { it.first == roleKey }?.second ?: 0f
            val gameLimitByRole = player.seasonGameLimit.toFloat() * role.chanceToDraw

            if (gamesForRole == 0 || gamesForRole < gameLimitByRole) return@mapNotNull null

            val winRate = winsForRole.toFloat() / gamesForRole
            val avgPoints = pointsForRole / gamesForRole

            Triple(player, winRate, avgPoints)
        }

        if (roleStats.isEmpty()) return null

        // Determine the max values for normalization
        val maxWinRate = roleStats.maxOf { it.second }

        // Compute score
        return roleStats
            .filter { it.second  >= (maxWinRate - 0.2) }
            .sortedByDescending { it.second }
            .maxByOrNull { it.third }!!.first
    }

    fun loadPlayers(json: String) {
        val players = parseJsonList<Player>(json)
        playersRepository.addPlayers(players)
    }

    fun loadDataBySeason(season: Season, fileContent: String) {
        if (fileContent.isNotEmpty()) {
            loadSeason(season, fileContent)
        } else {
//            loadDataFromServer()
        }
    }

    private fun loadSeason(season: Season, fileContent: String) {
        val rawData = parseJsonList<GamesDataSeason>(fileContent)
            .filter { filterRawData(it, season.id) }
        val gamesData = getGamesDataSeason(season.id, rawData).filter { it.isRatingGame() }
        gamesData.forEachIndexed { index, game ->
            if (!game.isNormalGame()) {
                throw Exception("is not normal game #$index ${game.players}")
            }
        }
        gamesRepository.addGames(gamesData)
        val playersList = gamesData.getPlayersList(season.id)
        val ratings = playersList.map { player ->
            val gamesForPlayer = gamesData.filter { it.players.contains(player) }
            val gamesPlayed = gamesForPlayer.size
            if (gamesPlayed == 0) {
                return@map RatingPlayerStats(season.id, player)
            }
            val firstKilled = gamesForPlayer.filter { it.isFirstKilled(player) }.size
            val firstKilledCityLost =
                gamesForPlayer.filter { it.isFirstKilled(player) && !it.hasPlayerWon(player) }.size
            val fullGamesForRole = Role.entries.map { role ->
                Pair(role.sheetValue.last(), gamesForPlayer.getGamesForRole(player, role))
            }
            val gamesAsRed = fullGamesForRole
                .filter { it.first == Role.SHERIFF.sheetValue.last() || it.first == Role.CIVILIAN.sheetValue.last() }
                .sumOf { it.second.size }
            val winByRole = fullGamesForRole.map { gameForRole ->
                Pair(
                    gameForRole.first,
                    gameForRole.second.filter {
                        it.hasPlayerWon(player)
                    }.size
                )
            }
            val loseByRole = fullGamesForRole.map { gameForRole ->
                Pair(
                    gameForRole.first,
                    gameForRole.second.filter {
                        !it.hasPlayerWon(player)
                    }.size
                )
            }

            val additionalPointsByRole = fullGamesForRole.map {
                Pair(it.first, it.second.map {
                    it.getPlayerAdditionalPoints(player)
                }.sum())
            }
            val additionalPointsByRoleSum = additionalPointsByRole.map { it.second }.sum()

            val penaltyPointsByRole = fullGamesForRole.map {
                it.first to it.second.map { it.getPlayerPenaltyPoints(player) }.sum()
            }
            val penaltyPointsByRoleSum = penaltyPointsByRole.map { it.second }.sum()

            val bestMovePointsByRoleSum = gamesForPlayer
                .map {
                    if (it.isFirstKilled(player))
                        it.bestMovePoints
                    else 0.0f
                }.sum()
            val bestMoveAndAdditionalPointsByRole = fullGamesForRole.map {
                Pair(it.first, it.second.map {
                    it.getPlayerAdditionalPoints(player) + if (it.isFirstKilled(player)) {
                        it.bestMovePoints
                    } else {
                        0F
                    }
                }.sum())
            }
            val autoAdditionalPointsByRoleSum =
                gamesForPlayer.map { it.getPlayerAutoAdditionalPoints(player) }.sum()

            val wins = winByRole.sumOf { it.second }
            val winByRoleSum = winByRole.sumOf {
                calculateWinByRole(season.id, it.first, it.second)
            }
            val loseByRoleSum = loseByRole.sumOf {
                if (playerIsDonOrSheriff(it.first)) {
                    it.second
                } else {
                    0
                }
            }
            val gamesForRole = fullGamesForRole.map { it.first to it.second.size }
            val ciForGame =
                calculateCiForGame(firstKilledCityLost, firstKilled, gamesPlayed, season.id)
            val ci = ciForGame * firstKilledCityLost
            val percentOfDeath = firstKilled.toFloat() / gamesAsRed
            val winRate = wins.toFloat() / gamesPlayed
            val winPoints = calculateWinPoints(
                season.id,
                additionalPointsByRoleSum,
                bestMovePointsByRoleSum,
                penaltyPointsByRoleSum,
                ci,
                autoAdditionalPointsByRoleSum,
                winByRoleSum,
                loseByRoleSum
            )
            val mvp = calculateMvp(
                season.id,
                gamesPlayed,
                additionalPointsByRoleSum,
                bestMovePointsByRoleSum,
                penaltyPointsByRoleSum,
                winPoints
            )
            val ratingCoefficient = calculateRatingCoefficient(
                player = player,
                winPoints = winPoints,
                gamesPlayed = gamesPlayed,
                winRate = winRate,
                ci = ci,
                bestMovePointsByRoleSum = bestMovePointsByRoleSum,
                additionalPointsByRoleSum = additionalPointsByRoleSum,
                penaltyPointsByRoleSum = penaltyPointsByRoleSum,
                autoAdditionalPointByRoleSum = autoAdditionalPointsByRoleSum,
                season = season
            )
            RatingPlayerStats(
                seasonId = season.id,
                player = playersRepository.getDisplayName(player),
                ratingCoefficient = ratingCoefficient,
                wins = wins,
                gamesPlayed = gamesPlayed,
                winRate = winRate,
                additionalPoints = additionalPointsByRoleSum,
                penaltyPoints = penaltyPointsByRoleSum,
                bestMovePoints = bestMovePointsByRoleSum,
                firstKilled = firstKilled,
                firstKilledCityLost = firstKilledCityLost,
                percentOfDeath = percentOfDeath,
                ciForGame = ciForGame,
                ci = ci,
                mvp = mvp,
                winByRole = winByRole,
                gamesForRole = gamesForRole,
                bestMoveAndAdditionalPointsByRole = bestMoveAndAdditionalPointsByRole,
                penaltyPointsByRole = penaltyPointsByRole,
                seasonGameLimit = season.gameLimit
            )
        }
        ratingRepository.addRatings(season, ratings)

        val ratingPlayerStats = ratings
            .filter { it.gamesPlayed >= season.gameLimit }
            .sortedByDescending { it.ratingCoefficient }

        seasonRepository.addSeason(generateSeasonStats(ratingPlayerStats))
    }

    private fun calculateWinPoints(
        seasonId: Int,
        additionalPointsByRoleSum: Float,
        bestMovePointsByRoleSum: Float,
        penaltyPointsByRoleSum: Float,
        ci: Float,
        autoAdditionalPointsByRoleSum: Float,
        winByRoleSum: Int,
        loseByRoleSum: Int
    ) = when (seasonId) {
        in 0..1 -> winByRoleSum - loseByRoleSum + penaltyPointsByRoleSum + bestMovePointsByRoleSum
        in 2..3 -> winByRoleSum + additionalPointsByRoleSum + bestMovePointsByRoleSum + penaltyPointsByRoleSum
        in 4..16 -> winByRoleSum + additionalPointsByRoleSum + bestMovePointsByRoleSum
        else -> additionalPointsByRoleSum + autoAdditionalPointsByRoleSum + penaltyPointsByRoleSum + bestMovePointsByRoleSum + ci
    }

    private fun calculateMvp(
        seasonId: Int,
        gamesPlayed: Int,
        additionalPointsByRoleSum: Float,
        bestMovePointsByRoleSum: Float,
        penaltyPointsByRoleSum: Float,
        winPoints: Float
    ) = when (seasonId) {
        in 0..1 -> (winPoints / gamesPlayed).roundTo(3)
        else -> ((additionalPointsByRoleSum + bestMovePointsByRoleSum + penaltyPointsByRoleSum).toFloat() / gamesPlayed).roundTo(4)
    }

    private fun filterRawData(
        dataSeason: GamesDataSeason,
        seasonId: Int
    ) = when (seasonId) {
        in 0..16 -> dataSeason.a.toIntOrNull() != null
        else -> dataSeason.a != "" && dataSeason.c != ""
    }

    private fun calculateCiForGame(
        firstKilledCityLost: Int,
        firstKilled: Int,
        gamesPlayed: Int,
        seasonId: Int
    ): Float = when (seasonId) {
        in 0..16 -> 0F
        in 17..18 -> 0.1
        in 19..20 -> {
            val firstKilledToGamesPlayed = firstKilled.toFloat() / gamesPlayed
            if (firstKilledToGamesPlayed > 0.399) {
                0.4 * firstKilledCityLost
            } else {
                firstKilledToGamesPlayed * 5 / 2 * 0.4
            }
        }
        else -> {
            val firstKilledToGamesPlayed = firstKilled.toFloat() / gamesPlayed
            if (firstKilledToGamesPlayed > 0.399) {
                0.5
            } else {
                firstKilledToGamesPlayed * 1.25
            }
        }
    }.toFloat()


    private fun calculateRatingCoefficient(
        player: String,
        winPoints: Float,
        gamesPlayed: Int,
        winRate: Float,
        ci: Float = 0F,
        bestMovePointsByRoleSum: Float = 0F,
        additionalPointsByRoleSum: Float = 0F,
        penaltyPointsByRoleSum: Float = 0F,
        autoAdditionalPointByRoleSum: Float = 0F,
        season: Season
    ) = when (season.id) {
        in 0..1 -> (winPoints / gamesPlayed).roundTo(2) * 100 + gamesPlayed * season.gamesMultiplier
        in 2..3 -> winPoints / gamesPlayed + gamesPlayed * season.gamesMultiplier
        4 -> (winPoints / gamesPlayed + gamesPlayed * season.gamesMultiplier) * 100
        in 5..16 -> (((winPoints / gamesPlayed).roundTo(2) + gamesPlayed * (winRate * 100).roundTo(2) / 100 * season.gamesMultiplier)).roundTo(3) * 100
        // In season 17 there was 1 fake win to Железный, which gave him 2nd place instead of 3rd
        17 -> winRate * 100 + (winPoints / gamesPlayed) + ci + bestMovePointsByRoleSum + autoAdditionalPointByRoleSum + additionalPointsByRoleSum + if (player == "Железный") {
            1
        } else {
            0
        }
        in 18..20 -> {
            val gamesWithoutAutoPoints =
                gamesPlayed - (autoAdditionalPointByRoleSum / 0.3).roundToInt()
            winRate * 100 + (winPoints / gamesPlayed) + ci + bestMovePointsByRoleSum + additionalPointsByRoleSum - gamesWithoutAutoPoints * 0.3F
        }
        else -> winRate * 100 + (winPoints / gamesPlayed) + ci + bestMovePointsByRoleSum + additionalPointsByRoleSum + penaltyPointsByRoleSum
    }.roundTo(3)

    private fun calculateWinByRole(
        seasonId: Int,
        role: String,
        wins: Int
    ) = when (seasonId) {
        in 0..1 -> if (playerIsDonOrSheriff(role)) {
                wins * 4
            } else {
                wins * 3
            }
        in 2..3 -> wins * 2
        in 4..16 -> wins
        else -> 0
    }

    private fun playerIsDonOrSheriff(role: String) =
        Role.findByValue(role)?.sheetValue == Role.DON.sheetValue || Role.findByValue(
            role
        )?.sheetValue == Role.SHERIFF.sheetValue

    private fun getGamesDataSeason(seasonId: Int, rawData: List<GamesDataSeason>) =
        rawData.chunked(
            when (seasonId) {
                in 0..16 -> 10
                else -> 14
            }
        ).map { playersInfo ->
            when (seasonId) {
                in 0..1 -> {
                    val firstPlayer = playersInfo.first()
                    Game(
                        seasonId = seasonId,
                        players = playersInfo.map { it.b },
                        roles = playersInfo.map { it.c },
                        cityWon = if (Role.findByValue(firstPlayer.c)!!.isBlack) {
                            firstPlayer.d != Values.YES.sheetValue.first()
                        } else {
                            firstPlayer.d == Values.YES.sheetValue.first()
                        },
                        firstKilled = playersInfo.find { it.f == Values.YES.sheetValue.first() }?.a?.toInt()
                            ?: 0,
                        bestMovePoints = playersInfo.find { it.g.isNotEmpty() }?.g?.toFloat()
                            ?: 0.0F,
                        wonByPlayer = playersInfo.map { it.d },
                        penaltyPoints = playersInfo.map { if (it.e == Values.YES.sheetValue.first()) -1F else 0f },
                        bestMove = emptyList()
                    )
                }

                in 2..3 -> {
                    Game(
                        seasonId = seasonId,
                        players = playersInfo.map { it.g },
                        roles = playersInfo.map { it.h },
                        cityWon = getVictoryTeam(playersInfo[0].c),
                        firstKilled = playersInfo[1].c.toIntOrNull() ?: 0,
                        bestMovePoints = playersInfo[1].c.toIntOrNull()?.let { firstKilled ->
                            if (firstKilled == 0) {
                                0f
                            } else {
                                try {
                                    playersInfo.map { it.j }[firstKilled - 1].toFloat()
                                } catch (e: Exception) {
                                    0f
                                }
                            }
                        } ?: 0F,
                        penaltyPoints = playersInfo.map {
                            if (it.f.toIntOrNull() == 4)
                                -1F
                            else
                                0F
                        },
                        bestMove = listOf(
                            playersInfo[3].c.toIntOrNull() ?: 0,
                            playersInfo[3].d.toIntOrNull() ?: 0,
                            playersInfo[3].e.toIntOrNull() ?: 0,
                        ),
                        additionalPoints = playersInfo.map { it.i.toFloatOrNull() ?: 0F }
                    )
                }

                in 4..16 -> {
                    Game(
                        seasonId = seasonId,
                        players = playersInfo.map { it.g },
                        roles = playersInfo.map { it.h },
                        cityWon = getVictoryTeam(playersInfo[0].c),
                        firstKilled = playersInfo[1].c.toIntOrNull() ?: 0,
                        bestMovePoints = playersInfo[1].c.toIntOrNull()?.let { firstKilled ->
                            if (firstKilled == 0) {
                                0f
                            } else {
                                try {
                                    playersInfo.map { it.j }[firstKilled - 1].toFloat()
                                } catch (e: Exception) {
                                    0f
                                }
                            }
                        } ?: 0F,
                        bestMove = listOf(
                            playersInfo[3].c.toIntOrNull() ?: 0,
                            playersInfo[3].d.toIntOrNull() ?: 0,
                            playersInfo[3].e.toIntOrNull() ?: 0,
                        ),
                        additionalPoints = playersInfo.map { it.i.toFloatOrNull() ?: 0F }
                    )
                }

                else -> {
                    Game(
                        seasonId = seasonId,
                        players = playersInfo.subList(2, 12).map { it.b },
                        roles = playersInfo.subList(2, 12).map { it.c },
                        cityWon = getVictoryTeam(playersInfo.last().c),
                        firstKilled = playersInfo[12].b.toIntOrNull() ?: 0,
                        bestMovePoints = playersInfo[12].b.toIntOrNull()?.let { firstKilled ->
                            if (firstKilled == 0) {
                                0f
                            } else {
                                try {
                                    playersInfo.map { it.i }[firstKilled + 1].toFloat()
                                } catch (e: Exception) {
                                    0f
                                }
                            }
                        } ?: 0F,
                        bestMove = listOf(
                            playersInfo[12].d.toIntOrNull() ?: 0,
                            playersInfo[12].e.toIntOrNull() ?: 0,
                            playersInfo[12].f.toIntOrNull() ?: 0,
                        ),
                        additionalPoints = playersInfo.subList(2, 12)
                            .map { it.j.toFloatOrNull() ?: 0F },
                        autoAdditionalPoints = if (seasonId in 17..20) {
                            playersInfo.subList(2, 12)
                                .map { it.h.toFloatOrNull() ?: 0F }
                        } else {
                            null
                        },
                        penaltyPoints = if (seasonId !in 17..20) {
                            playersInfo.subList(2, 12)
                                .map { it.h.toFloatOrNull() ?: 0F }
                        } else {
                            null
                        }
                    )
                }
            }

        }

    private fun getVictoryTeam(string: String): Boolean? = when {
        Values.MAFIA_WON.sheetValue.contains(string) -> false
        Values.CITY_WON.sheetValue.contains(string) -> true
        else -> null
    }

    inline fun <reified T> parseJsonList(json: String): List<T> {
        return try {
            val type = object : TypeToken<List<T>>() {}.type
            Gson().fromJson(json, type)
        } catch (e: Exception) {
            emptyList()
        }
    }

//    private fun loadDataFromServer() {
//        viewModelScope.launch {
//            service.fetchData()
//        }
//    }

    companion object {
        const val TAG: String = "HomeViewModel"
    }
}

fun List<Game>.getGamesForRole(
    player: String,
    role: Role
) = filter {
    role.sheetValue.contains(it.getPlayerRole(player))
}

fun List<Game>.getPlayersList(
    seasonId: Int
) = flatMap {
    it.players
}.toSet().filter {
    when (seasonId) {
        // Рауль had excluded himself from the 0th season
        0 -> it != "Рауль"
        // Рауль and Остин had excluded themself from the 8th season
        8 -> it != "Рауль" && it != "Остин"
        // Рауль had excluded himself from the 9th season
        9 -> it != "Рауль"
        else -> true
    }
}
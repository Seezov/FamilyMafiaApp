package com.example.familymafiaapp.ui.home

import android.content.Context
import androidx.annotation.RawRes
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import com.example.familymafiaapp.R
import com.example.familymafiaapp.entities.RatingPlayerStats
import com.example.familymafiaapp.entities.SeasonStats
import com.example.familymafiaapp.enums.Role
import com.example.familymafiaapp.enums.Season
import com.example.familymafiaapp.extensions.roundTo
import com.example.familymafiaapp.extensions.roundTo2Digits

@Composable
fun HomeScreen(homeViewModel: HomeViewModel = hiltViewModel()) {
    val context = LocalContext.current
    val seasonStats by homeViewModel.seasonStats.collectAsState()
    val selectedSeason by homeViewModel.selectedSeason.collectAsState()
    val debugText by homeViewModel.debugText.collectAsState()

    LaunchedEffect(Unit) {
        val json = readJsonFromAssets(context, R.raw.players)
        homeViewModel.loadPlayers(json)
        Season.entries.forEach {
            val json = readJsonFromAssets(context, it.jsonFileRes)
            homeViewModel.loadDataBySeason(it, json)
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(8.dp)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .horizontalScroll(rememberScrollState())
                .padding(bottom = 8.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Season.entries.reversed().forEach { season ->
                Button(onClick = {
                    homeViewModel.displaySeason(season)
                }) {
                    Text(season.title)
                }
            }
        }

        if (debugText.isNotEmpty()) {
            Column(modifier = Modifier.verticalScroll(rememberScrollState())) {
                Text(debugText)
            }
        } else {
            selectedSeason?.let {
                Text(
                    text = it.title,
                    style = MaterialTheme.typography.titleMedium,
                    modifier = Modifier
                        .padding(vertical = 8.dp)
                        .align(Alignment.CenterHorizontally)
                )
            }
            if (seasonStats != null) {
                Column {
                    Box(
                        modifier = Modifier.fillMaxWidth(),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            "Season ${seasonStats!!.playerStats.first().seasonId}",
                            style = MaterialTheme.typography.titleLarge,
                        )
                    }
                    Spacer(Modifier.height(8.dp))
                    StatsView(seasonStats!!)
                    LazyColumn(
                        modifier = Modifier
                            .fillMaxSize()
                    ) {
                        val items = seasonStats!!.playerStats
                        items(items) { rating ->
                            PlayerStatsSeasonItem(rating)
                        }
                    }
                }
            } else {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .weight(1f),
                    contentAlignment = Alignment.Center
                ) {
                    Text("Select a season")
                }
            }
        }
    }

}

@Composable
fun StatsView(seasonStats: SeasonStats) {
    Column {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.Center
        ) {
            Text(
                text = "MVP: ${seasonStats.playerStats[seasonStats.mvpIndex].player}",
                style = MaterialTheme.typography.titleMedium,
            )
            Spacer(Modifier.width(16.dp))
            Text(
                text = "Most Killed: ${seasonStats.playerStats[seasonStats.mostKilledIndex].player}",
                style = MaterialTheme.typography.titleMedium,
            )
        }
        Spacer(Modifier.height(8.dp))
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.Center
        ) {
            Text(
                text = "Best Sheriff: ${seasonStats.playerStats[seasonStats.bestSheriffIndex].player}",
                style = MaterialTheme.typography.titleSmall,
            )
            Spacer(Modifier.width(8.dp))
            Text(
                text = "Best Don: ${seasonStats.playerStats[seasonStats.bestDonIndex].player}",
                style = MaterialTheme.typography.titleSmall,
            )
        }
        Spacer(Modifier.height(8.dp))
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.Center
        ) {
            Text(
                text = "Best Civilian: ${seasonStats.playerStats[seasonStats.bestCivilianIndex].player}",
                style = MaterialTheme.typography.titleSmall,
            )
            Spacer(Modifier.width(8.dp))
            Text(
                text = "Best Mafia: ${seasonStats.playerStats[seasonStats.bestMafiaIndex].player}",
                style = MaterialTheme.typography.titleSmall,
            )
        }
    }
}

@Composable
fun PlayerStatsSeasonItem(rating: RatingPlayerStats) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .padding(8.dp),
        elevation = CardDefaults.cardElevation(defaultElevation = 4.dp)
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Row {
                Text(rating.player, style = MaterialTheme.typography.titleLarge)
                Spacer(Modifier.width(16.dp))
                Text(
                    "${rating.ratingCoefficient}",
                    style = MaterialTheme.typography.titleMedium,
                    modifier = Modifier.align(Alignment.CenterVertically)
                )
            }

            Spacer(Modifier.height(8.dp))

            Text(
                "Wins: ${rating.wins}/${rating.gamesPlayed} games (${(rating.winRate * 100).roundTo(2)}% WR)",
                style = MaterialTheme.typography.bodySmall
            )
            Text(
                "Add. Points: ${rating.additionalPoints.roundTo(2)} | Penalty: ${rating.penaltyPoints.roundTo(2)}",
                style = MaterialTheme.typography.bodySmall
            )
            Text(
                "Best Move Points: ${rating.bestMovePoints.roundTo(2)}",
                style = MaterialTheme.typography.bodySmall
            )
            Text(
                "MVP: ${rating.mvp.roundTo(4)}",
                style = MaterialTheme.typography.bodySmall
            )
            Text(
                "First Killed: ${rating.firstKilled} (City Lost: ${rating.firstKilledCityLost})",
                style = MaterialTheme.typography.bodySmall
            )
            Text(
                "Death percentage: ${(rating.percentOfDeath * 100).roundTo(2)}%",
                style = MaterialTheme.typography.bodySmall
            )
            Text(
                "CI/Game: ${rating.ciForGame.roundTo(2)} | CI: ${rating.ci.roundTo(2)}",
                style = MaterialTheme.typography.bodySmall
            )


            Spacer(Modifier.height(8.dp))

            Role.entries.forEach { role ->
                val roleName = role.name.lowercase().replaceFirstChar { it.uppercaseChar() }
                val wins = rating.winByRole.find { role.sheetValue.contains(it.first) }?.second ?: 0
                val games =
                    rating.gamesForRole.find { role.sheetValue.contains(it.first) }?.second ?: 0
                val add =
                    rating.bestMoveAndAdditionalPointsByRole.find { role.sheetValue.contains(it.first) }?.second
                        ?: 0f
                val penalty =
                    rating.penaltyPointsByRole.find { role.sheetValue.contains(it.first) }?.second
                        ?: 0f
                val winRatePercent =
                    if (games > 0) (wins.toFloat() / games * 100).roundTo(2) else 0

                Text(
                    text = "$roleName: $wins/$games games, $winRatePercent% winrate, ${(add + penalty).roundTo(2)} Add. Points",
                    style = MaterialTheme.typography.bodySmall
                )
            }
        }
    }
}

fun readJsonFromAssets(context: Context, @RawRes resId: Int): String {
    return context.resources.openRawResource(resId).bufferedReader().use { it.readText() }
}

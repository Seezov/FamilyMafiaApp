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
import com.example.familymafiaapp.entities.RatingUniversal
import com.example.familymafiaapp.enums.Role
import com.example.familymafiaapp.enums.Season
import com.example.familymafiaapp.extensions.roundTo2Digits

@Composable
fun HomeScreen(homeViewModel: HomeViewModel = hiltViewModel()) {
    val context = LocalContext.current
    val ratings by homeViewModel.ratings.collectAsState()
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
            if (ratings.isNotEmpty()) {
                LazyColumn(
                    modifier = Modifier
                        .fillMaxSize()
                ) {
                    items(ratings) { rating ->
                        RatingItem(rating)
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
fun RatingItem(rating: RatingUniversal) {
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
                "Wins: ${rating.wins}/${rating.gamesPlayed} games (${(rating.winRate * 100).roundTo2Digits()}% WR)",
                style = MaterialTheme.typography.bodySmall
            )
            Text(
                "Add. Points: ${rating.additionalPoints.roundTo2Digits()} | Penalty: ${rating.penaltyPoints.roundTo2Digits()}",
                style = MaterialTheme.typography.bodySmall
            )
            Text(
                "Best Move Points: ${rating.bestMovePoints.roundTo2Digits()}",
                style = MaterialTheme.typography.bodySmall
            )
            Text(
                "MVP: ${rating.mvp.roundTo2Digits()}",
                style = MaterialTheme.typography.bodySmall
            )
            Text(
                "First Killed: ${rating.firstKilled} (City Lost: ${rating.firstKilledCityLost})",
                style = MaterialTheme.typography.bodySmall
            )
            Text(
                "Death percentage: ${(rating.percentOfDeath * 100).roundTo2Digits()}%",
                style = MaterialTheme.typography.bodySmall
            )
            Text(
                "CI/Game: ${rating.ciForGame.roundTo2Digits()} | CI: ${rating.ci.roundTo2Digits()}",
                style = MaterialTheme.typography.bodySmall
            )


            Spacer(Modifier.height(8.dp))

            Role.entries.forEach { role ->
                val roleName = role.name.lowercase().replaceFirstChar { it.uppercaseChar() }
                val wins = rating.winByRole.find { role.sheetValue.contains(it.first) }?.second ?: 0
                val games =
                    rating.gamesForRole.find { role.sheetValue.contains(it.first) }?.second ?: 0
                val add =
                    rating.additionalPointsByRole.find { role.sheetValue.contains(it.first) }?.second
                        ?: 0f
                val penalty =
                    rating.penaltyPointsByRole.find { role.sheetValue.contains(it.first) }?.second
                        ?: 0f
                val winRatePercent =
                    if (games > 0) (wins.toFloat() / games * 100).roundTo2Digits() else 0

                Text(
                    text = "$roleName: $wins/$games games, $winRatePercent% winrate, ${(add + penalty).roundTo2Digits()} Add. Points",
                    style = MaterialTheme.typography.bodySmall
                )
            }
        }
    }
}

fun readJsonFromAssets(context: Context, @RawRes resId: Int): String {
    return context.resources.openRawResource(resId).bufferedReader().use { it.readText() }
}

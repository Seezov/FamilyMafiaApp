package com.example.familymafiaapp.ui.hallOfFame

import android.widget.Toast
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
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
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
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import com.example.familymafiaapp.extensions.roundTo2Digits

@Composable
fun HallOfFameScreen(hallOfFameViewModel: HallOfFameViewModel = hiltViewModel()) {

    val debugText by hallOfFameViewModel.debugText.collectAsState()
    val ratings by hallOfFameViewModel.ratings.collectAsState()
    val playerOnSlot by hallOfFameViewModel.playerOnSlot.collectAsState()

    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        if (debugText.isNotEmpty()) {
            Column(modifier = Modifier.verticalScroll(rememberScrollState())) {
                Text(debugText)
                CopyToClipboardButton(debugText)
            }
        } else if (playerOnSlot.isNotEmpty()) {
            PlayerOnSlotStatsScreen(playerOnSlot)
        } else {
            PlayerStatsScreen(ratings)
        }
    }
}

@Composable
fun PlayerOnSlotStatsScreen(stats: List<Triple<String, Int, List<Pair<Int, Int>>>>) {
    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp)
    ) {
        itemsIndexed(stats) { index, player ->
            PlayerOnSlotStatsItem(index, player)
        }
    }
}

@Composable
fun PlayerOnSlotStatsItem(index: Int, player: Triple<String, Int, List<Pair<Int, Int>>>) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 4.dp),
        elevation = CardDefaults.cardElevation(4.dp)
    ) {
        Column {
            Row(
                modifier = Modifier
                    .padding(8.dp,8.dp,8.dp,0.dp),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Text(
                    text = (index + 1).toString(),
                    style = MaterialTheme.typography.titleMedium
                )
                Spacer(Modifier.width(8.dp))
                Text(
                    text = player.first,
                    style = MaterialTheme.typography.titleMedium
                )
                Spacer(Modifier.width(8.dp))
                Text(
                    text = "${player.second} games",
                    style = MaterialTheme.typography.bodyMedium
                )
            }
            Column (
                modifier = Modifier
                    .padding(8.dp, 2.dp, 0.dp, 8.dp),
                verticalArrangement = Arrangement.SpaceBetween
            ) {
                player.third.forEach { slot ->
                    Row {
                        Text(
                            text = "Slot ${slot.first + 1}",
                            style = MaterialTheme.typography.bodyMedium
                        )
                        Spacer(Modifier.width(8.dp))
                        Text(
                            text = "${slot.second}% WR",
                            style = MaterialTheme.typography.bodyMedium
                        )
//                        Spacer(Modifier.width(8.dp))
//                        Text(
//                            text = "${(slot.second.toFloat() / player.second * 100).roundTo2Digits()}%",
//                            style = MaterialTheme.typography.bodyMedium
//                        )
                    }
                }
            }
        }
    }
}

@Composable
fun PlayerStatsScreen(stats: List<Triple<String, Int, Float>>) {
    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp)
    ) {
        itemsIndexed(stats) { index, player ->
            PlayerStatsItem(index, player)
        }
    }
}

@Composable
fun PlayerStatsItem(index: Int, player: Triple<String, Int, Float>) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 4.dp),
        elevation = CardDefaults.cardElevation(4.dp)
    ) {
        Row(
            modifier = Modifier
                .padding(16.dp),
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Text(
                text = (index + 1).toString(),
                style = MaterialTheme.typography.titleMedium
            )
            Spacer(Modifier.width(8.dp))
            Text(
                text = player.first,
                style = MaterialTheme.typography.titleMedium
            )
            Spacer(Modifier.width(8.dp))
            Text(
                text = "М ${player.second} games",
                style = MaterialTheme.typography.bodyMedium
            )
            Spacer(Modifier.width(8.dp))
            Text(
                text = "- winstreak ${player.third.toInt()} games",
                style = MaterialTheme.typography.bodyMedium
            )
        }
    }
}

@Composable
fun CopyToClipboardButton(textToCopy: String) {
    val context = LocalContext.current
    val clipboardManager = LocalClipboardManager.current
    val toastMessage = "Copied to clipboard"

    Button(onClick = {
        clipboardManager.setText(AnnotatedString(textToCopy))
        Toast.makeText(context, toastMessage, Toast.LENGTH_SHORT).show()
    }) {
        Text("Copy")
    }
}

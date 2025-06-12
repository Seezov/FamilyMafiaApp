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
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import com.example.familymafiaapp.R
import com.example.familymafiaapp.entities.PlayerPlacements
import com.example.familymafiaapp.entities.SlotStats
import com.example.familymafiaapp.entities.Stats
import com.example.familymafiaapp.extensions.roundTo
import com.example.familymafiaapp.extensions.roundTo2Digits

@Composable
fun HallOfFameScreen(hallOfFameViewModel: HallOfFameViewModel = hiltViewModel()) {

    val debugText by hallOfFameViewModel.debugText.collectAsState()
    val ratings by hallOfFameViewModel.ratings.collectAsState()
    val playerPlacements by hallOfFameViewModel.playerPlacements.collectAsState()
    val playerOnSlot by hallOfFameViewModel.playerOnSlot.collectAsState()
    val stats by hallOfFameViewModel.stats.collectAsState()
    val slotStats by hallOfFameViewModel.slotStats.collectAsState()

    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        if (debugText.isNotEmpty()) {
            Column(modifier = Modifier.verticalScroll(rememberScrollState())) {
                Text(debugText)
                CopyToClipboardButton(debugText)
            }
        } else if (playerPlacements.isNotEmpty()) {
            PlayerPlacementsScreen(playerPlacements)
        } else if (stats.isNotEmpty()) {
            PlayerWholeStatsScreen(stats)
        } else if (slotStats.isNotEmpty()) {
            SlotStatsScreen(slotStats)
        } else if (playerOnSlot.isNotEmpty()) {
            PlayerOnSlotStatsScreen(playerOnSlot)
        } else {
            PlayerStatsScreen(ratings)
        }
    }
}

@Composable
fun PlayerPlacementsScreen(playerPlacements: List<PlayerPlacements>) {
    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp)
    ) {
        itemsIndexed(playerPlacements) { index, playerPlacement ->
            PlayerPlacementsItem(index, playerPlacement)
        }
    }
}

@Composable
fun PlayerPlacementsItem(index: Int, placement: PlayerPlacements) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 4.dp, horizontal = 8.dp),
        elevation = CardDefaults.cardElevation(4.dp)
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Text(
                    text = (index + 1).toString() + ") " + placement.player,
                    style = MaterialTheme.typography.titleLarge
                )
                Text(
                    text = "Total: ${placement.sumOfNominations()}",
                    style = MaterialTheme.typography.titleSmall,
                    modifier = Modifier.align(Alignment.CenterVertically)
                )
            }
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.Center) {
                Text(
                    text = "Seasons",
                    style = MaterialTheme.typography.titleSmall
                )
            }

            Spacer(Modifier.height(8.dp))

            PlacementRow(placement)

            Spacer(Modifier.height(12.dp))
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.Center) {
                Text(
                    text = "Nominations",
                    style = MaterialTheme.typography.titleSmall
                )
            }
            Spacer(Modifier.height(8.dp))
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.Center) {
                Icon(
                    painter = painterResource(id = R.drawable.ic_mvp),
                    contentDescription = "First place",
                    tint = Color.Unspecified,
                    modifier = Modifier.size(24.dp)
                )
                Spacer(modifier = Modifier.width(4.dp))
                Text(text = placement.mvp.toString(), modifier = Modifier.align(Alignment.CenterVertically))
            }
            PlacementRoles(placement)
        }
    }
}

@Composable
fun PlacementRow(placement: PlayerPlacements) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Row {
            Icon(
                painter = painterResource(id = R.drawable.ic_first_place),
                contentDescription = "First place",
                tint = Color.Unspecified,
                modifier = Modifier.size(24.dp)
            )
            Spacer(modifier = Modifier.width(4.dp))
            Text(text = placement.firsts.toString(), modifier = Modifier.align(Alignment.CenterVertically))
        }
        Row {
            Icon(
                painter = painterResource(id = R.drawable.ic_second_place),
                contentDescription = "Second place",
                tint = Color.Unspecified,
                modifier = Modifier.size(24.dp)
            )
            Spacer(modifier = Modifier.width(4.dp))
            Text(text = placement.seconds.toString(), modifier = Modifier.align(Alignment.CenterVertically))
        }
        Row {
            Icon(
                painter = painterResource(id = R.drawable.ic_third_place),
                contentDescription = "Third place",
                tint = Color.Unspecified,
                modifier = Modifier.size(24.dp)
            )
            Spacer(modifier = Modifier.width(4.dp))
            Text(text = placement.thirds.toString(), modifier = Modifier.align(Alignment.CenterVertically))
        }
    }
}

@Composable
fun PlacementRoles(placement: PlayerPlacements) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Row {
            Icon(
                painter = painterResource(id = R.drawable.ic_sheriff),
                contentDescription = "Best Sheriff",
                modifier = Modifier.size(24.dp),
                tint = Color.Unspecified  // keep original colors of vector drawable
            )
            Spacer(modifier = Modifier.width(4.dp))
            Text(text = placement.bestSheriff.toString(), modifier = Modifier.align(Alignment.CenterVertically))
        }
        Row {
            Icon(
                painter = painterResource(id = R.drawable.ic_don),
                contentDescription = "Best Don",
                modifier = Modifier.size(24.dp),
                tint = Color.Unspecified
            )
            Spacer(modifier = Modifier.width(4.dp))
            Text(text = placement.bestDon.toString(), modifier = Modifier.align(Alignment.CenterVertically))
        }
    }

    Spacer(Modifier.height(8.dp))

    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Row {
            Icon(
                painter = painterResource(id = R.drawable.ic_civilian),
                contentDescription = "Best Civilian",
                modifier = Modifier.size(24.dp),
                tint = Color.Unspecified
            )
            Spacer(modifier = Modifier.width(4.dp))
            Text(text = placement.bestCivilian.toString(), modifier = Modifier.align(Alignment.CenterVertically))
        }
        Row {
            Icon(
                painter = painterResource(id = R.drawable.ic_mafia),
                contentDescription = "Best Mafia",
                modifier = Modifier.size(24.dp),
                tint = Color.Unspecified
            )
            Spacer(modifier = Modifier.width(4.dp))
            Text(text = placement.bestMafia.toString(), modifier = Modifier.align(Alignment.CenterVertically))
        }
    }
}

@Composable
fun PlayerWholeStatsScreen(stats: List<Stats>) {
    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp)
    ) {
        itemsIndexed(stats) { index, player ->
            PlayerWholeStatsItem(index, player)
        }
    }
}

@Composable
fun PlayerWholeStatsItem(index: Int, player: Stats) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 4.dp),
        elevation = CardDefaults.cardElevation(4.dp)
    ) {
        Column {
            Row(
                modifier = Modifier
                    .padding(8.dp, 8.dp, 8.dp, 0.dp),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Text(
                    text = (index + 1).toString(),
                    style = MaterialTheme.typography.titleMedium
                )
                Spacer(Modifier.width(8.dp))
                Text(
                    text = player.playerName,
                    style = MaterialTheme.typography.titleMedium
                )
                Spacer(Modifier.width(8.dp))
                Text(
                    text = "${player.gamesPlayed} Total games",
                    style = MaterialTheme.typography.bodyMedium
                )
            }
            Column(
                modifier = Modifier
                    .padding(8.dp, 2.dp, 0.dp, 8.dp),
                verticalArrangement = Arrangement.SpaceBetween
            ) {
                Text(
                    text = "Stats for ${player.role} (${player.slotToWr.sumOf { it.third }} games)",
                    style = MaterialTheme.typography.bodyMedium
                )
                player.slotToWr.forEach { slot ->
                    Row {
                        Text(
                            text = "Slot ${slot.first + 1}",
                            style = MaterialTheme.typography.bodySmall
                        )
                        Spacer(Modifier.width(8.dp))
                        Text(
                            text = "${slot.second}/${slot.third}",
                            style = MaterialTheme.typography.bodySmall
                        )
                        Spacer(Modifier.width(8.dp))
                        val wr = if (slot.second > 0) {
                            slot.second.toFloat() / slot.third * 100
                        } else {
                            0F
                        }.roundTo(2)
                        Text(
                            text = "${wr}% WR",
                            style = MaterialTheme.typography.bodySmall
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
                    .padding(8.dp, 8.dp, 8.dp, 0.dp),
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
            Column(
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
fun SlotStatsScreen(stats: List<SlotStats>) {
    Column {
        Row {
            Spacer(Modifier.width(16.dp))
            Spacer(Modifier.width(16.dp))
            Text(
                text = "#",
                style = MaterialTheme.typography.titleMedium
            )
            Spacer(Modifier.width(16.dp))
            Spacer(Modifier.width(16.dp))
            Text(
                text = "S",
                style = MaterialTheme.typography.titleMedium
            )
            Spacer(Modifier.width(16.dp))
            Spacer(Modifier.width(16.dp))
            Text(
                text = "D",
                style = MaterialTheme.typography.titleMedium
            )
            Spacer(Modifier.width(16.dp))
            Spacer(Modifier.width(16.dp))
            Text(
                text = "C",
                style = MaterialTheme.typography.titleMedium
            )
            Spacer(Modifier.width(16.dp))
            Spacer(Modifier.width(16.dp))
            Text(
                text = "M",
                style = MaterialTheme.typography.titleMedium
            )
        }
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(16.dp)
        ) {
            itemsIndexed(stats) { index, player ->
                SlotStatsItem(index, player)
            }
        }
    }
}

@Composable
fun SlotStatsItem(index: Int, slotStats: SlotStats) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .padding(4.dp),
        elevation = CardDefaults.cardElevation(4.dp)
    ) {
        Row(modifier = Modifier.padding(8.dp)) {
            Text(
                text = "${slotStats.slot + 1}",
                style = MaterialTheme.typography.titleMedium
            )
            slotStats.roleWr.forEach { roleStats ->
                Spacer(Modifier.width(16.dp))
                Text(
                    text = roleStats.second.toString(),
                    style = MaterialTheme.typography.bodySmall
                )
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

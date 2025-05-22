package com.example.familymafiaapp.ui.home

import android.content.Context
import android.widget.Toast
import androidx.annotation.RawRes
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.Divider
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
import androidx.lifecycle.viewmodel.compose.viewModel
import com.example.familymafiaapp.R
import com.example.familymafiaapp.entities.Rating

@Composable
fun HomeScreen(homeViewModel: HomeViewModel) {
    val context = LocalContext.current
    val ratings by homeViewModel.ratings.collectAsState()

    // This block runs only once when the screen is first composed
    LaunchedEffect(Unit) {
        val json = readJsonFromAssets(context, R.raw.season0)
        homeViewModel.loadData(json)
    }

    LazyColumn(
        modifier = Modifier.fillMaxSize().padding(16.dp)
    ) {
        items(ratings) { rating ->
            RatingItem(rating)
        }
    }
}

@Composable
fun RatingItem(rating: Rating) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 8.dp)
    ) {
        Text("Player: ${rating.player}", style = MaterialTheme.typography.titleMedium)
        Text("Rating Coef: ${rating.ratingCoefficient}")
        Text("Win Points: ${rating.winPoints}")
        Text("Games Played: ${rating.gamesPlayed}")
        Text("First Killed: ${rating.firstKilled}")
        Text("MVP: ${rating.mvp}")
        rating.winByRole.forEach {
            Text("Won on ${it.first}: ${it.second}")
        }
        rating.additionalPointsByRole.forEach {
            Text("Add points on ${it.first}: ${it.second}")
        }
    }
    Divider()
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

fun readJsonFromAssets(context: Context, @RawRes resId: Int): String {
    return context.resources.openRawResource(resId).bufferedReader().use { it.readText() }
}

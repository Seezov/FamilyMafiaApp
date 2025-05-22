package com.example.familymafiaapp.ui.home

import android.content.Context
import androidx.annotation.RawRes
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.example.familymafiaapp.R

@Composable
fun HomeScreen(homeViewModel: HomeViewModel) {
    val context = LocalContext.current
    val text by homeViewModel.uiText.collectAsState()
    val scrollState = rememberScrollState()

    // This block runs only once when the screen is first composed
    LaunchedEffect(Unit) {
        val json = readJsonFromAssets(context, R.raw.season0)
        homeViewModel.loadData(json)
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(scrollState)
            .padding(16.dp) // add some padding if you want
    ) {
        Text(text)
    }
}

fun readJsonFromAssets(context: Context, @RawRes resId: Int): String {
    return context.resources.openRawResource(resId).bufferedReader().use { it.readText() }
}

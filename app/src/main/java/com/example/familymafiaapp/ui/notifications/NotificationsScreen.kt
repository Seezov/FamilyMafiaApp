package com.example.familymafiaapp.ui.notifications

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier

@Composable
fun NotificationsScreen(notificationsViewModel: NotificationsViewModel) {
    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Text("Notifications Screen")
    }
}
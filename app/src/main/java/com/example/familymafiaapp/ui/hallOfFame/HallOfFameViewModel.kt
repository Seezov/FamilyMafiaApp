package com.example.familymafiaapp.ui.hallOfFame

import androidx.lifecycle.LiveData
import androidx.lifecycle.MutableLiveData
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.familymafiaapp.entities.RatingUniversal
import com.example.familymafiaapp.enums.Season
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
) : ViewModel() {

    private val _ratings = MutableStateFlow<List<Pair<String,Int>>>(emptyList())
    val ratings: StateFlow<List<Pair<String,Int>>> = _ratings

    private val _debugText = MutableStateFlow<String>("")
    val debugText: StateFlow<String> = _debugText

    init {
        viewModelScope.launch {
            val ratings = ratingRepository.getAllRatings().groupBy { it.player }.map { it.key to it.value.sumOf { it.gamesPlayed } }
            val players = playersRepository.getAllPlayers()
            val gamesForPlayers = ratings.map { rating ->
                if (players.find { it.displayName == rating.first} != null) {
                    rating.first
                } else {
                    players.find { it.nicknames?.contains(rating.first) == true }?.displayName ?: rating.first
                } to rating.second
            }.sortedByDescending { it.second }
            _ratings.value = gamesForPlayers
        }
    }
}
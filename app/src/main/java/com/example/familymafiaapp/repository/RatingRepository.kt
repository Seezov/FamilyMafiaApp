package com.example.familymafiaapp.repository

import com.example.familymafiaapp.entities.RatingUniversal
import com.example.familymafiaapp.enums.Season
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class RatingRepository @Inject constructor()  {
    private val _localRatings = mutableListOf<Pair<Season, List<RatingUniversal>>>()
    val localRatings: List<Pair<Season, List<RatingUniversal>>>
        get() = _localRatings

    fun addRatings(season: Season, ratings: List<RatingUniversal>) {
        _localRatings.removeAll { it.first == season } // Avoid duplicates
        _localRatings.add(season to ratings)
    }

    fun getRatingsForSeason(season: Season): List<RatingUniversal> {
        return _localRatings.find { it.first == season }?.second ?: emptyList()
    }

    fun getAllRatings(): List<RatingUniversal> {
        return _localRatings.flatMap { it.second }
    }

    fun clearRatings() {
        _localRatings.clear()
    }
}
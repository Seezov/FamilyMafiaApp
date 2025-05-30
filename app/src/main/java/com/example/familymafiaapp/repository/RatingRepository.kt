package com.example.familymafiaapp.repository

import com.example.familymafiaapp.entities.RatingPlayerStats
import com.example.familymafiaapp.enums.Season
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class RatingRepository @Inject constructor()  {
    private val _localRatings = mutableListOf<Pair<Season, List<RatingPlayerStats>>>()
    val localRatings: List<Pair<Season, List<RatingPlayerStats>>>
        get() = _localRatings

    fun addRatings(season: Season, ratings: List<RatingPlayerStats>) {
        _localRatings.removeAll { it.first == season } // Avoid duplicates
        _localRatings.add(season to ratings)
    }

    fun getRatingsForSeason(season: Season): List<RatingPlayerStats> {
        return _localRatings.find { it.first == season }?.second ?: emptyList()
    }

    fun getAllRatings(): List<RatingPlayerStats> {
        return _localRatings.flatMap { it.second }
    }

    fun clearRatings() {
        _localRatings.clear()
    }
}
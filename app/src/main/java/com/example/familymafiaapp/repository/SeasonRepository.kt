package com.example.familymafiaapp.repository

import com.example.familymafiaapp.entities.SeasonStats
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class SeasonRepository @Inject constructor()  {
    private val _seasonStats = mutableListOf<SeasonStats>()
    val seasons: List<SeasonStats>
        get() = _seasonStats

    fun addSeason(season: SeasonStats) {
        _seasonStats.remove(season)
        _seasonStats.add(season)
    }

    fun addSeasons(seasons: List<SeasonStats>) {
        _seasonStats.removeAll(seasons)
        _seasonStats.addAll(seasons)
    }

    fun getSeason(id: Int): SeasonStats {
        return _seasonStats[id]
    }

    fun clearSeasons() {
        _seasonStats.clear()
    }
}
package com.example.familymafiaapp.ui.home

import android.content.Context
import androidx.lifecycle.LiveData
import androidx.lifecycle.MutableLiveData
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.familymafiaapp.entities.PlayerData
import com.example.familymafiaapp.network.GoogleSheetService
import com.google.gson.reflect.TypeToken
import com.google.gson.Gson
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

class HomeViewModel : ViewModel() {

    private val _uiText = MutableStateFlow("Hello from ViewModel!")
    val uiText: StateFlow<String> = _uiText

    val service = GoogleSheetService.create()

    fun loadData(fileContent: String) {
        if (fileContent.isNotEmpty()) {
            val playersData: List<PlayerData> = loadDataFromFile(fileContent)
            _uiText.value = playersData.toString()
        } else {
            loadDataFromServer()
        }
    }

    private fun loadDataFromFile(fileContent: String): List<PlayerData> = try {
            val listType = object : TypeToken<List<PlayerData>>() {}.type
            val players = Gson().fromJson<List<PlayerData>>(fileContent, listType)
             players
        } catch (e: Exception) {
            emptyList()
        }

    private fun loadDataFromServer() {
        viewModelScope.launch {
            _uiText.value = "Loading"
            _uiText.value = service.fetchData().toString()
        }
    }
}
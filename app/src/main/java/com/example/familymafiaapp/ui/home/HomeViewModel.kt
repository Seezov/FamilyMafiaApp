package com.example.familymafiaapp.ui.home

import androidx.lifecycle.LiveData
import androidx.lifecycle.MutableLiveData
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.familymafiaapp.network.GoogleSheetService
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

class HomeViewModel : ViewModel() {

    private val _uiText = MutableStateFlow("Hello from ViewModel!")
    val uiText: StateFlow<String> = _uiText

    val service = GoogleSheetService.create()

    init {
        viewModelScope.launch {
            updateText(service.fetchData().toString())
        }
    }

    fun updateText(newText: String) {
        _uiText.value = newText
    }
}
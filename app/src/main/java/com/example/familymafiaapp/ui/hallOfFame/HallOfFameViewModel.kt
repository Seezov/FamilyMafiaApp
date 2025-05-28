package com.example.familymafiaapp.ui.hallOfFame

import androidx.lifecycle.LiveData
import androidx.lifecycle.MutableLiveData
import androidx.lifecycle.ViewModel

class HallOfFameViewModel : ViewModel() {

    private val _text = MutableLiveData<String>().apply {
        value = "This is Hall Of Fame Fragment"
    }
    val text: LiveData<String> = _text


    init {
        
    }
}
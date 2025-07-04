package com.example.familymafiaapp.network

import com.example.familymafiaapp.entities.GamesDataSeason
import okhttp3.OkHttpClient
import retrofit2.Retrofit
import retrofit2.converter.gson.GsonConverterFactory
import retrofit2.http.GET
import java.util.concurrent.TimeUnit

interface  GoogleSheetService {

    @GET("exec")
    suspend fun fetchData(): List<GamesDataSeason>

    companion object {
        // Season 0 https://script.google.com/macros/s/AKfycbxObz_uchvy3h9L5w3lBCweU8rtiCqmLx_Xg2ofq9KTRYGvY_4JhD1Ucg1VacXwQYAj/exec
        private const val BASE_URL = "https://script.google.com/macros/s/AKfycbxObz_uchvy3h9L5w3lBCweU8rtiCqmLx_Xg2ofq9KTRYGvY_4JhD1Ucg1VacXwQYAj/"

        fun create(): GoogleSheetService {
            val okHttpClient = OkHttpClient.Builder()
                .connectTimeout(30, TimeUnit.SECONDS)
                .readTimeout(30, TimeUnit.SECONDS)
                .writeTimeout(30, TimeUnit.SECONDS)
                .build()

            return Retrofit.Builder()
                .baseUrl(BASE_URL)
                .client(okHttpClient)
                .addConverterFactory(GsonConverterFactory.create())
                .build()
                .create(GoogleSheetService::class.java)
        }
    }
}
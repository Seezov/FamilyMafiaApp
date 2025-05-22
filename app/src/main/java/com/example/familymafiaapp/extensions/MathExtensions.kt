package com.example.familymafiaapp.extensions

import java.math.BigDecimal
import java.math.RoundingMode

fun Float.roundTo2Digits(): Float =
    BigDecimal(this.toDouble()).setScale(2, RoundingMode.HALF_UP).toFloat()

fun Double.roundTo2Digits(): Double =
    BigDecimal(this).setScale(2, RoundingMode.HALF_UP).toDouble()
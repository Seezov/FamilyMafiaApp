package com.example.familymafiaapp.entities

data class YearStats(
    val player: String,
    val gamesPlayed: Int,
    val totalWr: Float,
    val civWr: Float,
    val mafWr: Float,
    val sherWr: Float,
    val donWr: Float,
    val firstKilled: Float
) {
    override fun toString(): String {
        return """
            📊 Stats for $player
            ----------------------------
            🎮 Games Played: $gamesPlayed
            🏆 Total WR:    ${"%.1f".format(totalWr)}%
            ----------------------------
            🏙️ Civilian WR: ${"%.1f".format(civWr)}%
            🕵️ Sheriff WR:  ${"%.1f".format(sherWr)}%
            🔪 Mafia WR:    ${"%.1f".format(mafWr)}%
            🕶️ Don WR:      ${"%.1f".format(donWr)}%
            ----------------------------
            💀 First Killed: ${"%.1f".format(firstKilled)}%
        """.trimIndent() + "\n" + "\n"
    }
}

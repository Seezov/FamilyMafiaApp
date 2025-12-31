package com.example.familymafiaapp.entities

data class YearStats(
    val player: String,
    val gamesPlayed: Int,
    val totalWr: Float,
    val civWr: Float,
    val mafWr: Float,
    val sherWr: Float,
    val donWr: Float,
    val firstKilled: Float,
    val averageAddPoints: Float,
    val averageAddPointsCiv: Float,
    val averageAddPointsMaf: Float,
    val averageAddPointsSher: Float,
    val averageAddPointsDon: Float,
) {
    override fun toString(): String {
        return """
            📊 Stats for $player
            ----------------------------
            🎮 Games Played: $gamesPlayed
            🏆 Total WR:    ${"%.1f".format(totalWr)}%
            ⚡ Average AP:   ${"%.2f".format(averageAddPoints)}
            ----------------------------
            🏙️ Civilian WR: ${"%.1f".format(civWr)}%
            ⚡ Average AP:   ${"%.2f".format(averageAddPointsCiv)}
            
            🕵️ Sheriff WR:  ${"%.1f".format(sherWr)}%
            ⚡ Average AP:   ${"%.2f".format(averageAddPointsSher)}
            
            🔪 Mafia WR:    ${"%.1f".format(mafWr)}%
            ⚡ Average AP:   ${"%.2f".format(averageAddPointsMaf)}
            
            🕶️ Don WR:      ${"%.1f".format(donWr)}%
            ⚡ Average AP:   ${"%.2f".format(averageAddPointsDon)}
            
            ----------------------------
            💀 First Killed: ${"%.1f".format(firstKilled)}%
        """.trimIndent() + "\n" + "\n"
    }
}

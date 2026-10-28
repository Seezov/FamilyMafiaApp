// /players/ «Season games» / «+ Tournaments»: season games plus federation tournament games
// (data/federation_games.json). Only players with federation games are listed; the others show the same values.
export interface ScopeStats { games: number; wins: number; tGames: number; tWins: number }

export function scopeStats(
  players: { slug: string; games: number; winRate: number }[],
  fed: Record<string, { games: number; wins: number }>,
): Record<string, ScopeStats> {
  const out: Record<string, ScopeStats> = {};
  for (const p of players) {
    const f = fed[p.slug];
    if (!f?.games) continue;
    const wins = Math.round(p.winRate * p.games);
    out[p.slug] = { games: p.games, wins, tGames: p.games + f.games, tWins: wins + f.wins };
  }
  return out;
}

export function shown(s: ScopeStats, tournaments: boolean): { games: number; wr: number } {
  const [games, wins] = tournaments ? [s.tGames, s.tWins] : [s.games, s.wins];
  return { games, wr: games ? wins / games : 0 };
}

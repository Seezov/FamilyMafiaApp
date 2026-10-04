export interface SiteColumn { label: string; numeric: boolean; tip?: string; group?: string; phone?: boolean }
export interface SiteCell { t: string; s?: number; link?: string; tone?: 'wr' | 'pos' | 'neg' }
export interface SiteTable {
  title?: string; empty?: string; columns: SiteColumn[]; rows: SiteCell[][];
  sortColumn?: number; desc: boolean; showRank: boolean; collapsed?: number;
}

export type RoleKey = 'civilian' | 'sheriff' | 'mafia' | 'don';

export interface IndexData {
  seasons: { id: number; title: string }[];
  latestSeasonId: number;
  club: { seasons: number; games: number; players: number; cityWR: number };
  roleWR: Record<RoleKey, number>;
  leaderboardNote: string;
  leaderboards: { role: RoleKey; label: string; table: SiteTable }[];
  protocol: SiteTable;
  seasonsTable: SiteTable;
}

export interface StatItem { label: string; winner: string; table?: SiteTable }
export interface Award { key: string; label: string; winner: string; winnerLink?: string; table: SiteTable }
export interface LeagueData { ratings: SiteTable; stats: StatItem[]; awards?: Award[] }
export interface SeasonData {
  id: number; title: string; gameLimit: number; smallLeagueMinGames: number;
  summary: { games: number; players: number; cityWR: number; mafiaWR: number } | null;
  leagueCounts: { main: number; small: number } | null;
  tournaments: { type: string; label: string; name: string; games: number; date: string | null; podium: string[] }[];
  tournamentCounts: { type: string; label: string; count: number }[];
  leagues: { main: LeagueData; small: LeagueData };
}

export interface PlayerSummary {
  id: number; slug: string; name: string; initials: string;
  games: number; winRate: number; seasons: number; latestRating: number | null;
}
export interface PlayersData { players: PlayerSummary[]; table: SiteTable }
export interface PlayerData extends PlayerSummary {
  accomplishments: {
    total: number; main: number[]; small: number[];
    groups: { title: string; cards: AwardCard[] }[];
    awards: Record<'mvp' | 'sheriff' | 'don' | 'civilian' | 'mafia' | 'killed', number>;
    tournaments: { type: string; label: string; podiums: number; places: number[] }[];
  };
  timeline: { seasonId: number; title: string; games: number; league: 'main' | 'small' | 'below' | 'none' }[];
  roles: { role: RoleKey; label: string; games: number; wins: number; share: number; top: string | null }[];
  firstKill: { total: number; cityLost: number; civSherGames: number };
  bestMoves: { firstKilled: number; zero: number; one: number; two: number; three: number };
}

export type FilterName = 'role' | 'scope' | 'period' | 'league';
export interface RecordCategory { slug: string; label: string; filters: FilterName[]; group?: string }
export interface RecordsData {
  categories: RecordCategory[];
  roles: { key: string; label: string }[];
  scopes: { key: string; label: string }[];
  periods: { key: string; label: string }[];
  leagues: { key: string; label: string }[];
  defaults: Record<FilterName, string>;
  tables: Record<string, { scope: string; table: SiteTable }>;
}

export interface TournamentsData {
  totals: { tournaments: number; games: number };
  types: { type: string; label: string; count: number; games: number }[];
  winners: SiteTable;
  bySeason: SiteTable;
  seasons: {
    id: number; title: string;
    events: { type: string; label: string; name: string; games: number; date: string | null; unconfirmed?: boolean; podium: SiteCell[] }[];
  }[];
}

export interface AwardCard {
  label: string; icon: 'trophy' | 'star' | 'sheriff' | 'civilian' | 'mafia' | 'don' | 'killed' | 'medal';
  tone: string; kind?: string; kindType?: string; count: number; where: string[];
}

export interface DebugEvidence {
  games: number; dates: string[]; hosts: Record<string, number>;
  standings: (SiteCell & { pts: number; w: number; g: number })[];
}
export interface DebugData {
  repo: { owner: string; name: string; branch: string; files: string[] };
  types: { type: string; label: string }[];
  tournaments: {
    key: string; season: number; type: string; name: string; games: number; date: string | null;
    podium: string[]; status: 'sheet' | 'detected' | 'confirmed'; evidence: DebugEvidence | null;
    podiumMatches: boolean | null;
  }[];
  candidates: {
    id: string; season: number; evidence: DebugEvidence;
    suggested: { type: string; name: string; games: number; date: string | null; podium: string[] };
  }[];
}

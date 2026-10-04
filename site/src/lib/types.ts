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
    awards: Record<'mvp' | 'sheriff' | 'don' | 'civilian' | 'mafia', number>;
    tournaments: { type: string; label: string; podiums: number; places: number[] }[];
  };
  timeline: { seasonId: number; title: string; games: number; league: 'main' | 'small' | 'below' | 'none' }[];
  roles: { role: RoleKey; label: string; games: number; wins: number; share: number; top: string | null }[];
  firstKill: { total: number; cityLost: number; civSherGames: number };
  bestMoves: { firstKilled: number; zero: number; one: number; two: number; three: number };
}

export type FilterName = 'role' | 'scope' | 'period';
export interface RecordCategory { slug: string; label: string; filters: FilterName[] }
export interface RecordsData {
  categories: RecordCategory[];
  roles: { key: string; label: string }[];
  scopes: { key: string; label: string }[];
  periods: { key: string; label: string }[];
  defaults: Record<FilterName, string>;
  tables: Record<string, { scope: string; table: SiteTable }>;
}

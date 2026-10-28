// Federation tournament games (scripts/fetch-federation-games.ts) folded into the club's player stats:
// attribution through confirmed links, club / cross-federation duplicates, possible duplicates for review. Pure.
import type { Fed } from './core';

export type FedRole = 'citizen' | 'sheriff' | 'mafia' | 'don';
export interface FedSeat { seat: number; nick: string; fedPlayerId?: string; role: FedRole }
export interface FedGame { key: string; round?: string; table?: number; result: 'city' | 'mafia'; seats: FedSeat[] }
/** Dates are YYYY-MM-DD. alsoOn: the same tournament published on another federation. */
export interface FedTournament {
  fed: Fed; tournamentId: string; name: string; dateFrom: string; dateTo: string;
  online?: boolean; alsoOn?: { fed: Fed; id: string }; games: FedGame[];
}
export interface TournamentRef { fed: Fed; tournamentId: string; date?: string }

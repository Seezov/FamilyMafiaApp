import fs from 'node:fs';
import path from 'node:path';
import type { AllstarsData, AnnualData, DebugData, GamesData, IndexData, PlayerData, PlayersData, RecordsData, SeasonData, TournamentsData, UnresolvedData } from './types';
import type { CandidatesFile } from './federations/core';
import type { FedGamesFile } from './federations/games';

// Written by `flutter test tool/export_site_data_test.dart` (repo root).
const dir = process.env.SITE_DATA_DIR ?? path.resolve(process.cwd(), 'data');

function read<T>(rel: string): T {
  const file = path.join(dir, rel);
  if (!fs.existsSync(file)) {
    throw new Error(`Missing ${file}. Run the export first: flutter test tool/export_site_data_test.dart`);
  }
  return JSON.parse(fs.readFileSync(file, 'utf8')) as T;
}

export const loadIndex = () => read<IndexData>('index.json');
export const loadSeason = (id: number) => read<SeasonData>(`season/${id}.json`);
export const loadPlayers = () => read<PlayersData>('players.json');
export const loadUnresolved = () => read<UnresolvedData>('unresolved.json');
export const loadPlayer = (slug: string) => read<PlayerData>(`player/${slug}.json`);
export const loadRecords = () => read<RecordsData>('records.json');
export const loadTournaments = () => read<TournamentsData>('tournaments.json');
export const loadAnnual = () => read<AnnualData>('annual.json');
export const loadAllstars = () => read<AllstarsData>('allstars.json');
export const loadDebug = () => read<DebugData>('debug.json');
export const loadGames = (id: number) => read<GamesData>(`games/${id}.json`);

// Committed output of scripts/find-federation-players.ts (repo root assets/raw/); empty until its first run.
export function loadFederationCandidates(): CandidatesFile {
  const file = path.resolve(process.cwd(), '..', 'assets', 'raw', 'federation_candidates.json');
  return fs.existsSync(file) ? JSON.parse(fs.readFileSync(file, 'utf8')) as CandidatesFile : { generatedAt: '', players: {}, unmatched: [] };
}

// Written by scripts/federation-games.ts before astro build; missing in a bare `astro dev` → no federation games.
export function loadFederationGames(): FedGamesFile {
  const file = path.join(dir, 'federation_games.json');
  return fs.existsSync(file)
    ? JSON.parse(fs.readFileSync(file, 'utf8')) as FedGamesFile
    : { generatedAt: '', players: {}, review: [], counts: { tournaments: 0, games: 0, clubDuplicates: 0, crossFedDuplicates: 0, possible: 0, counted: 0 } };
}

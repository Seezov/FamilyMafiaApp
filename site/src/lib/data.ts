import fs from 'node:fs';
import path from 'node:path';
import type { IndexData, PlayerData, PlayersData, RecordsData, SeasonData } from './types';

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
export const loadPlayer = (slug: string) => read<PlayerData>(`player/${slug}.json`);
export const loadRecords = () => read<RecordsData>('records.json');

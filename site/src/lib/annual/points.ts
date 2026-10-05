// The annual rating's points per result — a port of lib/services/stats/annual_rating.dart.
// Both are checked against test/fixtures/annual_points_cases.json.
export type EventKind = 'tournament' | 'series' | 'marathon' | 'season';

const SEASON: Record<number, number> = { 1: 18, 2: 15, 3: 12, 4: 9, 5: 6, 101: 5, 102: 4, 103: 3, 104: 2, 105: 1 };
const SERIES: Record<number, number> = { 1: 10, 2: 8, 3: 6, 4: 4, 5: 3, 6: 2, 7: 2 };
const MARATHON: Record<number, number> = { 1: 6, 2: 4, 3: 3, 4: 2, 5: 2 };

export function eventPoints(kind: EventKind, place: number, stars?: number | null, participants?: number | null): number {
  switch (kind) {
    case 'season': return SEASON[place] ?? (place > 10 ? 2 : place > 5 ? 4 : 0);
    case 'series': return SERIES[place] ?? 1;
    case 'marathon': return MARATHON[place] ?? 1;
    case 'tournament': {
      const b = 1 + (stars ?? 0) / 3;
      const n = participants ?? 0;
      if (place < 1) return 0;
      if (place < 11) return b + ((n - place) * b) / 4;
      if (place < n / 2) return b + ((n - place) * b) / 5;
      return b + ((n - place) * b) / 10;
    }
  }
}

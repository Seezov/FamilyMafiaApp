import type { GamesData } from './types';

export interface Attendee { key: string; name: string; slug?: string; games: number }
export interface AttendanceDay { date: string | null; games: number; hosts: string[]; labels: string[]; players: Attendee[] }
export interface AttendanceTotal { key: string; name: string; slug?: string; days: number; games: number }

const byGames = <T extends { games: number; name: string }>(a: T, b: T) =>
  b.games - a.games || a.name.toLowerCase().localeCompare(b.name.toLowerCase());

/** Who played on each game day and how many games, newest day first (undated
 * games last), plus season totals. Every game counts, rated or not. */
export function attendance(data: GamesData): { days: AttendanceDay[]; totals: AttendanceTotal[] } {
  const names = new Map(data.players.map((p) => [p.key, p.name]));
  const totals = new Map<string, AttendanceTotal>();
  const days: AttendanceDay[] = data.days.map((d) => {
    const players = new Map<string, Attendee>();
    for (const g of d.games) {
      for (const s of g.seats) {
        if (!s.key) continue;
        const a = players.get(s.key) ?? { key: s.key, name: names.get(s.key) ?? s.player ?? s.key, slug: s.slug, games: 0 };
        a.games++;
        players.set(s.key, a);
      }
    }
    for (const a of players.values()) {
      const t = totals.get(a.key) ?? { key: a.key, name: a.name, slug: a.slug, days: 0, games: 0 };
      t.days++;
      t.games += a.games;
      totals.set(a.key, t);
    }
    const uniq = (xs: (string | undefined)[]) => [...new Set(xs.filter((x): x is string => !!x))];
    return {
      date: d.date,
      games: d.games.length,
      hosts: uniq(d.games.map((g) => g.host)),
      labels: uniq(d.games.map((g) => g.label)),
      players: [...players.values()].sort(byGames),
    };
  });
  days.sort((a, b) => (a.date === null ? 1 : b.date === null ? -1 : b.date.localeCompare(a.date)));
  return { days, totals: [...totals.values()].sort(byGames) };
}

/** Plain-text list for pasting into a chat. */
export const attendanceText = (title: string, players: Attendee[]) =>
  [title, ...players.map((p) => `${p.name} — ${p.games}`)].join('\n');

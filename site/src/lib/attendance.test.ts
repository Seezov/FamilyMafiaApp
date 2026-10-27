import { describe, expect, it } from 'vitest';
import { attendance, attendanceText } from './attendance';
import type { GameEntry, GamesData } from './types';

const game = (id: string, keys: string[], extra: Partial<GameEntry> = {}): GameEntry => ({
  id, n: 1, result: 'city',
  seats: keys.map((k, i) => (k ? { n: i + 1, role: 'civilian', key: k, player: k, slug: k === 'Гість' ? undefined : k } : { n: i + 1, role: 'civilian' })),
  ...extra,
});

const data: GamesData = {
  season: 31, autoLabel: 'ОП', hosts: [],
  players: [{ name: 'Seezov', key: 'seezov' }, { name: 'Німфа', key: 'nimfa' }, { name: 'Гість', key: 'Гість' }],
  days: [
    { date: '2026-10-20', games: [game('a', ['seezov', 'nimfa'], { host: 'Шпак' }), game('b', ['seezov', 'Гість', ''], { host: 'Шпак', result: 'unrated' })] },
    { date: null, games: [game('c', ['nimfa'])] },
    { date: '2026-10-22', games: [game('d', ['nimfa'], { host: 'Луна', label: 'Мінікап' })] },
  ],
};

describe('attendance', () => {
  const { days, totals } = attendance(data);
  it('orders days newest first, undated last', () => {
    expect(days.map((d) => d.date)).toEqual(['2026-10-22', '2026-10-20', null]);
  });
  it('counts every game a player sat in, rated or not, skipping empty seats', () => {
    expect(days[1].players).toEqual([
      { key: 'seezov', name: 'Seezov', slug: 'seezov', games: 2 },
      { key: 'Гість', name: 'Гість', slug: undefined, games: 1 },
      { key: 'nimfa', name: 'Німфа', slug: 'nimfa', games: 1 },
    ]);
    expect(days[1]).toMatchObject({ games: 2, hosts: ['Шпак'], labels: [] });
    expect(days[0].labels).toEqual(['Мінікап']);
  });
  it('sums days and games per player', () => {
    expect(totals.map((t) => [t.name, t.days, t.games])).toEqual([['Німфа', 3, 3], ['Seezov', 1, 2], ['Гість', 1, 1]]);
  });
  it('formats a pasteable list', () => {
    expect(attendanceText('Tue', days[1].players)).toBe('Tue\nSeezov — 2\nГість — 1\nНімфа — 1');
  });
});

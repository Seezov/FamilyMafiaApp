import { describe, expect, it } from 'vitest';
import { tableGroups, dayLabel, filtersToSearch, fmtPts, gameIdFromHash, initialView, matchesFilters, parseFilters } from './games';

describe('filters', () => {
  it('round-trips through the query string', () => {
    const f = parseFilters('?player=seezov&host=%D0%A8%D0%BF%D0%B0%D0%BA');
    expect(f).toEqual({ player: 'seezov', host: 'Шпак' });
    expect(parseFilters(filtersToSearch(f))).toEqual(f);
    expect(filtersToSearch({ player: null, host: null })).toBe('');
  });
  it('matches by slug, by host, by both', () => {
    expect(matchesFilters(['seezov', 'nimfa'], 'Шпак', { player: 'seezov', host: null })).toBe(true);
    expect(matchesFilters(['seezov'], 'Шпак', { player: null, host: 'Rathma' })).toBe(false);
    expect(matchesFilters(['seezov'], undefined, { player: null, host: null })).toBe(true);
  });
  it('matches by name when the player has no slug', () => {
    expect(matchesFilters(['Гість Петро'], 'Шпак', { player: 'Гість Петро', host: null })).toBe(true);
  });
});

describe('deep links', () => {
  it('reads a game id from the hash', () => {
    expect(gameIdFromHash('#g-2026-09-01-1-3')).toBe('g-2026-09-01-1-3');
    expect(gameIdFromHash('#g-x-0')).toBe('g-x-0');
    expect(gameIdFromHash('#top')).toBeNull();
    expect(gameIdFromHash('')).toBeNull();
    expect(gameIdFromHash('#g-%E0%A4%A')).toBeNull();
  });
  it('initialView clears filters that hide the target', () => {
    const f = { player: 'seezov', host: null };
    expect(initialView('#g-x-0', f, () => false)).toEqual({ open: 'g-x-0', filters: { player: null, host: null } });
    expect(initialView('#g-x-0', f, () => true)).toEqual({ open: 'g-x-0', filters: f });
    expect(initialView('', f, () => false)).toEqual({ open: null, filters: f });
  });
});

describe('format', () => {
  it('drops trailing zeros and uses a real minus', () => {
    expect(fmtPts(0.3)).toBe('0.3');
    expect(fmtPts(1)).toBe('1');
    expect(fmtPts(-0.5)).toBe('−0.5');
    expect(fmtPts(1.25)).toBe('1.25');
    expect(fmtPts(undefined)).toBe('');
  });
  it('labels a day', () => {
    expect(dayLabel('2026-09-01')).toBe('Tue, 1 Sep 2026');
    expect(dayLabel(null)).toBe('No date');
  });
});

type G = { n?: number; table?: number };

describe('tableGroups', () => {
  it('has no heading for a single group', () => {
    expect(tableGroups<G>([{ n: 1 }, { n: 2 }]).map((g) => g.table)).toEqual([null]);
    expect(tableGroups([{ table: 2 }]).map((g) => g.table)).toEqual([null]);
  });
  it('labels unknown tables as Table 1 when the day has several tables', () => {
    const g = tableGroups<G>([{ n: 1 }, { n: 2, table: 2 }, { n: 3 }]);
    expect(g.map((x) => x.table)).toEqual([1, 2]);
    expect(g[0].games.map((x) => x.n)).toEqual([1, 3]);
  });
  it('merges unknown and real table 1 in sheet order', () => {
    const g = tableGroups([{ n: 1, table: 1 }, { n: 2, table: 2 }, { n: 3 }, { n: 4, table: 1 }]);
    expect(g.map((x) => x.table)).toEqual([1, 2]);
    expect(g[0].games.map((x) => x.n)).toEqual([1, 3, 4]);
  });
});

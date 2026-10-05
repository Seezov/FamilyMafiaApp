import fs from 'node:fs';
import { describe, expect, it } from 'vitest';
import { hostDefaultSeason, nextSeason, seasonErrors, toSeasons, type ClubSeason } from './seasons';

const cases = JSON.parse(fs.readFileSync(new URL('../../../../test/fixtures/club_season_cases.json', import.meta.url), 'utf8')) as
  { case: string; lastJsonId: number; seasons: ClubSeason[]; valid: boolean }[];
const S = (id: number, startDate: string, min = 15): ClubSeason => ({ id, title: `Season ${id}`, smallLeagueMinGames: min, startDate });

describe('seasonErrors', () => {
  it('matches every shared case (same fixture as the Dart test)', () => {
    for (const c of cases) expect(seasonErrors(c.seasons, c.lastJsonId).length === 0, c.case).toBe(c.valid);
  });
  it('more than 100 is invalid', () => {
    expect(seasonErrors(Array.from({ length: 101 }, (_, i) => S(32 + i, '2026-12-01')), 31)).not.toEqual([]);
  });
});

describe('nextSeason', () => {
  it('the first club season follows the JSON and copies its minimum', () => {
    expect(nextSeason([], 31, 15, '2026-11-20')).toEqual(S(32, '2026-11-20'));
  });
  it('later seasons follow the list and copy the previous minimum', () => {
    expect(nextSeason([S(32, '2026-12-01', 12)], 31, 15, '2027-03-01')).toEqual(S(33, '2027-03-01', 12));
  });
});

describe('hostDefaultSeason', () => {
  const list = [S(32, '2026-12-01'), S(33, '2027-03-01')];
  it('the newest season that has started', () => {
    expect(hostDefaultSeason(list, '2027-01-15', 31)).toBe(32);
    expect(hostDefaultSeason(list, '2027-03-01', 31)).toBe(33);
  });
  it('before any start date: the fallback', () => {
    expect(hostDefaultSeason(list, '2026-11-30', 31)).toBe(31);
    expect(hostDefaultSeason([], '2026-11-30', null)).toBeNull();
  });
});

describe('toSeasons', () => {
  it('reads Firestore data and drops malformed entries', () => {
    expect(toSeasons([S(32, '2026-12-01'), { id: '33' }, null])).toEqual([S(32, '2026-12-01')]);
    expect(toSeasons(undefined)).toEqual([]);
  });
});

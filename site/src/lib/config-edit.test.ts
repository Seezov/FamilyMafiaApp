import { describe, expect, it } from 'vitest';
import { applyOps, entryKey, clubBody, startDay, type ConfigEntry, type SeasonConfigFile } from './config-edit';


const e = (season: number, name: string, date?: string): ConfigEntry =>
  ({ season, type: 'minicap', name, games: 4, ...(date ? { date } : {}), podium: ['A', 'B', 'C'] });
const file = (): SeasonConfigFile => ({
  configVersion: 1,
  tournaments: [e(19, 'Big Fish', '12.09.2023'), e(19, 'Undated'), e(20, 'Мінікап 16.12.2023', '16–17.12.2023')],
});

describe('applyOps', () => {
  it('adds in date order within the season', () => {
    const out = applyOps(file(), [{ kind: 'add', id: 'x', entry: e(19, 'Мінікап 10.10.2023', '10.10.2023') }]);
    expect(out.tournaments!.map((t) => t.name)).toEqual(['Big Fish', 'Undated', 'Мінікап 10.10.2023', 'Мінікап 16.12.2023']);
    const early = applyOps(file(), [{ kind: 'add', id: 'y', entry: e(20, 'Early', '01.12.2023') }]);
    expect(early.tournaments!.map((t) => t.name)).toEqual(['Big Fish', 'Undated', 'Early', 'Мінікап 16.12.2023']);
  });

  it('confirms, edits, deletes and rejects', () => {
    const out = applyOps(file(), [
      { kind: 'confirm', key: '19|Big Fish' },
      { kind: 'edit', key: '19|Undated', entry: { ...e(19, ' Renamed ', '03.10.2023'), podium: ['X', ' ', 'Y'] } },
      { kind: 'delete', key: entryKey(e(20, 'Мінікап 16.12.2023')) },
      { kind: 'reject', id: 'S7-2020-11-17-x-4' },
      { kind: 'reject', id: 'S7-2020-11-17-x-4' },
    ]);
    expect(out.tournaments).toEqual([
      { ...e(19, 'Big Fish', '12.09.2023'), status: 'confirmed' },
      { season: 19, type: 'minicap', name: 'Renamed', games: 4, date: '03.10.2023', podium: ['X', 'Y'] },
    ]);
    expect(Object.keys(out.tournaments![0])).toEqual(['season', 'type', 'name', 'games', 'date', 'status', 'podium']);
    expect(out.rejectedCandidates).toEqual(['S7-2020-11-17-x-4']);
  });

  it('refuses to touch an entry that is gone', () => {
    expect(() => applyOps(file(), [{ kind: 'delete', key: '19|Nope' }])).toThrow(/no longer in the config/);
  });
});

it('startDay reads every date shape the config uses', () => {
  expect(startDay('16.12.2023')).toBe(Date.UTC(2023, 11, 16));
  expect(startDay('31.03–02.04.2024')).toBe(Date.UTC(2024, 2, 31));
  expect(startDay('16–17.12.2023')).toBe(Date.UTC(2023, 11, 16));
  expect(startDay('10.10')).toBeNull();
});

describe('clubBody', () => {
  it('normalizes entries and keeps order, rejected and limits', () => {
    const f: SeasonConfigFile = {
      tournaments: [
        { season: 30, type: 'minicap', name: ' A ', games: 3, date: '', podium: ['x', ' '] },
        { season: 31, type: 'maxicap', name: 'B', games: 5, date: '01.09.2026', status: 'detected', podium: [] },
      ],
      rejectedCandidates: ['31|2026-09-08'],
    };
    expect(clubBody(f, { '31': 41 })).toEqual({
      tournaments: [
        { season: 30, type: 'minicap', name: 'A', games: 3, podium: ['x'] },
        { season: 31, type: 'maxicap', name: 'B', games: 5, date: '01.09.2026', status: 'detected', podium: [] },
      ],
      rejectedCandidates: ['31|2026-09-08'],
      gameLimits: { '31': 41 },
    });
  });
  it('never emits undefined (Firestore rejects it)', () => {
    const body = clubBody({ tournaments: [{ season: 1, type: 't', name: 'n', games: 1, podium: [] }] });
    expect(Object.values(body.tournaments[0]).includes(undefined)).toBe(false);
    expect(Object.keys(body.tournaments[0])).toEqual(['season', 'type', 'name', 'games', 'podium']);
    expect(body.rejectedCandidates).toEqual([]);
    expect(body.gameLimits).toEqual({});
  });
});

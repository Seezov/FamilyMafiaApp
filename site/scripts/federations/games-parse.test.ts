import fs from 'node:fs';
import path from 'node:path';
import { describe, expect, it } from 'vitest';
import { parseEgGames, parseEgInfo, parseEgPlayer, parseMafgameHistory, parseMafgameTournament } from './games-parse.ts';

const fx = (f: string) => fs.readFileSync(path.join(import.meta.dirname, 'fixtures', 'games', f), 'utf8');
const json = (f: string) => JSON.parse(fx(f));
const ROLES = ['citizen', 'sheriff', 'mafia', 'don'];

describe('emotion.games', () => {
  it('lists a player\'s tournaments', () => {
    const refs = parseEgPlayer(json('eg-player-112.json'));
    expect(refs).toHaveLength(12);
    expect(refs[0]).toEqual({ fed: 'eg', tournamentId: '599', date: '2026-08-30' });
  });
  it('reads tournament dates', () => {
    expect(parseEgInfo(json('eg-info-716.json'))).toEqual({
      fed: 'eg', tournamentId: '716', name: 'Пара Лева 2026', dateFrom: '2026-10-10', dateTo: '2026-10-11', online: false,
    });
  });
  it('marks a tournament also published on imafia', () => {
    const j = json('eg-info-716.json');
    j.info.is_imafia = 1; j.info.im_id = 321;
    expect(parseEgInfo(j).alsoOn).toEqual({ fed: 'imafia', id: '321' });
  });
  it('reads every game with seats, roles and result', () => {
    const games = parseEgGames(json('eg-games-716.json'));
    expect(games).toHaveLength(75);
    for (const g of games) {
      expect(g.seats.map((s) => s.seat)).toEqual([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
      for (const s of g.seats) expect(ROLES).toContain(s.role);
    }
    expect(games[0]).toMatchObject({ key: 'q-1-1', round: '1', table: 1, result: 'city' });
    expect(games[0].seats[0]).toEqual({ seat: 1, nick: 'Енай', fedPlayerId: '63', role: 'sheriff' });
    expect(new Set(games.map((g) => g.key)).size).toBe(75);
  });
  it('skips an unfinished game', () => {
    const j = json('eg-games-716.json');
    j.qualifiers.lines[0].tables[0].game_result = null;
    expect(parseEgGames(j)).toHaveLength(74);
  });
});

describe('mafgame.org', () => {
  it('lists a player\'s tournaments', () => {
    expect(parseMafgameHistory(fx('mafgame-user-3041.html'))).toEqual([
      { fed: 'mafgame', tournamentId: '901', date: '2026-06-21' },
      { fed: 'mafgame', tournamentId: '842', date: '2026-06-06' },
      { fed: 'mafgame', tournamentId: '672', date: '2026-05-16' },
    ]);
  });
  it('reads games with user ids from the participants page', () => {
    const t = parseMafgameTournament(fx('mafgame-game-results-842.html'), fx('mafgame-participants-842.html'));
    expect(t).toMatchObject({ fed: 'mafgame', tournamentId: '842', name: 'Arena Moldova Cup 5/20 Chişinău', dateFrom: '2026-06-06', dateTo: '2026-06-06', online: false });
    expect(t.games).toHaveLength(9);
    const g = t.games.find((x) => x.key === '1-1-1')!;
    expect(g).toMatchObject({ round: '1-1', table: 1, result: 'city' });
    expect(g.seats.map((s) => s.role)).toEqual(['citizen', 'citizen', 'citizen', 'citizen', 'citizen', 'don', 'mafia', 'sheriff', 'citizen', 'mafia']);
    expect(g.seats[5]).toEqual({ seat: 6, nick: 'Тян', fedPlayerId: '3041', role: 'don' });
  });
});

import fs from 'node:fs';
import path from 'node:path';
import { describe, expect, it } from 'vitest';
import {
  parseEgGames, parseEgInfo, parseEgPlayer, parseFiimProfile, parseFiimUserGames, parseImafiaProfile, parseImafiaTournament,
  parseMafgameHistory, parseMafgameTournament,
} from './games-parse.ts';

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

describe('imafia.org', () => {
  it("lists a player's tournaments with dates", () => {
    const refs = parseImafiaProfile(fx('imafia-u-5057.html'));
    expect(refs).toContainEqual({ fed: 'imafia', tournamentId: '1760', date: '2026-09-26' });
    expect(refs[0]).toEqual({ fed: 'imafia', tournamentId: '1453', date: '2026-11-07' });
    expect(refs).toHaveLength(3);
  });
  it('reads games: role_1 citizen, role_2 sheriff, role_3 mafia, role_4 don; result_1 city', () => {
    const t = parseImafiaTournament(fx('imafia-tournament-1760.html'), '1760');
    expect(t).toMatchObject({ fed: 'imafia', tournamentId: '1760', name: 'Східний Рубіж 2026 2 серія Кременчук', dateFrom: '2026-09-26', dateTo: '2026-09-26' });
    expect(t.games).toHaveLength(10);
    const g = t.games[0];
    expect(g).toMatchObject({ key: 't1-g1', table: 1, result: 'city' });
    expect(g.seats.map((s) => s.role)).toEqual(['don', 'citizen', 'sheriff', 'citizen', 'citizen', 'citizen', 'mafia', 'citizen', 'mafia', 'citizen']);
    expect(g.seats[3]).toEqual({ seat: 4, nick: 'Аглая', fedPlayerId: '5057', role: 'citizen' });
    expect(t.games[1].result).toBe('mafia');
  });
});

describe('fiim.world', () => {
  it("lists a player's tournaments by award date", () => {
    expect(parseFiimProfile(fx('fiim-user-14478.html'), '14478')).toEqual([{ fed: 'fiim', tournamentId: '1479', date: '2021-08-09' }]);
  });
  it("reads one player's games, marking the owner's seat", () => {
    const t = parseFiimUserGames(fx('fiim-games-14478-1479.html'), '1479', '14478', '2021-08-09');
    expect(t).toMatchObject({ fed: 'fiim', tournamentId: '1479', name: 'Кубок Долины Роз 2021', dateFrom: '2021-08-07', dateTo: '2021-08-09' });
    expect(t.games).toHaveLength(12);
    expect(t.games.filter((g) => g.result === 'mafia')).toHaveLength(8);
    const g = t.games[0];
    expect(g).toMatchObject({ key: 'g222363', round: '1', table: 1, result: 'mafia' });
    expect(g.seats.map((s) => s.nick)).toEqual(['Павлин', 'Паранойя.', 'Луиза', 'Бонд.', 'Мари', 'Holmes', 'Pадагаст', 'Majest', 'Упс', 'Меланхолия']);
    expect(g.seats.map((s) => s.role)).toEqual(['mafia', 'citizen', 'citizen', 'citizen', 'don', 'citizen', 'mafia', 'citizen', 'sheriff', 'citizen']);
    for (const x of t.games) expect(x.seats.filter((s) => s.fedPlayerId)).toHaveLength(1);
    expect(g.seats[2]).toEqual({ seat: 3, nick: 'Луиза', fedPlayerId: '14478', role: 'citizen' });
  });
});

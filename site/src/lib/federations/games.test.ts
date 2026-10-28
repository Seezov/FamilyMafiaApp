import { describe, expect, it } from 'vitest';
import type { FedDoc } from './core';
import { computeFedGames, mergeParts, type ClubGame, type ClubPlayer, type FedGame, type FedRole, type FedTournament } from './games';

// Ten roster players p0…p9 (slug = name lower-case); p0 is Braun with confirmed eg 100 / imafia 200 / fiim 300.
const NAMES = ['Braun', 'Alpha', 'Beta', 'Gamma', 'Delta', 'Eps', 'Zeta', 'Eta', 'Theta', 'Iota'];
const players: ClubPlayer[] = NAMES.map((n) => ({ name: n, slug: n.toLowerCase(), aliases: [n.toLowerCase()] }));
const doc: FedDoc = { links: { Braun: { eg: ['100'], imafia: ['200'], fiim: ['300'] } }, rejected: {} };
const ROLES: FedRole[] = ['citizen', 'citizen', 'sheriff', 'mafia', 'don', 'citizen', 'citizen', 'mafia', 'citizen', 'citizen'];
const CLUB_ROLE: Record<FedRole, string> = { citizen: 'civilian', sheriff: 'sheriff', mafia: 'mafia', don: 'don' };

function fedGame(key: string, o: { result?: 'city' | 'mafia'; ids?: Record<number, string>; nicks?: string[]; roles?: FedRole[] } = {}): FedGame {
  const nicks = o.nicks ?? NAMES;
  const roles = o.roles ?? ROLES;
  return {
    key, result: o.result ?? 'city',
    seats: nicks.map((nick, i) => ({ seat: i + 1, nick, role: roles[i], ...(o.ids?.[i] && { fedPlayerId: o.ids[i] }) })),
  };
}
const tour = (fed: FedTournament['fed'], id: string, games: FedGame[], extra: Partial<FedTournament> = {}): FedTournament =>
  ({ fed, tournamentId: id, name: `T${id}`, dateFrom: '2026-05-10', dateTo: '2026-05-11', games, ...extra });
function club(id: string, date: string | null, o: { roles?: FedRole[]; names?: string[] } = {}): ClubGame {
  const names = o.names ?? NAMES;
  const roles = o.roles ?? ROLES;
  return { id, season: 30, date, result: 'city', seats: names.map((p, i) => ({ n: i + 1, player: p, slug: p.toLowerCase(), role: CLUB_ROLE[roles[i]] })) };
}
const run = (tournaments: FedTournament[], clubGames: ClubGame[] = [], d: FedDoc = doc) =>
  computeFedGames({ tournaments, club: clubGames, players, doc: d, now: '2026-10-28T00:00:00Z' });
const BRAUN = { 0: '100' };

describe('computeFedGames', () => {
  it('counts a linked player\'s game and win', () => {
    const r = run([tour('eg', '1', [fedGame('a', { ids: BRAUN })])]);
    expect(r.players.braun).toEqual({ games: 1, wins: 1 });
    expect(r.counts).toMatchObject({ tournaments: 1, games: 1, counted: 1 });
  });

  it('counts a loss on the losing side', () => {
    expect(run([tour('eg', '1', [fedGame('a', { ids: BRAUN, result: 'mafia' })])]).players.braun).toEqual({ games: 1, wins: 0 });
  });

  it('drops a full club match even without a date', () => {
    const r = run([tour('eg', '1', [fedGame('a', { ids: BRAUN })])], [club('g-x-1', null)]);
    expect(r.counts.clubDuplicates).toBe(1);
    expect(r.players.braun).toBeUndefined();
    expect(r.review).toEqual([]);
  });

  it('holds an 8-of-10 match inside the window for review', () => {
    const roles = [...ROLES];
    roles[9] = 'sheriff'; roles[2] = 'citizen';  // seats 3 and 10 swap roles → 8 match
    const r = run([tour('eg', '1', [fedGame('a', { ids: BRAUN })])], [club('g-1', '2026-05-12', { roles })]);
    expect(r.players.braun).toBeUndefined();
    expect(r.counts.possible).toBe(1);
    expect(r.review[0]).toMatchObject({ key: 'eg:1:a', fed: 'eg', tournamentId: '1', tournament: 'T1', matched: 8 });
    expect(r.review[0].club).toMatchObject({ season: 30, id: 'g-1', date: '2026-05-12' });
    expect(r.review[0].fedSeats[0]).toEqual({ seat: 1, nick: 'Braun', role: 'citizen', slug: 'braun' });
    expect(r.review[0].club.seats[0]).toEqual({ seat: 1, player: 'Braun', role: 'civilian', slug: 'braun' });
  });

  it('counts a partial match outside ±3 days', () => {
    const names = [...NAMES]; names[9] = 'Other';
    const r = run([tour('eg', '1', [fedGame('a', { ids: BRAUN })])], [club('g-1', '2026-05-15', { names })]);
    expect(r.players.braun).toEqual({ games: 1, wins: 1 });
    expect(r.review).toEqual([]);
  });

  it('counts a match of only 6 seats', () => {
    const names = [...NAMES]; names[6] = 'X1'; names[7] = 'X2'; names[8] = 'X3'; names[9] = 'X4';
    const r = run([tour('eg', '1', [fedGame('a', { ids: BRAUN })])], [club('g-1', '2026-05-10', { names })]);
    expect(r.players.braun).toEqual({ games: 1, wins: 1 });
  });

  it('applies decisions: different counts, same drops', () => {
    const names = [...NAMES]; names[9] = 'Other';
    const other = [...NAMES]; other[8] = 'Other2';
    const t = [tour('eg', '1', [fedGame('a', { ids: BRAUN }), fedGame('b', { ids: BRAUN, result: 'mafia', nicks: other })])];
    const r = run(t, [club('g-1', '2026-05-10', { names })], { ...doc, gameDecisions: { 'eg:1:a': 'different', 'eg:1:b': 'same' } });
    expect(r.players.braun).toEqual({ games: 1, wins: 1 });
    expect(r.counts.possible).toBe(0);
  });

  it('counts a game published on two federations once', () => {
    const r = run([
      tour('imafia', '7', [fedGame('t1-g1', { ids: { 0: '200', 1: '9' } })]),
      tour('fiim', '8', [fedGame('g5', { ids: { 0: '300' } })]),
    ]);
    expect(r.players.braun).toEqual({ games: 1, wins: 1 });
    expect(r.counts.crossFedDuplicates).toBe(1);
  });

  it('drops an emotion.games copy of a tournament also fetched from imafia', () => {
    const r = run([
      tour('eg', '1', [fedGame('q-1-1', { ids: BRAUN, nicks: NAMES.map((n) => n + '!') })], { alsoOn: { fed: 'imafia', id: '7' } }),
      tour('imafia', '7', [fedGame('t1-g1', { ids: { 0: '200' } })]),
    ]);
    expect(r.players.braun).toEqual({ games: 1, wins: 1 });
    expect(r.counts.crossFedDuplicates).toBe(1);
  });

  it('does not attribute by nick', () => {
    const r = run([tour('eg', '1', [fedGame('a')])]);
    expect(r.players.braun).toBeUndefined();
    expect(r.counts.counted).toBe(0);
  });

  it('an ambiguous alias resolves to nobody', () => {
    const twins: ClubPlayer[] = [...players, { name: 'Braun2', slug: 'braun2', aliases: ['alpha'] }];
    const r = computeFedGames({ tournaments: [tour('eg', '1', [fedGame('a', { ids: BRAUN })])], club: [club('g-1', null)], players: twins, doc, now: '' });
    // Seat 2 "Alpha" no longer resolves to one player, so the full club match is lost.
    expect(r.counts.clubDuplicates).toBe(0);
    expect(r.players.braun).toEqual({ games: 1, wins: 1 });
  });

  it('a federation nick "Braun (Браун)" resolves through either half', () => {
    const nicks = [...NAMES]; nicks[1] = 'Alpha (Альфа)';
    const r = run([tour('eg', '1', [fedGame('a', { ids: BRAUN, nicks })])], [club('g-1', null)]);
    expect(r.counts.clubDuplicates).toBe(1);
  });
});

describe('review fixes', () => {
  const twoLinks: FedDoc = { links: { Braun: { imafia: ['200'] }, Alpha: { eg: ['101'] } }, rejected: {} };
  it('a game on two federations counts for players linked on either', () => {
    const r = run([
      tour('imafia', '7', [fedGame('t1-g1', { ids: { 0: '200', 2: '9' } })]),
      tour('eg', '1', [fedGame('q-1-1', { ids: { 1: '101' } })]),
    ], [], twoLinks);
    expect(r.players).toEqual({ braun: { games: 1, wins: 1 }, alpha: { games: 1, wins: 1 } });
    expect(r.counts).toMatchObject({ crossFedDuplicates: 1, counted: 1 });
  });
  it('an alsoOn copy hands its players to the twin game, even when nicks differ', () => {
    const r = run([
      tour('eg', '1', [fedGame('q-1-1', { ids: { 1: '101' }, nicks: NAMES.map((n) => n + '!') })], { alsoOn: { fed: 'imafia', id: '7' } }),
      tour('imafia', '7', [fedGame('t1-g1', { ids: { 0: '200' } })]),
    ], [], twoLinks);
    expect(r.players).toEqual({ braun: { games: 1, wins: 1 }, alpha: { games: 1, wins: 1 } });
  });
  it('an alsoOn game with no twin match still counts', () => {
    const r = run([
      tour('eg', '1', [fedGame('q-1-1', { ids: { 1: '101' }, roles: [...ROLES].reverse() })], { alsoOn: { fed: 'imafia', id: '7' } }),
      tour('imafia', '7', [fedGame('t1-g1', { ids: { 0: '200' } })]),
    ], [], twoLinks);
    expect(r.players.alpha).toEqual({ games: 1, wins: 1 });
    expect(r.players.braun).toEqual({ games: 1, wins: 1 });
  });
  it('decided possible duplicates stay listed so the decision can be undone', () => {
    const names = [...NAMES]; names[9] = 'Other';
    const other = [...NAMES]; other[8] = 'Other2';
    const t = [tour('eg', '1', [fedGame('a', { ids: BRAUN }), fedGame('b', { ids: BRAUN, result: 'mafia', nicks: other })])];
    const r = run(t, [club('g-1', '2026-05-10', { names })], { ...doc, gameDecisions: { 'eg:1:a': 'same', 'eg:1:b': 'different' } });
    expect(r.review.map((x) => x.key).sort()).toEqual(['eg:1:a', 'eg:1:b']);
    expect(r.players.braun).toEqual({ games: 1, wins: 0 });
    expect(r.counts.possible).toBe(0);
  });
});

describe('club games with a blank seat', () => {
  it('never match and do not throw', () => {
    const blank = club('g-1', '2026-05-10');
    delete (blank.seats[9] as { player?: string }).player;
    delete blank.seats[9].slug;
    const r = run([tour('eg', '1', [fedGame('a', { ids: BRAUN })])], [blank]);
    expect(r.counts.possible).toBe(1);
    expect(r.review[0].club.seats[9]).toEqual({ seat: 10, player: '', role: 'civilian' });
  });
});

describe('mergeParts', () => {
  it('merges parts by game key, keeping both owners\' ids', () => {
    const a = tour('fiim', '8', [fedGame('g5', { ids: { 0: '300' } })], { dateFrom: '2026-05-09', dateTo: '2026-05-11' });
    const b = tour('fiim', '8', [fedGame('g5', { ids: { 3: '301' } }), fedGame('g6')], { dateFrom: '2026-05-08', dateTo: '2026-05-11' });
    const [m, ...rest] = mergeParts([a, b]);
    expect(rest).toEqual([]);
    expect(m.games.map((g) => g.key)).toEqual(['g5', 'g6']);
    expect(m.games[0].seats[0].fedPlayerId).toBe('300');
    expect(m.games[0].seats[3].fedPlayerId).toBe('301');
    expect(m.dateFrom).toBe('2026-05-08');
  });
});

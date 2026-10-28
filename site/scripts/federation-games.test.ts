import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { describe, expect, it } from 'vitest';
import { buildFederationGames } from './federation-games.ts';

const NAMES = ['Braun', 'Alpha', 'Beta', 'Gamma', 'Delta', 'Eps', 'Zeta', 'Eta', 'Theta', 'Iota'];
const ROLES = ['citizen', 'citizen', 'sheriff', 'mafia', 'don', 'citizen', 'citizen', 'mafia', 'citizen', 'citizen'];
const CLUB = ['civilian', 'civilian', 'sheriff', 'mafia', 'don', 'civilian', 'civilian', 'mafia', 'civilian', 'civilian'];

function setup() {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'fedbuild-'));
  const cacheDir = path.join(root, 'cache');
  const dataDir = path.join(root, 'data');
  fs.mkdirSync(path.join(cacheDir, 't'), { recursive: true });
  fs.mkdirSync(path.join(dataDir, 'games'), { recursive: true });
  fs.writeFileSync(path.join(dataDir, 'players.json'), JSON.stringify({
    players: NAMES.map((n) => ({ name: n, slug: n.toLowerCase(), aliases: [n.toLowerCase()] })),
  }));
  const game = (key: string) => ({ key, result: 'city', seats: NAMES.map((nick, i) => ({ seat: i + 1, nick, role: ROLES[i], ...(i === 0 && { fedPlayerId: '100' }) })) });
  fs.writeFileSync(path.join(cacheDir, 't', 'eg-1.json'), JSON.stringify({
    fed: 'eg', tournamentId: '1', name: 'T1', dateFrom: '2026-05-10', dateTo: '2026-05-10', games: [game('a'), game('b')],
  }));
  // Club season 30: one rating game equal to the federation's (date unknown), one unrated equal game (ignored).
  const seats = NAMES.map((p, i) => ({ n: i + 1, player: p, slug: p.toLowerCase(), key: p.toLowerCase(), role: CLUB[i] }));
  fs.writeFileSync(path.join(dataDir, 'games', '30.json'), JSON.stringify({
    season: 30, days: [
      { date: null, games: [{ id: 'g-x-0', n: 1, result: 'city', seats }] },
      { date: '2026-05-10', games: [{ id: 'g-2026-05-10-1-1', n: 1, result: 'unrated', seats }] },
    ],
  }));
  return { cacheDir, dataDir };
}
const fedDoc = (decisions: Record<string, string> = {}) => JSON.stringify({ fields: {
  links: { mapValue: { fields: { Braun: { mapValue: { fields: { eg: { arrayValue: { values: [{ stringValue: '100' }] } } } } } } } },
  gameDecisions: { mapValue: { fields: Object.fromEntries(Object.entries(decisions).map(([k, v]) => [k, { stringValue: v }])) } },
} });
const read = (dataDir: string) => JSON.parse(fs.readFileSync(path.join(dataDir, 'federation_games.json'), 'utf8'));

describe('buildFederationGames', () => {
  it('writes per-player tournament games, dropping the club duplicate', async () => {
    const { cacheDir, dataDir } = setup();
    const lines: string[] = [];
    await buildFederationGames({ fetch: (async () => new Response(fedDoc())) as typeof fetch, cacheDir, dataDir, log: (s) => lines.push(s), now: '2026-10-28T03:00:00Z' });
    const out = read(dataDir);
    // The two federation games have identical seats, so they collapse to one, which fully matches the club rating game.
    expect(out.players).toEqual({});
    expect(out.counts).toMatchObject({ tournaments: 1, games: 2, clubDuplicates: 1 });
    expect(lines.join('\n')).toMatch(/federation-games: /);
  });

  it('counts games when the club has no matching rating game', async () => {
    const { cacheDir, dataDir } = setup();
    fs.rmSync(path.join(dataDir, 'games', '30.json'));
    await buildFederationGames({ fetch: (async () => new Response(fedDoc())) as typeof fetch, cacheDir, dataDir, log: () => {}, now: '' });
    expect(read(dataDir).players).toEqual({ braun: { games: 1, wins: 1 } });
  });

  it('writes an empty file and keeps going when config/federations fails', async () => {
    const { cacheDir, dataDir } = setup();
    const lines: string[] = [];
    await buildFederationGames({ fetch: (async () => new Response('', { status: 500 })) as typeof fetch, cacheDir, dataDir, log: (s) => lines.push(s), now: '' });
    expect(read(dataDir)).toMatchObject({ players: {}, review: [] });
    expect(lines.join('\n')).toMatch(/WARNING/);
  });

  it('works without a cache directory', async () => {
    const { dataDir } = setup();
    await buildFederationGames({ fetch: (async () => new Response(fedDoc())) as typeof fetch, cacheDir: path.join(dataDir, 'nope'), dataDir, log: () => {}, now: '' });
    expect(read(dataDir)).toMatchObject({ players: {}, counts: { tournaments: 0 } });
  });
});

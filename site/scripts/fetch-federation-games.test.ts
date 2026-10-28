import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { describe, expect, it } from 'vitest';
import { fetchFederationGames } from './fetch-federation-games.ts';

const fx = (f: string) => fs.readFileSync(new URL(`./federations/fixtures/games/${f}`, import.meta.url), 'utf8');
const ok = (body: string) => new Response(body, { status: 200 });
const page = (props: object) => `<div id="app" data-page="${JSON.stringify({ props }).replace(/"/g, '&quot;')}"></div>`;

// config/federations over REST: one confirmed profile per federation.
const fedDoc = JSON.stringify({
  fields: {
    links: { mapValue: { fields: { Аглая: { mapValue: { fields: {
      eg: { arrayValue: { values: [{ stringValue: '112' }] } },
      imafia: { arrayValue: { values: [{ stringValue: '5057' }] } },
      fiim: { arrayValue: { values: [{ stringValue: '14478' }] } },
      mafgame: { arrayValue: { values: [{ stringValue: '3041' }] } },
    } } } } } },
  },
});

function fakeFetch(log: string[], fail: RegExp | null = null) {
  return (async (input: string | URL) => {
    const u = String(input);
    log.push(u);
    if (fail?.test(u)) return new Response('', { status: 500 });
    if (u.includes('documents/config/federations')) return ok(fedDoc);
    if (u.includes('year_points/player/112')) return ok(JSON.stringify({ tournaments: [{ id: 716, start_date: '2026-10-10T10:00:00.000Z' }] }));
    if (u.includes('json_info/716')) return ok(fx('eg-info-716.json'));
    if (u.includes('seating_games_tab/716')) return ok(fx('eg-games-716.json'));
    if (u.endsWith('imafia.org/u/5057')) return ok('<tr><td>26/09/2026</td>\n<td><a href="/tournament/1760">x</a></td>');
    if (u.endsWith('imafia.org/tournament/1760')) return ok(fx('imafia-tournament-1760.html'));
    if (u.endsWith('fiim.world/user/14478/show')) return ok(fx('fiim-user-14478.html'));
    if (u.endsWith('fiim.world/user/14478/games/1479')) return ok(fx('fiim-games-14478-1479.html'));
    if (u.endsWith('mafgame.org/user/3041/view')) return ok(page({ history: [{ id: 842, start_date: '2026-06-06' }] }));
    if (u.endsWith('mafgame.org/tournaments/842/game_results')) return ok(fx('mafgame-game-results-842.html'));
    if (u.endsWith('mafgame.org/tournaments/842/participants')) return ok(fx('mafgame-participants-842.html'));
    throw new Error(`unexpected ${u}`);
  }) as typeof fetch;
}

const tmp = () => fs.mkdtempSync(path.join(os.tmpdir(), 'fedgames-'));
const run = (cacheDir: string, log: string[], extra: Partial<Parameters<typeof fetchFederationGames>[0]> = {}) => {
  const lines: string[] = [];
  return fetchFederationGames({
    fetch: fakeFetch(log), cacheDir, budgetMs: 60_000, now: new Date('2026-10-28T03:00:00Z'), log: (s) => lines.push(s), delayMs: 0, ...extra,
  }).then((r) => ({ ...r, lines }));
};

describe('fetchFederationGames', () => {
  it('writes one file per tournament (per player on fiim)', async () => {
    const dir = tmp();
    const r = await run(dir, []);
    expect(fs.readdirSync(path.join(dir, 't')).sort()).toEqual(['eg-716.json', 'fiim-1479-u14478.json', 'imafia-1760.json', 'mafgame-842.json']);
    const eg = JSON.parse(fs.readFileSync(path.join(dir, 't', 'eg-716.json'), 'utf8'));
    expect(eg).toMatchObject({ fed: 'eg', tournamentId: '716', dateTo: '2026-10-11' });
    expect(eg.games).toHaveLength(75);
    expect(r).toMatchObject({ fetched: 4, skipped: 0, left: 0 });
  });

  it('never refetches a finished tournament', async () => {
    const dir = tmp();
    await run(dir, []);
    const log: string[] = [];
    const r = await run(dir, log);
    expect(r).toMatchObject({ fetched: 0, skipped: 4 });
    expect(log.filter((u) => /json_info|seating|tournament\/1760|games\/1479|game_results|participants/.test(u))).toEqual([]);
  });

  it('refetches a tournament that ended less than two days ago', async () => {
    const dir = tmp();
    await run(dir, [], { now: new Date('2026-10-12T03:00:00Z') });
    const log: string[] = [];
    await run(dir, log, { now: new Date('2026-10-12T03:00:00Z') });
    expect(log.some((u) => u.includes('seating_games_tab/716'))).toBe(true);
  });

  it('a failing federation logs a warning and the others are written', async () => {
    const dir = tmp();
    const r = await fetchFederationGames({ fetch: fakeFetch([], /imafia\.org/), cacheDir: dir, budgetMs: 60_000, now: new Date('2026-10-28'), log: () => {}, delayMs: 0 });
    expect(fs.readdirSync(path.join(dir, 't'))).toHaveLength(3);
    expect(r.warnings).toBeGreaterThan(0);
  });

  it('stops at the time budget', async () => {
    const dir = tmp();
    const r = await run(dir, [], { budgetMs: 0 });
    expect(r.fetched).toBe(0);
    expect(r.left).toBeGreaterThan(0);
    expect(r.lines.join('\n')).toMatch(/budget/);
  });
});

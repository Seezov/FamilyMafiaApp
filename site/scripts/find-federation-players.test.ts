import fs from 'node:fs';
import { describe, expect, it } from 'vitest';
import { findCandidates, rosterFromRest } from './find-federation-players.ts';
import type { CandidatesFile } from '../src/lib/federations/core.ts';

const fx = (f: string) => fs.readFileSync(new URL(`./federations/fixtures/${f}`, import.meta.url), 'utf8');
const ok = (body: string) => new Response(body, { status: 200 });

/** Routes each site's URL to a fixture; unknown searches come back empty. */
function fakeFetch(log: string[], fail: RegExp | null = null) {
  return (async (input: string | URL) => {
    const u = String(input);
    log.push(u);
    if (fail?.test(u)) throw new Error('network down');
    if (u.includes('api-v1.emotion.games/club/clubs/13')) return ok(fx('eg-club-13-p1.json'));
    if (u.includes('api-v1.emotion.games/year_points/summary')) return ok(fx('eg-summary-2026.json'));
    if (u.includes('mafgame.org/clubs/9/members')) return ok(fx('mafgame-members-9.html'));
    if (u.includes('mafgame.org/rating')) return ok(u.includes('page=') ? '<div data-page="{&quot;props&quot;:{&quot;search_results&quot;:{&quot;data&quot;:[],&quot;last_page&quot;:1}}}"></div>' : fx('mafgame-rating.html'));
    if (u.includes('fiim.world/rating/search')) return ok(u.includes('name=Seezov') ? fx('fiim-search-seezov.json') : JSON.stringify({ success: '' }));
    if (u.includes('imafia.org/rating')) return ok(decodeURIComponent(u).includes('f[name]=Seezov') ? fx('imafia-search-seezov.html') : '<html></html>');
    if (u.includes('imafia.org/u/1003')) return ok(fx('imafia-u-1003.html'));
    throw new Error(`unexpected ${u}`);
  }) as typeof fetch;
}

const roster = [
  { name: 'Seezov', nicknames: ['SEEZOV'] },
  { name: 'Majest', nicknames: [] },
];
const run = (log: string[], extra: Partial<Parameters<typeof findCandidates>[0]> = {}) =>
  findCandidates({ fetch: fakeFetch(log), roster, previous: null, log: () => {}, delayMs: 0, year: 2026, ...extra });

describe('findCandidates', () => {
  it('collects club members and nick hits under the roster name', async () => {
    const out = await run([]);
    const s = out.players.Seezov;
    expect(s.find((c) => c.fed === 'eg')).toMatchObject({ id: '87', strength: 'club' });
    expect(s.find((c) => c.fed === 'fiim')).toMatchObject({ id: '9169', strength: 'club' });
    expect(s.find((c) => c.fed === 'imafia')).toMatchObject({ id: '1003', realName: 'Сізов Олександр', city: 'Україна', games: 86 });
    expect(out.players.Majest.find((c) => c.fed === 'mafgame')).toMatchObject({ id: '899', strength: 'club' });
    expect(s.map((c) => c.fed)).toEqual(['imafia', 'eg', 'fiim', 'mafgame']);
  });
  it('lists club members nobody in the roster matches', async () => {
    const out = await run([]);
    expect(out.unmatched.some((c) => c.fed === 'eg' && c.nick === 'Пустой')).toBe(true);
    expect(out.unmatched.some((c) => c.id === '87')).toBe(false);
  });
  it('searches imafia and fiim once per distinct nick; profiles only for exact hits', async () => {
    const log: string[] = [];
    await run(log);
    expect(log.filter((u) => u.includes('imafia.org/rating'))).toHaveLength(2);   // Seezov (=SEEZOV), Majest
    expect(log.filter((u) => u.includes('fiim.world/rating/search'))).toHaveLength(2);
    expect(log.filter((u) => u.includes('imafia.org/u/'))).toEqual(['https://imafia.org/u/1003']);
  });
  it('keeps the previous candidates of a federation that fails', async () => {
    const old = { fed: 'imafia' as const, id: '1', nick: 'Majest', url: 'https://imafia.org/u/1', strength: 'nick' as const };
    const previous: CandidatesFile = { generatedAt: 'x', players: { Majest: [old] }, unmatched: [] };
    const lines: string[] = [];
    const out = await findCandidates({ fetch: fakeFetch([], /imafia\.org/), roster, previous, log: (s) => lines.push(s), delayMs: 0, year: 2026 });
    expect(out.players.Majest).toContainEqual(old);
    expect(out.players.Seezov.some((c) => c.fed === 'imafia')).toBe(false);
    expect(lines.some((l) => l.includes('imafia'))).toBe(true);
  });
});

describe('rosterFromRest', () => {
  it('reads config/players from the Firestore REST shape', () => {
    const doc = { fields: { players: { arrayValue: { values: [
      { mapValue: { fields: { name: { stringValue: 'Braun' }, nicknames: { arrayValue: { values: [{ stringValue: 'Браун' }] } } } } },
      { mapValue: { fields: { name: { stringValue: 'Tina' }, nicknames: { arrayValue: {} } } } },
    ] } } } };
    expect(rosterFromRest(doc)).toEqual([{ name: 'Braun', nicknames: ['Браун'] }, { name: 'Tina', nicknames: [] }]);
  });
});

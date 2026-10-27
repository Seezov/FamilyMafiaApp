// Manual run: finds federation profiles for every roster player → ../assets/raw/federation_candidates.json,
// reviewed by admins on /federations/edit/. `cd site && node scripts/find-federation-players.ts` (10–20 min).
// A federation that fails keeps its candidates from the previous file.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { candKey, FEDS, normNick, type Candidate, type CandidatesFile, type Fed } from '../src/lib/federations/core.ts';
import type { RosterEntry } from '../src/lib/roster/roster.ts';
import {
  nickVariants, parseEgClub, parseEgSummary, parseFiimSearch, parseImafiaProfile, parseImafiaSearch, parseMafgameMembers, parseMafgameRating,
} from './federations/parse.ts';

const ROSTER_URL = 'https://firestore.googleapis.com/v1/projects/familymafiaapp/databases/(default)/documents/config/players';
const EG_FIRST_YEAR = 2024;

type Opts = { fetch: typeof fetch; roster: RosterEntry[]; previous: CandidatesFile | null; log: (s: string) => void; delayMs?: number; year?: number };

export function rosterFromRest(doc: any): RosterEntry[] {
  return (doc.fields?.players?.arrayValue?.values ?? []).map((v: any) => ({
    name: String(v.mapValue.fields.name.stringValue),
    nicknames: (v.mapValue.fields.nicknames?.arrayValue?.values ?? []).map((n: any) => String(n.stringValue)),
  }));
}

export async function findCandidates(o: Opts): Promise<CandidatesFile> {
  const delay = o.delayMs ?? 300;
  const year = o.year ?? new Date().getFullYear();
  async function get(url: string): Promise<string> {
    for (let attempt = 0; ; attempt++) {
      if (delay) await new Promise((r) => setTimeout(r, delay));
      try {
        const res = await o.fetch(url, { headers: { 'User-Agent': 'Mozilla/5.0 (FamilyMafiaClub federation matcher)' } });
        if (!res.ok) throw new Error(`HTTP ${res.status} ${url}`);
        return await res.text();
      } catch (e) {
        if (attempt >= 1) throw e;
      }
    }
  }

  // Normalised nick → roster name (the first player that claims it).
  const owner = new Map<string, string>();
  for (const e of o.roster) for (const n of [e.name, ...e.nicknames]) if (!owner.has(normNick(n))) owner.set(normNick(n), e.name);
  const searchNicks = [...owner.keys()];
  const nickOf = new Map<string, string>();
  for (const e of o.roster) for (const n of [e.name, ...e.nicknames]) if (!nickOf.has(normNick(n))) nickOf.set(normNick(n), n.trim());

  const found: Record<Fed, Candidate[]> = { imafia: [], eg: [], fiim: [], mafgame: [] };
  const failed = new Set<Fed>();
  const step = async (fed: Fed, fn: () => Promise<void>) => {
    try {
      await fn();
      o.log(`${fed}: ${found[fed].length} profiles`);
    } catch (e) {
      failed.add(fed);
      o.log(`${fed}: FAILED (${(e as Error).message}) — keeping the previous candidates`);
    }
  };
  const exact = (c: Candidate, nick: string) => nickVariants(c.nick).some((v) => normNick(v) === nick);

  await step('eg', async () => {
    const first = parseEgClub(JSON.parse(await get('https://api-v1.emotion.games/club/clubs/13?page=1')));
    found.eg.push(...first.members);
    for (let p = 2; p <= first.totalPages; p++) found.eg.push(...parseEgClub(JSON.parse(await get(`https://api-v1.emotion.games/club/clubs/13?page=${p}`))).members);
    for (let y = EG_FIRST_YEAR; y <= year; y++) found.eg.push(...parseEgSummary(JSON.parse(await get(`https://api-v1.emotion.games/year_points/summary?year=${y}`))));
  });
  await step('mafgame', async () => {
    const first = parseMafgameMembers(await get('https://mafgame.org/clubs/9/members'));
    found.mafgame.push(...first.members);
    for (let p = 2; p <= first.lastPage; p++) found.mafgame.push(...parseMafgameMembers(await get(`https://mafgame.org/clubs/9/members?page=${p}`)).members);
    for (const y of parseMafgameRating(await get('https://mafgame.org/rating')).years) {
      const top = parseMafgameRating(await get(`https://mafgame.org/rating?year=${y}`));
      found.mafgame.push(...top.rows);
      for (let p = 2; p <= top.lastPage; p++) found.mafgame.push(...parseMafgameRating(await get(`https://mafgame.org/rating?year=${y}&page=${p}`)).rows);
    }
  });
  await step('fiim', async () => {
    for (const k of searchNicks) {
      const q = encodeURIComponent(nickOf.get(k)!);
      found.fiim.push(...parseFiimSearch(JSON.parse(await get(`https://fiim.world/rating/search?year=all&name=${q}&masters=global`))).filter((c) => exact(c, k)));
    }
  });
  await step('imafia', async () => {
    const profiles = new Map<string, Candidate>();
    for (const k of searchNicks) {
      for (const c of parseImafiaSearch(await get(`https://imafia.org/rating?f[name]=${encodeURIComponent(nickOf.get(k)!)}`)).filter((c) => exact(c, k))) {
        if (!profiles.has(c.id)) {
          const p = parseImafiaProfile(await get(c.url));
          profiles.set(c.id, { ...c, ...(p.realName && { realName: p.realName }), ...(p.club && { club: p.club }), ...(p.country && { city: p.country }), ...(p.games !== undefined && { games: p.games }) });
        }
        found.imafia.push(profiles.get(c.id)!);
      }
    }
  });

  const players: Record<string, Candidate[]> = {};
  const assigned = new Set<string>();
  const add = (player: string, c: Candidate) => {
    const list = (players[player] ??= []);
    const i = list.findIndex((x) => candKey(x) === candKey(c));
    if (i < 0) list.push(c);
    else if (c.strength === 'club' && list[i].strength !== 'club') list[i] = { ...list[i], ...c };
    assigned.add(candKey(c));
  };
  for (const fed of FEDS) {
    if (failed.has(fed)) {
      for (const [p, list] of Object.entries(o.previous?.players ?? {})) for (const c of list) if (c.fed === fed) add(p, c);
      continue;
    }
    for (const c of found[fed]) {
      const players = new Set(nickVariants(c.nick).map((v) => owner.get(normNick(v))).filter((p): p is string => !!p));
      for (const p of players) add(p, c);
    }
  }
  const unmatched = new Map<string, Candidate>();
  for (const fed of FEDS) {
    const pool = failed.has(fed) ? (o.previous?.unmatched ?? []).filter((c) => c.fed === fed) : found[fed].filter((c) => c.strength === 'club');
    for (const c of pool) if (!assigned.has(candKey(c)) && !unmatched.has(candKey(c))) unmatched.set(candKey(c), c);
  }
  const order = (c: Candidate) => FEDS.indexOf(c.fed) * 2 + (c.strength === 'club' ? 0 : 1);
  for (const list of Object.values(players)) list.sort((a, b) => order(a) - order(b));
  return { generatedAt: new Date().toISOString(), players, unmatched: [...unmatched.values()].sort((a, b) => order(a) - order(b)) };
}

if (process.argv[1] && fileURLToPath(import.meta.url) === path.resolve(process.argv[1])) {
  const out = path.resolve('..', 'assets', 'raw', 'federation_candidates.json');
  const previous = fs.existsSync(out) ? JSON.parse(fs.readFileSync(out, 'utf8')) as CandidatesFile : null;
  const res = await fetch(ROSTER_URL);
  if (!res.ok) throw new Error(`config/players: HTTP ${res.status}`);
  const roster = rosterFromRest(await res.json());
  console.log(`roster: ${roster.length} players`);
  const file = await findCandidates({ fetch, roster, previous, log: console.log });
  fs.writeFileSync(out, JSON.stringify(file, null, 1) + '\n');
  console.log(`wrote ${out}: ${Object.keys(file.players).length} players with candidates, ${file.unmatched.length} unmatched club members`);
}

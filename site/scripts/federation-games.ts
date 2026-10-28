// Build step (npm run build): federation games from the fetch cache (scripts/fetch-federation-games.ts) + club rating
// games (data/games/*.json) + live config/federations → data/federation_games.json, read by /players/ and
// /federations/edit/. Never fails the build: without the config or the cache it writes an empty file.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { computeFedGames, type ClubGame, type ClubPlayer, type FedGamesFile, type FedTournament } from '../src/lib/federations/games.ts';
import { FED_DOC_URL, fedDocFromRest, politeGet } from './federations/http.ts';

type Opts = { fetch: typeof fetch; cacheDir: string; dataDir: string; log: (s: string) => void; now: string };

export const emptyFedGames = (now: string): FedGamesFile => ({
  generatedAt: now, players: {}, review: [],
  counts: { tournaments: 0, games: 0, clubDuplicates: 0, crossFedDuplicates: 0, possible: 0, counted: 0 },
});

function clubGames(dataDir: string): ClubGame[] {
  const dir = path.join(dataDir, 'games');
  if (!fs.existsSync(dir)) return [];
  const out: ClubGame[] = [];
  for (const f of fs.readdirSync(dir).filter((f) => f.endsWith('.json'))) {
    const s = JSON.parse(fs.readFileSync(path.join(dir, f), 'utf8'));
    for (const day of s.days ?? []) {
      for (const g of day.games ?? []) {
        if (g.result !== 'city' && g.result !== 'mafia') continue;
        out.push({ id: g.id, season: s.season, date: day.date ?? null, result: g.result, seats: g.seats });
      }
    }
  }
  return out;
}

export async function buildFederationGames(o: Opts) {
  const out = path.join(o.dataDir, 'federation_games.json');
  try {
    const doc = fedDocFromRest(JSON.parse(await politeGet(o.fetch, FED_DOC_URL, { delayMs: 0 })));
    const tDir = path.join(o.cacheDir, 't');
    const tournaments: FedTournament[] = fs.existsSync(tDir)
      ? fs.readdirSync(tDir).filter((f) => f.endsWith('.json')).map((f) => JSON.parse(fs.readFileSync(path.join(tDir, f), 'utf8')))
      : [];
    const players = (JSON.parse(fs.readFileSync(path.join(o.dataDir, 'players.json'), 'utf8')).players as ClubPlayer[])
      .filter((p) => p.slug)
      .map((p) => ({ name: p.name, slug: p.slug, aliases: p.aliases ?? [] }));
    const result = computeFedGames({ tournaments, club: clubGames(o.dataDir), players, doc, now: o.now });
    fs.writeFileSync(out, JSON.stringify(result));
    const c = result.counts;
    o.log(`federation-games: ${c.tournaments} tournaments, ${c.games} games; ${c.clubDuplicates} club duplicates, `
      + `${c.crossFedDuplicates} cross-federation duplicates, ${c.possible} possible duplicates, ${c.counted} counted`);
  } catch (e) {
    o.log(`federation-games: WARNING ${(e as Error).message} — building without federation games`);
    fs.writeFileSync(out, JSON.stringify(emptyFedGames(o.now)));
  }
}

if (process.argv[1] && fileURLToPath(import.meta.url) === path.resolve(process.argv[1])) {
  await buildFederationGames({
    fetch,
    cacheDir: process.env.FED_CACHE_DIR ?? path.resolve('.fedgames'),
    dataDir: process.env.SITE_DATA_DIR ?? path.resolve('data'),
    log: console.log,
    now: new Date().toISOString(),
  });
}

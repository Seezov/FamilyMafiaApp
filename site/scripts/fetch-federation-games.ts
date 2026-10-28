// Nightly CI step (web.yml, schedule or "Run workflow" with federations): downloads the games of every tournament
// played by a profile confirmed on /federations/edit/ into a cache directory (kept in the GitHub Actions cache).
// A tournament that ended more than two days ago is never fetched again. Never fails: problems are warnings.
// `cd site && node scripts/fetch-federation-games.ts` (FED_CACHE_DIR, FED_BUDGET_MIN).
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { FEDS, type Fed } from '../src/lib/federations/core.ts';
import type { FedTournament, TournamentRef } from '../src/lib/federations/games.ts';
import { FED_DOC_URL, fedDocFromRest, politeGet } from './federations/http.ts';
import {
  parseEgGames, parseEgInfo, parseEgPlayer, parseFiimProfile, parseFiimUserGames, parseImafiaProfile, parseImafiaTournament,
  parseMafgameHistory, parseMafgameTournament,
} from './federations/games-parse.ts';

const EG = 'https://api-v1.emotion.games';
/** Days after its last day before a tournament's results count as final. */
const SETTLE_DAYS = 2;

// left: profiles and tournaments the time budget did not reach.
type Opts = { fetch: typeof fetch; cacheDir: string; budgetMs: number; now: Date; log: (s: string) => void; delayMs?: number };
type Job = { ref: TournamentRef; owner: string; file: string };

export async function fetchFederationGames(o: Opts) {
  const start = Date.now();
  const get = (url: string) => politeGet(o.fetch, url, { delayMs: o.delayMs ?? 300 });
  const over = () => Date.now() - start >= o.budgetMs;
  const tDir = path.join(o.cacheDir, 't');
  fs.mkdirSync(tDir, { recursive: true });
  const r = { fetched: 0, skipped: 0, left: 0, warnings: 0 };
  const warn = (s: string) => {
    r.warnings++;
    o.log(`fetch-federation-games: WARNING ${s}`);
  };

  let doc;
  try {
    doc = fedDocFromRest(JSON.parse(await get(FED_DOC_URL)));
  } catch (e) {
    warn(`config/federations: ${(e as Error).message}`);
    return r;
  }
  const profiles = new Set<string>();
  for (const feds of Object.values(doc.links)) for (const f of FEDS) for (const id of feds[f] ?? []) profiles.add(`${f}:${id}`);

  const listOf = async (fed: Fed, id: string): Promise<TournamentRef[]> => {
    switch (fed) {
      case 'eg': return parseEgPlayer(JSON.parse(await get(`${EG}/year_points/player/${id}`)));
      case 'imafia': return parseImafiaProfile(await get(`https://imafia.org/u/${id}`));
      case 'fiim': return parseFiimProfile(await get(`https://fiim.world/user/${id}/show`), id);
      case 'mafgame': return parseMafgameHistory(await get(`https://mafgame.org/user/${id}/view`));
    }
  };
  const fetchOne = async ({ ref, owner }: Job): Promise<FedTournament> => {
    const id = ref.tournamentId;
    switch (ref.fed) {
      case 'eg': {
        const info = parseEgInfo(JSON.parse(await get(`${EG}/tournament/tournaments/json_info/${id}`)));
        return { ...info, games: parseEgGames(JSON.parse(await get(`${EG}/tournament/tournaments/seating_games_tab/${id}`))) };
      }
      case 'imafia': return parseImafiaTournament(await get(`https://imafia.org/tournament/${id}`), id);
      case 'fiim': return parseFiimUserGames(await get(`https://fiim.world/user/${owner}/games/${id}`), id, owner, ref.date ?? '');
      case 'mafgame': return parseMafgameTournament(
        await get(`https://mafgame.org/tournaments/${id}/game_results`), await get(`https://mafgame.org/tournaments/${id}/participants`));
    }
  };

  const jobs = new Map<string, Job>();
  for (const p of profiles) {
    if (over()) {
      r.left++; // a profile not even listed
      continue;
    }
    const [fed, id] = p.split(':') as [Fed, string];
    try {
      for (const ref of await listOf(fed, id)) {
        // fiim pages hold one player's games, so each club player's page of a tournament is a file of its own.
        const file = fed === 'fiim' ? `fiim-${ref.tournamentId}-u${id}.json` : `${fed}-${ref.tournamentId}.json`;
        jobs.set(file, { ref, owner: id, file });
      }
    } catch (e) {
      warn(`${p}: ${(e as Error).message}`);
    }
  }

  const settled = new Date(o.now.getTime() - SETTLE_DAYS * 86400000).toISOString().slice(0, 10);
  for (const job of jobs.values()) {
    const file = path.join(tDir, job.file);
    if (fs.existsSync(file)) {
      try {
        const t = JSON.parse(fs.readFileSync(file, 'utf8')) as FedTournament;
        // No games yet may mean seatings come later (or a page we failed to read): ask again.
        if (t.dateTo && t.dateTo < settled && t.games.length) {
          r.skipped++;
          continue;
        }
      } catch { /* unreadable: fetch again */ }
    }
    if (over()) {
      r.left++;
      continue;
    }
    try {
      fs.writeFileSync(file, JSON.stringify(await fetchOne(job)));
      r.fetched++;
    } catch (e) {
      warn(`${job.file}: ${(e as Error).message}`);
    }
  }
  if (r.left) o.log(`fetch-federation-games: time budget reached, ${r.left} profiles/tournaments left for the next run`);
  o.log(`fetch-federation-games: ${profiles.size} profiles, ${jobs.size} tournaments: ${r.fetched} fetched, ${r.skipped} cached, ${r.left} left, ${r.warnings} warnings`);
  return r;
}

if (process.argv[1] && fileURLToPath(import.meta.url) === path.resolve(process.argv[1])) {
  await fetchFederationGames({
    fetch,
    cacheDir: process.env.FED_CACHE_DIR ?? path.resolve('.fedgames'),
    budgetMs: Number(process.env.FED_BUDGET_MIN ?? 12) * 60_000,
    now: new Date(),
    log: console.log,
  });
}

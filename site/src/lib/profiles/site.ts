// Build-time display of player profiles (nick + avatar) written by scripts/fetch-profiles.ts.
import fs from 'node:fs';
import path from 'node:path';
import { playerKey } from './core.ts';
import type { SiteProfile } from './build.ts';

export type { SiteProfile };

export function indexBySlug(players: { slug: string; name: string }[], profiles: Record<string, SiteProfile>) {
  const out = new Map<string, SiteProfile>();
  for (const p of players) {
    const prof = profiles[playerKey(p.name)];
    if (prof) out.set(p.slug, prof);
  }
  return out;
}

let cache: Map<string, SiteProfile> | undefined;
function index() {
  if (cache) return cache;
  const dir = process.env.SITE_DATA_DIR ?? path.resolve(process.cwd(), 'data');
  const read = (f: string) => (fs.existsSync(path.join(dir, f)) ? JSON.parse(fs.readFileSync(path.join(dir, f), 'utf8')) : null);
  const players = (read('players.json')?.players ?? []) as { slug: string; name: string }[];
  cache = indexBySlug(players, (read('profiles.json') ?? {}) as Record<string, SiteProfile>);
  return cache;
}

export const profileFor = (slug: string | undefined) => (slug ? index().get(slug) : undefined);
export const nameFor = (slug: string | undefined, fallback: string) => profileFor(slug)?.nick ?? fallback;

// site/scripts/fetch-profiles.ts
// Pre-build: public `profiles` from Firestore → data/profiles.json + public/avatars/.
// Never fails the build: on any error the site is built with sheet names.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { parseRestPage, selectProfiles, type RestProfile } from '../src/lib/profiles/build.ts';

const URL_BASE = 'https://firestore.googleapis.com/v1/projects/familymafiaapp/databases/(default)/documents/profiles?pageSize=300';

export async function fetchProfiles(opts: { fetch: typeof fetch; dataDir: string; publicDir: string; log: (s: string) => void }) {
  const out = path.join(opts.dataDir, 'profiles.json');
  const avatarsDir = path.join(opts.publicDir, 'avatars');
  fs.rmSync(avatarsDir, { recursive: true, force: true });
  try {
    const docs: RestProfile[] = [];
    let token: string | undefined;
    do {
      const res = await opts.fetch(token ? `${URL_BASE}&pageToken=${encodeURIComponent(token)}` : URL_BASE);
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const page = parseRestPage(await res.json());
      docs.push(...page.docs);
      token = page.next;
    } while (token);
    const { players } = JSON.parse(fs.readFileSync(path.join(opts.dataDir, 'players.json'), 'utf8')) as { players: { name: string }[] };
    const { profiles, files, warnings } = selectProfiles(players.map((p) => p.name), docs);
    warnings.forEach((w) => opts.log(`fetch-profiles: ${w}`));
    for (const f of files) {
      fs.mkdirSync(path.dirname(path.join(opts.publicDir, f.path)), { recursive: true });
      fs.writeFileSync(path.join(opts.publicDir, f.path), f.bytes);
    }
    fs.writeFileSync(out, JSON.stringify(profiles));
    opts.log(`fetch-profiles: ${Object.keys(profiles).length} profiles, ${files.length} avatars`);
  } catch (e) {
    opts.log(`fetch-profiles: WARNING ${(e as Error).message} — building with sheet names`);
    fs.writeFileSync(out, '{}');
  }
}

if (process.argv[1] && fileURLToPath(import.meta.url) === path.resolve(process.argv[1])) {
  await fetchProfiles({
    fetch,
    dataDir: process.env.SITE_DATA_DIR ?? path.resolve('data'),
    publicDir: path.resolve('public'),
    log: console.log,
  });
}

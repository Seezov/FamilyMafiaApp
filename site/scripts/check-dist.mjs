// Post-build guards: no API keys, every internal link resolves, every player has a page.
import fs from 'node:fs';
import path from 'node:path';

const dist = path.resolve('dist');
const dataDir = process.env.SITE_DATA_DIR ?? path.resolve('data');
const base = '/FamilyMafiaApp/';
const errors = [];
// The Firebase web key is public by design (firestore.rules guard the data);
// it is the only key allowed in the build.
const fbConfig = fs.readFileSync(path.resolve('src/lib/hosting/firebase-config.ts'), 'utf8');
const allowedKey = fbConfig.match(/apiKey:\s*'([^']+)'/)?.[1];

const walk = (dir) =>
  fs.readdirSync(dir, { withFileTypes: true }).flatMap((e) =>
    e.isDirectory() ? walk(path.join(dir, e.name)) : [path.join(dir, e.name)]);
const files = walk(dist);

for (const file of files) {
  const text = fs.readFileSync(file, 'latin1');
  const keys = text.match(/AIza[0-9A-Za-z_-]{35}/g) ?? [];
  if (keys.some((k) => k !== allowedKey)) errors.push(`API key pattern in ${path.relative(dist, file)}`);
  if (!file.endsWith('.html')) continue;
  for (const [, url] of text.matchAll(/(?:href|src)="([^"]+)"/g)) {
    if (!url.startsWith(base)) continue;
    const rel = decodeURI(url.slice(base.length).split(/[?#]/)[0]);
    let target = path.join(dist, rel);
    if (rel === '' || rel.endsWith('/')) target = path.join(target, 'index.html');
    if (!fs.existsSync(target)) errors.push(`${path.relative(dist, file)} → ${url}`);
  }
}

if (!fs.existsSync(path.join(dist, 'index.html'))) errors.push('dist/index.html is missing');

const { players } = JSON.parse(fs.readFileSync(path.join(dataDir, 'players.json'), 'utf8'));
for (const p of players) {
  if (!fs.existsSync(path.join(dist, 'players', p.slug, 'index.html'))) errors.push(`No page for player ${p.slug}`);
}

// Profiles: only nick/avatar may reach the site (no uid, no claim data).
const profilesFile = path.join(dataDir, 'profiles.json');
if (fs.existsSync(profilesFile)) {
  for (const [key, p] of Object.entries(JSON.parse(fs.readFileSync(profilesFile, 'utf8')))) {
    const extra = Object.keys(p).filter((k) => k !== 'nick' && k !== 'avatar');
    if (extra.length) errors.push(`profiles.json ${key} has ${extra.join(', ')}`);
  }
}
for (const file of files.filter((f) => f.endsWith('.html'))) {
  if (/[\w.+-]+@gmail\.com/i.test(fs.readFileSync(file, 'utf8'))) errors.push(`email address in ${path.relative(dist, file)}`);
}

if (errors.length) {
  console.error(`check-dist: ${errors.length} problem(s)\n` + errors.slice(0, 50).join('\n'));
  process.exit(1);
}
console.log(`check-dist: ${files.length} files, ${players.length} players, all links resolve`);

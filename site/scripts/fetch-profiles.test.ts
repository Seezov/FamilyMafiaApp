import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { describe, expect, it } from 'vitest';
import { fetchProfiles } from './fetch-profiles.ts';

const tmp = () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'profiles-'));
  const dataDir = path.join(root, 'data');
  fs.mkdirSync(dataDir);
  fs.writeFileSync(path.join(dataDir, 'players.json'), JSON.stringify({ players: [{ name: 'Braun', slug: 'braun' }] }));
  return { dataDir, publicDir: path.join(root, 'public') };
};
const json = (body: unknown) => new Response(JSON.stringify(body), { status: 200 });

describe('fetchProfiles', () => {
  it('writes profiles.json and avatar files, following page tokens', async () => {
    const dirs = tmp();
    const pages = [
      { documents: [{ name: 'projects/p/databases/(default)/documents/profiles/braun', fields: { player: { stringValue: 'Braun' }, avatar: { stringValue: 'data:image/webp;base64,UklGRg==' } } }], nextPageToken: 'p2' },
      { documents: [{ name: 'projects/p/databases/(default)/documents/profiles/ghost', fields: { player: { stringValue: 'Ghost' } } }] },
    ];
    const urls: string[] = [];
    await fetchProfiles({ ...dirs, log: () => {}, fetch: (async (u: string) => { urls.push(u); return json(pages.shift()); }) as typeof fetch });
    expect(urls[1]).toContain('pageToken=p2');
    const out = JSON.parse(fs.readFileSync(path.join(dirs.dataDir, 'profiles.json'), 'utf8'));
    expect(Object.keys(out)).toEqual(['braun']);
    expect(fs.existsSync(path.join(dirs.publicDir, out.braun.avatar))).toBe(true);
  });
  it('on a network error writes an empty profiles.json and does not throw', async () => {
    const dirs = tmp();
    const logs: string[] = [];
    await fetchProfiles({ ...dirs, log: (s) => logs.push(s), fetch: (async () => { throw new Error('offline'); }) as typeof fetch });
    expect(JSON.parse(fs.readFileSync(path.join(dirs.dataDir, 'profiles.json'), 'utf8'))).toEqual({});
    expect(logs.join('\n')).toMatch(/offline/);
  });
  it('treats a non-200 response as an error', async () => {
    const dirs = tmp();
    await fetchProfiles({ ...dirs, log: () => {}, fetch: (async () => new Response('no', { status: 500 })) as typeof fetch });
    expect(JSON.parse(fs.readFileSync(path.join(dirs.dataDir, 'profiles.json'), 'utf8'))).toEqual({});
  });
});

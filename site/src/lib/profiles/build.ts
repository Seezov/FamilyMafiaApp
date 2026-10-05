// Turns the public `profiles` collection into site data. Pure: no I/O.
import { createHash } from 'node:crypto';
import { cleanNick, isAvatar, nickError, playerKey } from './core.ts';

export interface RestProfile { player: string; nick?: string; avatar?: string }
export interface SiteProfile { nick?: string; avatar?: string }

type RestValue = { stringValue?: string };
type RestDoc = { fields?: Record<string, RestValue> };

export function parseRestPage(json: unknown): { docs: RestProfile[]; next?: string } {
  const body = (json ?? {}) as { documents?: RestDoc[]; nextPageToken?: string };
  const docs: RestProfile[] = [];
  for (const d of body.documents ?? []) {
    const f = d.fields ?? {};
    const player = f.player?.stringValue;
    if (!player) continue;
    const p: RestProfile = { player };
    if (f.nick?.stringValue !== undefined) p.nick = f.nick.stringValue;
    if (f.avatar?.stringValue !== undefined) p.avatar = f.avatar.stringValue;
    docs.push(p);
  }
  return { docs, next: body.nextPageToken };
}

export function selectProfiles(names: string[], docs: RestProfile[]) {
  const byKey = new Map(names.map((n) => [playerKey(n), n]));
  const profiles: Record<string, SiteProfile> = {};
  const files: { path: string; bytes: Uint8Array }[] = [];
  const warnings: string[] = [];
  const taken = new Set(names.map((n) => n.trim().toLowerCase()));
  // Code-point order, so the first-come nick is deterministic on every machine.
  const sorted = [...docs].sort((a, b) => (playerKey(a.player) < playerKey(b.player) ? -1 : 1));
  for (const d of sorted) {
    const key = playerKey(d.player);
    const name = byKey.get(key);
    if (!name) continue;
    const out: SiteProfile = {};
    if (d.nick !== undefined) {
      const nick = cleanNick(d.nick);
      const others = [...taken].filter((t) => t !== name.trim().toLowerCase());
      const err = nickError(nick, name, others);
      if (err) warnings.push(`profile ${name}: nick "${nick}" dropped — ${err}`);
      else if (nick && nick.toLowerCase() !== name.trim().toLowerCase()) {
        out.nick = nick;
        taken.add(nick.toLowerCase());
      }
    }
    if (d.avatar !== undefined) {
      if (!isAvatar(d.avatar)) warnings.push(`profile ${name}: avatar dropped — not a webp/jpeg data URL within the limit`);
      else {
        const [head, b64] = d.avatar.split(',');
        const bytes = Uint8Array.from(Buffer.from(b64, 'base64'));
        const ext = head.includes('jpeg') ? 'jpg' : 'webp';
        const path = `avatars/${createHash('sha1').update(bytes).digest('hex').slice(0, 8)}.${ext}`;
        files.push({ path, bytes });
        out.avatar = path;
      }
    }
    if (out.nick || out.avatar) profiles[key] = out;
  }
  return { profiles, files, warnings };
}

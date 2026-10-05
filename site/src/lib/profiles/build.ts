// Turns the public `profiles` collection into site data. Pure: no I/O.
import { createHash } from 'node:crypto';
import { cleanNick, isAvatar, nickError, playerKey } from './core.ts';

export interface RestProfile { id: string; player: string; nick?: string; avatar?: string }
export interface SiteProfile { nick?: string; avatar?: string }

type RestValue = { stringValue?: string };
type RestDoc = { name?: string; fields?: Record<string, RestValue> };

export function parseRestPage(json: unknown): { docs: RestProfile[]; next?: string } {
  const body = (json ?? {}) as { documents?: RestDoc[]; nextPageToken?: string };
  const docs: RestProfile[] = [];
  for (const d of body.documents ?? []) {
    const f = d.fields ?? {};
    const player = f.player?.stringValue;
    if (!player) continue;
    const p: RestProfile = { id: (d.name ?? '').split('/').pop() ?? '', player };
    if (f.nick?.stringValue !== undefined) p.nick = f.nick.stringValue;
    if (f.avatar?.stringValue !== undefined) p.avatar = f.avatar.stringValue;
    docs.push(p);
  }
  return { docs, next: body.nextPageToken };
}

export function selectProfiles(names: string[], docs: RestProfile[], aliases: Record<string, string> = {}) {
  const byKey = new Map(names.map((n) => [playerKey(n), n]));
  // An old spelling (renamed or merged player) → the player's current name.
  const owner = (player: string) => byKey.get(playerKey(player)) ?? aliases[player.trim().toLowerCase()];
  const profiles: Record<string, SiteProfile> = {};
  const files: { path: string; bytes: Uint8Array }[] = [];
  const warnings: string[] = [];
  const taken = new Set(names.map((n) => n.trim().toLowerCase()));
  const used = new Map<string, string>();
  // A profile made under the display name first, then code-point order, so the
  // winner is deterministic on every machine.
  const exact = (d: RestProfile) => (byKey.has(playerKey(d.player)) ? 0 : 1);
  const sorted = [...docs].sort((a, b) => exact(a) - exact(b) || (playerKey(a.player) < playerKey(b.player) ? -1 : 1));
  for (const d of sorted) {
    const name = owner(d.player);
    if (!name) continue;
    // The id comes from the claim the admin approved; only the key of the name it was made for is trusted.
    const docKey = playerKey(d.player);
    if (d.id !== docKey && safeDecode(d.id) !== docKey) {
      warnings.push(`profile ${name}: ignored — document id "${d.id}" is not this player's key`);
      continue;
    }
    const key = playerKey(name);
    if (used.has(key)) {
      warnings.push(`profile ${d.player}: ignored — ${name} already has the profile made for "${used.get(key)}"`);
      continue;
    }
    used.set(key, d.player);
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

function safeDecode(s: string) {
  try { return decodeURIComponent(s); } catch { return s; }
}

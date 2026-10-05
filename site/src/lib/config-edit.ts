// Edits to the club's tournament list (Firestore `config/club`), applied to
// the latest copy.

export interface ConfigEntry {
  season: number;
  type: string;
  name: string;
  games: number;
  date?: string;
  status?: string;
  podium: string[];
}

export interface SeasonConfigFile {
  tournaments?: ConfigEntry[];
  rejectedCandidates?: string[];
  [key: string]: unknown;
}

export type Op =
  | { kind: 'edit'; key: string; entry: ConfigEntry }
  | { kind: 'confirm'; key: string }
  | { kind: 'delete'; key: string }
  | { kind: 'add'; id: string; entry: ConfigEntry }
  | { kind: 'reject'; id: string };

export const entryKey = (e: { season: number; name: string }) => `${e.season}|${e.name}`;

/** The entry with keys in the file's order; empty optional fields dropped. */
export function normalize(e: ConfigEntry): ConfigEntry {
  return {
    season: e.season,
    type: e.type,
    name: e.name.trim(),
    games: e.games,
    ...(e.date?.trim() ? { date: e.date.trim() } : {}),
    ...(e.status ? { status: e.status } : {}),
    podium: e.podium.map((p) => p.trim()).filter(Boolean),
  };
}

/** First day of a `16.12.2023` / `16–17.12.2023` / `31.03–02.04.2024` date. */
export function startDay(date?: string): number | null {
  const m = date?.trim().match(/^(\d{1,2})(?:\.(\d{1,2}))?(?:\.(\d{4}))?(?:\s*[–—-]\s*(\d{1,2})(?:\.(\d{1,2}))?(?:\.(\d{4}))?)?$/);
  if (!m) return null;
  const month = m[2] ?? m[5];
  const year = m[3] ?? m[6];
  if (!month || !year) return null;
  return Date.UTC(+year, +month - 1, +m[1]);
}

/** Where a new entry goes: before the first dated entry of its season that
 * starts later, else after the season's last entry, else by season order. */
function insertAt(list: ConfigEntry[], e: ConfigEntry): number {
  const day = startDay(e.date);
  let lastOfSeason = -1;
  for (let i = 0; i < list.length; i++) {
    if (list[i].season !== e.season) continue;
    lastOfSeason = i;
    const d = startDay(list[i].date);
    if (day !== null && d !== null && d > day) return i;
  }
  if (lastOfSeason >= 0) return lastOfSeason + 1;
  const next = list.findIndex((t) => t.season > e.season);
  return next < 0 ? list.length : next;
}

/** Applies [ops] in order. Throws when an op's target is gone, so a stale
 * page never silently edits the wrong entry. */
export function applyOps(file: SeasonConfigFile, ops: Op[]): SeasonConfigFile {
  const list = [...(file.tournaments ?? [])];
  let rejected = [...(file.rejectedCandidates ?? [])];
  const find = (key: string) => {
    const i = list.findIndex((t) => entryKey(t) === key);
    if (i < 0) throw new Error(`"${key.split('|')[1]}" (S${key.split('|')[0]}) is no longer in the config`);
    return i;
  };
  for (const op of ops) {
    switch (op.kind) {
      case 'edit': {
        const i = find(op.key);
        const next = normalize(op.entry);
        if (next.season === list[i].season) list[i] = next;
        else { list.splice(i, 1); list.splice(insertAt(list, next), 0, next); }
        break;
      }
      case 'confirm': {
        const i = find(op.key);
        list[i] = normalize({ ...list[i], status: 'confirmed' });
        break;
      }
      case 'delete':
        list.splice(find(op.key), 1);
        break;
      case 'add': {
        const e = normalize(op.entry);
        if (list.some((t) => entryKey(t) === entryKey(e))) throw new Error(`"${e.name}" (S${e.season}) already exists`);
        list.splice(insertAt(list, e), 0, e);
        break;
      }
      case 'reject':
        if (!rejected.includes(op.id)) rejected = [...rejected, op.id].sort();
        break;
    }
  }
  const out: SeasonConfigFile = { ...file, tournaments: list };
  if (rejected.length) out.rejectedCandidates = rejected;
  return out;
}

/** Firestore `config/club` minus its author/time fields. */
export type ClubDoc = { tournaments: ConfigEntry[]; rejectedCandidates: string[]; gameLimits: Record<string, number> };

/** What /debug/ writes to `config/club`: normalized entries (no undefined
 * fields — Firestore rejects them) in the file's order. */
export const clubBody = (file: SeasonConfigFile, gameLimits: Record<string, number> = {}): ClubDoc => ({
  tournaments: (file.tournaments ?? []).map(normalize),
  rejectedCandidates: [...(file.rejectedCandidates ?? [])],
  gameLimits: { ...gameLimits },
});

// Edits to the season config's tournament list, applied to the latest file
// from GitHub and written back in the file's own layout.

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

// The file's layout: two-space indent at the top, one array element per line,
// each element on one line with ", " and ": " separators.
const inline = (v: unknown): string => {
  if (Array.isArray(v)) return `[${v.map(inline).join(', ')}]`;
  if (v && typeof v === 'object') {
    return `{${Object.entries(v).map(([k, x]) => `${JSON.stringify(k)}: ${inline(x)}`).join(', ')}}`;
  }
  return JSON.stringify(v);
};

const block = (list: unknown[]) => `[\n${list.map((x) => `    ${inline(x)}`).join(',\n')}\n  ]`;

/** [text] with its tournament list and rejected candidates replaced by
 * [file]'s; the rest (the season list, with its `0.0`s) stays byte for byte. */
export function rewriteConfig(text: string, file: SeasonConfigFile): string {
  const marker = '\n  "tournaments": [';
  const start = text.indexOf(marker);
  const close = text.indexOf('\n  ]', start);
  if (start < 0 || close < 0) throw new Error('Unexpected config layout: no tournaments block');
  const after = text
    .slice(close + '\n  ]'.length)
    .replace(/^,\n {2}"rejectedCandidates": \[[^\n]*\]/, '');
  const rejected = file.rejectedCandidates?.length
    ? `,\n  "rejectedCandidates": ${inline(file.rejectedCandidates)}`
    : '';
  return `${text.slice(0, start)}${marker.slice(0, -1)}${block(file.tournaments ?? [])}${rejected}${after}`;
}

/** A short commit message for [ops]. */
export function describe(ops: Op[]): string {
  const n = (k: Op['kind']) => ops.filter((o) => o.kind === k).length;
  const parts = [
    n('confirm') && `confirm ${n('confirm')}`,
    n('edit') && `edit ${n('edit')}`,
    n('add') && `add ${n('add')}`,
    n('delete') && `delete ${n('delete')}`,
    n('reject') && `reject ${n('reject')} candidate${n('reject') === 1 ? '' : 's'}`,
  ].filter(Boolean);
  return `tournaments (Debug page): ${parts.join(', ')}`;
}

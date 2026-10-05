export interface GameFilters { player: string | null; host: string | null }

export function parseFilters(search: string): GameFilters {
  const q = new URLSearchParams(search);
  return { player: q.get('player') || null, host: q.get('host') || null };
}

export function filtersToSearch(f: GameFilters): string {
  const q = new URLSearchParams();
  if (f.player) q.set('player', f.player);
  if (f.host) q.set('host', f.host);
  const s = q.toString();
  return s ? `?${s}` : '';
}

/** [keys] are the game's player keys (slug, or name for players without a page). */
export const matchesFilters = (keys: string[], host: string | undefined, f: GameFilters) =>
  (!f.player || keys.includes(f.player)) && (!f.host || host === f.host);

export function gameIdFromHash(hash: string): string | null {
  let id: string;
  try { id = decodeURIComponent(hash.replace(/^#/, '')); } catch { return null; }
  return /^g-[\w-]+$/.test(id) ? id : null;
}

/** What to show first: the linked game wins over a filter that would hide it. */
export function initialView(hash: string, filters: GameFilters, gameMatches: (id: string, f: GameFilters) => boolean) {
  const open = gameIdFromHash(hash);
  if (open && !gameMatches(open, filters)) return { open, filters: { player: null, host: null } };
  return { open, filters };
}

export function fmtPts(v: number | undefined): string {
  if (v === undefined) return '';
  const s = String(Math.round(v * 100) / 100);
  return s.startsWith('-') ? `−${s.slice(1)}` : s;
}

const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
export function dayLabel(date: string | null): string {
  if (!date) return 'No date';
  const [y, m, d] = date.split('-').map(Number);
  const wd = new Date(Date.UTC(y, m - 1, d)).getUTCDay();
  return `${days[wd]}, ${d} ${months[m - 1]} ${y}`;
}

/** A day's games grouped by table, in order of first appearance. An unknown
 * table counts as table 1 (the export's ids do), so both share one group.
 * `table` is null when the day has a single group (no heading needed). */
export function tableGroups<T extends { table?: number }>(games: T[]): { table: number | null; games: T[] }[] {
  const order: number[] = [];
  const by = new Map<number, T[]>();
  for (const g of games) {
    const t = g.table || 1;
    if (!by.has(t)) { by.set(t, []); order.push(t); }
    by.get(t)!.push(g);
  }
  return order.map((t) => ({ table: order.length > 1 ? t : null, games: by.get(t)! }));
}

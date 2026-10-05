import type { EventKind } from './points';

export interface EventDraft {
  year: number; kind: EventKind; name: string; date: string | null;
  stars: number | null; participants: number | null;
  results: { player: string; place: number }[];
}

/** Problems that keep [d] from being saved; empty when it is fine. */
export function validateEvent(d: EventDraft): string[] {
  const errors: string[] = [];
  if (!d.name.trim()) errors.push('Name is required');
  if (d.date !== null && !/^\d{4}-\d{2}-\d{2}$/.test(d.date)) errors.push('Date must be YYYY-MM-DD');
  if (d.results.length === 0) errors.push('Add at least one player');
  const seen = new Map<string, string>(); // lower-cased → as first entered
  d.results.forEach((r, i) => {
    if (!r.player.trim()) errors.push(`Row ${i + 1}: player is empty`);
    if (!Number.isInteger(r.place) || r.place < 1) errors.push(`Row ${i + 1}: place must be a whole number ≥ 1`);
    const key = r.player.trim().toLowerCase();
    if (key && seen.has(key)) errors.push(`${seen.get(key)} is listed twice`);
    else if (key) seen.set(key, r.player.trim());
  });
  if (d.kind === 'tournament') {
    if (d.stars === null || !Number.isInteger(d.stars) || d.stars < 0 || d.stars > 5) errors.push('Stars must be 0–5');
    const maxPlace = Math.max(0, ...d.results.map((r) => r.place).filter(Number.isFinite));
    if (d.participants === null || !Number.isInteger(d.participants) || d.participants < Math.max(1, maxPlace)) {
      errors.push(`Participants must be at least ${Math.max(1, maxPlace)}`);
    }
  }
  return errors;
}

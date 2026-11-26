import type { EventKind } from './points';

export interface EventDraft {
  year: number; kind: EventKind; name: string; date: string | null;
  stars: number | null; participants: number | null;
  results: { player: string; place: number }[];
}

/** Problems that keep [d] from being saved; empty when it is fine. */
export function validateEvent(d: EventDraft): string[] {
  const errors: string[] = [];
  if (!d.name.trim()) errors.push('Потрібна назва');
  if (d.date !== null && !/^\d{4}-\d{2}-\d{2}$/.test(d.date)) errors.push('Дата має бути у форматі РРРР-ММ-ДД');
  if (d.results.length === 0) errors.push('Додай хоча б одного гравця');
  const seen = new Map<string, string>(); // lower-cased → as first entered
  d.results.forEach((r, i) => {
    if (!r.player.trim()) errors.push(`Рядок ${i + 1}: не вказано гравця`);
    if (!Number.isInteger(r.place) || r.place < 1) errors.push(`Рядок ${i + 1}: місце має бути цілим числом ≥ 1`);
    const key = r.player.trim().toLowerCase();
    if (key && seen.has(key)) errors.push(`${seen.get(key)} записаний двічі`);
    else if (key) seen.set(key, r.player.trim());
  });
  if (d.kind === 'tournament') {
    if (d.stars === null || !Number.isInteger(d.stars) || d.stars < 0 || d.stars > 5) errors.push('Зірки мають бути 0–5');
    const maxPlace = Math.max(0, ...d.results.map((r) => r.place).filter(Number.isFinite));
    if (d.participants === null || !Number.isInteger(d.participants) || d.participants < Math.max(1, maxPlace)) {
      errors.push(`Учасників має бути щонайменше ${Math.max(1, maxPlace)}`);
    }
  }
  return errors;
}

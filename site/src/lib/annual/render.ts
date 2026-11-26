// HTML for /annual/edit/. Everything that comes from Firestore goes through esc():
// the rules cannot vouch for every string an admin (or a stolen session) saves.
import type { EventKind } from './points';
import type { EventDraft } from './validate';

export const esc = (s: unknown) =>
  String(s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]!);

export const LABEL: Record<EventKind, string> = { tournament: 'Турнір', series: 'Серія', marathon: 'Марафон', season: 'Сезон' };

/** One stored event in the list; season events (imported) can be deleted, not edited. */
export function eventRow(id: string, d: EventDraft, o: { canSave: boolean; confirming: boolean }): string {
  const i = esc(id);
  const buttons = !o.canSave ? '' : o.confirming
    ? `<button class="btn" data-del-yes="${i}">Видалити назавжди</button><button class="btn" data-del-no>Залишити</button>`
    : `${d.kind === 'season' ? '' : `<button class="btn" data-edit="${i}">Редагувати</button>`}<button class="btn" data-del="${i}">Видалити</button>`;
  const meta = `${d.date === null ? 'без дати' : esc(d.date)}${d.kind === 'tournament' ? ` · ${esc(d.stars)}★ · гравців: ${esc(d.participants)}` : ''} · результатів: ${d.results.length}`;
  return `<div class="ev"><span class="label">${esc(LABEL[d.kind] ?? d.kind)}</span><span class="name">${esc(d.name)}</span><span class="label">${meta}</span>${buttons}</div>`;
}

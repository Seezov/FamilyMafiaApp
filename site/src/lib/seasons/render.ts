// HTML for /seasons/edit/. Every Firestore value is escaped.
import { esc } from '../annual/render';
import type { ClubSeason } from './seasons';

export interface SeasonRow { id: number; title: string; source: string; startDate: string | null; games: number | null }

export const canDelete = (list: ClubSeason[], id: number, games: number) =>
  list.length > 0 && list[list.length - 1].id === id && games === 0;

export function seasonRow(r: SeasonRow, o: { deletable: boolean; confirming: boolean }): string {
  const del = !o.deletable ? '' : o.confirming
    ? `<button type="button" class="btn primary" data-act="delete-ok" data-id="${r.id}">Delete season ${r.id}</button>
       <button type="button" class="btn" data-act="cancel">Cancel</button>`
    : `<button type="button" class="btn" data-act="delete" data-id="${r.id}">Delete</button>`;
  return `<tr><td class="num">${r.id}</td><td>${esc(r.title)}</td><td>${esc(r.source)}</td>
    <td>${esc(r.startDate ?? '')}</td><td class="num">${r.games ?? ''}</td><td>${del}</td></tr>`;
}

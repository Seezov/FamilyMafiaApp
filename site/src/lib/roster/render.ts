// HTML for /players/edit/. Every roster value is escaped: the document is admin-written but public.
import { esc } from '../annual/render';
import type { RosterEntry } from './roster';

export type RowMode = 'rename' | 'merge' | null;

export const filterRoster = (r: RosterEntry[], q: string) => {
  const k = q.trim().toLowerCase();
  return k ? r.filter((e) => [e.name, ...e.nicknames].some((n) => n.toLowerCase().includes(k))) : r;
};

export function playerRow(e: RosterEntry, o: { canSave: boolean; mode: RowMode }): string {
  const p = esc(e.name);
  const nicks = e.nicknames.map((n) => `<span class="chip">${esc(n)}${o.canSave
    ? ` <button type="button" class="x" data-act="nick-remove" data-player="${p}" data-nick="${esc(n)}" aria-label="Remove ${esc(n)}">×</button>` : ''}</span>`).join(' ');
  const actions = !o.canSave ? '' : o.mode === 'rename'
    ? `<span class="act"><input name="to" value="${p}" aria-label="New name"> <button type="button" class="btn primary" data-act="rename-ok" data-player="${p}">Rename</button>
       <button type="button" class="btn" data-act="cancel">Cancel</button>
       <span class="hint">The old name stays as a nickname; the player's page URL changes.</span></span>`
    : o.mode === 'merge'
      ? `<span class="act"><input name="into" list="roster-names" placeholder="Merge into…" aria-label="Merge into"> <button type="button" class="btn primary" data-act="merge-ok" data-player="${p}">Merge</button>
         <button type="button" class="btn" data-act="cancel">Cancel</button>
         <span class="hint">${p} and its nicknames become nicknames of the chosen player; ${p} disappears from the list.</span></span>`
      : `<span class="act"><input name="nick" placeholder="Add nickname" aria-label="Add nickname"> <button type="button" class="btn" data-act="nick-add" data-player="${p}">Add</button>
         <button type="button" class="btn" data-act="rename" data-player="${p}">Rename</button>
         <button type="button" class="btn" data-act="merge" data-player="${p}">Merge into…</button></span>`;
  return `<div class="pl" data-player="${p}"><span class="name">${p}</span> ${nicks} ${actions}</div>`;
}

export function unresolvedRow(u: { name: string; games: number; lastSeason: number }, owner: string | undefined, canSave: boolean): string {
  const n = esc(u.name);
  const head = `<span class="name">${n}</span> <span class="label">${u.games} games · last S${u.lastSeason}</span>`;
  if (owner) return `<div class="un">${head} <span class="hint">now resolves to ${esc(owner)}</span></div>`;
  return `<div class="un">${head}${canSave ? ` <input name="attach" list="roster-names" placeholder="Attach to…" aria-label="Attach ${n} to">
    <button type="button" class="btn" data-act="attach" data-name="${n}">Attach</button>
    <button type="button" class="btn" data-act="new" data-name="${n}">New player</button>` : ''}</div>`;
}

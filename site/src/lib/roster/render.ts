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
    ? ` <button type="button" class="x" data-act="nick-remove" data-player="${p}" data-nick="${esc(n)}" aria-label="Прибрати ${esc(n)}">×</button>` : ''}</span>`).join(' ');
  const actions = !o.canSave ? '' : o.mode === 'rename'
    ? `<span class="act"><input name="to" value="${p}" aria-label="Нове ім'я"> <button type="button" class="btn primary" data-act="rename-ok" data-player="${p}">Перейменувати</button>
       <button type="button" class="btn" data-act="cancel">Скасувати</button>
       <span class="hint">Старе ім'я лишиться нікнеймом; адреса сторінки гравця зміниться.</span></span>`
    : o.mode === 'merge'
      ? `<span class="act"><input name="into" list="roster-names" placeholder="Об'єднати з…" aria-label="Об'єднати з"> <button type="button" class="btn primary" data-act="merge-ok" data-player="${p}">Об'єднати</button>
         <button type="button" class="btn" data-act="cancel">Скасувати</button>
         <span class="hint">${p} і його нікнейми стануть нікнеймами вибраного гравця; ${p} зникне зі списку.</span></span>`
      : `<span class="act"><input name="nick" placeholder="Додати нікнейм" aria-label="Додати нікнейм"> <button type="button" class="btn" data-act="nick-add" data-player="${p}">Додати</button>
         <button type="button" class="btn" data-act="rename" data-player="${p}">Перейменувати</button>
         <button type="button" class="btn" data-act="merge" data-player="${p}">Об'єднати з…</button></span>`;
  return `<div class="pl" data-player="${p}"><span class="name">${p}</span> ${nicks} ${actions}</div>`;
}

export function unresolvedRow(u: { name: string; games: number; lastSeason: number }, owner: string | undefined, canSave: boolean): string {
  const n = esc(u.name);
  const head = `<span class="name">${n}</span> <span class="label">ігор: ${u.games} · востаннє S${u.lastSeason}</span>`;
  if (owner) return `<div class="un">${head} <span class="hint">тепер належить ${esc(owner)}</span></div>`;
  return `<div class="un">${head}${canSave ? ` <input name="attach" list="roster-names" placeholder="Прив'язати до…" aria-label="Прив'язати ${n} до">
    <button type="button" class="btn" data-act="attach" data-name="${n}">Прив'язати</button>
    <button type="button" class="btn" data-act="new" data-name="${n}">Новий гравець</button>` : ''}</div>`;
}

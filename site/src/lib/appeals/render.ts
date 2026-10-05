// HTML for the appeal sections on /account/ and /account/admin/. Every value is escaped.
import { MAX_REQUESTED, MAX_TEXT, type Appeal, type HostTotal } from './core';

export const esc = (v: unknown) => String(v ?? '').replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]!);
const day = (iso: string) => iso.split('-').reverse().join('.');
const when = (ms?: number) => (ms ? new Date(ms).toLocaleDateString('uk-UA') : '');

export const gameTitle = (a: { date: string; table: number; gameNumber: number }) => `${day(a.date)} · Стіл ${a.table} · Гра ${a.gameNumber}`;

export function statusLabel(a: Appeal): string {
  if (a.status === 'accepted') return `прийнято +${a.granted}`;
  if (a.status === 'partial') return `частково +${a.granted} з ${a.requested}`;
  if (a.status === 'rejected') return 'відхилено';
  return 'на розгляді';
}

const form = (a: Appeal | null) => `<div class="ap-form">
  <label class="field">Чому ти заслуговуєш дод бал?
    <textarea id="ap-text" maxlength="${MAX_TEXT}" rows="4">${esc(a?.text ?? '')}</textarea></label>
  <label class="field">Очікуваний дод бал
    <input id="ap-req" inputmode="decimal" value="${esc(a?.requested ?? '')}" placeholder="0.5" /></label>
  <span class="label">Не більше ${MAX_REQUESTED}.</span>
  <div class="actions"><button class="btn sm primary" data-act="save" type="button">${a ? 'Зберегти' : 'Подати апеляцію'}</button>
    ${a ? '<button class="btn sm" data-act="withdraw" type="button">Відкликати</button>' : ''}
    <button class="btn sm" data-act="close" type="button">Скасувати</button></div></div>`;

export function myGameRow(r: { gameId: string; title: string; host: string; seat: number; appeal: Appeal | null }, open: boolean): string {
  const a = r.appeal;
  const head = `<span class="grow"><b>${esc(r.title)}</b> · ведучий ${esc(r.host)} · місце ${r.seat}</span>`;
  const state = a ? `<span class="st-${a.status}">${esc(statusLabel(a))}</span>` : '';
  const action = open ? '' : !a ? '<button class="btn sm" data-act="open" type="button">Подати апеляцію</button>'
    : a.status === 'pending' ? '<button class="btn sm" data-act="open" type="button">Змінити</button>' : '';
  const decided = a && a.status !== 'pending'
    ? `<p class="ap-note">Ти просив +${a.requested}: ${esc(a.text)}${a.adminComment ? `<br>Адмін: ${esc(a.adminComment)}` : ''}</p>` : '';
  return `<div class="box item" data-game="${esc(r.gameId)}">${head}${state}${action}${decided}${open ? form(a) : ''}</div>`;
}

export function pendingCard(a: Appeal, currentAdditional: number | null, gamesHref: string): string {
  const now = currentAdditional === null ? 'гру не знайдено' : `зараз дод ${currentAdditional}`;
  return `<div class="box ap-card" data-id="${esc(a.id)}">
    <p><b>${esc(a.player)}</b> · місце ${a.seat} · <a href="${esc(gamesHref)}">${esc(gameTitle(a))}</a> · ведучий ${esc(a.host)}
      <span class="label">подано ${when(a.createdAt)}</span></p>
    <p>Просить <b>+${a.requested}</b> (${now})</p>
    <p class="ap-text">${esc(a.text)}</p>
    <input class="ap-comment" maxlength="${MAX_TEXT}" placeholder="Коментар (необовʼязково)" />
    <div class="actions">
      <button class="btn sm primary" data-act="ap-accept" data-id="${esc(a.id)}" type="button">Прийняти +${a.requested}</button>
      <input class="ap-granted" inputmode="decimal" placeholder="скільки" aria-label="Скільки нарахувати" />
      <button class="btn sm" data-act="ap-partial" data-id="${esc(a.id)}" type="button">Частково</button>
      <button class="btn sm" data-act="ap-reject" data-id="${esc(a.id)}" type="button">Відхилити</button>
      <span class="ap-msg" aria-live="polite"></span>
    </div></div>`;
}

export const historyRow = (a: Appeal) => `<tr>
  <td>${when(a.createdAt)}</td><td>${esc(a.player)}</td><td>S${a.season} · ${esc(gameTitle(a))}</td><td>${esc(a.host)}</td>
  <td class="num">+${a.requested}</td><td class="st-${a.status}">${esc(statusLabel(a))}</td>
  <td>${esc(a.decidedBy ?? '')}</td><td>${when(a.decidedAt)}</td><td>${esc(a.adminComment ?? '')}</td>
  <td class="ap-text">${esc(a.text)}</td></tr>`;

export const totalsRows = (t: HostTotal[]) => t.map((h) => `<tr><td>${esc(h.host)}</td><td class="num">${h.total}</td>
  <td class="num">${h.pending}</td><td class="num">${h.accepted}</td><td class="num">${h.partial}</td>
  <td class="num">${h.rejected}</td><td class="num">+${h.points}</td></tr>`).join('');

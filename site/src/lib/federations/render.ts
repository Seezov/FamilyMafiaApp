// HTML for /federations/edit/. Every value from the candidates file or Firestore goes through esc().
import { esc } from '../annual/render';
import type { RosterEntry } from '../roster/roster';
import { candKey, FED_TITLES, FEDS, linkedKeys, profileUrl, rowStatus, type Candidate, type Fed, type FedDoc } from './core';

export type Filter = 'unreviewed' | 'confirmed' | 'nothing' | 'all';
export interface Row { entry: RosterEntry; cands: Candidate[] }
type RowOpts = { canSave: boolean; showRejected: boolean; shared: Map<string, string[]> };

const BADGE = { club: '<span class="badge club">в нашому клубі</span>', nick: '<span class="badge nick">збіг ніку</span>' };

function card(player: string, c: Candidate, o: RowOpts & { linked: boolean; rejected: boolean }): string {
  const p = esc(player);
  const others = (o.shared.get(candKey(c)) ?? []).filter((x) => x !== player);
  const where = [c.club, c.city].filter(Boolean).map(esc).join(' · ');
  const meta = [c.realName && esc(c.realName), where, c.games !== undefined && `${c.games} турн.`].filter(Boolean).join(' · ');
  const box = `<input type="checkbox" data-act="toggle" data-player="${p}" data-fed="${c.fed}" data-id="${esc(c.id)}"${o.linked ? ' checked' : ''}${o.canSave ? '' : ' disabled'}>`;
  return `<div class="cand${o.rejected ? ' rejected' : ''}${o.linked ? ' linked' : ''}">
    <label>${box} <a href="${esc(c.url)}" target="_blank" rel="noopener">${esc(c.nick)}</a></label> ${BADGE[c.strength]}
    ${meta ? `<div class="meta">${meta}</div>` : ''}
    ${others.length ? `<div class="warn">⚠ також у ${others.map(esc).join(', ')}</div>` : ''}
    ${o.rejected && o.canSave ? `<button type="button" class="btn small" data-act="unreject" data-player="${p}" data-key="${esc(candKey(c))}">Повернути</button>` : ''}
  </div>`;
}

export function fedRow(entry: RosterEntry, cands: Candidate[], d: FedDoc, o: RowOpts): string {
  const player = entry.name;
  const p = esc(player);
  const linked = linkedKeys(d, player);
  const rejected = new Set(d.rejected[player] ?? []);
  // Links added by hand (pasted URL, unmatched block) have no candidate entry: show them as bare cards.
  const all = [...cands];
  for (const k of linked) {
    if (!all.some((c) => candKey(c) === k)) {
      const [fed, id] = k.split(':') as [Fed, string];
      all.push({ fed, id, nick: `${FED_TITLES[fed]} #${id}`, url: profileUrl(fed, id), strength: 'nick' });
    }
  }
  const status = rowStatus(d, player, cands);
  const cols = FEDS.map((fed) => {
    const shown = all.filter((c) => c.fed === fed && (o.showRejected || !rejected.has(candKey(c)) || linked.has(candKey(c))));
    return `<div class="fed" data-fed-col="${fed}"><span class="label">${FED_TITLES[fed]}</span>${shown.map((c) =>
      card(player, c, { ...o, linked: linked.has(candKey(c)), rejected: rejected.has(candKey(c)) && !linked.has(candKey(c)) })).join('') || '<span class="none">—</span>'}</div>`;
  }).join('');
  const actions = o.canSave
    ? `<span class="act">${status === 'unreviewed' ? `<button type="button" class="btn" data-act="reviewed" data-player="${p}">Переглянуто</button>` : ''}
       <input name="url" placeholder="Посилання на профіль" aria-label="Посилання на профіль для ${p}"> <button type="button" class="btn" data-act="paste" data-player="${p}">Додати</button></span>`
    : '';
  return `<div class="row ${status}" data-player="${p}"><div class="head"><span class="name">${p}</span>${actions}</div><div class="feds">${cols}</div></div>`;
}

/** A club member on a federation that no roster nick matched; gone once linked to anyone. */
export function unmatchedRow(c: Candidate, d: FedDoc, canSave: boolean): string {
  const k = candKey(c);
  if (Object.keys(d.links).some((p) => linkedKeys(d, p).has(k))) return '';
  const meta = [c.realName, c.club, c.city].filter(Boolean).map(esc).join(' · ');
  return `<div class="un"><span class="label">${FED_TITLES[c.fed]}</span> <a href="${esc(c.url)}" target="_blank" rel="noopener">${esc(c.nick)}</a> ${meta ? `<span class="meta">${meta}</span>` : ''}${canSave
    ? ` <input name="attach" list="roster-names" placeholder="Гравець…" aria-label="Прив'язати ${esc(c.nick)} до"> <button type="button" class="btn" data-act="attach" data-fed="${c.fed}" data-id="${esc(c.id)}">Прив'язати</button>` : ''}</div>`;
}

export function filterRows(rows: Row[], d: FedDoc, f: Filter, q: string): Row[] {
  const k = q.trim().toLowerCase();
  return rows.filter((r) => {
    if (k && ![r.entry.name, ...r.entry.nicknames].some((n) => n.toLowerCase().includes(k))) return false;
    return f === 'all' || rowStatus(d, r.entry.name, r.cands) === f;
  });
}

// /account/admin/: approve or reject player claims; reset or unlink profiles. Rules re-check everything.
import { signIn } from '../lib/firebase';
import { decideClaim, explainAccountError, listClaims, listProfiles, onAccount, resetProfile, unlink, type AccountUser } from '../lib/account/store';
import { claimKeyOk, sortClaims, takenKeys, type Claim, type Profile } from '../lib/account/state';
import { decisionError, filterFromQuery, filterHistory, filterToQuery, hostTotals, parseAmount, type Appeal, type Decision, type HistoryFilter } from '../lib/appeals/core';
import { historyRow, pendingCard, totalsRows } from '../lib/appeals/render';
import { decideAppeal, explainAppealError, getGames, listAllAppeals } from '../lib/appeals/store';
import type { GameDoc } from '../lib/hosting/types';

const $ = <T extends HTMLElement>(id: string) => document.getElementById(id) as T;
const esc = (v: unknown) => String(v ?? '').replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]!);
const STATUS = { pending: 'чекає', approved: 'схвалено', rejected: 'відхилено' } as const;
let user: AccountUser | null = null;
let claims: Claim[] = [];
let profiles: Profile[] = [];
const adminPage = JSON.parse(document.getElementById('admin-data')!.textContent!) as { base: string };
let appeals: Appeal[] = [];
let games = new Map<string, GameDoc>();
let tab: 'new' | 'history' = new URLSearchParams(location.search).has('tab') ? 'history' : 'new';
let hf: HistoryFilter = filterFromQuery(new URLSearchParams(location.search));

async function loadAppeals() {
  try {
    appeals = await listAllAppeals();
    games = await getGames(appeals.filter((a) => a.status === 'pending').map((a) => a.gameId));
  } catch (e) { $('who').textContent = explainAppealError(e); }
  renderAppeals();
}

function renderAppeals() {
  const pending = appeals.filter((a) => a.status === 'pending').sort((a, b) => (a.createdAt ?? 0) - (b.createdAt ?? 0));
  $('new-count').textContent = pending.length ? `(${pending.length})` : '';
  $('tab-new').classList.toggle('on', tab === 'new');
  $('tab-history').classList.toggle('on', tab === 'history');
  $('appeals-new').hidden = tab !== 'new';
  $('appeals-history').hidden = tab !== 'history';
  $('appeals-new').innerHTML = pending.map((a) => {
    const g = games.get(a.gameId);
    const cur = g?.seats.find((s) => s.player === a.player)?.additional ?? (g ? 0 : null);
    return pendingCard(a, cur, `${adminPage.base}season/${a.season}/games/`);
  }).join('') || '<p class="label">Нових апеляцій немає.</p>';
  fillSelect('h-host', [...new Set(appeals.map((a) => a.host))].sort((a, b) => a.localeCompare(b, 'uk')), 'Усі ведучі');
  fillSelect('h-season', [...new Set(appeals.map((a) => String(a.season)))].sort((a, b) => +b - +a), 'Усі сезони');
  $<HTMLInputElement>('h-player').value = hf.player;
  $<HTMLSelectElement>('h-host').value = hf.host;
  $<HTMLSelectElement>('h-status').value = hf.status;
  $<HTMLSelectElement>('h-season').value = hf.season;
  const shown = filterHistory(appeals, hf);
  $('h-totals').innerHTML = totalsRows(hostTotals(shown));
  $('h-rows').innerHTML = shown.map(historyRow).join('') || '<tr><td colspan="10" class="label">Нічого не знайдено.</td></tr>';
}

function fillSelect(id: string, values: string[], all: string) {
  $(id).innerHTML = `<option value="">${all}</option>` + values.map((v) => `<option value="${esc(v)}">${esc(v)}</option>`).join('');
}

function syncUrl() {
  const q = filterToQuery(hf);
  const params = new URLSearchParams(q);
  if (tab === 'history') params.set('tab', 'history');
  history.replaceState(null, '', `${location.pathname}${params.toString() ? `?${params}` : ''}`);
}

$('tab-new').addEventListener('click', () => { tab = 'new'; syncUrl(); renderAppeals(); });
$('tab-history').addEventListener('click', () => { tab = 'history'; syncUrl(); renderAppeals(); });
$('appeals-history').addEventListener('input', () => {
  hf = { player: $<HTMLInputElement>('h-player').value, host: $<HTMLSelectElement>('h-host').value,
    status: $<HTMLSelectElement>('h-status').value as HistoryFilter['status'], season: $<HTMLSelectElement>('h-season').value };
  syncUrl();
  const shown = filterHistory(appeals, hf); // re-render only the tables so the player input keeps focus
  $('h-totals').innerHTML = totalsRows(hostTotals(shown));
  $('h-rows').innerHTML = shown.map(historyRow).join('') || '<tr><td colspan="10" class="label">Нічого не знайдено.</td></tr>';
});

async function load() {
  try { [claims, profiles] = await Promise.all([listClaims(), listProfiles()]); render(); }
  catch (e) { $('who').textContent = explainAccountError(e); }
}

function render() {
  const taken = takenKeys(profiles);
  $('claims').innerHTML = sortClaims(claims).map((c) => {
    const forged = !claimKeyOk(c);
    const busy = c.status !== 'approved' && taken.has(c.playerKey);
    const block = forged ? 'підроблена заявка' : busy ? 'вже привʼязаний' : '';
    return `<div class="box item"><span class="grow"><b>${esc(c.player)}</b> ← ${esc(c.googleName)} &lt;${esc(c.email)}&gt;
      <span class="label">${c.createdAt ? new Date(c.createdAt).toLocaleDateString('uk-UA') : ''}</span></span>
      <span class="st-${c.status}">${STATUS[c.status]}</span>
      ${c.status === 'pending' ? `<button class="btn sm primary" data-act="approve" data-uid="${esc(c.uid)}" ${block ? `disabled title="${block}"` : ''}>${block || 'Схвалити'}</button>
      <button class="btn sm" data-act="reject" data-uid="${esc(c.uid)}">Відхилити</button>` : ''}</div>`;
  }).join('') || '<p class="label">Заявок немає.</p>';
  $('profiles').innerHTML = profiles.map((p) => `<div class="box item">
      ${p.avatar ? `<img src="${esc(p.avatar)}" alt="" />` : ''}
      <span class="grow"><b>${esc(p.player)}</b>${p.nick ? ` → ${esc(p.nick)}` : ''}</span>
      ${p.nick ? `<button class="btn sm" data-act="reset-nick" data-key="${esc(p.key)}">Скинути нік</button>` : ''}
      ${p.avatar ? `<button class="btn sm" data-act="reset-avatar" data-key="${esc(p.key)}">Скинути аватарку</button>` : ''}
      <button class="btn sm" data-act="unlink" data-key="${esc(p.key)}">Відвʼязати</button></div>`).join('')
    || '<p class="label">Профілів ще немає.</p>';
}

document.addEventListener('click', async (e) => {
  const b = (e.target as HTMLElement).closest<HTMLButtonElement>('button[data-act]');
  if (!b || !user) return;
  if (['accept', 'partial', 'reject'].includes(b.dataset.act!)) return decide(b);
  // Destructive actions arm on the first tap and run on the second.
  if (b.dataset.act === 'unlink' && !b.dataset.armed) { b.dataset.armed = '1'; b.textContent = 'Точно відвʼязати?'; return; }
  b.disabled = true;
  try {
    const c = claims.find((x) => x.uid === b.dataset.uid);
    const p = profiles.find((x) => x.key === b.dataset.key);
    if (b.dataset.act === 'approve' && c) await decideClaim(c, true, user.email);
    if (b.dataset.act === 'reject' && c) await decideClaim(c, false, user.email);
    if (b.dataset.act === 'reset-nick' && p) await resetProfile(p.key, 'nick');
    if (b.dataset.act === 'reset-avatar' && p) await resetProfile(p.key, 'avatar');
    if (b.dataset.act === 'unlink' && p) await unlink(p);
    await load();
  } catch (err) {
    $('who').textContent = explainAccountError(err);
    b.disabled = false;
  }
});

async function decide(b: HTMLButtonElement) {
  const a = appeals.find((x) => x.id === b.dataset.id);
  const card = b.closest<HTMLElement>('.ap-card')!;
  const out = card.querySelector<HTMLElement>('.ap-msg')!;
  if (!a || !user) return;
  const d: Decision = {
    status: b.dataset.act === 'accept' ? 'accepted' : b.dataset.act === 'partial' ? 'partial' : 'rejected',
    adminComment: card.querySelector<HTMLInputElement>('.ap-comment')!.value,
    ...(b.dataset.act === 'partial' ? { granted: parseAmount(card.querySelector<HTMLInputElement>('.ap-granted')!.value) } : {}),
  };
  const err = decisionError(a, d);
  if (err) { out.className = 'ap-msg msg-error'; out.textContent = err; return; }
  card.querySelectorAll('button').forEach((x) => { x.disabled = true; });
  try { await decideAppeal(a, d, user); await loadAppeals(); }
  catch (e) {
    out.className = 'ap-msg msg-error'; out.textContent = explainAppealError(e);
    card.querySelectorAll('button').forEach((x) => { x.disabled = false; });
  }
}

$('sign-in').addEventListener('click', () => signIn().catch((e) => { $('gate-text').textContent = explainAccountError(e); }));
onAccount((u) => {
  user = u;
  $('who').textContent = u?.email ?? '';
  $('gate').hidden = !!u?.admin;
  $('admin').hidden = !u?.admin;
  if (u && !u.admin) { $('gate-text').textContent = 'Немає доступу.'; $('sign-in').hidden = true; }
  if (u?.admin) { load(); loadAppeals(); }
});

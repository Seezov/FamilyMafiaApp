// /account/admin/: approve or reject player claims; reset or unlink profiles. Rules re-check everything.
import { signIn } from '../lib/firebase';
import { decideClaim, deleteInvite, explainAccountError, listClaims, listInvites, listProfiles, onAccount, resetProfile, saveInvites, unlink, type AccountUser } from '../lib/account/store';
import { parseInvites, type Invite } from '../lib/account/invites';
import { aliasPairs } from '../lib/roster/roster';
import { loadRoster } from '../lib/roster/store';
import { playerKey } from '../lib/profiles/core';
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
const adminPage = JSON.parse(document.getElementById('admin-data')!.textContent!) as { base: string; aliases: [string, string][] };
const aliases = new Map(adminPage.aliases);
let invites: Invite[] = [];
// The baked roster is as of the last build; a player just added on /players/edit/ is known at once.
void loadRoster().then((r) => { if (r) { aliases.clear(); for (const [k, v] of aliasPairs(r)) aliases.set(k, v); } }).catch(() => { /* keep the baked list */ });
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
  try { [claims, profiles, invites] = await Promise.all([listClaims(), listProfiles(), listInvites().catch(() => [] as Invite[])]); render(); }
  catch (e) { $('who').textContent = explainAccountError(e); }
}

function render() {
  const taken = takenKeys(profiles);
  $('invites').innerHTML = [...invites].sort((a, b) => (b.createdAt ?? 0) - (a.createdAt ?? 0)).map((i) => `<div class="inv">
      <span class="grow"><b>${esc(i.player)}</b> ← ${esc(i.email)}
        <span class="label">${i.createdAt ? new Date(i.createdAt).toLocaleDateString('uk-UA') : ''}${i.createdBy ? ` · ${esc(i.createdBy)}` : ''}</span>
        ${taken.has(playerKey(i.player)) ? '<span class="warn">гравця вже привʼязано до іншого акаунта</span>' : ''}</span>
      <button class="btn sm" data-act="inv-delete" data-email="${esc(i.email)}">Видалити</button></div>`).join('')
    || '<p class="label">Запрошень, що чекають на вхід, немає.</p>';
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
  if (['ap-accept', 'ap-partial', 'ap-reject'].includes(b.dataset.act!)) return decide(b);
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
    if (b.dataset.act === 'inv-delete' && b.dataset.email) await deleteInvite(b.dataset.email);
    await load();
  } catch (err) {
    $('who').textContent = explainAccountError(err);
    b.disabled = false;
  }
});

$('inv-add').addEventListener('click', async () => {
  if (!user) return;
  const out = $('inv-msg');
  const { invites: list, errors } = parseInvites($<HTMLTextAreaElement>('inv-text').value, aliases);
  if (!list.length) { out.className = 'msg-error'; out.textContent = errors.join('\n') || 'Впиши хоча б один рядок: імейл — нік.'; return; }
  const btn = $<HTMLButtonElement>('inv-add');
  btn.disabled = true;
  try {
    await saveInvites(list, user.email);
    $<HTMLTextAreaElement>('inv-text').value = errors.length ? $<HTMLTextAreaElement>('inv-text').value : '';
    out.className = errors.length ? 'msg-warn' : '';
    out.textContent = `Додано запрошень: ${list.length}.` + (errors.length ? `\nПропущено:\n${errors.join('\n')}` : '');
    await load();
  } catch (e) { out.className = 'msg-error'; out.textContent = explainAccountError(e); }
  btn.disabled = false;
});

async function decide(b: HTMLButtonElement) {
  const a = appeals.find((x) => x.id === b.dataset.id);
  const card = b.closest<HTMLElement>('.ap-card')!;
  const out = card.querySelector<HTMLElement>('.ap-msg')!;
  if (!a || !user) return;
  const d: Decision = {
    status: b.dataset.act === 'ap-accept' ? 'accepted' : b.dataset.act === 'ap-partial' ? 'partial' : 'rejected',
    adminComment: card.querySelector<HTMLInputElement>('.ap-comment')!.value,
    ...(b.dataset.act === 'ap-partial' ? { granted: parseAmount(card.querySelector<HTMLInputElement>('.ap-granted')!.value) } : {}),
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

// The /host/ page: sign-in, a host's games, and the protocol form.
import { docToForm, draftKey, emptyForm, eveningDate, formToDoc, nextGameNumber, pickDraft, wrapDraft } from '../lib/hosting/form';
import { supportFivePoints } from '../lib/hosting/points';
import { explainError, listSeasonGames, millis, onUser, saveGame, signIn, signOutUser, type HostUser } from '../lib/hosting/store';
import { ROLES, type FormState, type GameDoc, type Role } from '../lib/hosting/types';
import { validate } from '../lib/hosting/validate';

const page = JSON.parse(document.getElementById('host-data')!.textContent!) as { names: string[]; defaultSeason: number | null; aliases: [string, string][] };
const aliases = new Map(page.aliases);
const $ = <T extends HTMLElement>(id: string) => document.getElementById(id) as T;
const store = {
  get(k: string) { try { return localStorage.getItem(k); } catch { return null; } },
  set(k: string, v: string | null) { try { if (v === null) localStorage.removeItem(k); else localStorage.setItem(k, v); } catch { /* private mode */ } },
};
const today = () => eveningDate(); // the club evening: after midnight still counts as the day before
const esc = (v: unknown) => String(v ?? '').replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]!);
const ROLE_LETTER: Record<Role, string> = { 'Мирний': 'М', 'Мафія': 'Ч', 'Дон': 'Д', 'Шериф': 'Ш' };
const nextRole = (r: Role) => ROLES[(ROLES.indexOf(r) + 1) % ROLES.length];
const isNew = (name: string) => !!name.trim() && !page.names.includes(name.trim());

let user: HostUser | null = null;
let games: (GameDoc & { id: string })[] = [];
let form: FormState = emptyForm(page.defaultSeason, today());
let editing: { id: string; updatedAtMillis: number } | null = null;

function show(view: 'signed-out' | 'not-host' | 'list-view' | 'game-form') {
  for (const id of ['signed-out', 'not-host', 'list-view', 'game-form']) $(id).hidden = id !== view;
}

// ── Draft (per game id) ───────────────────────────────────────────────────
const saveDraft = () => store.set(draftKey(editing?.id ?? null), wrapDraft(form, editing?.updatedAtMillis ?? null));
const loadDraft = (id: string | null, serverMillis: number | null) => pickDraft(store.get(draftKey(id)), serverMillis, today());

// ── List ──────────────────────────────────────────────────────────────────
async function refreshList() {
  const season = form.season ?? page.defaultSeason;
  games = season ? await listSeasonGames(season) : [];
  const visible = games
    .filter((g) => user!.admin || g.createdBy === user!.uid || g.date === today())
    .sort((a, b) => b.date.localeCompare(a.date) || a.table - b.table || b.gameNumber - a.gameNumber);
  const label = { city: 'Місто', mafia: 'Мафія', unrated: 'Не рейтинг' } as const;
  $('games').innerHTML = visible.length
    ? visible.map((g) => `<button class="box game-row" data-id="${esc(g.id)}" type="button">
        <b>${esc(g.date)}</b> · стіл ${esc(g.table)} · гра ${esc(g.gameNumber)} · ${esc(g.host)} · ${esc(label[g.result] ?? g.result)}</button>`).join('')
    : '<p class="label">Ігор ще немає.</p>';
}

// ── Form rendering ────────────────────────────────────────────────────────
const num = (k: string, v: string, cls = '') =>
  `<td><input data-k="${k}" class="${cls}" inputmode="decimal" value="${esc(v)}" aria-label="${k}" /></td>`;

function renderSeats() {
  $('seats').querySelector('tbody')!.innerHTML = form.seats.map((s, i) => `
    <tr class="seat" data-i="${i}">
      <td>${i + 1}</td>
      <td class="pl"><input data-k="player" class="${isNew(s.player) ? 'new' : ''}" list="names" autocomplete="off"
        value="${esc(s.player)}" aria-label="Гравець ${i + 1}" title="${isNew(s.player) ? 'новий гравець' : ''}" /></td>
      <td><button type="button" class="role" data-role="${esc(s.role)}" title="${esc(s.role)}" aria-label="Роль: ${esc(s.role)}">${esc(ROLE_LETTER[s.role] ?? '?')}</button></td>
      <td><input data-k="fouls" type="number" min="0" max="4" inputmode="numeric" value="${esc(s.fouls || '')}" aria-label="Фоли" /></td>
      ${num('additional', s.additional)}${num('penalty', s.penalty)}${num('protocolAdditional', s.protocolAdditional)}${num('protocolPenalty', s.protocolPenalty)}
    </tr>`).join('');
}

const dot = (black: boolean) =>
  `<button type="button" class="dot ${black ? 'black' : 'red'}" data-k="color" aria-label="${black ? 'чорний' : 'червоний'}" title="${black ? 'чорний' : 'червоний'}"></button>`;

function renderSupport() {
  $('support').innerHTML = Array.from({ length: 5 }, (_, j) => {
    const g = form.supportFive[j] ?? 0;
    return `<span class="cell" data-j="${j}"><input data-k="slot" type="number" min="1" max="10" inputmode="numeric"
      value="${esc(g ? Math.abs(g) : '')}" aria-label="Опорна ${j + 1}" />${dot(g < 0)}</span>`;
  }).join('');
  renderOp();
}

function renderOp() {
  $('op-value').textContent = form.firstKilled
    ? `ОП гравця ${form.firstKilled}: ${supportFivePoints(form.supportFive, form.seats.map((s) => s.role)).toFixed(2)}`
    : '';
}

function renderProtocol() {
  $('protocol').innerHTML = form.protocol.map((p, j) => `
    <div class="row" data-j="${j}">
      <label>вбитий <input data-k="slot" type="number" min="1" max="10" inputmode="numeric" value="${esc(p.slot || '')}" /></label>
      <label>версія <input data-k="version" type="number" min="1" max="10" inputmode="numeric" value="${esc(p.version ?? '')}" /></label>
      <label>колір <input data-k="cslot" type="number" min="1" max="10" inputmode="numeric" value="${esc(p.color?.slot ?? '')}" /></label>
      ${dot(!!p.color?.black)}
      <button class="x" type="button" data-remove aria-label="Прибрати">✕</button>
    </div>`).join('');
}

function renderComments() {
  $('comments').innerHTML = form.comments.map((c, j) => `
    <div class="row" data-j="${j}">
      <input data-k="slot" type="number" min="1" max="10" inputmode="numeric" value="${esc(c.slot || '')}" aria-label="Номер" placeholder="№" />
      <input data-k="text" value="${esc(c.text)}" aria-label="Коментар" />
      <button class="x" type="button" data-remove aria-label="Прибрати">✕</button>
    </div>`).join('');
}

function renderAll() {
  $<HTMLInputElement>('f-season').value = form.season?.toString() ?? '';
  $<HTMLInputElement>('f-date').value = form.date;
  $<HTMLSelectElement>('f-table').value = String(form.table);
  $<HTMLInputElement>('f-number').value = form.gameNumber?.toString() ?? '';
  $<HTMLInputElement>('f-host').value = form.host;
  $<HTMLInputElement>('f-first').value = form.firstKilled ? String(form.firstKilled) : '';
  document.querySelectorAll<HTMLInputElement>('input[name=result]').forEach((r) => { r.checked = r.value === form.result; });
  renderSeats(); renderSupport(); renderProtocol(); renderComments();
  showMessages(false);
}

function showMessages(highlight: boolean) {
  const r = validate(form, aliases);
  document.querySelectorAll('.invalid').forEach((el) => el.classList.remove('invalid'));
  if (highlight) {
    const map: Record<string, string> = { host: 'f-host', result: 'f-result', season: 'f-season', gameNumber: 'f-number', date: 'f-date', protocol: 'protocol', supportFive: 'support', roles: 'seats' };
    for (const f of r.fields) {
      const m = /^seat-(\d+)-player$/.exec(f);
      const el = m ? document.querySelector(`.seat[data-i="${+m[1] - 1}"] [data-k=player]`) : document.getElementById(map[f]);
      el?.classList.add('invalid');
    }
  }
  $('messages').innerHTML = [
    ...(highlight ? r.errors.map((e) => `<p class="msg-error">${esc(e)}</p>`) : []),
    ...r.warnings.map((w) => `<p class="msg-warn">⚠ ${esc(w)}</p>`),
  ].join('');
  return r;
}

const changed = () => { saveDraft(); renderOp(); showMessages(false); };

// ── Reading compound inputs back ──────────────────────────────────────────
const isBlackDot = (el: Element | null) => !!el?.classList.contains('black');

function readSupport() {
  form.supportFive = [...$('support').querySelectorAll<HTMLElement>('.cell')]
    .map((c) => {
      const n = Number(c.querySelector<HTMLInputElement>('[data-k=slot]')!.value) || 0;
      return isBlackDot(c.querySelector('.dot')) ? -n : n;
    })
    .filter((x) => x !== 0);
}

function readProtocolRow(row: HTMLElement) {
  const p = form.protocol[+row.dataset.j!];
  const v = (key: string) => Number(row.querySelector<HTMLInputElement>(`[data-k=${key}]`)!.value) || 0;
  p.slot = v('slot');
  p.version = v('version') || null;
  p.color = v('cslot') ? { slot: v('cslot'), black: isBlackDot(row.querySelector('.dot')) } : null;
}

function readCommentRow(row: HTMLElement) {
  const c = form.comments[+row.dataset.j!];
  c.slot = Number(row.querySelector<HTMLInputElement>('[data-k=slot]')!.value) || 0;
  c.text = row.querySelector<HTMLInputElement>('[data-k=text]')!.value;
}

function onEdit(t: HTMLInputElement | HTMLSelectElement) {
  const seat = t.closest<HTMLElement>('.seat');
  const row = t.closest<HTMLElement>('.row');
  const k = t.dataset.k;
  if (t.id === 'f-season') form.season = t.value ? Number(t.value) : null;
  else if (t.id === 'f-date') {
    form.date = t.value;
    if (!editing) { form.gameNumber = nextGameNumber(games, form.date, form.table); $<HTMLInputElement>('f-number').value = String(form.gameNumber); }
  }
  else if (t.id === 'f-number') form.gameNumber = t.value ? Number(t.value) : null;
  else if (t.id === 'f-host') form.host = t.value;
  else if (t.id === 'f-table') {
    form.table = Number(t.value) as 1 | 2;
    if (!editing) { form.gameNumber = nextGameNumber(games, form.date, form.table); $<HTMLInputElement>('f-number').value = String(form.gameNumber); }
  } else if (t.id === 'f-first') {
    form.firstKilled = Number(t.value) || 0;
    if (form.firstKilled && !form.protocol.length) { form.protocol = [{ slot: form.firstKilled, version: null, color: null }]; renderProtocol(); }
  } else if (t.getAttribute('name') === 'result') form.result = t.value as FormState['result'];
  else if (seat && k) {
    const s = form.seats[+seat.dataset.i!];
    if (k === 'fouls') s.fouls = Math.max(0, Math.min(4, Number(t.value) || 0));
    else (s as unknown as Record<string, string>)[k] = t.value;
    if (k === 'player') { t.classList.toggle('new', isNew(t.value)); t.title = isNew(t.value) ? 'новий гравець' : ''; }
  } else if (t.closest('#support')) readSupport();
  else if (row?.parentElement?.id === 'protocol') readProtocolRow(row);
  else if (row?.parentElement?.id === 'comments') readCommentRow(row);
  changed();
}

$('game-form').addEventListener('input', (e) => {
  const t = e.target as HTMLInputElement;
  if (t.tagName !== 'SELECT') onEdit(t);
});
$('game-form').addEventListener('change', (e) => {
  const t = e.target as HTMLInputElement | HTMLSelectElement;
  if (t.tagName === 'SELECT' || t.getAttribute('name') === 'result') onEdit(t);
});

$('game-form').addEventListener('click', (e) => {
  const t = e.target as HTMLElement;
  if (t.classList.contains('role')) {
    const s = form.seats[+t.closest<HTMLElement>('.seat')!.dataset.i!];
    s.role = nextRole(s.role);
    t.dataset.role = s.role; t.textContent = ROLE_LETTER[s.role]; t.title = s.role;
    t.setAttribute('aria-label', `Роль: ${s.role}`);
    changed();
  } else if (t.classList.contains('dot')) {
    const black = !t.classList.contains('black');
    t.classList.toggle('black', black); t.classList.toggle('red', !black);
    t.title = black ? 'чорний' : 'червоний'; t.setAttribute('aria-label', t.title);
    const row = t.closest<HTMLElement>('.row');
    if (t.closest('#support')) readSupport(); else if (row) readProtocolRow(row);
    changed();
  } else if (t.hasAttribute('data-remove')) {
    const row = t.closest<HTMLElement>('.row')!;
    const isProtocol = row.parentElement!.id === 'protocol';
    (isProtocol ? form.protocol : form.comments).splice(+row.dataset.j!, 1);
    if (isProtocol) renderProtocol(); else renderComments();
    changed();
  }
});

$('add-protocol').addEventListener('click', () => { form.protocol.push({ slot: 0, version: null, color: null }); renderProtocol(); changed(); });
$('add-comment').addEventListener('click', () => { form.comments.push({ slot: 0, text: '' }); renderComments(); changed(); });
$('cancel').addEventListener('click', async () => { show('list-view'); await refreshList(); });

$('game-form').addEventListener('submit', async (e) => {
  e.preventDefault();
  const r = showMessages(true);
  if (r.errors.length || !user) return;
  const btn = $<HTMLButtonElement>('save');
  if (btn.disabled) return;
  btn.disabled = true;
  try {
    await saveGame(formToDoc(form), editing, user);
    store.set(draftKey(editing?.id ?? null), null);
    $('messages').innerHTML = '<p>Гру збережено. У статистиці зʼявиться протягом години.</p>';
    // The button stays disabled until the list is back: a second tap must not save a copy.
    setTimeout(async () => { show('list-view'); btn.disabled = false; await refreshList(); }, 1200);
  } catch (err) {
    $('messages').innerHTML = `<p class="msg-error">${esc(explainError(err))}</p>`;
    btn.disabled = false;
  }
});

// ── Opening a game ────────────────────────────────────────────────────────
function openNew() {
  editing = null;
  form = loadDraft(null, null) ?? emptyForm(form.season ?? page.defaultSeason, today());
  if (form.gameNumber === null) form.gameNumber = nextGameNumber(games, form.date, form.table);
  show('game-form'); renderAll();
}

function openExisting(g: GameDoc & { id: string }) {
  editing = { id: g.id, updatedAtMillis: millis(g.updatedAt) };
  const draft = loadDraft(g.id, editing.updatedAtMillis);
  const stale = !draft && store.get(draftKey(g.id)) !== null;
  if (stale) store.set(draftKey(g.id), null);
  form = draft ?? docToForm(g);
  show('game-form'); renderAll();
  if (stale) $('messages').innerHTML = '<p class="msg-warn">⚠ Гру змінили після твоєї чернетки — показано збережену версію.</p>';
}

$('new-game').addEventListener('click', openNew);
$('l-season').addEventListener('change', async (e) => {
  form.season = Number((e.target as HTMLInputElement).value) || page.defaultSeason;
  await refreshList();
});
$('games').addEventListener('click', (e) => {
  const id = (e.target as HTMLElement).closest<HTMLElement>('[data-id]')?.dataset.id;
  const g = games.find((x) => x.id === id);
  if (g) openExisting(g);
});

// ── Auth ──────────────────────────────────────────────────────────────────
$('sign-in').addEventListener('click', () => signIn().catch((e) => { $('who').textContent = explainError(e); }));
for (const id of ['sign-out', 'sign-out-2']) $(id).addEventListener('click', () => signOutUser());

onUser(async (u) => {
  if (u === null) { user = null; $('who').textContent = ''; return show('signed-out'); }
  if (u === 'not-host') { user = null; return show('not-host'); }
  user = u;
  $('who').textContent = `${u.name}${u.admin ? ' · адмін' : ''}`;
  show('list-view');
  $<HTMLInputElement>('l-season').value = (form.season ?? page.defaultSeason)?.toString() ?? '';
  try { await refreshList(); } catch (e) { $('games').innerHTML = `<p class="msg-error">${esc(explainError(e))}</p>`; }
});

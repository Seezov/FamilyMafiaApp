// The /host/ page: sign-in, a host's games, and the protocol form.
import { docToForm, draftKey, emptyForm, formToDoc, nextGameNumber } from '../lib/hosting/form';
import { supportFivePoints } from '../lib/hosting/points';
import { explainError, listSeasonGames, millis, onUser, saveGame, signIn, signOutUser, type HostUser } from '../lib/hosting/store';
import { ROLES, type FormState, type GameDoc, type Role } from '../lib/hosting/types';
import { validate } from '../lib/hosting/validate';

const page = JSON.parse(document.getElementById('host-data')!.textContent!) as { names: string[]; defaultSeason: number | null };
const $ = <T extends HTMLElement>(id: string) => document.getElementById(id) as T;
const store = {
  get(k: string) { try { return localStorage.getItem(k); } catch { return null; } },
  set(k: string, v: string | null) { try { if (v === null) localStorage.removeItem(k); else localStorage.setItem(k, v); } catch { /* private mode */ } },
};
const today = () => new Date().toLocaleDateString('sv-SE'); // yyyy-mm-dd, local
const esc = (s: string) => s.replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]!);

let user: HostUser | null = null;
let games: (GameDoc & { id: string })[] = [];
let form: FormState = emptyForm(page.defaultSeason, today());
let editing: { id: string; updatedAtMillis: number } | null = null;

function show(view: 'signed-out' | 'not-host' | 'list-view' | 'game-form') {
  for (const id of ['signed-out', 'not-host', 'list-view', 'game-form']) $(id).hidden = id !== view;
}

// ── Draft (per game id) ───────────────────────────────────────────────────
const saveDraft = () => store.set(draftKey(editing?.id ?? null), JSON.stringify(form));
function loadDraft(id: string | null): FormState | null {
  try { const s = store.get(draftKey(id)); return s ? (JSON.parse(s) as FormState) : null; } catch { return null; }
}

// ── List ──────────────────────────────────────────────────────────────────
async function refreshList() {
  const season = form.season ?? page.defaultSeason;
  games = season ? await listSeasonGames(season) : [];
  const visible = games
    .filter((g) => user!.admin || g.createdBy === user!.uid || g.date === today())
    .sort((a, b) => b.date.localeCompare(a.date) || a.table - b.table || b.gameNumber - a.gameNumber);
  const label = { city: 'Місто', mafia: 'Мафія', unrated: 'Не рейтинг' } as const;
  $('games').innerHTML = visible.length
    ? visible.map((g) => `<button class="box game-row" data-id="${g.id}" type="button">
        <b>${g.date}</b> · стіл ${g.table} · гра ${g.gameNumber} · ${esc(g.host)} · ${label[g.result]}</button>`).join('')
    : '<p class="label">Ігор ще немає.</p>';
}

// ── Form rendering ────────────────────────────────────────────────────────
function renderSeats() {
  $('seats').innerHTML = form.seats.map((s, i) => `
    <div class="seat" data-i="${i}">
      <b>${i + 1}</b>
      <input data-k="player" list="names" autocomplete="off" placeholder="Гравець" value="${esc(s.player)}" aria-label="Гравець ${i + 1}" />
      <div class="roles nums">${ROLES.map((r) => `<button type="button" data-role="${r}" aria-pressed="${s.role === r}">${r}</button>`).join('')}</div>
      <div class="nums">
        <label>Фоли <input data-k="fouls" type="number" min="0" max="4" inputmode="numeric" value="${s.fouls}" /></label>
        <label>Доп <input data-k="additional" inputmode="decimal" value="${esc(s.additional)}" /></label>
        <label>Штраф <input data-k="penalty" inputmode="decimal" value="${esc(s.penalty)}" /></label>
        <label>ПрДод <input data-k="protocolAdditional" inputmode="decimal" value="${esc(s.protocolAdditional)}" /></label>
        <label>ПрШтраф <input data-k="protocolPenalty" inputmode="decimal" value="${esc(s.protocolPenalty)}" /></label>
      </div>
      <span class="label new-player" ${!s.player.trim() || page.names.includes(s.player.trim()) ? 'hidden' : ''}>новий гравець</span>
    </div>`).join('');
}

function renderSupport() {
  const rows = [...form.supportFive, ...(form.supportFive.length < 5 ? [0] : [])];
  $('support').innerHTML = rows.map((g, j) => `
    <div class="row" data-j="${j}">
      <label>Опорна ${j + 1} <input data-k="slot" type="number" min="1" max="10" inputmode="numeric" value="${g ? Math.abs(g) : ''}" /></label>
      <select data-k="color" aria-label="Колір"><option value="red" ${g >= 0 ? 'selected' : ''}>червоний</option><option value="black" ${g < 0 ? 'selected' : ''}>чорний</option></select>
    </div>`).join('');
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
      <label>Вбитий <input data-k="slot" type="number" min="1" max="10" inputmode="numeric" value="${p.slot || ''}" /></label>
      <label>Версія (шериф) <input data-k="version" type="number" min="1" max="10" inputmode="numeric" value="${p.version ?? ''}" /></label>
      <label>Колір: гравець <input data-k="cslot" type="number" min="1" max="10" inputmode="numeric" value="${p.color?.slot ?? ''}" /></label>
      <select data-k="cblack" aria-label="Колір"><option value="red" ${p.color?.black ? '' : 'selected'}>червоний</option><option value="black" ${p.color?.black ? 'selected' : ''}>чорний</option></select>
      <button class="btn" type="button" data-remove aria-label="Прибрати">✕</button>
    </div>`).join('');
}

function renderComments() {
  $('comments').innerHTML = form.comments.map((c, j) => `
    <div class="row" data-j="${j}">
      <input data-k="slot" type="number" min="1" max="10" inputmode="numeric" value="${c.slot || ''}" aria-label="Номер" />
      <input data-k="text" value="${esc(c.text)}" aria-label="Коментар" />
      <button class="btn" type="button" data-remove aria-label="Прибрати">✕</button>
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
  const r = validate(form);
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

// ── Form events ───────────────────────────────────────────────────────────
function readSupport() {
  const inputs = [...$('support').querySelectorAll<HTMLElement>('.row')].map((r) => {
    const n = Number(r.querySelector<HTMLInputElement>('[data-k=slot]')!.value) || 0;
    return r.querySelector<HTMLSelectElement>('[data-k=color]')!.value === 'black' ? -n : n;
  });
  form.supportFive = inputs.filter((x) => x !== 0);
  return inputs;
}

function readProtocolRow(row: HTMLElement) {
  const p = form.protocol[+row.dataset.j!];
  const v = (key: string) => Number(row.querySelector<HTMLInputElement>(`[data-k=${key}]`)!.value) || 0;
  p.slot = v('slot');
  p.version = v('version') || null;
  p.color = v('cslot') ? { slot: v('cslot'), black: row.querySelector<HTMLSelectElement>('[data-k=cblack]')!.value === 'black' } : null;
}

function onEdit(t: HTMLInputElement | HTMLSelectElement) {
  const seat = t.closest<HTMLElement>('.seat');
  const row = t.closest<HTMLElement>('.row');
  const k = t.dataset.k;
  if (t.id === 'f-season') form.season = t.value ? Number(t.value) : null;
  else if (t.id === 'f-date') form.date = t.value;
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
    if (k === 'player') seat.querySelector<HTMLElement>('.new-player')!.hidden = !t.value.trim() || page.names.includes(t.value.trim());
  } else if (row?.parentElement?.id === 'support') {
    const inputs = readSupport();
    // A filled last row grows a new empty one (up to 5).
    if (k === 'slot' && t.value && inputs.length < 5 && row.dataset.j === String(inputs.length - 1)) renderSupport();
  } else if (row?.parentElement?.id === 'protocol') {
    readProtocolRow(row);
  } else if (row?.parentElement?.id === 'comments') {
    const c = form.comments[+row.dataset.j!];
    c.slot = Number(row.querySelector<HTMLInputElement>('[data-k=slot]')!.value) || 0;
    c.text = row.querySelector<HTMLInputElement>('[data-k=text]')!.value;
  }
  changed();
}

$('game-form').addEventListener('input', (e) => {
  const t = e.target as HTMLInputElement;
  if (t.tagName !== 'SELECT') onEdit(t);
});
$('game-form').addEventListener('change', (e) => {
  const t = e.target as HTMLSelectElement;
  if (t.tagName === 'SELECT') onEdit(t);
});

$('game-form').addEventListener('click', (e) => {
  const t = e.target as HTMLElement;
  const role = t.dataset.role as Role | undefined;
  if (role) {
    form.seats[+t.closest<HTMLElement>('.seat')!.dataset.i!].role = role;
    t.parentElement!.querySelectorAll('button').forEach((b) => b.setAttribute('aria-pressed', String(b === t)));
    changed();
  }
  if (t.hasAttribute('data-remove')) {
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
  btn.disabled = true;
  try {
    await saveGame(formToDoc(form), editing, user);
    store.set(draftKey(editing?.id ?? null), null);
    $('messages').innerHTML = '<p>Гру збережено. У статистиці зʼявиться протягом години.</p>';
    setTimeout(async () => { show('list-view'); await refreshList(); }, 1200);
  } catch (err) {
    $('messages').innerHTML = `<p class="msg-error">${esc(explainError(err))}</p>`;
  } finally {
    btn.disabled = false;
  }
});

// ── Opening a game ────────────────────────────────────────────────────────
function openNew() {
  editing = null;
  form = loadDraft(null) ?? emptyForm(form.season ?? page.defaultSeason, today());
  if (form.gameNumber === null) form.gameNumber = nextGameNumber(games, form.date, form.table);
  show('game-form'); renderAll();
}

function openExisting(g: GameDoc & { id: string }) {
  editing = { id: g.id, updatedAtMillis: millis(g.updatedAt) };
  form = loadDraft(g.id) ?? docToForm(g);
  show('game-form'); renderAll();
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

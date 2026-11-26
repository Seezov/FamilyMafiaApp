// /players/edit/: admins edit the club's player list (Firestore config/players).
import { onClubUser, signIn, signOutUser, type ClubAdmin } from '../lib/club/store';
import { importRoster, loadRoster, saveRosterOp } from '../lib/roster/store';
import { dedupeRoster, fromAppJson, ownerOf, type RosterEntry, type RosterOp } from '../lib/roster/roster';
import { filterRoster, playerRow, unresolvedRow, type RowMode } from '../lib/roster/render';
import { esc } from '../lib/annual/render';

const IMPORT_URL = 'https://raw.githubusercontent.com/Seezov/FamilyMafiaApp/feature/flutter_migration/assets/raw/players.json';
const SHOWN = 100;
const $ = <T extends HTMLElement>(id: string) => document.getElementById(id) as T;
const unresolved = JSON.parse($('unresolved-data').textContent!) as { name: string; games: number; lastSeason: number }[];

let user: ClubAdmin | null | 'not-host' = null;
let roster: RosterEntry[] | null = null;
let mode: { player: string; mode: RowMode } | null = null;
let busy = false;
const canSave = () => typeof user === 'object' && user !== null && user.admin && roster !== null && !busy;

function say(text: string, error = false) {
  $('msg').textContent = text;
  $('msg').classList.toggle('error', error);
}

async function refresh() {
  try {
    roster = await loadRoster();
    $('state').textContent = roster ? `гравців: ${roster.length}` : 'Ще не імпортовано';
  } catch (e) {
    $('state').textContent = 'Не вдалося завантажити список';
    say(String(e), true);
  }
  render();
}

function render() {
  const r = roster ?? [];
  const shown = filterRoster(r, ($('q') as HTMLInputElement).value);
  $('list').innerHTML = shown.slice(0, SHOWN).map((e) => playerRow(e, { canSave: canSave(), mode: mode?.player === e.name ? mode.mode : null })).join('')
    + (shown.length > SHOWN ? `<p class="hint">${shown.length - SHOWN} more — refine the search.</p>` : '');
  $('unresolved').innerHTML = unresolved.map((u) => unresolvedRow(u, roster ? ownerOf(r, u.name) : undefined, canSave())).join('')
    || '<p class="hint">Every game name belongs to a player.</p>';
  $('roster-names').innerHTML = r.map((e) => `<option value="${esc(e.name)}">`).join('');
  $('add').toggleAttribute('disabled', !canSave());
  const admin = typeof user === 'object' && user !== null && user.admin;
  $('import').hidden = !(admin && roster === null);
  $('who').textContent = user === null ? 'Лише перегляд' : user === 'not-host' ? 'Не ведучий — лише перегляд' : `${user.name}${user.admin ? ' (адмін)' : ' — не адмін, лише перегляд'}`;
  $('sign-in').hidden = user !== null;
  $('sign-out').hidden = user === null;
}

async function run(op: RosterOp, done: string) {
  if (!canSave()) return;
  busy = true;
  render();
  try {
    roster = await saveRosterOp(op, user as ClubAdmin);
    mode = null;
    $('state').textContent = `гравців: ${roster.length}`;
    say(`${done} The site updates within an hour.`);
  } catch (e) {
    say((e as Error).message, true);
  } finally {
    busy = false;
    render();
  }
}

const inputIn = (el: Element, name: string) => (el.closest('.pl, .un')?.querySelector(`input[name="${name}"]`) as HTMLInputElement | null)?.value ?? '';

document.addEventListener('click', (ev) => {
  const b = (ev.target as HTMLElement).closest<HTMLElement>('[data-act]');
  if (!b) return;
  const player = b.dataset.player ?? '';
  const name = b.dataset.name ?? '';
  switch (b.dataset.act) {
    case 'nick-add': void run({ kind: 'nick-add', player, nick: inputIn(b, 'nick') }, `Нікнейм додано гравцю ${player}.`); break;
    case 'nick-remove': void run({ kind: 'nick-remove', player, nick: b.dataset.nick ?? '' }, `Нікнейм прибрано в гравця ${player}.`); break;
    case 'rename': mode = { player, mode: 'rename' }; render(); break;
    case 'merge': mode = { player, mode: 'merge' }; render(); break;
    case 'cancel': mode = null; render(); break;
    case 'rename-ok': void run({ kind: 'rename', player, to: inputIn(b, 'to') }, `${player} перейменовано.`); break;
    case 'merge-ok': void run({ kind: 'merge', from: player, into: inputIn(b, 'into') }, `${player} об'єднано.`); break;
    case 'attach': void run({ kind: 'nick-add', player: inputIn(b, 'attach'), nick: name }, `${name} прив'язано.`); break;
    case 'new': void run({ kind: 'add', name }, `${name} додано.`); break;
  }
});

$('add').addEventListener('click', () => {
  const input = $('new-name') as HTMLInputElement;
  void run({ kind: 'add', name: input.value }, `${input.value.trim()} додано.`).then(() => { input.value = ''; });
});
$('q').addEventListener('input', render);
$('sign-in').addEventListener('click', () => void signIn().catch((e) => say(String(e), true)));
$('sign-out').addEventListener('click', () => void signOutUser());
$('import').addEventListener('click', async () => {
  if (!canSaveImport()) return;
  busy = true;
  render();
  try {
    const res = await fetch(IMPORT_URL);
    if (!res.ok) throw new Error(`HTTP ${res.status} під час читання players.json`);
    const list = dedupeRoster(fromAppJson(await res.json()));
    await importRoster(list, user as ClubAdmin);
    say(`Імпортовано гравців: ${list.length}.`);
  } catch (e) {
    say((e as Error).message, true);
  } finally {
    busy = false;
    await refresh();
  }
});
const canSaveImport = () => typeof user === 'object' && user !== null && user.admin && roster === null && !busy;

onClubUser((u) => { user = u; render(); });
void refresh();

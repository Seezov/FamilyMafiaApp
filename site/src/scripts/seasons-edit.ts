// /seasons/edit/: admins open new club seasons (Firestore config/seasons).
import { onClubUser, signIn, signOutUser, type ClubAdmin } from '../lib/club/store';
import { createSeason, deleteNewestSeason, gamesCount, loadClubSeasons } from '../lib/seasons/store';
import { nextSeason, type ClubSeason } from '../lib/seasons/seasons';
import { canDelete, seasonRow } from '../lib/seasons/render';

const $ = <T extends HTMLElement>(id: string) => document.getElementById(id) as T;
const page = JSON.parse($('seasons-data').textContent!) as { json: { id: number; title: string; source: string }[]; lastJsonId: number; jsonMinGames: number };
const today = () => new Date().toLocaleDateString('sv-SE'); // YYYY-MM-DD, local day

let user: ClubAdmin | null | 'not-host' = null;
let club: ClubSeason[] = [];
const games = new Map<number, number>();
let confirming: number | null = null;
let busy = false;
const isAdmin = () => typeof user === 'object' && user !== null && user.admin;

function say(text: string, error = false) {
  $('msg').textContent = text;
  $('msg').classList.toggle('error', error);
}

async function refresh() {
  try {
    club = await loadClubSeasons();
    await Promise.all(club.map(async (s) => games.set(s.id, await gamesCount(s.id))));
    $('state').textContent = `${page.json.length + club.length} seasons`;
  } catch (e) {
    $('state').textContent = 'Could not load seasons';
    say(String(e), true);
  }
  render();
}

function render() {
  const rows = [
    ...club.slice().reverse().map((s) => seasonRow({ id: s.id, title: s.title, source: 'Firestore', startDate: s.startDate, games: games.get(s.id) ?? null },
      { deletable: isAdmin() && !busy && canDelete(club, s.id, games.get(s.id) ?? 1), confirming: confirming === s.id })),
    ...page.json.slice().reverse().map((s) => seasonRow({ ...s, startDate: null, games: null }, { deletable: false, confirming: false })),
  ];
  $('rows').innerHTML = rows.join('');
  const f = $('create') as HTMLFormElement;
  f.hidden = !isAdmin();
  const next = nextSeason(club, page.lastJsonId, page.jsonMinGames, today());
  $('create-title').textContent = `Create season ${next.id}`;
  if (!f.dataset.for || f.dataset.for !== String(next.id)) {
    f.dataset.for = String(next.id);
    (f.elements.namedItem('title') as HTMLInputElement).value = next.title;
    (f.elements.namedItem('min') as HTMLInputElement).value = String(next.smallLeagueMinGames);
    (f.elements.namedItem('start') as HTMLInputElement).value = next.startDate;
  }
  f.querySelector('button')!.toggleAttribute('disabled', busy);
  $('who').textContent = user === null ? 'Read-only' : user === 'not-host' ? 'Not a host — read-only' : `${user.name}${user.admin ? ' (admin)' : ' — not an admin, read-only'}`;
  $('sign-in').hidden = user !== null;
  $('sign-out').hidden = user === null;
}

async function run(work: () => Promise<ClubSeason[]>, done: string) {
  busy = true;
  render();
  try {
    club = await work();
    confirming = null;
    say(`${done} The site updates within an hour.`);
  } catch (e) {
    say((e as Error).message, true);
  } finally {
    busy = false;
    await refresh();
  }
}

$('create').addEventListener('submit', (ev) => {
  ev.preventDefault();
  if (!isAdmin() || busy) return;
  const f = ev.target as HTMLFormElement;
  const v = (n: string) => (f.elements.namedItem(n) as HTMLInputElement).value;
  const id = Number(f.dataset.for);
  void run(() => createSeason({ title: v('title'), smallLeagueMinGames: Number(v('min')), startDate: v('start') }, id, page.lastJsonId, user as ClubAdmin),
    `Season ${id} created.`);
});

document.addEventListener('click', (ev) => {
  const b = (ev.target as HTMLElement).closest<HTMLElement>('[data-act]');
  if (!b || !isAdmin() || busy) return;
  const id = Number(b.dataset.id);
  if (b.dataset.act === 'delete') { confirming = id; render(); }
  else if (b.dataset.act === 'cancel') { confirming = null; render(); }
  else if (b.dataset.act === 'delete-ok') void run(() => deleteNewestSeason(id, user as ClubAdmin), `Season ${id} deleted.`);
});

$('sign-in').addEventListener('click', () => void signIn().catch((e) => say(String(e), true)));
$('sign-out').addEventListener('click', () => void signOutUser());
onClubUser((u) => { user = u; render(); });
void refresh();

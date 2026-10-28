// /federations/edit/: admins confirm which federation profiles belong to roster players (Firestore config/federations).
import { onClubUser, signIn, signOutUser, type ClubAdmin } from '../lib/club/store';
import { loadRoster } from '../lib/roster/store';
import type { RosterEntry } from '../lib/roster/roster';
import { loadFeds, saveFedOp } from '../lib/federations/store';
import { candidatesFor, candKey, linkedKeys, parseProfileUrl, sharedLinks, type CandidatesFile, type Fed, type FedDoc, type FedOp } from '../lib/federations/core';
import { fedRow, filterRows, reviewRow, unmatchedRow, type Filter, type Row } from '../lib/federations/render';
import type { ReviewItem } from '../lib/federations/games';
import { esc } from '../lib/annual/render';

const SHOWN = 100;
const $ = <T extends HTMLElement>(id: string) => document.getElementById(id) as T;
const file = JSON.parse($('cands').textContent!) as CandidatesFile;
const review = JSON.parse($('review-data').textContent!) as ReviewItem[];

let user: ClubAdmin | null | 'not-host' = null;
let roster: RosterEntry[] | null = null;
let feds: FedDoc = { links: {}, rejected: {} };
let filter: Filter = 'unreviewed';
let busy = false;
const canSave = () => typeof user === 'object' && user !== null && user.admin && roster !== null && !busy;

function say(text: string, error = false) {
  $('msg').textContent = text;
  $('msg').classList.toggle('error', error);
}

const rows = (): Row[] => (roster ?? []).map((entry) => ({ entry, cands: candidatesFor(file, entry) }));

async function refresh() {
  try {
    [roster, feds] = await Promise.all([loadRoster(), loadFeds()]);
    $('state').textContent = roster ? `${roster.length} гравців` : 'Ростер ще не імпортовано';
  } catch (e) {
    $('state').textContent = 'Не вдалося завантажити';
    say(String(e), true);
  }
  render();
}

function render() {
  const all = rows();
  const q = ($('q') as HTMLInputElement).value;
  for (const b of document.querySelectorAll<HTMLElement>('[data-filter]')) {
    const f = b.dataset.filter as Filter;
    b.classList.toggle('on', f === filter);
    b.querySelector('span')!.textContent = String(filterRows(all, feds, f, q).length);
  }
  const shown = filterRows(all, feds, filter, q);
  const o = { canSave: canSave(), showRejected: ($('show-rejected') as HTMLInputElement).checked, shared: sharedLinks(feds) };
  $('list').innerHTML = shown.slice(0, SHOWN).map((r) => fedRow(r.entry, r.cands, feds, o)).join('')
    + (shown.length > SHOWN ? `<p class="hint">Ще ${shown.length - SHOWN} — уточніть пошук.</p>` : '')
    + (shown.length ? '' : '<p class="hint">Нічого.</p>');
  $('unmatched').innerHTML = file.unmatched.map((c) => unmatchedRow(c, feds, canSave())).join('') || '<p class="hint">Усі прив\'язані.</p>';
  $('review').innerHTML = review.map((r) => reviewRow(r, feds.gameDecisions?.[r.key], canSave())).join('') || '<p class="hint">Немає.</p>';
  $('roster-names').innerHTML = (roster ?? []).map((e) => `<option value="${esc(e.name)}">`).join('');
  $('who').textContent = user === null ? 'Read-only' : user === 'not-host' ? 'Not a host — read-only' : `${user.name}${user.admin ? ' (admin)' : ' — not an admin, read-only'}`;
  $('sign-in').hidden = user !== null;
  $('sign-out').hidden = user === null;
}

async function run(ops: FedOp[], done: string) {
  if (!canSave() || !ops.length) return;
  busy = true;
  render();
  try {
    for (const op of ops) feds = await saveFedOp(op, user as ClubAdmin);
    say(done);
  } catch (e) {
    say((e as Error).message, true);
  } finally {
    busy = false;
    render();
  }
}

const inputIn = (el: Element, name: string) => (el.closest('.row, .un')?.querySelector(`input[name="${name}"]`) as HTMLInputElement | null)?.value.trim() ?? '';

document.addEventListener('click', (ev) => {
  const t = ev.target as HTMLElement;
  const f = t.closest<HTMLElement>('[data-filter]');
  if (f) { filter = f.dataset.filter as Filter; render(); return; }
  const d = t.closest<HTMLElement>('[data-decide]');
  if (d) {
    const value = (d.dataset.decide || null) as 'same' | 'different' | null;
    void run([{ kind: 'decide', key: d.dataset.key ?? '', value }], value ? 'Рішення збережено.' : 'Рішення скасовано.');
    return;
  }
  const b = t.closest<HTMLElement>('[data-act]');
  if (!b || b.dataset.act === 'toggle') return;
  const player = b.dataset.player ?? '';
  switch (b.dataset.act) {
    case 'reviewed': {
      const entry = roster?.find((e) => e.name === player);
      if (!entry) return;
      const linked = linkedKeys(feds, player);
      const keys = candidatesFor(file, entry).map(candKey).filter((k) => !linked.has(k));
      void run([{ kind: 'reviewed', player, keys }], `${player}: решту кандидатів відхилено.`);
      break;
    }
    case 'unreject': void run([{ kind: 'unreject', player, key: b.dataset.key ?? '' }], `${player}: кандидата повернуто.`); break;
    case 'paste': {
      const p = parseProfileUrl(inputIn(b, 'url'));
      if (!p) { say('Не схоже на посилання на профіль imafia.org, emotion.games, fiim.world чи mafgame.org.', true); return; }
      void run([{ kind: 'link', player, ...p }], `${player}: профіль додано.`);
      break;
    }
    case 'attach': {
      const to = inputIn(b, 'attach');
      if (!roster?.some((e) => e.name === to)) { say(`«${to}» немає в ростері — оберіть гравця зі списку.`, true); return; }
      void run([{ kind: 'link', player: to, fed: b.dataset.fed as Fed, id: b.dataset.id ?? '' }], `Прив'язано до ${to}.`);
      break;
    }
  }
});

document.addEventListener('change', (ev) => {
  const b = ev.target as HTMLInputElement;
  if (b.dataset.act !== 'toggle') return;
  const op: FedOp = { kind: b.checked ? 'link' : 'unlink', player: b.dataset.player ?? '', fed: b.dataset.fed as Fed, id: b.dataset.id ?? '' };
  void run([op], `${op.player}: ${b.checked ? 'підтверджено' : 'знято'}.`);
});

$('q').addEventListener('input', render);
$('show-rejected').addEventListener('change', render);
$('sign-in').addEventListener('click', () => void signIn().catch((e) => say(String(e), true)));
$('sign-out').addEventListener('click', () => void signOutUser());

onClubUser((u) => { user = u; render(); });
void refresh();

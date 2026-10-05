// /annual/edit/: admins add, edit and delete the annual rating's events in Firestore.
import { onClubUser, signIn, signOutUser, type ClubAdmin } from '../lib/club/store';
import { deleteEvent, eventsEmpty, importEvents, loadEvents, saveEvent } from '../lib/annual/store';
import { eventPoints, type EventKind } from '../lib/annual/points';
import { validateEvent, type EventDraft } from '../lib/annual/validate';
import { esc, eventRow, LABEL } from '../lib/annual/render';

const IMPORT_URL = 'https://raw.githubusercontent.com/Seezov/FamilyMafiaApp/feature/flutter_migration/tool/import/annual_events.json';
const $ = <T extends HTMLElement>(id: string) => document.getElementById(id) as T;
const names = new Set((JSON.parse($('player-names').textContent!) as string[]).map((n) => n.toLowerCase()));

let user: ClubAdmin | null | 'not-host' = null;
let events: { id: string; data: EventDraft }[] = [];
let editing: { id: string | null; draft: EventDraft } | null = null;
let confirmDelete: string | null = null;
let busy = false;
const canSave = () => typeof user === 'object' && user !== null && user.admin;
const year = () => Number(($('year') as HTMLSelectElement).value);

function say(text: string, error = false) {
  const m = $('msg');
  m.textContent = text;
  m.classList.toggle('error', error);
}

async function refresh() {
  $('state').textContent = 'Loading…';
  try {
    events = (await loadEvents(year())).sort((a, b) => (b.data.date ?? '').localeCompare(a.data.date ?? '') || a.data.name.localeCompare(b.data.name));
    $('state').textContent = `${events.length} events in ${year()}`;
  } catch (e) {
    $('state').textContent = 'Could not load events';
    say(String(e), true);
  }
  render();
}

function render() {
  $('add').toggleAttribute('disabled', !canSave() || editing !== null);
  $('list').innerHTML = events.map(({ id, data: d }) => eventRow(id, d, { canSave: canSave(), confirming: confirmDelete === id }))
    .join('') || '<p class="hint">No stored events for this year (club seasons are added automatically).</p>';
  renderForm();
}

function renderForm() {
  const f = $('form') as HTMLFormElement;
  f.hidden = editing === null;
  if (!editing) { f.innerHTML = ''; return; }
  const d = editing.draft;
  const t = d.kind === 'tournament';
  f.innerHTML = `
    <div class="fields">
      <label>Kind <select name="kind">${(['tournament', 'series', 'marathon'] as EventKind[]).map((k) => `<option value="${k}" ${k === d.kind ? 'selected' : ''}>${LABEL[k]}</option>`).join('')}</select></label>
      <label>Name <input name="name" value="${esc(d.name)}" required></label>
      <label>Date <input name="date" type="date" value="${esc(d.date ?? '')}"></label>
      ${t ? `<label>Stars <input name="stars" type="number" min="0" max="5" value="${esc(d.stars ?? '')}"></label>
             <label>Participants <input name="participants" type="number" min="1" value="${esc(d.participants ?? '')}"></label>` : ''}
    </div>
    <div class="rows">
      ${d.results.map((r, i) => `
        <div class="r ${r.player.trim() && !names.has(r.player.trim().toLowerCase()) ? 'guest' : ''}" data-i="${i}">
          <input name="player" list="players" value="${esc(r.player)}" placeholder="Player" aria-label="Player ${i + 1}">
          <input name="place" type="number" min="1" value="${Number.isFinite(r.place) ? r.place : ''}" aria-label="Place ${i + 1}">
          <span class="num">${Number.isFinite(r.place) && r.place >= 1 ? eventPoints(d.kind, r.place, d.stars, d.participants).toFixed(2) : ''}</span>
          <button type="button" class="btn" data-rm="${i}" aria-label="Remove row ${i + 1}">×</button>
        </div>`).join('')}
    </div>
    <div><button type="button" class="btn" data-add-row>Add player</button></div>
    <ul class="errors">${validateEvent(d).map((e) => `<li>${esc(e)}</li>`).join('')}</ul>
    <div><button type="submit" class="btn primary" ${busy ? 'disabled' : ''}>Save</button> <button type="button" class="btn" data-cancel>Cancel</button></div>`;
}

/** Reads the form into editing.draft (keeps focus: only re-render on structural changes). */
function readForm() {
  if (!editing) return;
  const f = $('form') as HTMLFormElement;
  const val = (n: string) => (f.elements.namedItem(n) as HTMLInputElement | null)?.value ?? '';
  const int = (s: string) => (s.trim() === '' ? NaN : Number(s));
  const d = editing.draft;
  d.kind = val('kind') as EventKind;
  d.name = val('name');
  d.date = val('date') || null;
  d.stars = d.kind === 'tournament' && val('stars') !== '' ? int(val('stars')) : null;
  d.participants = d.kind === 'tournament' && val('participants') !== '' ? int(val('participants')) : null;
  d.results = [...f.querySelectorAll<HTMLElement>('.r')].map((row) => ({
    player: (row.querySelector('[name=player]') as HTMLInputElement).value,
    place: int((row.querySelector('[name=place]') as HTMLInputElement).value),
  }));
}

function updateLive() {
  if (!editing) return;
  const f = $('form');
  const d = editing.draft;
  f.querySelectorAll<HTMLElement>('.r').forEach((row, i) => {
    const r = d.results[i];
    row.classList.toggle('guest', !!r.player.trim() && !names.has(r.player.trim().toLowerCase()));
    row.querySelector('.num')!.textContent = Number.isFinite(r.place) && r.place >= 1 ? eventPoints(d.kind, r.place, d.stars, d.participants).toFixed(2) : '';
  });
  f.querySelector('.errors')!.innerHTML = validateEvent(d).map((e) => `<li>${esc(e)}</li>`).join('');
}

$('form').addEventListener('input', (ev) => {
  const kindChanged = (ev.target as HTMLElement).getAttribute('name') === 'kind';
  readForm();
  if (kindChanged) renderForm(); else updateLive();
});
$('form').addEventListener('change', (ev) => {
  if ((ev.target as HTMLElement).getAttribute('name') === 'kind') { readForm(); renderForm(); }
});
$('form').addEventListener('click', (ev) => {
  const b = (ev.target as HTMLElement).closest('button');
  if (!b || !editing) return;
  readForm();
  if (b.dataset.rm !== undefined) { editing.draft.results.splice(Number(b.dataset.rm), 1); renderForm(); }
  else if (b.hasAttribute('data-add-row')) {
    const next = Math.max(0, ...editing.draft.results.map((r) => (Number.isFinite(r.place) ? r.place : 0))) + 1;
    editing.draft.results.push({ player: '', place: next });
    renderForm();
  } else if (b.hasAttribute('data-cancel')) { editing = null; render(); }
});
$('form').addEventListener('submit', async (ev) => {
  ev.preventDefault();
  if (!editing || !canSave() || busy) return;
  readForm();
  const errors = validateEvent(editing.draft);
  if (errors.length) { updateLive(); return; }
  busy = true; renderForm();
  try {
    await saveEvent(editing.id, editing.draft, user as ClubAdmin);
    say(`Saved “${editing.draft.name}”. The site updates within an hour.`);
    editing = null;
    await refresh();
  } catch (e) { say(`Could not save: ${e}`, true); } finally { busy = false; renderForm(); }
});

$('list').addEventListener('click', async (ev) => {
  const b = (ev.target as HTMLElement).closest('button');
  if (!b || !canSave() || busy) return;
  if (b.dataset.edit) {
    const e = events.find((x) => x.id === b.dataset.edit)!;
    editing = { id: e.id, draft: structuredClone(e.data) };
    render();
  } else if (b.dataset.del) { confirmDelete = b.dataset.del; render(); }
  else if (b.hasAttribute('data-del-no')) { confirmDelete = null; render(); }
  else if (b.dataset.delYes) {
    busy = true;
    try { await deleteEvent(b.dataset.delYes, user as ClubAdmin); say('Deleted.'); confirmDelete = null; await refresh(); }
    catch (e) { say(`Could not delete: ${e}`, true); } finally { busy = false; }
  }
});

$('add').addEventListener('click', () => {
  editing = { id: null, draft: { year: year(), kind: 'tournament', name: '', date: null, stars: 3, participants: null, results: [{ player: '', place: 1 }] } };
  render();
});
$('year').addEventListener('change', () => { editing = null; confirmDelete = null; refresh(); });
$('sign-in').addEventListener('click', () => signIn().catch((e) => say(String(e), true)));
$('sign-out').addEventListener('click', () => signOutUser());
$('import').addEventListener('click', async () => {
  if (!canSave() || busy) return;
  busy = true;
  say('Importing…');
  try {
    const list = (await (await fetch(IMPORT_URL)).json()) as EventDraft[];
    await importEvents(list, user as ClubAdmin);
    say(`Imported ${list.length} events.`);
    $('import').hidden = true;
    await refresh();
  } catch (e) { say(`Import failed: ${e}`, true); } finally { busy = false; }
});

onClubUser(async (u) => {
  user = u;
  $('who').textContent = u === null ? 'Read-only' : u === 'not-host' ? 'Signed in, not a host — read-only' : `${u.name}${u.admin ? ' (admin)' : ' — not an admin, read-only'}`;
  $('sign-in').hidden = u !== null;
  $('sign-out').hidden = u === null;
  $('import').hidden = !(canSave() && (await eventsEmpty().catch(() => false)));
  render();
});
refresh();

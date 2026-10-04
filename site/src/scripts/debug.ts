// The Debug page: the live tournament list from GitHub, the games behind each
// entry from the build, and edits that are saved back as one commit.
import { applyOps, describe, entryKey, normalize, rewriteConfig, type ConfigEntry, type Op, type SeasonConfigFile } from '../lib/config-edit';
import { commitFiles, headSha, readFile, whoAmI } from '../lib/github';
import type { DebugData, DebugEvidence } from '../lib/types';

const data = JSON.parse(document.getElementById('debug-data')!.textContent!) as DebugData;
const base = document.getElementById('base')!.dataset.base!;
const repo = data.repo;
const [mainFile] = repo.files;
const $ = <T extends HTMLElement>(id: string) => document.getElementById(id) as T;

// ── Browser storage (all optional: the page works without it) ──────────────
const store = {
  get(k: string) { try { return localStorage.getItem(k); } catch { return null; } },
  set(k: string, v: string | null) {
    try { if (v === null) localStorage.removeItem(k); else localStorage.setItem(k, v); } catch { /* private mode */ }
  },
};
const TOKEN = 'fm-debug-token';
const OPS = 'fm-debug-ops';

let token = store.get(TOKEN);
let login: string | null = null;
let ops: Op[] = (() => { try { return JSON.parse(store.get(OPS) ?? '[]'); } catch { return []; } })();
let live: SeasonConfigFile | null = null;
let liveSha: string | null = null;
let busy = false;
const editing = new Set<string>();

const saveOps = () => store.set(OPS, ops.length ? JSON.stringify(ops) : null);

// ── Evidence from the build, found by key, else by season + date ────────────
const evidenceByKey = new Map(data.tournaments.map((t) => [t.key, t]));
const buildEntry = (e: ConfigEntry) =>
  evidenceByKey.get(entryKey(e)) ??
  data.tournaments.find((t) => t.season === e.season && t.date && t.date === e.date);

type Row =
  | { kind: 'tournament'; entry: ConfigEntry; key: string; pending: boolean }
  | { kind: 'candidate'; c: DebugData['candidates'][number]; pending: boolean; rejected: boolean };

function rows(): Row[] {
  const file = live ?? { tournaments: data.tournaments.map((t) => normalize({ ...t, date: t.date ?? undefined, status: t.status === 'sheet' ? undefined : t.status })) };
  let view = file;
  try { view = applyOps(file, ops); } catch { /* shown when saving */ }
  const touched = new Set(ops.flatMap((o) => ('key' in o ? [o.key] : []).concat('entry' in o ? [entryKey(o.entry)] : [])));
  const rejected = new Set(view.rejectedCandidates ?? []);
  const pendingIds = new Set(ops.flatMap((o) => ('id' in o ? [o.id] : [])));
  const taken = new Set((view.tournaments ?? []).map((t) => `${t.season}|${t.date ?? ''}`));
  const out: Row[] = (view.tournaments ?? []).map((entry) => ({
    kind: 'tournament', entry, key: entryKey(entry), pending: touched.has(entryKey(entry)),
  }));
  for (const c of data.candidates) {
    const added = c.suggested.date && taken.has(`${c.season}|${c.suggested.date}`) && !pendingIds.has(c.id);
    if (added) continue;
    if (pendingIds.has(c.id) && ops.some((o) => o.kind === 'add' && o.id === c.id)) continue;
    out.push({ kind: 'candidate', c, pending: pendingIds.has(c.id), rejected: rejected.has(c.id) });
  }
  return out;
}

// ── Filters ─────────────────────────────────────────────────────────────────
const FILTERS = [
  ['review', 'Needs review'], ['all', 'All tournaments'], ['detected', 'Auto-detected'], ['confirmed', 'Confirmed'],
  ['sheet', 'From sheet tabs'], ['differs', 'Podium differs'], ['candidates', 'Candidates'], ['rejected', 'Rejected'],
] as const;
type Filter = (typeof FILTERS)[number][0];
let filter: Filter = (new URLSearchParams(location.search).get('show') as Filter) || 'review';

const statusOf = (e: ConfigEntry) => e.status ?? 'sheet';
/** Enough of the entry's games are in the main game list to judge it;
 * tournaments with their own game tab have few or none there. */
const comparable = (e: ConfigEntry) => {
  const ev = buildEntry(e)?.evidence;
  return !!ev && ev.games >= e.games - 1;
};
const differs = (e: ConfigEntry) => {
  const b = buildEntry(e);
  return comparable(e) && b!.podiumMatches === false && b!.name === e.name && b!.podium.join() === e.podium.join();
};

function visible(r: Row): boolean {
  const season = $<HTMLSelectElement>('season').value;
  const q = $<HTMLInputElement>('q').value.trim().toLowerCase();
  const s = r.kind === 'tournament' ? r.entry.season : r.c.season;
  if (season && String(s) !== season) return false;
  if (q) {
    const text = r.kind === 'tournament'
      ? [r.entry.name, ...r.entry.podium].join(' ')
      : [r.c.suggested.name, ...r.c.evidence.standings.map((x) => x.t)].join(' ');
    if (!text.toLowerCase().includes(q)) return false;
  }
  if (r.kind === 'candidate') return filter === 'rejected' ? r.rejected : !r.rejected && (filter === 'candidates' || filter === 'review');
  switch (filter) {
    case 'review': return statusOf(r.entry) === 'detected' || differs(r.entry) || r.pending;
    case 'all': return true;
    case 'differs': return differs(r.entry);
    case 'detected': case 'confirmed': case 'sheet': return statusOf(r.entry) === filter;
    default: return false;
  }
}

// ── Rendering ───────────────────────────────────────────────────────────────
const esc = (s: unknown) => String(s ?? '').replace(/[&<>"']/g, (c) => `&#${c.charCodeAt(0)};`);
const typeLabel = (t: string) => data.types.find((x) => x.type === t)?.label ?? t;
const STATUS: Record<string, string> = { sheet: 'sheet tab', detected: 'auto-detected', confirmed: 'confirmed' };

function podium(list: string[]) {
  return list.length
    ? `<div class="pod">${list.map((p, i) => `<span class="p${i + 1}"><i>${i + 1}</i>${esc(p)}</span>`).join('')}</div>`
    : '<div class="flag bad">No podium</div>';
}

function evidence(ev: DebugEvidence | null | undefined, expectedGames?: number) {
  if (!ev) return '<div class="flag">None of its games are in the main game list (own tab or no date).</div>';
  const hosts = Object.entries(ev.hosts).map(([h, n]) => `${esc(h)}${n > 1 ? ` ×${n}` : ''}`).join(', ');
  const countFlag = expectedGames === undefined || ev.games === expectedGames ? ''
    : ev.games < expectedGames - 1
      ? ` <span class="flag">· only ${ev.games} of ${expectedGames} games are in the main list (own tab?)</span>`
      : ` <span class="flag">· found ${ev.games} games, entry says ${expectedGames}</span>`;
  const rowsHtml = ev.standings.map((s, i) => `<tr><td>${i + 1}</td><td>${s.link
    ? `<a href="${base}players/${esc(s.link)}/">${esc(s.t)}</a>` : esc(s.t)}</td><td>${s.pts.toFixed(2)}</td><td>${s.w}/${s.g}</td></tr>`).join('');
  return `<details class="ev"><summary>Games behind it: ${ev.games} · ${esc(ev.dates.join(', ') || 'no date')} · host ${hosts}${countFlag}</summary>
    <table><thead><tr><th>#</th><th>Player</th><th>Points</th><th>Won</th></tr></thead><tbody>${rowsHtml}</tbody></table></details>`;
}

function editForm(id: string, e: ConfigEntry, saveLabel: string) {
  const types = data.types.map((t) => `<option value="${t.type}" ${t.type === e.type ? 'selected' : ''}>${esc(t.label)}</option>`).join('');
  return `<form class="edit" data-form="${esc(id)}">
    <label class="wide">Name<input name="name" value="${esc(e.name)}" required></label>
    <label>Type<select name="type">${types}</select></label>
    <label>Season<input name="season" type="number" min="0" value="${e.season}" required></label>
    <label>Games<input name="games" type="number" min="1" value="${e.games}" required></label>
    <label>Date<input name="date" value="${esc(e.date ?? '')}" placeholder="dd.mm.yyyy"></label>
    ${[0, 1, 2].map((i) => `<label>${i + 1}${['st', 'nd', 'rd'][i]} place<input name="p${i}" value="${esc(e.podium[i] ?? '')}"></label>`).join('')}
    <div class="row"><button class="btn primary" type="submit">${saveLabel}</button><button class="btn" type="button" data-act="cancel" data-id="${esc(id)}">Cancel</button></div>
  </form>`;
}

function card(r: Row): string {
  if (r.kind === 'tournament') {
    const e = r.entry;
    const st = statusOf(e);
    const b = buildEntry(e);
    const computed = b?.evidence?.standings.slice(0, 3).map((s) => s.t) ?? [];
    const acts = [
      st === 'detected' ? `<button class="btn primary" data-act="confirm" data-id="${esc(r.key)}">Confirm</button>` : '',
      `<button class="btn" data-act="edit" data-id="${esc(r.key)}">Edit</button>`,
      `<button class="btn danger" data-act="delete" data-id="${esc(r.key)}">Delete</button>`,
    ].join('');
    return `<article class="dbg-card st-${st} ${r.pending ? 'pending-op' : ''}">
      <div class="dbg-head"><span class="s">S${e.season}</span><span class="chip t-${esc(e.type)}">${esc(typeLabel(e.type))}</span>
        <span class="nm">${esc(e.name)}</span><span class="meta">${esc(e.date ?? 'no date')} · ${e.games} games</span>
        <span class="chip s-${st}">${STATUS[st] ?? esc(st)}</span>${r.pending ? '<span class="chip s-pending">unsaved</span>' : ''}
        <span class="acts">${acts}</span></div>
      ${podium(e.podium)}
      ${differs(e) ? `<div class="flag bad">The games give: ${computed.map(esc).join(' · ')}</div>` : ''}
      ${editing.has(r.key) ? editForm(r.key, e, 'Apply') : evidence(b?.evidence, e.games)}
    </article>`;
  }
  const { c } = r;
  const s = c.suggested;
  const acts = r.rejected ? '' : `<button class="btn primary" data-act="add" data-id="${esc(c.id)}">Add</button>
    <button class="btn" data-act="reject" data-id="${esc(c.id)}">Not a tournament</button>`;
  return `<article class="dbg-card st-candidate ${r.pending ? 'pending-op' : ''}">
    <div class="dbg-head"><span class="s">S${c.season}</span><span class="chip t-${esc(s.type)}">${esc(typeLabel(s.type))}?</span>
      <span class="nm">${esc(s.name)}</span><span class="meta">${esc(s.date ?? 'no date')} · ${s.games} games</span>
      <span class="chip s-candidate">${r.rejected ? 'rejected' : 'candidate'}</span>${r.pending ? '<span class="chip s-pending">unsaved</span>' : ''}
      <span class="acts">${acts}</span></div>
    ${podium(s.podium)}
    ${editing.has(c.id) ? editForm(c.id, { ...s, date: s.date ?? undefined, season: c.season }, 'Add') : evidence(c.evidence)}
  </article>`;
}

function render() {
  const all = rows();
  $('filters').innerHTML = FILTERS.map(([k, label]) => {
    const n = all.filter((r) => { const f = filter; filter = k; const v = visible(r); filter = f; return v; }).length;
    return `<button type="button" class="pill" role="tab" data-filter="${k}" aria-current="${k === filter}">${label} <b>${n}</b></button>`;
  }).join('');
  const shown = all.filter(visible);
  $('list').innerHTML = shown.length ? shown.map(card).join('') : '<p class="empty-list">Nothing here.</p>';
  const p = $('pending');
  p.hidden = ops.length === 0;
  $('pending-text').textContent = `${ops.length} unsaved change${ops.length === 1 ? '' : 's'}${token ? '' : ' · add a GitHub token to save'}`;
  $<HTMLButtonElement>('commit').disabled = !token || busy;
}

// ── Actions ─────────────────────────────────────────────────────────────────
const armed = new Set<string>();
function push(op: Op) { ops.push(op); saveOps(); render(); }

$('list').addEventListener('click', (ev) => {
  const b = (ev.target as HTMLElement).closest<HTMLButtonElement>('button[data-act]');
  if (!b) return;
  const id = b.dataset.id!;
  switch (b.dataset.act) {
    case 'confirm': push({ kind: 'confirm', key: id }); break;
    case 'edit': case 'add': editing.add(id); render(); break;
    case 'cancel': editing.delete(id); render(); break;
    case 'reject': push({ kind: 'reject', id }); break;
    case 'delete':
      if (!armed.has(id)) { armed.add(id); b.textContent = 'Sure? Delete'; setTimeout(() => armed.delete(id), 4000); return; }
      armed.delete(id); push({ kind: 'delete', key: id }); break;
  }
});

$('list').addEventListener('submit', (ev) => {
  ev.preventDefault();
  const f = ev.target as HTMLFormElement;
  const id = f.dataset.form!;
  const v = (n: string) => (f.elements.namedItem(n) as HTMLInputElement).value;
  const isCandidate = data.candidates.some((c) => c.id === id);
  const current = rows().find((r) => r.kind === 'tournament' && r.key === id);
  const entry: ConfigEntry = {
    season: +v('season'), type: v('type'), name: v('name'), games: +v('games'), date: v('date'),
    status: 'confirmed', podium: [v('p0'), v('p1'), v('p2')],
  };
  editing.delete(id);
  if (isCandidate) push({ kind: 'add', id, entry });
  else if (current?.kind === 'tournament') push({ kind: 'edit', key: id, entry: { ...entry, status: entry.status } });
});

$('filters').addEventListener('click', (ev) => {
  const b = (ev.target as HTMLElement).closest<HTMLButtonElement>('[data-filter]');
  if (!b) return;
  filter = b.dataset.filter as Filter;
  const u = new URL(location.href); u.searchParams.set('show', filter); history.replaceState(null, '', u);
  render();
});
$('season').addEventListener('change', render);
$('q').addEventListener('input', render);
$('discard').addEventListener('click', () => { ops = []; saveOps(); render(); });

// ── GitHub ──────────────────────────────────────────────────────────────────
async function loadLive() {
  try {
    liveSha = await headSha(repo, token);
    live = JSON.parse(await readFile(repo, mainFile, liveSha, token));
    $('live-state').textContent = `Live config @ ${liveSha.slice(0, 7)}`;
  } catch (e) {
    $('live-state').textContent = `Showing the build's copy (${(e as Error).message})`;
  }
  render();
}

async function refreshWho() {
  if (!token) { $('who').textContent = 'Read-only'; return; }
  try { login = await whoAmI(token); $('who').textContent = `Saving as @${login}`; }
  catch (e) { $('who').textContent = `Token rejected: ${(e as Error).message}`; }
}

$('token-form').addEventListener('submit', async (ev) => {
  ev.preventDefault();
  token = $<HTMLInputElement>('token').value.trim() || null;
  $<HTMLInputElement>('token').value = '';
  store.set(TOKEN, token);
  await refreshWho();
  render();
});
$('forget').addEventListener('click', () => { token = null; login = null; store.set(TOKEN, null); refreshWho(); render(); });

$('commit').addEventListener('click', async () => {
  if (!token || busy || !ops.length) return;
  busy = true; render();
  const text = $('pending-text');
  text.textContent = 'Saving…';
  try {
    let sha = '';
    for (let attempt = 0; ; attempt++) {
      const parent = await headSha(repo, token);
      const files = await Promise.all(repo.files.map(async (path) => {
        const original = await readFile(repo, path, parent, token);
        return { path, content: rewriteConfig(original, applyOps(JSON.parse(original), ops)) };
      }));
      try { sha = await commitFiles(repo, token, parent, files, `${describe(ops)}\n\nSaved by @${login ?? 'unknown'} from the site's Debug page.`); break; }
      catch (e) { if (attempt >= 1 || !/422|fast forward/i.test((e as Error).message)) throw e; }
    }
    ops = []; saveOps();
    busy = false;
    await loadLive();
    text.innerHTML = '';
    $('live-state').innerHTML = `Saved <a href="https://github.com/${repo.owner}/${repo.name}/commit/${sha}" target="_blank" rel="noopener">${sha.slice(0, 7)}</a>.
      The site redeploys in ~3 min (<a href="https://github.com/${repo.owner}/${repo.name}/actions" target="_blank" rel="noopener">progress</a>); the games shown update then.`;
  } catch (e) {
    busy = false;
    render();
    $('pending-text').textContent = `Not saved: ${(e as Error).message}`;
  }
});

render();
refreshWho();
loadLive();

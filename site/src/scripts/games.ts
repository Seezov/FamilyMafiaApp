import { filtersToSearch, initialView, matchesFilters, parseFilters, type GameFilters } from '../lib/games';

const players: { name: string; key: string }[] = JSON.parse(document.getElementById('games-players')!.textContent!);
const games = [...document.querySelectorAll<HTMLDetailsElement>('details.game')];
const input = document.getElementById('f-player') as HTMLInputElement;
const host = document.getElementById('f-host') as HTMLSelectElement;
const count = document.getElementById('count')!;

const keysOf = (g: HTMLElement) => (g.dataset.keys ?? '').split('|').filter(Boolean);
const matches = (g: HTMLElement, f: GameFilters) => matchesFilters(keysOf(g), g.dataset.host || undefined, f);

function apply(f: GameFilters) {
  let shown = 0;
  for (const g of games) {
    const ok = matches(g, f);
    g.hidden = !ok;
    if (ok) shown++;
    for (const p of g.querySelectorAll<HTMLElement>('.pick')) p.hidden = p.dataset.k !== f.player;
  }
  for (const group of document.querySelectorAll<HTMLElement>('.table-group, .day')) {
    const n = group.querySelectorAll('details.game:not([hidden])').length;
    group.hidden = n === 0;
    const c = group.querySelector('.day-count');
    if (c) {
      c.textContent = String(n);
      const u = group.querySelector('.day-unit');
      if (u) u.textContent = n === 1 ? 'game' : 'games';
    }
  }
  count.textContent = `${shown} ${shown === 1 ? 'game' : 'games'}`;
  input.value = players.find((p) => p.key === f.player)?.name ?? '';
  host.value = f.host ?? '';
}

function current(): GameFilters {
  const p = players.find((x) => x.name.toLowerCase() === input.value.trim().toLowerCase());
  return { player: p?.key ?? null, host: host.value || null };
}

function update() {
  const f = current();
  history.replaceState(null, '', location.pathname + filtersToSearch(f) + location.hash);
  apply(f);
}

input.addEventListener('change', update);
host.addEventListener('change', update);

const view = initialView(location.hash, parseFilters(location.search), (id, f) => {
  const g = document.getElementById(id);
  return !!g && matches(g, f);
});
apply(view.filters);
if (view.open) {
  const g = document.getElementById(view.open) as HTMLDetailsElement | null;
  if (g) { g.open = true; g.scrollIntoView({ block: 'start' }); }
  history.replaceState(null, '', location.pathname + filtersToSearch(view.filters) + location.hash);
}

document.addEventListener('click', async (e) => {
  const b = (e.target as HTMLElement).closest<HTMLButtonElement>('button.copy');
  if (!b) return;
  const url = `${location.origin}${location.pathname}#${b.dataset.id}`;
  try { await navigator.clipboard.writeText(url); b.textContent = 'Copied'; } catch { location.hash = b.dataset.id!; }
  setTimeout(() => (b.textContent = 'Copy link'), 1500);
});

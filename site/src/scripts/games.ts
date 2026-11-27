import { filtersToSearch, initialView, matchesFilters, parseFilters, type GameFilters } from '../lib/games';
import { GAMES, ukCount, ukWord } from '../lib/format';

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
    const visible = group.querySelectorAll<HTMLElement>('details.game:not([hidden])');
    const n = visible.length;
    const won = (r: string) => [...visible].filter((g) => g.dataset.result === r).length;
    const nc = group.querySelector('.n-city'), nm = group.querySelector('.n-mafia');
    if (nc) nc.textContent = String(won('city'));
    if (nm) nm.textContent = String(won('mafia'));
    group.hidden = n === 0;
    const c = group.querySelector('.day-count');
    if (c) {
      c.textContent = String(n);
      const u = group.querySelector('.day-unit');
      if (u) u.textContent = ukWord(n, GAMES);
    }
  }
  count.textContent = ukCount(shown, GAMES);
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
  try { await navigator.clipboard.writeText(url); b.textContent = 'Скопійовано'; } catch { location.hash = b.dataset.id!; }
  setTimeout(() => (b.textContent = 'Скопіювати посилання'), 1500);
});

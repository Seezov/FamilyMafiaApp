import { sortedIndices, type Dir } from '../lib/sort';
import type { SiteCell } from '../lib/types';

function cellOf(td: HTMLTableCellElement): SiteCell {
  const s = td.dataset.s;
  return { t: td.textContent?.trim() ?? '', s: s === undefined || s === '' ? undefined : Number(s) };
}

function renumber(root: HTMLElement) {
  root.querySelectorAll<HTMLTableSectionElement>('tbody').forEach((tb, i) => {
    const rank = tb.querySelector<HTMLElement>('[data-rank]');
    if (!rank) return;
    rank.textContent = String(i + 1);
    rank.classList.remove('r1', 'r2', 'r3');
    if (i < 3) rank.classList.add(`r${i + 1}`);
  });
}

function sortBy(root: HTMLElement, th: HTMLTableCellElement) {
  const table = root.querySelector('table')!;
  const col = Number(th.dataset.col);
  const current = th.getAttribute('aria-sort');
  const dir: Dir = current === 'descending' ? 'asc' : current === 'ascending' ? 'desc' : th.dataset.numeric ? 'desc' : 'asc';
  const bodies = [...table.tBodies];
  const rows = bodies.map((tb) => [...tb.rows[0].cells].filter((c) => !c.hasAttribute('data-rank')).map(cellOf));
  const order = sortedIndices(rows, col, dir);
  const collapsed = Number(root.dataset.collapsed) || undefined;
  order.forEach((i, pos) => {
    const tb = bodies[i];
    tb.classList.toggle('extra', collapsed !== undefined && pos >= collapsed);
    table.appendChild(tb);
  });
  root.querySelectorAll('th[data-col]').forEach((h) => h.removeAttribute('aria-sort'));
  root.querySelectorAll('.sorted').forEach((el) => el.classList.remove('sorted'));
  th.setAttribute('aria-sort', dir === 'desc' ? 'descending' : 'ascending');
  th.classList.add('sorted');
  table.querySelectorAll('tbody tr.row').forEach((tr) => {
    const cells = [...(tr as HTMLTableRowElement).cells].filter((c) => !c.hasAttribute('data-rank'));
    cells[col]?.classList.add('sorted');
  });
  renumber(root);
}

export function enhanceTables() {
  document.querySelectorAll<HTMLElement>('[data-table]').forEach((root) => {
    if (root.dataset.ready) return;
    root.dataset.ready = '1';
    renumber(root);
    root.querySelectorAll<HTMLTableCellElement>('th[data-col]').forEach((th) =>
      th.querySelector('button')?.addEventListener('click', () => sortBy(root, th)));
    root.querySelector('[data-more]')?.addEventListener('click', () => root.classList.add('open'));
    root.querySelectorAll<HTMLTableRowElement>('tr.tappable').forEach((tr) =>
      tr.addEventListener('click', (e) => {
        if ((e.target as HTMLElement).closest('a')) return;
        tr.parentElement?.classList.toggle('expanded');
      }));
  });
}

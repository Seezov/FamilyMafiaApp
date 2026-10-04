import type { SiteCell } from './types';

export type Dir = 'asc' | 'desc';

const collator = new Intl.Collator('uk');

export function compareCells(a: SiteCell, b: SiteCell): number {
  if (a.s !== undefined && b.s !== undefined) return a.s - b.s;
  return collator.compare(a.t, b.t);
}

/** Row order for sorting by [col]; rows without a sort key always go last; stable. */
export function sortedIndices(rows: SiteCell[][], col: number, dir: Dir): number[] {
  return rows
    .map((_, i) => i)
    .sort((i, j) => {
      const a = rows[i][col], b = rows[j][col];
      const am = a.s === undefined, bm = b.s === undefined;
      const anyKeyed = rows.some((r) => r[col].s !== undefined);
      if (anyKeyed && am !== bm) return am ? 1 : -1;
      const c = compareCells(a, b);
      return (dir === 'desc' ? -c : c) || i - j;
    });
}

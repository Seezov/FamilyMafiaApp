import { describe, expect, it } from 'vitest';
import { sortedIndices } from './sort';
import type { SiteCell } from './types';

const rows: SiteCell[][] = [
  [{ t: 'Olya' }, { t: '50%', s: 0.5 }],
  [{ t: 'Sasha' }, { t: '–' }],
  [{ t: 'Ivan' }, { t: '61%', s: 0.61 }],
  [{ t: 'Anna' }, { t: '50%', s: 0.5 }],
];

describe('sortedIndices', () => {
  it('sorts numerically descending, ties keep the given order', () => {
    expect(sortedIndices(rows, 1, 'desc')).toEqual([2, 0, 3, 1]);
  });
  it('puts cells without a sort key last in both directions', () => {
    expect(sortedIndices(rows, 1, 'asc')).toEqual([0, 3, 2, 1]);
  });
  it('falls back to Ukrainian-aware text order', () => {
    const names: SiteCell[][] = [[{ t: 'Яна' }], [{ t: 'Іра' }], [{ t: 'Аня' }]];
    expect(sortedIndices(names, 0, 'asc')).toEqual([2, 1, 0]);
  });
});

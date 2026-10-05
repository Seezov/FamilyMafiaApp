import { describe, expect, it } from 'vitest';
import { canDelete, seasonRow } from './render';

describe('render', () => {
  it('escapes the title and shows the start date and games', () => {
    const html = seasonRow({ id: 32, title: '<b>x', source: 'Firestore', startDate: '2026-12-01', games: 3 }, { deletable: false, confirming: false });
    expect(html).toContain('&lt;b&gt;x');
    expect(html).toContain('2026-12-01');
    expect(html).toContain('3');
    expect(html).not.toContain('data-act="delete"');
  });
  it('a deletable row has delete, then a confirm step', () => {
    const row = { id: 32, title: 'Season 32', source: 'Firestore', startDate: '2026-12-01', games: 0 };
    expect(seasonRow(row, { deletable: true, confirming: false })).toContain('data-act="delete"');
    expect(seasonRow(row, { deletable: true, confirming: true })).toContain('data-act="delete-ok"');
  });
  it('only the newest club season without games can be deleted', () => {
    const list = [{ id: 32, title: 'S', smallLeagueMinGames: 15, startDate: '2026-12-01' }, { id: 33, title: 'S', smallLeagueMinGames: 15, startDate: '2027-03-01' }];
    expect(canDelete(list, 33, 0)).toBe(true);
    expect(canDelete(list, 33, 2)).toBe(false);
    expect(canDelete(list, 32, 0)).toBe(false);
    expect(canDelete([], 31, 0)).toBe(false);
  });
});

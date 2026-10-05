import { describe, expect, it } from 'vitest';
import { filterRoster, playerRow, unresolvedRow } from './render';

const r = [{ name: 'Rathma', nicknames: ['Скай'] }, { name: '<b>x', nicknames: ['"q'] }];

describe('render', () => {
  it('escapes names and nicknames', () => {
    const html = playerRow(r[1], { canSave: true, mode: null });
    expect(html).not.toContain('<b>x');
    expect(html).toContain('&lt;b&gt;x');
    expect(html).not.toContain('"q"');
  });
  it('read-only rows have no action buttons', () => {
    expect(playerRow(r[0], { canSave: false, mode: null })).not.toContain('<button');
  });
  it('rename and merge modes show their confirm form', () => {
    expect(playerRow(r[0], { canSave: true, mode: 'rename' })).toContain('data-act="rename-ok"');
    expect(playerRow(r[0], { canSave: true, mode: 'merge' })).toContain('data-act="merge-ok"');
  });
  it('filters by name or nickname, case-insensitively', () => {
    expect(filterRoster(r, 'скай').map((e) => e.name)).toEqual(['Rathma']);
    expect(filterRoster(r, '')).toHaveLength(2);
  });
  it('an unresolved name that now resolves says so', () => {
    expect(unresolvedRow({ name: 'Скай', games: 3, lastSeason: 31 }, 'Rathma', true)).toContain('Rathma');
    expect(unresolvedRow({ name: 'Гість', games: 1, lastSeason: 31 }, undefined, true)).toContain('data-act="attach"');
  });
});

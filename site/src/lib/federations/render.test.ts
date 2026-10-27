import { describe, expect, it } from 'vitest';
import type { Candidate, FedDoc } from './core';
import { filterRows, fedRow, unmatchedRow } from './render';

const c = (fed: Candidate['fed'], id: string, extra: Partial<Candidate> = {}): Candidate =>
  ({ fed, id, nick: 'Seezov', url: `https://x/${fed}/${id}`, strength: 'nick', ...extra });
const entry = { name: 'Seezov', nicknames: [] };
const empty: FedDoc = { links: {}, rejected: {} };
const opts = { canSave: true, showRejected: false, shared: new Map<string, string[]>() };

describe('fedRow', () => {
  it('renders four federation columns in order with full candidate cards', () => {
    const html = fedRow(entry, [c('eg', '87', { strength: 'club', realName: 'Олександр', club: 'Family Mafia Club', city: 'Cherkasy', games: 6 }), c('imafia', '1003')],
      { links: { Seezov: { eg: ['87'] } }, rejected: {} }, opts);
    const cols = [...html.matchAll(/data-fed-col="(\w+)"/g)].map((m) => m[1]);
    expect(cols).toEqual(['imafia', 'eg', 'fiim', 'mafgame']);
    expect(html).toContain('href="https://x/eg/87" target="_blank" rel="noopener"');
    expect(html).toContain('Олександр');
    expect(html).toContain('Family Mafia Club · Cherkasy');
    expect(html).toContain('в нашому клубі');
    expect(html).toContain('збіг ніку');
    expect(html).toMatch(/data-act="toggle" data-player="Seezov" data-fed="eg" data-id="87" checked/);
    expect(html).not.toMatch(/data-fed="imafia" data-id="1003" checked/);
  });
  it('hides rejected candidates unless asked, then offers to restore them', () => {
    const d: FedDoc = { links: {}, rejected: { Seezov: ['imafia:1003'] } };
    expect(fedRow(entry, [c('imafia', '1003')], d, opts)).not.toContain('https://x/imafia/1003');
    const shown = fedRow(entry, [c('imafia', '1003')], d, { ...opts, showRejected: true });
    expect(shown).toContain('data-act="unreject"');
  });
  it('shows manual links that are not among the candidates', () => {
    expect(fedRow(entry, [], { links: { Seezov: { fiim: ['9169'] } }, rejected: {} }, opts)).toContain('https://fiim.world/user/9169/show');
  });
  it('warns when a profile is confirmed for another player too', () => {
    const shared = new Map([['eg:87', ['Seezov', 'Other']]]);
    expect(fedRow(entry, [c('eg', '87')], { links: { Seezov: { eg: ['87'] }, Other: { eg: ['87'] } }, rejected: {} }, { ...opts, shared })).toContain('також у Other');
  });
  it('escapes everything from the file', () => {
    const html = fedRow({ name: '<b>', nicknames: [] }, [c('eg', '1', { nick: '<script>x</script>', realName: '"q"' })], empty, opts);
    expect(html).not.toContain('<script>');
    expect(html).not.toContain('<b>');
    expect(html).toContain('&lt;script&gt;');
  });
  it('read-only: disabled checkboxes, no review button, no url field', () => {
    const html = fedRow(entry, [c('eg', '87')], empty, { ...opts, canSave: false });
    expect(html).toContain('disabled');
    expect(html).not.toContain('data-act="reviewed"');
    expect(html).not.toContain('name="url"');
  });
});

describe('unmatchedRow', () => {
  it('offers a roster picker; disappears once linked to anyone', () => {
    const m = c('eg', '1676', { nick: 'Пустой', strength: 'club' });
    expect(unmatchedRow(m, empty, true)).toContain('data-act="attach"');
    expect(unmatchedRow(m, { links: { X: { eg: ['1676'] } }, rejected: {} }, true)).toBe('');
  });
});

describe('filterRows', () => {
  const rows = [
    { entry: { name: 'A', nicknames: [] }, cands: [c('eg', '1')] },
    { entry: { name: 'B', nicknames: ['Бі'] }, cands: [c('eg', '2')] },
    { entry: { name: 'C', nicknames: [] }, cands: [] },
  ];
  const d: FedDoc = { links: { B: { eg: ['2'] } }, rejected: {} };
  it('filters by status and searches names and nicknames', () => {
    expect(filterRows(rows, d, 'unreviewed', '').map((r) => r.entry.name)).toEqual(['A']);
    expect(filterRows(rows, d, 'confirmed', '').map((r) => r.entry.name)).toEqual(['B']);
    expect(filterRows(rows, d, 'nothing', '').map((r) => r.entry.name)).toEqual(['C']);
    expect(filterRows(rows, d, 'all', 'бі').map((r) => r.entry.name)).toEqual(['B']);
  });
});

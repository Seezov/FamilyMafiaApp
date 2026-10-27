import { describe, expect, it } from 'vitest';
import { buildLedger, DEFAULT_CONFIG } from './payments';
import { configForm, dayCard, dayTitle, debtRows } from './render';

const l = buildLedger({
  games: [{ season: 32, date: '2026-12-01', players: ['<b>A</b>', 'B'] }], cfg: DEFAULT_CONFIG,
  days: [{ date: '2026-12-01', eventType: null, marks: { B: { free: 'закрив "вечір"' } } }],
  records: [{ id: 'r1', player: '<b>A</b>', amount: 20, date: '2026-12-02', note: '<i>x</i>', byEmail: 'a@x' }], auto: new Map(),
});

describe('payments render', () => {
  it('escapes names and notes', () => {
    const html = debtRows(l.players, { open: '<b>A</b>', paying: '<b>A</b>', onlyDebtors: false, today: '2026-12-02' }) + dayCard(l.days[0], true);
    expect(html).not.toMatch(/<b>A|<i>x/);
    expect(html).toContain('&lt;b&gt;A&lt;/b&gt;');
    expect(html).toContain('value="30"'); // pay form prefilled with the debt (50 for one game − 20 paid)
    expect(html).toContain('закрив &quot;вечір&quot;');
  });
  it('hides settled players when asked', () => {
    expect(debtRows(l.players, { open: null, paying: null, onlyDebtors: true, today: '' })).not.toContain('>B<');
  });
  it('labels days and renders the config form', () => {
    expect(dayTitle('2026-12-05')).toBe('Сб, 05.12.2026');
    expect(configForm(DEFAULT_CONFIG)).toContain('name="wd6" type="number" min="0" step="1" value="200"');
  });
});

import { describe, expect, it } from 'vitest';
import { buildLedger, chargeFor, DEFAULT_CONFIG, eventDates, nameResolver, toConfig, tournamentDays, weekday, type PaymentsConfig } from './payments';

const cfg: PaymentsConfig = { ...DEFAULT_CONFIG, students: ['Студ'], organizers: ['Орг'], prices: { ...DEFAULT_CONFIG.prices, events: { marathon: 300 } } };
const TUE = '2026-12-01', SAT = '2026-12-05', SUN = '2026-12-06';
const charge = (o: Partial<Parameters<typeof chargeFor>[0]>) =>
  chargeFor({ date: TUE, games: 3, player: 'A', cfg, eventType: null, ...o });

describe('chargeFor', () => {
  it('weekday prices', () => {
    expect(weekday(TUE)).toBe(2);
    expect(weekday(SUN)).toBe(7);
    expect(charge({}).amount).toBe(150);
    expect(charge({ date: SAT }).amount).toBe(200);
    expect(charge({ date: SUN }).amount).toBe(200);
  });
  it('takes the cheapest of student and single game', () => {
    expect(charge({ player: 'Студ', date: SAT })).toEqual({ amount: 100, notes: ['студент'] });
    expect(charge({ games: 1 })).toEqual({ amount: 50, notes: ['1 гра'] });
    expect(charge({ player: 'Студ', games: 1 })).toEqual({ amount: 50, notes: ['1 гра'] });
  });
  it('Russian doubles, also on top of discounts', () => {
    expect(charge({ mark: { russian: true } }).amount).toBe(300);
    expect(charge({ games: 1, mark: { russian: true } }).amount).toBe(100);
  });
  it('special evenings have no discounts', () => {
    expect(charge({ eventType: 'marathon', player: 'Студ', games: 1 })).toEqual({ amount: 300, notes: ['Марафон'] });
    expect(charge({ eventType: 'marathon', mark: { russian: true } }).amount).toBe(600);
  });
  it('an event without a price falls back to the weekday with a warning', () => {
    const c = charge({ eventType: 'series' });
    expect(c.amount).toBe(150);
    expect(c.warning).toMatch(/Серія/);
  });
  it('free cases and a manual amount', () => {
    expect(charge({ player: 'Орг', mark: { russian: true } }).amount).toBe(0);
    expect(charge({ mark: { newbie: true } })).toEqual({ amount: 0, notes: ['привів новачка'] });
    expect(charge({ mark: { free: 'закрив вечір' } })).toEqual({ amount: 0, notes: ['безкоштовно: закрив вечір'] });
    expect(charge({ mark: { amount: 75, russian: true } }).amount).toBe(75);
  });
});

describe('tournament dates', () => {
  it('parses the list formats', () => {
    expect(tournamentDays('04.12.2026')).toEqual(['2026-12-04']);
    expect(tournamentDays('06–08.12.2026')).toEqual(['2026-12-06', '2026-12-07', '2026-12-08']);
    expect(tournamentDays('30.11–01.12.2026')).toEqual(['2026-11-30', '2026-12-01']);
    expect(tournamentDays('31.12.2026–01.01.2027')).toEqual(['2026-12-31', '2027-01-01']);
    expect(tournamentDays('12.2026')).toEqual([]);
  });
  it('maps types from the season on; a multi-day tournament is a series', () => {
    const m = eventDates([
      { season: 31, type: 'marathon', date: '05.11.2026' },
      { season: 32, type: 'marathon', date: '05.12.2026' },
      { season: 32, type: 'tournament', date: '12–13.12.2026' },
      { season: 32, type: 'tournament', date: '20.12.2026' },
    ], 32);
    expect([...m]).toEqual([['2026-12-05', 'marathon'], ['2026-12-12', 'series'], ['2026-12-13', 'series'], ['2026-12-20', 'tournament']]);
  });
});

describe('buildLedger', () => {
  const games = [
    { season: 31, date: '2026-11-29', players: ['A'] },
    { season: 32, date: TUE, players: ['A', 'B', 'Орг'] },
    { season: 32, date: TUE, players: ['A', 'Орг'] },
    { season: 32, date: SAT, players: ['A', 'B'] },
  ];
  const r = buildLedger({
    games, cfg,
    days: [{ date: SAT, eventType: null, marks: { B: { russian: true } } }],
    records: [{ id: 'x', player: 'A', amount: 100, date: '2026-12-06', note: '', byEmail: 'a@x' }, { id: 'y', player: 'C', amount: 50, date: SUN, note: '', byEmail: 'a@x' }],
    auto: new Map([[SAT, 'marathon' as const]]),
  });
  it('charges each evening once, skipping earlier seasons', () => {
    const a = r.players.find((p) => p.player === 'A')!;
    expect(a.evenings.map((e) => [e.date, e.games, e.charge.amount])).toEqual([[SAT, 1, 300], [TUE, 2, 150]]);
    expect([a.charged, a.paid, a.debt]).toEqual([450, 100, 350]);
  });
  it('applies marks and the auto event type; sorts by debt', () => {
    expect(r.players.map((p) => [p.player, p.debt])).toEqual([['B', 650], ['A', 350], ['Орг', 0], ['C', -50]]);
    expect(r.days.map((d) => [d.date, d.eventType, d.total])).toEqual([[SAT, 'marathon', 900], [TUE, null, 150 + 50]]);
  });
  it("'none' overrides the tournament list", () => {
    const r2 = buildLedger({ games, cfg, days: [{ date: SAT, eventType: 'none', marks: {} }], records: [], auto: new Map([[SAT, 'marathon' as const]]) });
    expect(r2.days[0].eventType).toBeNull();
    expect(r2.days[0].total).toBe(100); // A and B each played one game there
  });
});

describe('helpers', () => {
  it('resolves nicknames case-insensitively', () => {
    const res = nameResolver([{ name: 'Seezov', nicknames: ['Seezov', 'Сізов'] }]);
    expect(res('сізов')).toBe('Seezov');
    expect(res(' Гість ')).toBe('Гість');
  });
  it('fills a partial config', () => {
    const c = toConfig({ prices: { student: 80, events: { marathon: 250, bogus: 1 } }, students: ['X', 3] });
    expect(c.prices.student).toBe(80);
    expect(c.prices.weekday['6']).toBe(200);
    expect(c.prices.events).toEqual({ marathon: 250 });
    expect(c.students).toEqual(['X']);
    expect(c.startSeason).toBe(32);
  });
});

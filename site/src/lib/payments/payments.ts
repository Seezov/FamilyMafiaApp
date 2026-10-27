// Debts for club evenings (/payments/). Pure: the page and a future Telegram bot share it.
// A player is charged once per game day they sat in at least one game; the price rules are the
// club's (see chargeFor). Debt = charged − paid, from config.startSeason on.

export const EVENT_TYPES = {
  marathon: 'Марафон', series: 'Серія', minicap: 'Мінікап', bigcap: 'Бігкап', maxicap: 'Максікап', tournament: 'Турнір',
} as const;
export type EventType = keyof typeof EVENT_TYPES;
export const isEventType = (v: unknown): v is EventType => typeof v === 'string' && v in EVENT_TYPES;

export interface Prices {
  /** ISO weekday '1' (Mon) … '7' (Sun) → price of an ordinary evening. */
  weekday: Record<string, number>;
  student: number;
  single: number;
  events: Partial<Record<EventType, number>>;
}
export interface PaymentsConfig {
  prices: Prices;
  students: string[];
  organizers: string[];
  /** Player → Telegram handle, for the reminder bot. */
  telegram: Record<string, string>;
  startSeason: number;
}
export const DEFAULT_CONFIG: PaymentsConfig = {
  prices: { weekday: { 1: 150, 2: 150, 3: 150, 4: 150, 5: 150, 6: 200, 7: 200 }, student: 100, single: 50, events: {} },
  students: [], organizers: [], telegram: {}, startSeason: 32,
};

/** Per-evening exceptions an organizer sets for one player. */
export interface Mark { newbie?: boolean; russian?: boolean; free?: string; amount?: number }
/** eventType: null = take it from the tournament list, 'none' = an ordinary evening. */
export interface DayDoc { date: string; eventType: EventType | 'none' | null; marks: Record<string, Mark> }
export interface PaymentRecord { id: string; player: string; amount: number; date: string; note: string; byEmail: string }
export interface PlayedGame { season: number; date: string; players: string[] }

export interface Charge { amount: number; notes: string[]; warning?: string }

/** ISO weekday of a YYYY-MM-DD date: 1 = Monday … 7 = Sunday. */
export function weekday(date: string): number {
  const [y, m, d] = date.split('-').map(Number);
  return new Date(Date.UTC(y, m - 1, d)).getUTCDay() || 7;
}

/**
 * One player's price for one evening. Organizers, a brought newbie or a «free» mark → 0; a set
 * amount wins next. A special evening costs its type's price with no discounts; an ordinary one
 * costs the cheapest of the weekday price, the student price and the single-game price. Playing
 * in Russian doubles it.
 */
export function chargeFor(o: { date: string; games: number; player: string; cfg: PaymentsConfig; eventType: EventType | null; mark?: Mark }): Charge {
  const { cfg, mark = {} } = o;
  if (cfg.organizers.includes(o.player)) return { amount: 0, notes: ['організатор'] };
  if (mark.newbie) return { amount: 0, notes: ['привів новачка'] };
  if (mark.free !== undefined) return { amount: 0, notes: [mark.free ? `безкоштовно: ${mark.free}` : 'безкоштовно'] };
  if (mark.amount !== undefined) return { amount: mark.amount, notes: ['сума вручну'] };
  const weekdayPrice = cfg.prices.weekday[String(weekday(o.date))] ?? 0;
  const notes: string[] = [];
  let amount: number;
  let warning: string | undefined;
  const eventPrice = o.eventType ? cfg.prices.events[o.eventType] : undefined;
  if (o.eventType && eventPrice !== undefined) {
    amount = eventPrice;
    notes.push(EVENT_TYPES[o.eventType]);
  } else {
    if (o.eventType) warning = `ціну «${EVENT_TYPES[o.eventType]}» не задано — рахую як звичайний вечір`;
    amount = weekdayPrice;
    if (cfg.students.includes(o.player) && cfg.prices.student < amount) { amount = cfg.prices.student; notes.push('студент'); }
    if (o.games === 1 && cfg.prices.single < amount) { amount = cfg.prices.single; notes.splice(0, notes.length, '1 гра'); }
  }
  if (mark.russian) { amount *= 2; notes.push('російською ×2'); }
  return { amount, notes, ...(warning ? { warning } : {}) };
}

/** Days of a tournament-list date: «04.07.2026», «06–14.07.2026», «30.06–02.07.2026», «30.06.2026–02.07.2026». */
export function tournamentDays(s: string): string[] {
  const iso = (d: number, m: number, y: number) => `${y}-${String(m).padStart(2, '0')}-${String(d).padStart(2, '0')}`;
  let r = s.trim().match(/^(\d{1,2})\.(\d{1,2})\.(\d{4})$/);
  if (r) return [iso(+r[1], +r[2], +r[3])];
  let from: string, to: string;
  if ((r = s.match(/^(\d{1,2})\s*[–-]\s*(\d{1,2})\.(\d{1,2})\.(\d{4})$/))) [from, to] = [iso(+r[1], +r[3], +r[4]), iso(+r[2], +r[3], +r[4])];
  else if ((r = s.match(/^(\d{1,2})\.(\d{1,2})\s*[–-]\s*(\d{1,2})\.(\d{1,2})\.(\d{4})$/))) [from, to] = [iso(+r[1], +r[2], +r[5]), iso(+r[3], +r[4], +r[5])];
  else if ((r = s.match(/^(\d{1,2})\.(\d{1,2})\.(\d{4})\s*[–-]\s*(\d{1,2})\.(\d{1,2})\.(\d{4})$/))) [from, to] = [iso(+r[1], +r[2], +r[3]), iso(+r[4], +r[5], +r[6])];
  else return [];
  const out: string[] = [];
  for (let t = Date.parse(from); t <= Date.parse(to) && out.length < 62; t += 86400000) out.push(new Date(t).toISOString().slice(0, 10));
  return out;
}

/** Date → event type from config/club tournaments of seasons ≥ [startSeason]. */
export function eventDates(tournaments: { season?: number; type?: string; date?: string }[], startSeason: number): Map<string, EventType> {
  const out = new Map<string, EventType>();
  for (const t of tournaments) {
    if ((t.season ?? 0) < startSeason || !t.date) continue;
    const type: EventType | null = t.type === 'marathon' || t.type === 'minicap' || t.type === 'bigcap' || t.type === 'maxicap' ? t.type
      : t.type === 'tournament' && tournamentDays(t.date).length > 1 ? 'series' : t.type === 'tournament' ? 'tournament' : null;
    if (type) for (const d of tournamentDays(t.date)) out.set(d, type);
  }
  return out;
}

export interface Evening { date: string; games: number; eventType: EventType | null; charge: Charge; mark?: Mark }
export interface PlayerLedger { player: string; charged: number; paid: number; debt: number; evenings: Evening[]; records: PaymentRecord[] }
export interface DayView { date: string; eventType: EventType | null; auto: EventType | null; override: DayDoc['eventType']; total: number;
  players: { player: string; games: number; charge: Charge; mark?: Mark }[] }

/** Everyone's charges, payments and debt (largest first) and each evening's breakdown (newest first). */
export function buildLedger(input: { games: PlayedGame[]; cfg: PaymentsConfig; days: DayDoc[]; records: PaymentRecord[]; auto: Map<string, EventType> }) {
  const { cfg } = input;
  const byDay = new Map<string, Map<string, number>>();
  for (const g of input.games) {
    if (g.season < cfg.startSeason) continue;
    const m = byDay.get(g.date) ?? new Map<string, number>();
    for (const p of new Set(g.players)) m.set(p, (m.get(p) ?? 0) + 1);
    byDay.set(g.date, m);
  }
  const docs = new Map(input.days.map((d) => [d.date, d]));
  const players = new Map<string, PlayerLedger>();
  const ledgerOf = (p: string) => {
    let l = players.get(p);
    if (!l) players.set(p, (l = { player: p, charged: 0, paid: 0, debt: 0, evenings: [], records: [] }));
    return l;
  };
  const days: DayView[] = [];
  for (const date of [...byDay.keys()].sort().reverse()) {
    const override = docs.get(date)?.eventType ?? null;
    const auto = input.auto.get(date) ?? null;
    const eventType = override === 'none' ? null : override ?? auto;
    const view: DayView = { date, eventType, auto, override, total: 0, players: [] };
    for (const [player, games] of byDay.get(date)!) {
      const mark = docs.get(date)?.marks[player];
      const charge = chargeFor({ date, games, player, cfg, eventType, mark });
      view.players.push({ player, games, charge, mark });
      view.total += charge.amount;
      const l = ledgerOf(player);
      l.evenings.push({ date, games, eventType, charge, mark });
      l.charged += charge.amount;
    }
    view.players.sort((a, b) => a.player.localeCompare(b.player, 'uk'));
    days.push(view);
  }
  for (const r of input.records) {
    const l = ledgerOf(r.player);
    l.records.push(r);
    l.paid += r.amount;
  }
  for (const l of players.values()) {
    l.debt = l.charged - l.paid;
    l.records.sort((a, b) => b.date.localeCompare(a.date));
  }
  return {
    players: [...players.values()].sort((a, b) => b.debt - a.debt || a.player.localeCompare(b.player, 'uk')),
    days,
  };
}

/** Game seat names → roster display names (names and nicknames, case-insensitive); unknown names stay as written. */
export function nameResolver(roster: { name: string; nicknames?: string[] }[]) {
  const m = new Map<string, string>();
  for (const p of roster) for (const n of [p.name, ...(p.nicknames ?? [])]) if (!m.has(n.trim().toLowerCase())) m.set(n.trim().toLowerCase(), p.name);
  return (raw: string) => m.get(raw.trim().toLowerCase()) ?? raw.trim();
}

/** Reads payments/config, filling anything missing from DEFAULT_CONFIG. */
export function toConfig(d: Record<string, unknown> | undefined): PaymentsConfig {
  const p = (d?.prices ?? {}) as Partial<Prices>;
  const num = (v: unknown, dflt: number) => (typeof v === 'number' && Number.isFinite(v) && v >= 0 ? v : dflt);
  const strs = (v: unknown) => (Array.isArray(v) ? v.filter((x): x is string => typeof x === 'string') : []);
  const D = DEFAULT_CONFIG.prices;
  const events: Prices['events'] = {};
  for (const [k, v] of Object.entries(p.events ?? {})) if (isEventType(k) && typeof v === 'number' && v >= 0) events[k] = v;
  return {
    prices: {
      weekday: Object.fromEntries(Object.entries(D.weekday).map(([k, v]) => [k, num(p.weekday?.[k], v)])),
      student: num(p.student, D.student), single: num(p.single, D.single), events,
    },
    students: strs(d?.students), organizers: strs(d?.organizers),
    telegram: Object.fromEntries(Object.entries((d?.telegram ?? {}) as Record<string, unknown>).filter((e): e is [string, string] => typeof e[1] === 'string')),
    startSeason: typeof d?.startSeason === 'number' ? d.startSeason : DEFAULT_CONFIG.startSeason,
  };
}

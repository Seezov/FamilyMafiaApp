// Appeals for an additional point: pure logic shared by /account/ and /account/admin/.
// The same limits are enforced by firestore.rules (match /appeals).
import type { GameDoc } from '../hosting/types';

export type AppealStatus = 'pending' | 'accepted' | 'partial' | 'rejected';
export const STATUSES: AppealStatus[] = ['pending', 'accepted', 'partial', 'rejected'];
export interface Appeal {
  id: string; gameId: string; season: number; date: string; table: number; gameNumber: number; host: string;
  seat: number; player: string; uid: string; email: string; text: string; requested: number; status: AppealStatus;
  granted?: number; adminComment?: string; createdAt?: number; decidedBy?: string; decidedAt?: number;
}
export interface Decision { status: 'accepted' | 'partial' | 'rejected'; granted?: number; adminComment: string }

export const MAX_TEXT = 1000;
export const MAX_REQUESTED = 5;

export const round2 = (n: number) => Math.round(n * 100) / 100;
export const parseAmount = (s: string) => (s.trim() ? round2(Number(s.trim().replace(',', '.'))) : NaN);
export const appealId = (gameId: string, uid: string) => `${gameId}_${uid}`;

export function draftError(text: string, requested: string): string | null {
  const t = text.trim();
  if (!t) return 'Опиши, за що має бути дод бал.';
  if (t.length > MAX_TEXT) return `Опис довший за ${MAX_TEXT} символів.`;
  const n = parseAmount(requested);
  if (!(n > 0)) return 'Очікуваний бал має бути більше 0.';
  if (n > MAX_REQUESTED) return `Очікуваний бал — не більше ${MAX_REQUESTED}.`;
  return null;
}

export function grantedFor(a: Appeal, d: Decision): number | null {
  if (d.status === 'accepted') return a.requested;
  if (d.status === 'partial') return round2(d.granted ?? NaN);
  return null;
}

export function decisionError(a: Appeal, d: Decision): string | null {
  if (d.adminComment.trim().length > MAX_TEXT) return `Коментар довший за ${MAX_TEXT} символів.`;
  if (d.status !== 'partial') return null;
  const g = grantedFor(a, d)!;
  if (!(g > 0)) return 'Нарахований бал має бути більше 0.';
  if (g >= a.requested) return `Частково — це менше, ніж просили (${a.requested}).`;
  return null;
}

/** The stored appeal differs from the one the admin decided on (player edited it, or it was decided). */
export function appealChanged(shown: Appeal, stored: { text: string; requested: number; status: AppealStatus }): boolean {
  return stored.status !== 'pending' || stored.text !== shown.text || stored.requested !== shown.requested;
}

export class SeatGoneError extends Error {}

/** The game after granting: the player's seat is found by name, since the host may have moved it. */
export function applyGrant(g: Pick<GameDoc, 'seats' | 'comments'>, player: string, granted: number): Pick<GameDoc, 'seats' | 'comments'> {
  const i = g.seats.findIndex((s) => s.player === player);
  if (i < 0) throw new SeatGoneError(player);
  return {
    seats: g.seats.map((s, j) => (j === i ? { ...s, additional: round2((s.additional || 0) + granted) } : s)),
    comments: [...g.comments, { slot: i + 1, text: `Апеляція: +${granted}` }],
  };
}

/** Rated games the player sat in, newest first, with their seat (1–10). */
export function myGames<G extends GameDoc & { id: string }>(games: G[], player: string): { game: G; seat: number }[] {
  return games
    .filter((g) => g.result !== 'unrated')
    .map((game) => ({ game, seat: game.seats.findIndex((s) => s.player === player) + 1 }))
    .filter((x) => x.seat > 0)
    .sort((a, b) => b.game.date.localeCompare(a.game.date) || b.game.table - a.game.table || b.game.gameNumber - a.game.gameNumber);
}

export interface HistoryFilter { player: string; host: string; status: '' | AppealStatus; season: string }

export function filterHistory(list: Appeal[], f: HistoryFilter): Appeal[] {
  const p = f.player.trim().toLowerCase();
  return list
    .filter((a) => (!p || a.player.toLowerCase().includes(p)) && (!f.host || a.host === f.host)
      && (!f.status || a.status === f.status) && (!f.season || String(a.season) === f.season))
    .sort((a, b) => (b.createdAt ?? 0) - (a.createdAt ?? 0));
}

export function filterFromQuery(q: URLSearchParams): HistoryFilter {
  const status = q.get('status') ?? '';
  return {
    player: q.get('player') ?? '', host: q.get('host') ?? '',
    status: (STATUSES as string[]).includes(status) ? (status as AppealStatus) : '', season: q.get('season') ?? '',
  };
}

export function filterToQuery(f: HistoryFilter): string {
  const q = new URLSearchParams();
  for (const k of ['player', 'host', 'status', 'season'] as const) if (f[k]) q.set(k, f[k]);
  return q.toString();
}

export interface HostTotal { host: string; total: number; pending: number; accepted: number; partial: number; rejected: number; points: number }

export function hostTotals(list: Appeal[]): HostTotal[] {
  const by = new Map<string, HostTotal>();
  for (const a of list) {
    const t = by.get(a.host) ?? { host: a.host, total: 0, pending: 0, accepted: 0, partial: 0, rejected: 0, points: 0 };
    t.total++; t[a.status]++; t.points = round2(t.points + (a.granted ?? 0));
    by.set(a.host, t);
  }
  return [...by.values()].sort((a, b) => b.total - a.total || a.host.localeCompare(b.host, 'uk'));
}

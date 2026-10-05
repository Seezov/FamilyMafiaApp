import { describe, expect, it } from 'vitest';
import type { GameDoc } from '../hosting/types';
import {
  appealId, applyGrant, decisionError, draftError, filterFromQuery, filterHistory, filterToQuery, grantedFor,
  hostTotals, myGames, parseAmount, round2, SeatGoneError, type Appeal,
} from './core';

const seat = (player: string, additional = 0) => ({ player, role: 'Мирний' as const, fouls: 0, additional, penalty: 0, protocolAdditional: 0, protocolPenalty: 0 });
const game = (id: string, extra: Partial<GameDoc> = {}) => ({
  id, season: 32, date: '2026-12-03', table: 1 as const, gameNumber: 1, host: 'Серпень',
  seats: Array.from({ length: 10 }, (_, i) => seat(`P${i + 1}`)), firstKilled: 0, supportFive: [], protocol: [],
  result: 'city' as const, comments: [], createdBy: '', createdByEmail: '', createdAt: null, updatedBy: '', updatedAt: null, ...extra,
});
const A = (extra: Partial<Appeal> = {}): Appeal => ({
  id: 'g_u', gameId: 'g', season: 32, date: '2026-12-03', table: 1, gameNumber: 1, host: 'Серпень', seat: 1,
  player: 'P1', uid: 'u', email: 'p@x', text: 't', requested: 0.5, status: 'pending', createdAt: 1, ...extra,
});

describe('numbers', () => {
  it('round2 hides float noise', () => { expect(round2(0.1 + 0.2)).toBe(0.3); });
  it('parseAmount accepts a comma', () => { expect(parseAmount('0,5')).toBe(0.5); expect(parseAmount(' 1.25 ')).toBe(1.25); });
  it('parseAmount of junk is NaN', () => { expect(parseAmount('abc')).toBeNaN(); expect(parseAmount('')).toBeNaN(); });
  it('appealId', () => { expect(appealId('G', 'U')).toBe('G_U'); });
});

describe('draftError', () => {
  it('ok', () => { expect(draftError(' Знайшов шерифа ', '0,5')).toBeNull(); });
  it('empty or too long text', () => {
    expect(draftError('  ', '0.5')).toMatch(/Опиши/);
    expect(draftError('x'.repeat(1001), '0.5')).toMatch(/1000/);
  });
  it('amount bounds', () => {
    expect(draftError('t', '0')).toMatch(/більше 0/);
    expect(draftError('t', 'x')).toMatch(/більше 0/);
    expect(draftError('t', '5.01')).toMatch(/5/);
    expect(draftError('t', '5')).toBeNull();
  });
});

describe('decisions', () => {
  it('accepted grants what was asked', () => {
    expect(grantedFor(A(), { status: 'accepted', adminComment: '' })).toBe(0.5);
  });
  it('partial grants the admin amount, rounded', () => {
    expect(grantedFor(A(), { status: 'partial', granted: 0.1 + 0.2, adminComment: '' })).toBe(0.3);
  });
  it('rejected grants nothing', () => { expect(grantedFor(A(), { status: 'rejected', adminComment: '' })).toBeNull(); });
  it('partial bounds', () => {
    expect(decisionError(A(), { status: 'partial', granted: 0.5, adminComment: '' })).toMatch(/менше/);
    expect(decisionError(A(), { status: 'partial', granted: 0, adminComment: '' })).toMatch(/більше 0/);
    expect(decisionError(A(), { status: 'partial', granted: NaN, adminComment: '' })).toMatch(/більше 0/);
    expect(decisionError(A(), { status: 'partial', granted: 0.2, adminComment: '' })).toBeNull();
  });
  it('comment length', () => {
    expect(decisionError(A(), { status: 'rejected', adminComment: 'x'.repeat(1001) })).toMatch(/1000/);
  });
});

describe('applyGrant', () => {
  it('adds to the player’s seat and appends a comment', () => {
    const g = game('g');
    g.seats[2] = seat('Braun', 0.1);
    const out = applyGrant(g, 'Braun', 0.2);
    expect(out.seats[2].additional).toBe(0.3);
    expect(out.comments).toEqual([{ slot: 3, text: 'Апеляція: +0.2' }]);
    expect(g.seats[2].additional).toBe(0.1); // input untouched
  });
  it('finds the player after the host moved them (by name, not stored seat)', () => {
    const g = game('g');
    g.seats[7] = seat('Braun');
    expect(applyGrant(g, 'Braun', 0.5).seats[7].additional).toBe(0.5);
  });
  it('throws when the player is gone', () => {
    expect(() => applyGrant(game('g'), 'Braun', 0.5)).toThrow(SeatGoneError);
  });
});

describe('myGames', () => {
  it('rated games where the player sat, newest first, with the seat number', () => {
    const a = game('a', { date: '2026-12-01' }); a.seats[4] = seat('Braun');
    const b = game('b', { date: '2026-12-08', gameNumber: 2 }); b.seats[0] = seat('Braun');
    const c = game('c', { date: '2026-12-09', result: 'unrated' }); c.seats[0] = seat('Braun');
    const d = game('d', { date: '2026-12-10' });
    expect(myGames([a, b, c, d], 'Braun').map((x) => [x.game.id, x.seat])).toEqual([['b', 1], ['a', 5]]);
  });
});

describe('history', () => {
  const list = [
    A({ id: '1', host: 'Серпень', status: 'accepted', granted: 0.5, createdAt: 1 }),
    A({ id: '2', host: 'Серпень', status: 'partial', granted: 0.2, createdAt: 3 }),
    A({ id: '3', host: 'Залізний', player: 'P2', status: 'rejected', season: 33, createdAt: 2 }),
    A({ id: '4', host: 'Залізний', status: 'pending', createdAt: 4 }),
  ];
  const none = { player: '', host: '', status: '' as const, season: '' };
  it('newest first, filters combine', () => {
    expect(filterHistory(list, none).map((a) => a.id)).toEqual(['4', '2', '3', '1']);
    expect(filterHistory(list, { ...none, host: 'Серпень' }).map((a) => a.id)).toEqual(['2', '1']);
    expect(filterHistory(list, { ...none, player: 'p2' }).map((a) => a.id)).toEqual(['3']);
    expect(filterHistory(list, { ...none, status: 'pending' }).map((a) => a.id)).toEqual(['4']);
    expect(filterHistory(list, { ...none, season: '33' }).map((a) => a.id)).toEqual(['3']);
  });
  it('per-host totals', () => {
    expect(hostTotals(list)).toEqual([
      { host: 'Залізний', total: 2, pending: 1, accepted: 0, partial: 0, rejected: 1, points: 0 },
      { host: 'Серпень', total: 2, pending: 0, accepted: 1, partial: 1, rejected: 0, points: 0.7 },
    ]);
  });
  it('query round trip', () => {
    const f = { player: 'Braun', host: 'Серпень', status: 'partial' as const, season: '32' };
    expect(filterFromQuery(new URLSearchParams(filterToQuery(f)))).toEqual(f);
    expect(filterToQuery(none)).toBe('');
    expect(filterFromQuery(new URLSearchParams('status=bogus')).status).toBe('');
  });
});

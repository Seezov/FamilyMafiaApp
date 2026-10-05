import { describe, expect, it } from 'vitest';
import type { Appeal } from './core';
import { gameTitle, historyRow, myGameRow, pendingCard, statusLabel, totalsRows } from './render';

const A = (extra: Partial<Appeal> = {}): Appeal => ({
  id: 'g_u', gameId: 'g', season: 32, date: '2026-12-03', table: 2, gameNumber: 4, host: 'Серпень', seat: 3,
  player: 'Braun', uid: 'u', email: 'p@x', text: 't', requested: 0.5, status: 'pending', createdAt: 1, ...extra,
});
const XSS = '<img src=x onerror=alert(1)>';

describe('labels', () => {
  it('game title', () => { expect(gameTitle(A())).toBe('03.12.2026 · Стіл 2 · Гра 4'); });
  it('status', () => {
    expect(statusLabel(A())).toBe('на розгляді');
    expect(statusLabel(A({ status: 'accepted', granted: 0.5 }))).toBe('прийнято +0.5');
    expect(statusLabel(A({ status: 'partial', granted: 0.2 }))).toBe('частково +0.2 з 0.5');
    expect(statusLabel(A({ status: 'rejected' }))).toBe('відхилено');
  });
});

describe('escaping', () => {
  it('every user string is escaped', () => {
    const a = A({ text: XSS, player: XSS, host: XSS, adminComment: XSS, status: 'rejected' });
    for (const html of [
      myGameRow({ gameId: 'g', title: XSS, host: XSS, seat: 1, appeal: a }, false),
      myGameRow({ gameId: 'g', title: 't', host: 'h', seat: 1, appeal: A({ text: XSS }) }, true),
      pendingCard(A({ text: XSS, player: XSS, host: XSS }), 0, '/x/'),
      historyRow(a),
      totalsRows([{ host: XSS, total: 1, pending: 0, accepted: 0, partial: 0, rejected: 1, points: 0 }]),
    ]) expect(html).not.toContain('<img');
  });
});

describe('player row', () => {
  it('no appeal: offers to file', () => {
    expect(myGameRow({ gameId: 'g', title: 't', host: 'h', seat: 1, appeal: null }, false)).toContain('data-act="open"');
  });
  it('pending: can edit and withdraw', () => {
    const html = myGameRow({ gameId: 'g', title: 't', host: 'h', seat: 1, appeal: A() }, true);
    expect(html).toContain('id="ap-text"');
    expect(html).toContain('data-act="withdraw"');
  });
  it('decided: read-only with the admin comment', () => {
    const html = myGameRow({ gameId: 'g', title: 't', host: 'h', seat: 1, appeal: A({ status: 'rejected', adminComment: 'Ні' }) }, false);
    expect(html).not.toContain('data-act="open"');
    expect(html).toContain('Ні');
  });
});

describe('admin', () => {
  it('pending card has the three decisions and the current additional', () => {
    const html = pendingCard(A(), 0.3, '/season/32/games/');
    for (const act of ['accept', 'partial', 'reject']) expect(html).toContain(`data-act="${act}"`);
    expect(html).toContain('зараз дод 0.3');
    expect(html).toContain('href="/season/32/games/"');
  });
  it('history row shows who decided', () => {
    expect(historyRow(A({ status: 'accepted', granted: 0.5, decidedBy: 'admin@x', decidedAt: Date.UTC(2026, 11, 4) }))).toContain('admin@x');
  });
});

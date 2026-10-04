import { describe, expect, it } from 'vitest';
import { docToForm, draftKey, emptyForm, formToDoc, nextGameNumber } from './form';

describe('formToDoc', () => {
  it('stores penalties negative whatever sign was typed', () => {
    const f = emptyForm(32, '2026-12-03');
    f.seats[0].penalty = '0.5'; f.seats[1].penalty = '-0.5'; f.seats[2].protocolPenalty = '0.3';
    const d = formToDoc(f);
    expect(d.seats[0].penalty).toBe(-0.5);
    expect(d.seats[1].penalty).toBe(-0.5);
    expect(d.seats[2].protocolPenalty).toBe(-0.3);
  });
  it('blank numbers become 0, comma decimals parse', () => {
    const f = emptyForm(32, '2026-12-03'); f.seats[0].additional = '0,3';
    const d = formToDoc(f);
    expect(d.seats[0].additional).toBe(0.3);
    expect(d.seats[1].additional).toBe(0);
  });
  it('trims names and host; drops empty comments', () => {
    const f = emptyForm(32, '2026-12-03');
    f.host = ' Серпень '; f.seats[0].player = ' Німфа '; f.comments = [{ slot: 1, text: ' ' }, { slot: 2, text: 'ok' }];
    const d = formToDoc(f);
    expect(d.host).toBe('Серпень');
    expect(d.seats[0].player).toBe('Німфа');
    expect(d.comments).toEqual([{ slot: 2, text: 'ok' }]);
  });
  it('round-trips through docToForm (penalties shown positive)', () => {
    const f = emptyForm(32, '2026-12-03'); f.seats[0].penalty = '0.5'; f.result = 'city'; f.gameNumber = 2; f.host = 'X';
    const back = docToForm({ ...formToDoc(f), createdBy: 'u', createdByEmail: 'e', createdAt: null, updatedBy: 'u', updatedAt: null });
    expect(back.seats[0].penalty).toBe('0.5');
    expect(back.gameNumber).toBe(2);
  });
});

describe('nextGameNumber', () => {
  const games = [
    { date: '2026-12-03', table: 1 as const, gameNumber: 1 },
    { date: '2026-12-03', table: 1 as const, gameNumber: 2 },
    { date: '2026-12-03', table: 2 as const, gameNumber: 1 },
    { date: '2026-12-10', table: 1 as const, gameNumber: 5 },
  ];
  it('counts per table per date', () => {
    expect(nextGameNumber(games, '2026-12-03', 1)).toBe(3);
    expect(nextGameNumber(games, '2026-12-03', 2)).toBe(2);
    expect(nextGameNumber(games, '2026-12-17', 1)).toBe(1);
  });
});

describe('draftKey', () => {
  it('separates new games from each existing game', () => {
    expect(draftKey(null)).toBe('fm-host-draft:new');
    expect(draftKey('abc')).toBe('fm-host-draft:abc');
    expect(draftKey('abc')).not.toBe(draftKey('def'));
  });
});

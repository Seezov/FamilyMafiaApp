import { describe, expect, it } from 'vitest';
import {
  applyFedOp, candidatesFor, gameKey, moveForRosterOp, normNick, parseProfileUrl, profileUrl, rowStatus, sharedLinks, type FedDoc,
} from './core';

describe('normNick', () => {
  it('folds case, spaces and look-alike letters, not transliteration', () => {
    expect(normNick('  Tina ')).toBe(normNick('Тina'));
    expect(normNick('Seezov')).toBe(normNick('SEEZOV'));
    expect(normNick('Red   Fox')).toBe(normNick('red fox'));
    expect(normNick('Luna')).not.toBe(normNick('Луна'));
  });
  it('is case-insensitive for every letter, look-alikes included', () => {
    for (const [a, b] of [['Tina', 'tina'], ['TINA', 'tina'], ['SMART', 'Smart'], ['Hunter', 'hunter'], ['Bob', 'bob'], ['Kot', 'kot'], ['Margo', 'MARGO']]) {
      expect(normNick(a)).toBe(normNick(b));
    }
  });
});

describe('profile urls', () => {
  it('builds each federation url', () => {
    expect(profileUrl('imafia', '1003')).toBe('https://imafia.org/u/1003');
    expect(profileUrl('eg', '87')).toBe('https://emotion.games/ua/players/87');
    expect(profileUrl('fiim', '9169')).toBe('https://fiim.world/user/9169/show');
    expect(profileUrl('mafgame', '899')).toBe('https://mafgame.org/user/899/view');
  });
  it('parses prefixes, slashes and queries; rejects others', () => {
    expect(parseProfileUrl('https://emotion.games/en/players/87?tab=x')).toEqual({ fed: 'eg', id: '87' });
    expect(parseProfileUrl('imafia.org/u/1003/')).toEqual({ fed: 'imafia', id: '1003' });
    expect(parseProfileUrl(' https://fiim.world/user/9169/show ')).toEqual({ fed: 'fiim', id: '9169' });
    expect(parseProfileUrl('https://mafgame.org/user/899/view')).toEqual({ fed: 'mafgame', id: '899' });
    expect(parseProfileUrl('https://example.com/u/1')).toBeNull();
    expect(parseProfileUrl('not a url')).toBeNull();
  });
});

describe('candidatesFor', () => {
  it('finds entries stored under an old name via nicknames, deduped', () => {
    const c = { fed: 'eg', id: '87', nick: 'Seezov', url: '', strength: 'club' } as const;
    const file = { generatedAt: '', players: { Old: [c], Seezov: [c] }, unmatched: [] };
    expect(candidatesFor(file, { name: 'Seezov', nicknames: ['Old'] })).toEqual([c]);
    expect(candidatesFor(file, { name: 'Nobody', nicknames: [] })).toEqual([]);
  });
});

describe('applyFedOp', () => {
  it('link un-rejects, reviewed rejects, unlink does not reject, input untouched', () => {
    const start: FedDoc = { links: {}, rejected: { 'P.1': ['eg:1'] } };
    let d = applyFedOp(start, { kind: 'link', player: 'P.1', fed: 'eg', id: '1' });
    expect(start.links).toEqual({});
    expect(d.links['P.1'].eg).toEqual(['1']);
    expect(d.rejected['P.1']).toEqual([]);
    d = applyFedOp(d, { kind: 'link', player: 'P.1', fed: 'eg', id: '1' });
    expect(d.links['P.1'].eg).toEqual(['1']);
    d = applyFedOp(d, { kind: 'reviewed', player: 'P.1', keys: ['imafia:5'] });
    expect(d.rejected['P.1']).toEqual(['imafia:5']);
    d = applyFedOp(d, { kind: 'unlink', player: 'P.1', fed: 'eg', id: '1' });
    expect(d.links['P.1'].eg).toEqual([]);
    expect(d.rejected['P.1']).toEqual(['imafia:5']);
    d = applyFedOp(d, { kind: 'unreject', player: 'P.1', key: 'imafia:5' });
    expect(d.rejected['P.1']).toEqual([]);
  });
});

describe('moveForRosterOp', () => {
  const d: FedDoc = { links: { A: { eg: ['1'] }, B: { eg: ['2'], fiim: ['3'] } }, rejected: { A: ['x:1'], B: ['x:1', 'x:2'] } };
  it('renames keys', () => {
    expect(moveForRosterOp(d, { kind: 'rename', player: 'A', to: 'A2' })).toEqual({
      links: { A2: { eg: ['1'] }, B: { eg: ['2'], fiim: ['3'] } }, rejected: { A2: ['x:1'], B: ['x:1', 'x:2'] },
    });
  });
  it('unions on merge', () => {
    const m = moveForRosterOp(d, { kind: 'merge', from: 'A', into: 'B' });
    expect(m.links).toEqual({ B: { eg: ['2', '1'], fiim: ['3'] } });
    expect(m.rejected).toEqual({ B: ['x:1', 'x:2'] });
  });
  it('a rename to the same name keeps everything', () => {
    expect(moveForRosterOp(d, { kind: 'rename', player: 'A', to: 'A' })).toEqual(d);
  });
  it('a rename stores links under the cleaned name the roster saves', () => {
    expect(Object.keys(moveForRosterOp(d, { kind: 'rename', player: 'A', to: ' A2   x ' }).links)).toEqual(['B', 'A2 x']);
  });
  it('a merge drops rejections of profiles that end up linked', () => {
    const m = moveForRosterOp({ links: { B: { eg: ['1'] } }, rejected: { A: ['eg:1', 'eg:9'] } }, { kind: 'merge', from: 'A', into: 'B' });
    expect(m.rejected).toEqual({ B: ['eg:9'] });
  });
  it('leaves other ops alone', () => {
    expect(moveForRosterOp(d, { kind: 'add', name: 'C' })).toEqual(d);
  });
});

describe('rowStatus and sharedLinks', () => {
  const c = (id: string) => ({ fed: 'eg' as const, id, nick: 'n', url: '', strength: 'nick' as const });
  const d: FedDoc = { links: { A: { eg: ['1'] }, B: { eg: ['1'] } }, rejected: { C: ['eg:2'] } };
  it('rowStatus', () => {
    expect(rowStatus(d, 'A', [c('1'), c('9')])).toBe('unreviewed');
    expect(rowStatus(d, 'A', [c('1')])).toBe('confirmed');
    expect(rowStatus(d, 'C', [c('2')])).toBe('reviewed');
    expect(rowStatus(d, 'D', [])).toBe('nothing');
  });
  it('sharedLinks lists keys linked to two or more players', () => {
    expect(sharedLinks(d).get('eg:1')).toEqual(['A', 'B']);
    expect(sharedLinks({ links: { A: { eg: ['5'] } }, rejected: {} }).size).toBe(0);
  });
});

describe('gameDecisions', () => {
  const d: FedDoc = { links: { Braun: { eg: ['5'] } }, rejected: { Braun: ['imafia:1'] }, gameDecisions: { 'eg:1:a': 'different' } };
  it('decide sets and removes a decision without touching the input', () => {
    const next = applyFedOp(d, { kind: 'decide', key: 'eg:716:q-1-2', value: 'same' });
    expect(next.gameDecisions).toEqual({ 'eg:1:a': 'different', 'eg:716:q-1-2': 'same' });
    expect(applyFedOp(next, { kind: 'decide', key: 'eg:1:a', value: null }).gameDecisions).toEqual({ 'eg:716:q-1-2': 'same' });
    expect(d.gameDecisions).toEqual({ 'eg:1:a': 'different' });
  });
  it('decide leaves rejected alone', () => {
    expect(Object.keys(applyFedOp(d, { kind: 'decide', key: 'k', value: 'same' }).rejected)).toEqual(['Braun']);
  });
  it('link, rename and merge keep the decisions', () => {
    expect(applyFedOp(d, { kind: 'link', player: 'Braun', fed: 'fiim', id: '9' }).gameDecisions).toEqual(d.gameDecisions);
    expect(moveForRosterOp(d, { kind: 'rename', player: 'Braun', to: 'Браун' } as any).gameDecisions).toEqual(d.gameDecisions);
    expect(moveForRosterOp(d, { kind: 'merge', from: 'Braun', into: 'X' } as any).gameDecisions).toEqual(d.gameDecisions);
  });
  it('gameKey joins fed, tournament and game', () => {
    expect(gameKey('eg', '716', 'q-1-2')).toBe('eg:716:q-1-2');
  });
});

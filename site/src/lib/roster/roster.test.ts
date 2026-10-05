import fs from 'node:fs';
import { describe, expect, it } from 'vitest';
import { aliasPairs, applyOp, autocompleteNames, dedupeRoster, fromAppJson, ownerOf, rosterClashes, rosterErrors, type RosterEntry } from './roster';

const cases = JSON.parse(fs.readFileSync(new URL('../../../../test/fixtures/roster_cases.json', import.meta.url), 'utf8')) as
  { case: string; roster: RosterEntry[]; clashes: string[] }[];
const R = (): RosterEntry[] => [
  { name: 'Rathma', nicknames: ['Скай'] },
  { name: 'Braun', nicknames: [] },
  { name: 'Joi', nicknames: ['Фантазер'] },
];

describe('validation', () => {
  it('matches every shared case (same fixture as the Dart test)', () => {
    for (const c of cases) expect(rosterClashes(c.roster), c.case).toEqual(c.clashes);
  });
  it('limits', () => {
    expect(rosterErrors(Array.from({ length: 2001 }, (_, i) => ({ name: `p${i}`, nicknames: [] })))).toHaveLength(1);
    expect(rosterErrors([{ name: 'A', nicknames: Array.from({ length: 51 }, (_, i) => `n${i}`) }])).toHaveLength(1);
    expect(rosterErrors(R())).toEqual([]);
  });
  it('the real players.json: dedupe removes the second Night and Volus only', () => {
    const raw = JSON.parse(fs.readFileSync(new URL('../../../../assets/raw/players.json', import.meta.url), 'utf8'));
    const r = fromAppJson(raw);
    expect(rosterClashes(r)).toEqual(['night', 'volus']);
    const d = dedupeRoster(r);
    expect(r.length - d.length).toBe(2);
    expect(rosterErrors(d)).toEqual([]);
  });
});

describe('applyOp', () => {
  it('add appends; refuses a taken or too short name', () => {
    expect(applyOp(R(), { kind: 'add', name: '  Новенький ' }).at(-1)).toEqual({ name: 'Новенький', nicknames: [] });
    expect(() => applyOp(R(), { kind: 'add', name: 'скай' })).toThrow(/Rathma/);
    expect(() => applyOp(R(), { kind: 'add', name: 'X' })).toThrow(/2 characters/);
  });
  it('nickname add and remove', () => {
    const r = applyOp(R(), { kind: 'nick-add', player: 'Braun', nick: 'Браун' });
    expect(r[1].nicknames).toEqual(['Браун']);
    expect(() => applyOp(r, { kind: 'nick-add', player: 'Joi', nick: 'браун' })).toThrow(/Braun/);
    expect(applyOp(r, { kind: 'nick-remove', player: 'Braun', nick: 'Браун' })[1].nicknames).toEqual([]);
  });
  it('rename keeps the old name as a nickname', () => {
    const r = applyOp(R(), { kind: 'rename', player: 'Braun', to: 'Браун' });
    expect(r[1]).toEqual({ name: 'Браун', nicknames: ['Braun'] });
  });
  it('rename to a case variant or to an own nickname is allowed', () => {
    expect(applyOp(R(), { kind: 'rename', player: 'Rathma', to: 'RATHMA' })[0]).toEqual({ name: 'RATHMA', nicknames: ['Скай'] });
    expect(applyOp(R(), { kind: 'rename', player: 'Rathma', to: 'Скай' })[0]).toEqual({ name: 'Скай', nicknames: ['Rathma'] });
    expect(() => applyOp(R(), { kind: 'rename', player: 'Rathma', to: 'joi' })).toThrow(/Joi/);
  });
  it('merge moves every name and removes the source', () => {
    const r = applyOp(R(), { kind: 'merge', from: 'Joi', into: 'Braun' });
    expect(r.map((e) => e.name)).toEqual(['Rathma', 'Braun']);
    expect(r[1].nicknames).toEqual(['Joi', 'Фантазер']);
    expect(() => applyOp(R(), { kind: 'merge', from: 'Joi', into: 'Joi' })).toThrow();
  });
  it('ops find players by name, so they apply after the list shifted', () => {
    const shifted = [{ name: 'Новий', nicknames: [] }, ...R()];
    expect(applyOp(shifted, { kind: 'nick-add', player: 'Joi', nick: 'Джой' })[3].nicknames).toEqual(['Фантазер', 'Джой']);
    expect(() => applyOp(R(), { kind: 'nick-add', player: 'Ghost', nick: 'x2' })).toThrow(/Ghost/);
  });
});

describe('lookups', () => {
  it('owner, autocomplete and alias pairs', () => {
    const r = [...R(), { name: '/', nicknames: [] }, { name: '17', nicknames: [] }];
    expect(ownerOf(r, 'скай')).toBe('Rathma');
    expect(autocompleteNames(r)).toEqual(['Скай', 'Фантазер', 'Braun', 'Joi', 'Rathma']); // 'uk' collation: Cyrillic first, as /host/ sorts today
    expect(aliasPairs(R())).toContainEqual(['скай', 'Rathma']);
  });
});

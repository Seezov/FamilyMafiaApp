import { describe, expect, it } from 'vitest';
import { validate } from './validate';
import { emptyForm } from './form';
import type { FormState, Role } from './types';

const ROLES: Role[] = ['Мирний', 'Мирний', 'Мирний', 'Шериф', 'Мафія', 'Мирний', 'Дон', 'Мирний', 'Мафія', 'Мирний'];
const valid = (): FormState => {
  const f = emptyForm(32, '2026-12-03');
  f.host = 'Серпень'; f.result = 'city'; f.gameNumber = 1;
  f.seats.forEach((s, i) => { s.player = `P${i + 1}`; s.role = ROLES[i]; });
  return f;
};

describe('validate', () => {
  it('a full game has no errors', () => expect(validate(valid()).errors).toEqual([]));
  it('host is required and highlighted', () => {
    const f = valid(); f.host = '  ';
    const r = validate(f);
    expect(r.errors).toContain('Оберіть ведучого');
    expect(r.fields.has('host')).toBe(true);
  });
  it('доп is limited to 0.2–1.0 by 0.1 and 1.3', () => {
    for (const ok of ['', '0', '0.2', '0,7', '1', '1.3']) {
      const f = valid(); f.seats[4].additional = ok;
      expect(validate(f).errors).toEqual([]);
    }
    for (const bad of ['0.1', '0.25', '1.1', '1.2', '1.5', '-0.3', 'x']) {
      const f = valid(); f.seats[4].additional = bad;
      const r = validate(f);
      expect(r.errors.some((e) => e.startsWith('Доп:'))).toBe(true);
      expect(r.fields.has('seat-5-additional')).toBe(true);
    }
  });
  it('a comment is about the whole game (0) or seat 1–10', () => {
    for (const slot of [0, 1, 10]) {
      const f = valid(); f.comments = [{ slot, text: 'x' }];
      expect(validate(f).errors).toEqual([]);
    }
    for (const slot of [11, -1, 1.5]) {
      const f = valid(); f.comments = [{ slot, text: 'x' }];
      const r = validate(f);
      expect(r.errors).toContain('Коментар: номер гравця має бути від 1 до 10');
      expect(r.fields.has('comments')).toBe(true);
    }
    const f = valid(); f.comments = [{ slot: 11, text: '  ' }]; // empty comments are dropped on save
    expect(validate(f).errors).toEqual([]);
  });
  it('result is required', () => {
    const f = valid(); f.result = null;
    expect(validate(f).fields.has('result')).toBe(true);
  });
  it('roles must be 6/2/1/1', () => {
    const f = valid(); f.seats[0].role = 'Мафія';
    expect(validate(f).errors).toContain('Ролі мають бути 6 мирних, 2 мафії, 1 дон, 1 шериф');
  });
  it('an empty player does not block saving; the seat is listed for the guest prompt', () => {
    const f = valid(); f.seats[2].player = ''; f.seats[6].player = '  ';
    const r = validate(f);
    expect(r.errors).toEqual([]);
    expect(r.emptySeats).toEqual([3, 7]);
  });
  it('several guests in one game are not duplicates', () => {
    const f = valid(); f.seats[2].player = 'Гість'; f.seats[6].player = 'гість';
    expect(validate(f).errors).toEqual([]);
  });
  it('duplicates differing by case/space are caught', () => {
    const f = valid(); f.seats[0].player = 'Seezov'; f.seats[1].player = ' seezov ';
    const r = validate(f);
    expect(r.errors).toContain('Гравець «Seezov» записаний двічі');
    expect(r.fields.has('seat-2-player')).toBe(true);
  });
  it('season and game number are required', () => {
    const f = valid(); f.season = null; f.gameNumber = null;
    const r = validate(f);
    expect(r.fields.has('season')).toBe(true);
    expect(r.fields.has('gameNumber')).toBe(true);
  });
  it('protocol slot must be a seat and not repeated', () => {
    const f = valid(); f.protocol = [{ slot: 11, version: null, color: null }];
    expect(validate(f).errors).toContain('Протокол: невірний номер вбитого');
  });
  it('warns when Доп + ОП > 3.6 (does not block)', () => {
    const f = valid(); f.seats.forEach((s) => { s.additional = '0.4'; });
    const r = validate(f);
    expect(r.errors).toEqual([]);
    expect(r.warnings).toContain('Сума Доп + ОП більша за 3.6');
  });
  it('warns when more than 7 point cells are filled', () => {
    const f = valid(); f.firstKilled = 6; f.seats.slice(0, 7).forEach((s) => { s.additional = '0.1'; });
    expect(validate(f).warnings).toContain('Бали мають більше ніж 7 клітинок');
  });
  it('duplicates differing only by inner spaces are caught', () => {
    const f = valid(); f.seats[0].player = 'Іван  Петров'; f.seats[1].player = 'Іван Петров';
    expect(validate(f).fields.has('seat-2-player')).toBe(true);
  });
  it('a nickname of a player already seated is a duplicate', () => {
    const f = valid(); f.seats[0].player = 'Seezov'; f.seats[1].player = 'Сізов';
    const aliases = new Map([['сізов', 'Seezov'], ['seezov', 'Seezov']]);
    const r = validate(f, aliases);
    expect(r.errors).toContain('Гравець «Seezov» записаний двічі');
    expect(r.fields.has('seat-2-player')).toBe(true);
  });
});

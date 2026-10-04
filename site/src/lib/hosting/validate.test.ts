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
  it('result is required', () => {
    const f = valid(); f.result = null;
    expect(validate(f).fields.has('result')).toBe(true);
  });
  it('roles must be 6/2/1/1', () => {
    const f = valid(); f.seats[0].role = 'Мафія';
    expect(validate(f).errors).toContain('Ролі мають бути 6 мирних, 2 мафії, 1 дон, 1 шериф');
  });
  it('empty player is highlighted', () => {
    const f = valid(); f.seats[2].player = '';
    expect(validate(f).fields.has('seat-3-player')).toBe(true);
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
});

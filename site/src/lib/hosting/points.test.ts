import { describe, expect, it } from 'vitest';
import { supportFivePoints, winPoint } from './points';
import type { Role } from './types';

const roles: Role[] = ['Мирний', 'Мирний', 'Мирний', 'Шериф', 'Мафія', 'Мирний', 'Дон', 'Мирний', 'Мафія', 'Мирний'];

describe('supportFivePoints (season-30 sheet formula)', () => {
  it('sheet game: 1,5,7 all red → -0.15', () => expect(supportFivePoints([1, 5, 7], roles)).toBeCloseTo(-0.15, 9));
  it('empty → -0.1', () => expect(supportFivePoints([], roles)).toBe(-0.1));
  it('three blacks found → 0.9', () => expect(supportFivePoints([-5, -7, -9], roles)).toBeCloseTo(0.9, 9));
  it('two blacks + two reds hit → 0.75', () => expect(supportFivePoints([-5, -9, 1, 2], roles)).toBeCloseTo(0.75, 9));
  it('five black guesses, three hit', () => expect(supportFivePoints([-5, -7, -9, -1, -2], roles)).toBeCloseTo(0.9 - 2.0, 9));
});

describe('winPoint', () => {
  it('city win: reds 1, blacks 0', () => {
    expect(winPoint('Шериф', 'city')).toBe(1);
    expect(winPoint('Дон', 'city')).toBe(0);
  });
  it('mafia win', () => expect(winPoint('Мафія', 'mafia')).toBe(1));
  it('unrated → null', () => expect(winPoint('Мирний', 'unrated')).toBeNull());
});

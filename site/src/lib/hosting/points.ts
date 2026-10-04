import type { Result, Role } from './types';

// Port of the season-30 sheet ОП formula (Опорна 5). Signed slots: + red, − black.
const M_SUCC = [0, 0.25, 0.55, 0.9, 0.9, 0.9];
const M_MISS = [0, -0.1, -0.25, -0.45, -1.45, -2.45];
const C_MISS = [0, -0.1, -0.2, -0.35, -0.55, -0.8];
const isBlack = (r: Role | undefined) => r === 'Мафія' || r === 'Дон';

export function supportFivePoints(supportFive: number[], roles: Role[]): number {
  const g = supportFive.filter((x) => x !== 0);
  if (g.length === 0) return -0.1;
  const black = (x: number) => isBlack(roles[Math.abs(x) - 1]);
  const nMaf = g.filter((x) => x < 0).length;
  const kMaf = g.filter((x) => x < 0 && black(x)).length;
  const nCit = g.filter((x) => x > 0).length;
  const kCit = g.filter((x) => x > 0 && !black(x)).length;
  return M_SUCC[kMaf] + (M_MISS[nMaf] - M_MISS[kMaf]) + 0.1 * kCit + (C_MISS[nCit] - C_MISS[kCit]);
}

export function winPoint(role: Role, result: Result): number | null {
  if (result === 'unrated') return null;
  return (result === 'mafia') === isBlack(role) ? 1 : 0;
}

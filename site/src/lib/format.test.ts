import { describe, expect, it } from 'vitest';
import { pct, ukCount, wrTone } from './format';

describe('format', () => {
  it('formats percentages', () => {
    expect(pct(0.546)).toBe('55%');
    expect(pct(0.6123, 1)).toBe('61.2%');
  });
  it('rounds to one decimal before applying the 50 / 35 thresholds, like the app', () => {
    expect(wrTone(0.5)).toBe('good');
    expect(wrTone(0.4996)).toBe('good');
    expect(wrTone(0.3496)).toBe('mid');
    expect(wrTone(0.349)).toBe('low');
    expect(wrTone(undefined)).toBeUndefined();
  });
  it('counts in Ukrainian: 1 гра, 2–4 гри, 5+ ігор, teens always ігор', () => {
    const games = ['гра', 'гри', 'ігор'] as const;
    expect([1, 2, 4, 5, 11, 12, 14, 15, 21, 22, 25, 111].map((n) => ukCount(n, games))).toEqual([
      '1 гра', '2 гри', '4 гри', '5 ігор', '11 ігор', '12 ігор', '14 ігор', '15 ігор',
      '21 гра', '22 гри', '25 ігор', '111 ігор',
    ]);
  });
});

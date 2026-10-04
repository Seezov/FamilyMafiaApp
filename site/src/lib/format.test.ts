import { describe, expect, it } from 'vitest';
import { pct, wrTone } from './format';

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
});

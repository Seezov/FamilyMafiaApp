export const pct = (v: number, digits = 0) => `${(v * 100).toFixed(digits)}%`;

/** WR colour band; the percentage is rounded to one decimal first, as the app does. */
export function wrTone(v: number | undefined): 'good' | 'mid' | 'low' | undefined {
  if (v === undefined) return undefined;
  const p = Math.round(v * 1000) / 10;
  return p >= 50 ? 'good' : p >= 35 ? 'mid' : 'low';
}

/** `n` with the Ukrainian form for it: [one, few, many], e.g. ['гра', 'гри', 'ігор']. */
export function ukCount(n: number, forms: readonly [string, string, string]): string {
  return `${n} ${ukWord(n, forms)}`;
}

/** Just the Ukrainian form for `n` (see [ukCount]). */
export function ukWord(n: number, [one, few, many]: readonly [string, string, string]): string {
  const d = n % 10, h = n % 100;
  return h >= 11 && h <= 14 ? many : d === 1 ? one : d >= 2 && d <= 4 ? few : many;
}

export const GAMES = ['гра', 'гри', 'ігор'] as const;
export const PLAYERS = ['гравець', 'гравці', 'гравців'] as const;

export const pct = (v: number, digits = 0) => `${(v * 100).toFixed(digits)}%`;

/** WR colour band; the percentage is rounded to one decimal first, as the app does. */
export function wrTone(v: number | undefined): 'good' | 'mid' | 'low' | undefined {
  if (v === undefined) return undefined;
  const p = Math.round(v * 1000) / 10;
  return p >= 50 ? 'good' : p >= 35 ? 'mid' : 'low';
}

import fs from 'node:fs';
import { describe, expect, it } from 'vitest';
import { eventPoints, type EventKind } from './points';

const cases = JSON.parse(fs.readFileSync(new URL('../../../../test/fixtures/annual_points_cases.json', import.meta.url), 'utf8')) as
  { kind: EventKind; place: number; stars: number | null; participants: number | null; points: number }[];

describe('eventPoints', () => {
  it('matches every sheet case (same fixture as the Dart test)', () => {
    expect(cases.length).toBeGreaterThan(0);
    for (const c of cases) expect(eventPoints(c.kind, c.place, c.stars, c.participants)).toBeCloseTo(c.points, 9);
  });
  it('edges', () => {
    expect(eventPoints('season', 101)).toBe(5);
    expect(eventPoints('season', 11)).toBe(2);
    expect(eventPoints('series', 12)).toBe(1);
    expect(eventPoints('tournament', 9, 2, 30)).toBeCloseTo(10.4166666667, 9);
  });
});

import { describe, expect, it } from 'vitest';
import { validateEvent, type EventDraft } from './validate';

const ok = (): EventDraft => ({
  year: 2026, kind: 'tournament', name: 'Cup', date: '2026-02-28', stars: 2, participants: 30,
  results: [{ player: 'A', place: 1 }, { player: 'B', place: 9 }],
});

describe('validateEvent', () => {
  it('accepts a good event', () => expect(validateEvent(ok())).toEqual([]));
  it('refuses missing name, no rows, bad places, duplicates', () => {
    expect(validateEvent({ ...ok(), name: ' ' })).toContain('Name is required');
    expect(validateEvent({ ...ok(), results: [] })).toContain('Add at least one player');
    expect(validateEvent({ ...ok(), results: [{ player: 'A', place: 0 }] })).toContain('Row 1: place must be a whole number ≥ 1');
    expect(validateEvent({ ...ok(), results: [{ player: '', place: 1 }] })).toContain('Row 1: player is empty');
    expect(validateEvent({ ...ok(), results: [{ player: 'A', place: 1 }, { player: 'a', place: 2 }] })).toContain('A is listed twice');
  });
  it('tournament needs stars 0–5 and participants ≥ the largest place', () => {
    expect(validateEvent({ ...ok(), stars: null })).toContain('Stars must be 0–5');
    expect(validateEvent({ ...ok(), stars: 6 })).toContain('Stars must be 0–5');
    expect(validateEvent({ ...ok(), participants: 5 })).toContain('Participants must be at least 9');
    expect(validateEvent({ ...ok(), kind: 'series', stars: null, participants: null })).toEqual([]);
  });
  it('bad date', () => expect(validateEvent({ ...ok(), date: '28.02.2026' })).toContain('Date must be YYYY-MM-DD'));
});

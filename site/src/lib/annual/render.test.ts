import { describe, expect, it } from 'vitest';
import { eventRow } from './render';
import type { EventDraft } from './validate';

const ev = (extra: Partial<EventDraft> = {}): EventDraft => ({
  year: 2026, kind: 'series', name: 'Cup', date: '2026-02-15', stars: null, participants: null,
  results: [{ player: 'A', place: 1 }], ...extra,
});

describe('eventRow', () => {
  it('escapes everything from Firestore, the date and the id included', () => {
    const html = eventRow('a"><b', ev({ name: '<i>x</i>', date: '"><img src=x onerror=alert(1)>' }), { canSave: true, confirming: false });
    expect(html).not.toContain('<img');
    expect(html).not.toContain('<i>');
    expect(html).not.toContain('a"><b');
    expect(html).toContain('data-edit="a&quot;&gt;&lt;b"');
  });
  it('season events can be deleted but not edited', () => {
    const html = eventRow('s1', ev({ kind: 'season' }), { canSave: true, confirming: false });
    expect(html).toContain('data-del="s1"');
    expect(html).not.toContain('data-edit');
  });
  it('read-only shows no buttons; confirming shows the second step', () => {
    expect(eventRow('e', ev(), { canSave: false, confirming: false })).not.toContain('<button');
    expect(eventRow('e', ev(), { canSave: true, confirming: true })).toContain('data-del-yes="e"');
  });
});

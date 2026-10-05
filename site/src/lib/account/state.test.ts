import { describe, expect, it } from 'vitest';
import { accountView, pickList, takenKeys, type Claim, type Profile } from './state.ts';

const claim = (status: Claim['status']): Claim => ({ uid: 'u', player: 'Braun', playerKey: 'braun', email: 'a@b.c', googleName: 'A', status });
const profile: Profile = { key: 'braun', player: 'Braun', uid: 'u' };

describe('accountView', () => {
  it('walks the five states', () => {
    expect(accountView(false, null, null)).toBe('signed-out');
    expect(accountView(true, null, null)).toBe('pick');
    expect(accountView(true, claim('pending'), null)).toBe('pending');
    expect(accountView(true, claim('rejected'), null)).toBe('rejected');
    expect(accountView(true, claim('approved'), profile)).toBe('settings');
  });
  it('an approved claim whose profile is gone (unlinked mid-session) goes back to picking', () => {
    expect(accountView(true, claim('approved'), null)).toBe('pick');
  });
});

describe('takenKeys', () => {
  it('collects linked player keys', () => {
    expect([...takenKeys([profile])]).toEqual(['braun']);
  });
});

describe('pickList', () => {
  const players = [
    { name: 'Braun', slug: 'braun', games: 2750, seasons: 31 },
    { name: 'Brandon', slug: 'brandon', games: 3, seasons: 1 },
    { name: 'Floppy', slug: 'floppy', games: 900, seasons: 20 },
  ];
  it('filters case-insensitively, most games first, marks taken players', () => {
    expect(pickList(players, new Set(['braun']), 'BRA')).toEqual([
      { ...players[0], taken: true },
      { ...players[1], taken: false },
    ]);
  });
  it('empty query lists the top 30', () => {
    expect(pickList(players, new Set(), '')).toHaveLength(3);
    const many = Array.from({ length: 50 }, (_, i) => ({ name: `P${i}`, slug: `p${i}`, games: i, seasons: 1 }));
    expect(pickList(many, new Set(), '')).toHaveLength(30);
  });
});

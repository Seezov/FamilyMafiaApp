// site/src/lib/account/state.test.ts
import { describe, expect, it } from 'vitest';
import { accountView, takenKeys, type Claim, type Profile } from './state.ts';

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

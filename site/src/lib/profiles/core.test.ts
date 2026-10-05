import { describe, expect, it } from 'vitest';
import { AVATAR_MAX_CHARS, cleanNick, isAvatar, matchesFilter, nickError, playerKey } from './core.ts';

describe('playerKey', () => {
  it('is lower-case, trimmed and safe as a Firestore id', () => {
    expect(playerKey(' Braun ')).toBe('braun');
    expect(playerKey('Don`Tright')).toBe('don%60tright');
    expect(playerKey('A/B')).not.toContain('/');
    expect(playerKey('Залізний')).toBe(encodeURIComponent('залізний'));
  });
});

describe('nicks', () => {
  it('cleans whitespace', () => {
    expect(cleanNick('  Big   Boss ')).toBe('Big Boss');
  });
  it('accepts empty (= sheet name) and the own sheet name', () => {
    expect(nickError('', 'Braun', ['Залізний'])).toBeNull();
    expect(nickError('braun', 'Braun', ['Залізний'])).toBeNull();
  });
  it('checks length', () => {
    expect(nickError('X', 'Braun', [])).toMatch(/від 2 до 24/);
    expect(nickError('X'.repeat(25), 'Braun', [])).toMatch(/від 2 до 24/);
    expect(nickError('X'.repeat(24), 'Braun', [])).toBeNull();
  });
  it('rejects a name or nick of another player, any case', () => {
    expect(nickError('ЗАЛІЗНИЙ', 'Braun', ['Залізний'])).toMatch(/інший гравець/);
    expect(nickError('Boss', 'Braun', ['boss'])).toMatch(/інший гравець/);
  });
});

describe('isAvatar', () => {
  it('accepts webp and jpeg data URLs within the limit', () => {
    expect(isAvatar('data:image/webp;base64,UklGRg==')).toBe(true);
    expect(isAvatar('data:image/jpeg;base64,/9j/4A==')).toBe(true);
  });
  it('rejects other types, junk and oversize', () => {
    expect(isAvatar('data:image/png;base64,iVBO')).toBe(false);
    expect(isAvatar('https://x/y.webp')).toBe(false);
    expect(isAvatar(`data:image/webp;base64,${'A'.repeat(AVATAR_MAX_CHARS)}`)).toBe(false);
    expect(isAvatar(42)).toBe(false);
  });
});

describe('matchesFilter', () => {
  it('matches the shown nick or the sheet name', () => {
    expect(matchesFilter('bos', 'Boss', 'Braun')).toBe(true);
    expect(matchesFilter('brau', 'Boss', 'Braun')).toBe(true);
    expect(matchesFilter('flop', 'Boss', 'Braun')).toBe(false);
    expect(matchesFilter('', 'Boss', undefined)).toBe(true);
    expect(matchesFilter(' BRA ', 'Braun', undefined)).toBe(true);
  });
});

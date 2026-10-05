import { describe, expect, it } from 'vitest';
import { parseRestPage, selectProfiles } from './build.ts';

const WEBP = 'data:image/webp;base64,UklGRg==';
const restDoc = (fields: Record<string, string>) => ({
  name: 'projects/familymafiaapp/databases/(default)/documents/profiles/x',
  fields: Object.fromEntries(Object.entries(fields).map(([k, v]) => [k, { stringValue: v }])),
});

describe('parseRestPage', () => {
  it('reads string fields and the page token', () => {
    const page = parseRestPage({ documents: [restDoc({ player: 'Braun', uid: 'u1', nick: 'Boss', avatar: WEBP })], nextPageToken: 't' });
    expect(page).toEqual({ docs: [{ player: 'Braun', nick: 'Boss', avatar: WEBP }], next: 't' });
  });
  it('an empty collection has no documents key', () => {
    expect(parseRestPage({})).toEqual({ docs: [], next: undefined });
  });
  it('drops documents without a player and never keeps uid', () => {
    const page = parseRestPage({ documents: [restDoc({ uid: 'u1' }), restDoc({ player: 'Floppy', uid: 'u2' })] });
    expect(page.docs).toEqual([{ player: 'Floppy' }]);
  });
});

describe('selectProfiles', () => {
  const names = ['Braun', 'Залізний', 'Floppy'];
  it('maps by player key and writes avatars as files', () => {
    const out = selectProfiles(names, [{ player: 'Braun', nick: ' Big  Boss ', avatar: WEBP }]);
    expect(out.profiles.braun.nick).toBe('Big Boss');
    expect(out.profiles.braun.avatar).toMatch(/^avatars\/[0-9a-f]{8}\.webp$/);
    expect(out.files).toHaveLength(1);
    expect(out.files[0].path).toBe(out.profiles.braun.avatar);
    expect([...out.files[0].bytes.slice(0, 4)]).toEqual([0x52, 0x49, 0x46, 0x46]); // "RIFF"
  });
  it('jpeg avatars get a .jpg file', () => {
    const out = selectProfiles(names, [{ player: 'Braun', avatar: 'data:image/jpeg;base64,/9j/4A==' }]);
    expect(out.profiles.braun.avatar).toMatch(/\.jpg$/);
  });
  it('ignores players no longer on the site', () => {
    const out = selectProfiles(names, [{ player: 'Ghost', nick: 'Boo' }]);
    expect(out.profiles).toEqual({});
  });
  it('drops a nick that collides with another name or an earlier nick, case-insensitively', () => {
    const out = selectProfiles(names, [
      { player: 'Floppy', nick: 'boss' },
      { player: 'Braun', nick: 'ЗАЛІЗНИЙ' },
      { player: 'Залізний', nick: 'Boss' },
    ]);
    // Keys are processed in code-point order: '%D0…' (Залізний) < 'braun' < 'floppy'.
    expect(out.profiles[encodeURIComponent('залізний')]).toEqual({ nick: 'Boss' });
    expect(out.profiles.braun).toBeUndefined();  // 'ЗАЛІЗНИЙ' is another player's sheet name
    expect(out.profiles.floppy).toBeUndefined(); // 'boss' was taken by Залізний first
    expect(out.warnings).toHaveLength(2);
  });
  it('drops an invalid avatar or nick with a warning', () => {
    const out = selectProfiles(names, [{ player: 'Braun', nick: 'X', avatar: 'data:image/png;base64,AA==' }]);
    expect(out.profiles.braun).toBeUndefined();
    expect(out.warnings).toHaveLength(2);
  });
});

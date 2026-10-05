// site/src/lib/profiles/core.ts
// Profile rules shared by the account pages, the build script and the site.
// Keep in sync with firestore.rules (nick length, avatar pattern and size).
export const NICK_MIN = 2;
export const NICK_MAX = 24;
export const AVATAR_MAX_CHARS = 140_000;
export const AVATAR_RE = /^data:image\/(webp|jpeg);base64,[A-Za-z0-9+/]+=*$/;

/** Firestore id of a player's profile: the display name, case-insensitive like the app's resolver. */
export const playerKey = (name: string) => encodeURIComponent(name.trim().toLowerCase());

export const cleanNick = (s: string) => s.trim().replace(/\s+/g, ' ');

export function nickError(nick: string, own: string, taken: Iterable<string>): string | null {
  if (nick === '') return null;
  if (nick.length < NICK_MIN || nick.length > NICK_MAX) return `Нік має бути від ${NICK_MIN} до ${NICK_MAX} символів.`;
  const low = nick.toLowerCase();
  if (low === own.trim().toLowerCase()) return null;
  for (const t of taken) if (t.trim().toLowerCase() === low) return 'Такий нік чи імʼя вже має інший гравець.';
  return null;
}

export const isAvatar = (s: unknown): s is string =>
  typeof s === 'string' && s.length <= AVATAR_MAX_CHARS && AVATAR_RE.test(s);

/** Players-list filter: the nick that is shown, or the sheet name kept in data-alt. */
export function matchesFilter(needle: string, shown: string, alt: string | undefined) {
  const n = needle.trim().toLowerCase();
  return !n || shown.toLowerCase().includes(n) || (alt ?? '').toLowerCase().includes(n);
}

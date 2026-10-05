const base = import.meta.env.BASE_URL.replace(/\/$/, '');

/** Site-internal URL under the base path; `href('players/')` → `/FamilyMafiaApp/players/`. */
export const href = (p: string) => `${base}/${p.replace(/^\//, '')}`;
export const playerHref = (slug: string) => href(`players/${slug}/`);
export const seasonHref = (id: number, small = false) => href(`season/${id}/${small ? 'small/' : ''}`);
export const gamesHref = (id: number, player?: string) =>
  href(`season/${id}/games/${player ? `?player=${encodeURIComponent(player)}` : ''}`);
export const absolute = (p: string) => new URL(href(p), 'https://seezov.github.io').toString();

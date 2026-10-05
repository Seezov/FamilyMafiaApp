// Club seasons 32+ (Firestore config/seasons): validation shared with Dart
// (test/fixtures/club_season_cases.json), defaults for /seasons/edit/, /host/'s default season. Pure.
export interface ClubSeason { id: number; title: string; smallLeagueMinGames: number; startDate: string }

export const MAX_SEASONS = 100;

function realDate(s: string): boolean {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(s);
  if (!m) return false;
  const d = new Date(Date.UTC(+m[1], +m[2] - 1, +m[3]));
  return d.getUTCFullYear() === +m[1] && d.getUTCMonth() === +m[2] - 1 && d.getUTCDate() === +m[3];
}

export function seasonErrors(list: ClubSeason[], lastJsonId: number): string[] {
  const errors: string[] = [];
  if (list.length > MAX_SEASONS) errors.push(`${list.length} seasons, the limit is ${MAX_SEASONS}`);
  list.forEach((s, i) => {
    const want = lastJsonId + 1 + i;
    if (s.id !== want) errors.push(`season ${s.id}: expected id ${want}`);
    const t = s.title.trim().length;
    if (t < 1 || t > 40) errors.push(`season ${s.id}: title must be 1–40 characters`);
    if (!Number.isInteger(s.smallLeagueMinGames) || s.smallLeagueMinGames < 1 || s.smallLeagueMinGames > 100) {
      errors.push(`season ${s.id}: small league minimum must be 1–100`);
    }
    if (!realDate(s.startDate)) errors.push(`season ${s.id}: start date "${s.startDate}" is not a YYYY-MM-DD date`);
  });
  return errors;
}

/** Defaults for «Create season N»: next id, `Season N`, the previous season's minimum, today. */
export function nextSeason(list: ClubSeason[], lastJsonId: number, jsonMinGames: number, today: string): ClubSeason {
  const prev = list.at(-1);
  const id = (prev?.id ?? lastJsonId) + 1;
  return { id, title: `Season ${id}`, smallLeagueMinGames: prev?.smallLeagueMinGames ?? jsonMinGames, startDate: today };
}

/** The newest club season whose start date has come, else [fallback]. */
export function hostDefaultSeason(list: ClubSeason[], today: string, fallback: number | null): number | null {
  const started = list.filter((s) => s.startDate <= today);
  return started.length ? started[started.length - 1].id : fallback;
}

export function toSeasons(raw: unknown): ClubSeason[] {
  return (Array.isArray(raw) ? raw : []).filter((s): s is ClubSeason =>
    !!s && typeof s === 'object' && Number.isInteger(s.id) && typeof s.title === 'string'
      && Number.isInteger(s.smallLeagueMinGames) && typeof s.startDate === 'string')
    .map((s) => ({ id: s.id, title: s.title, smallLeagueMinGames: s.smallLeagueMinGames, startDate: s.startDate }));
}

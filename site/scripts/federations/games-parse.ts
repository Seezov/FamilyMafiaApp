// Parsers for federation tournament games (see the federation games design doc). Pure: text/JSON in, FedTournament out.
// A game without a known result or without exactly ten seats with known roles is skipped, never thrown.
import type { FedGame, FedRole, FedSeat, FedTournament, TournamentRef } from '../../src/lib/federations/games.ts';
import { inertiaProps } from './parse.ts';

const day = (s: unknown) => String(s ?? '').slice(0, 10);
const addDays = (d: string, n: number) => new Date(Date.parse(`${d}T00:00:00Z`) + n * 86400000).toISOString().slice(0, 10);

function game(key: string, result: 'city' | 'mafia' | undefined, seats: (FedSeat | null)[], extra: Partial<FedGame> = {}): FedGame | null {
  if (!result || seats.length !== 10 || seats.some((s) => !s)) return null;
  const sorted = (seats as FedSeat[]).toSorted((a, b) => a.seat - b.seat);
  if (sorted.some((s, i) => s.seat !== i + 1)) return null;
  return { key, ...extra, result, seats: sorted };
}

function seat(n: unknown, nick: unknown, role: FedRole | undefined, fedPlayerId?: unknown): FedSeat | null {
  if (!role) return null;
  const id = fedPlayerId ? String(fedPlayerId) : '';
  return { seat: Number(n), nick: String(nick ?? '').trim(), ...(id && { fedPlayerId: id }), role };
}

// emotion.games and mafgame.org use the same words.
const RED_BLACK_ROLES: Record<string, FedRole> = { red: 'citizen', sheriff: 'sheriff', black: 'mafia', don: 'don' };
const RED_BLACK_RESULT: Record<string, 'city' | 'mafia'> = { red: 'city', black: 'mafia' };

// emotion.games — api-v1.emotion.games. year_points/player/<id> lists every tournament (the year parameter is ignored).
export function parseEgPlayer(j: any): TournamentRef[] {
  return (j.tournaments ?? []).map((t: any) => ({ fed: 'eg', tournamentId: String(t.id), date: day(t.start_date) }));
}

export function parseEgInfo(j: any): Omit<FedTournament, 'games'> {
  const i = j.info;
  const dateFrom = day(i.start_date);
  return {
    fed: 'eg', tournamentId: String(i.id), name: String(i.name).trim(), dateFrom,
    dateTo: addDays(dateFrom, Math.max(1, Number(i.time_duration) || 1) - 1), online: !!i.online,
    ...(i.is_imafia && i.im_id ? { alsoOn: { fed: 'imafia' as const, id: String(i.im_id) } } : {}),
  };
}

export function parseEgGames(j: any): FedGame[] {
  const out: FedGame[] = [];
  for (const [part, prefix] of [[j.qualifiers, 'q'], [j.finals, 'f']] as const) {
    for (const line of part?.lines ?? []) {
      for (const t of line.tables ?? []) {
        const seats = (t.game_board?.rows ?? []).map((r: any) => seat(r.place, r.nickname, RED_BLACK_ROLES[r.role], r.profile_id));
        const g = game(`${prefix}-${t.session ?? line.session}-${t.table_num}`, RED_BLACK_RESULT[t.game_result], seats,
          { round: String(t.session ?? line.session), table: Number(t.table_num) });
        if (g) out.push(g);
      }
    }
  }
  return out;
}

// mafgame.org — Inertia props. Seats carry the tournament's participant id; the participants page maps it to the user id.
export function parseMafgameHistory(html: string): TournamentRef[] {
  return (inertiaProps(html).history ?? []).map((t: any) => ({ fed: 'mafgame', tournamentId: String(t.id), date: day(t.start_date) }));
}

export function parseMafgameTournament(gamesHtml: string, participantsHtml: string): FedTournament {
  const p = inertiaProps(gamesHtml);
  const t = p.tournament ?? p.games.tournament;
  const users = new Map<string, string>();
  for (const pl of inertiaProps(participantsHtml).players ?? []) if (pl.user_id) users.set(String(pl.id), String(pl.user_id));
  const bySeat = new Map<string, (FedSeat | null)[]>();
  for (const [k, s] of Object.entries<any>(p.games.seats ?? {})) {
    const i = k.lastIndexOf('-');
    const list = bySeat.get(k.slice(0, i)) ?? [];
    list.push(seat(k.slice(i + 1), s.original_nickname, RED_BLACK_ROLES[s.role], users.get(String(s.player_id))));
    bySeat.set(k.slice(0, i), list);
  }
  const games: FedGame[] = [];
  for (const [key, res] of Object.entries<any>(p.games.results ?? {})) {
    const [part, session, table] = key.split('-');
    const g = game(key, RED_BLACK_RESULT[res], bySeat.get(key) ?? [], { round: `${part}-${session}`, table: Number(table) });
    if (g) games.push(g);
  }
  const dateFrom = day(t.start_date);
  return {
    fed: 'mafgame', tournamentId: String(t.id), name: String(t.name).trim(), dateFrom,
    dateTo: addDays(dateFrom, Math.max(1, Number(t.days) || 1) - 1), online: !!t.online, games,
  };
}

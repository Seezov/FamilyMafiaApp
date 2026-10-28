// Parsers for federation tournament games (see the federation games design doc). Pure: text/JSON in, FedTournament out.
// A game without a known result or without exactly ten seats with known roles is skipped, never thrown.
import type { FedGame, FedRole, FedSeat, FedTournament, TournamentRef } from '../../src/lib/federations/games.ts';
import { inertiaProps, text } from './parse.ts';

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

// imafia.org — HTML. The profile lists /tournament/<id> with dd/mm/yyyy dates; the tournament page has
// «Дата» dd.mm.yyyy, «Тривалість (днів)» and games_item blocks. role_1 citizen, role_2 sheriff, role_3 mafia,
// role_4 don; result_1 city, result_2 mafia (checked on tournament 1760: 6/1/2/1 seats, winners score 2).
const IMAFIA_ROLES: Record<string, FedRole> = { 1: 'citizen', 2: 'sheriff', 3: 'mafia', 4: 'don' };
const IMAFIA_RESULT: Record<string, 'city' | 'mafia'> = { 1: 'city', 2: 'mafia' };
const dmy = (d: string, m: string, y: string) => `${y}-${m.padStart(2, '0')}-${d.padStart(2, '0')}`;

export function parseImafiaProfile(html: string): TournamentRef[] {
  const out: TournamentRef[] = [];
  for (const m of html.matchAll(/<td>(\d{1,2})\/(\d{1,2})\/(\d{4})<\/td>\s*<td><a href="\/tournament\/(\d+)"/g)) {
    out.push({ fed: 'imafia', tournamentId: m[4], date: dmy(m[1], m[2], m[3]) });
  }
  return out;
}

const infoCell = (html: string, label: string) =>
  new RegExp(String.raw`<td>${label}</td>\s*<td>\s*([^<]*?)\s*<`).exec(html)?.[1];

export function parseImafiaTournament(html: string, id: string): FedTournament {
  const name = text(/<h1 class="tournament_page_name">([^<]*)/.exec(html)?.[1] ?? '');
  const d = /(\d{1,2})\.(\d{1,2})\.(\d{4})/.exec(infoCell(html, 'Дата') ?? '');
  const dateFrom = d ? dmy(d[1], d[2], d[3]) : '';
  const days = Math.max(1, Number(infoCell(html, String.raw`Тривалість \(днів\)`)) || 1);
  const games: FedGame[] = [];
  html.split('<div class="games_item games_item_js').slice(1).forEach((block, i) => {
    const title = text(/games_item_name">([\s\S]*?)<\/div>/.exec(block)?.[1] ?? '');
    const g = /Гра #(\d+)/.exec(title)?.[1];
    const t = /Стіл #(\d+)/.exec(title)?.[1];
    // Row cells: #seat, role icon, score, player (link /u/<id>, or plain text for a guest), notes.
    const seats = block.split('<div class="games_item_tr').slice(1).map((row) => {
      const td = row.split('<div class="games_item_td">');
      const n = /#(\d+)/.exec(td[1] ?? '')?.[1];
      return n ? seat(n, text(td[4] ?? ''), IMAFIA_ROLES[/role_(\d)/.exec(td[2] ?? '')?.[1] ?? ''], /href="\/u\/(\d+)"/.exec(td[4] ?? '')?.[1]) : null;
    });
    const game_ = game(g && t ? `t${t}-g${g}` : `n${i + 1}`, IMAFIA_RESULT[/result_(\d)/.exec(block)?.[1] ?? ''], seats,
      t ? { table: Number(t) } : {});
    if (game_) games.push(game_);
  });
  return { fed: 'imafia', tournamentId: id, name, dateFrom, dateTo: dateFrom && addDays(dateFrom, days - 1), games };
}

// fiim.world — HTML. The profile lists /user/<id>/games/<tid> after an award date; that page holds only this
// player's games (his seat's table is highlighed-result), with fiim's global game id. Other seats are nick text.
// The award date is the last day; tournaments run up to three days, so dateFrom = award − 2.
const FIIM_ROLES: Record<string, FedRole> = { red: 'citizen', sheriff: 'sheriff', black: 'mafia', don: 'don' };

export function parseFiimProfile(html: string, userId: string): TournamentRef[] {
  const out: TournamentRef[] = [];
  const re = new RegExp(String.raw`(\d{4}-\d{2}-\d{2})<\/span>[\s\S]*?\/user\/${userId}\/games\/(\d+)"`, 'g');
  for (const m of html.matchAll(re)) out.push({ fed: 'fiim', tournamentId: m[2], date: m[1] });
  return out;
}

export function parseFiimUserGames(html: string, tid: string, userId: string, awardDate: string): FedTournament {
  const name = text(/<h1>[^<]*в турнире \[([^<]*)\]<\/h1>/.exec(html)?.[1] ?? '');
  const games: FedGame[] = [];
  for (const block of html.split('<div class="panel-heading">').slice(1)) {
    const id = /href="#game-(\d+)"/.exec(block)?.[1];
    const head = text(/<a [^>]*href="#game-[\s\S]*?>([\s\S]*?)<\/a>/.exec(block)?.[1] ?? '');
    const result = /Победа мафии/.test(head) ? 'mafia' : /Победа города/.test(head) ? 'city' : undefined;
    const seats = block.split('<div class="game-result-block">').slice(1).map((s) => {
      const m = /<th class="place-no[^"]*">\s*(\d+)\s*<\/th>\s*<th[^>]*>([\s\S]*?)<\/th>/.exec(s);
      const role = FIIM_ROLES[/icon-(red|black|sheriff|don)"/.exec(s)?.[1] ?? ''];
      return m ? seat(m[1], text(m[2]), role, s.includes('highlighed-result') ? userId : undefined) : null;
    });
    const g = id && game(`g${id}`, result, seats, {
      round: /Тур\s+(\d+)/.exec(head)?.[1], table: Number(/Стол\s+(\d+)/.exec(head)?.[1]) || undefined,
    });
    if (g) games.push(g);
  }
  return { fed: 'fiim', tournamentId: tid, name, dateFrom: addDays(awardDate, -2), dateTo: awardDate, games };
}

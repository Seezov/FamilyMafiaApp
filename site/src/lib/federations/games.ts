// Federation tournament games (scripts/fetch-federation-games.ts) folded into the club's player stats:
// attribution through confirmed links, club / cross-federation duplicates, possible duplicates for review. Pure.
import { gameKey, nickVariants, normNick, type Fed, type FedDoc } from './core.ts';

export type FedRole = 'citizen' | 'sheriff' | 'mafia' | 'don';
export interface FedSeat { seat: number; nick: string; fedPlayerId?: string; role: FedRole }
export interface FedGame { key: string; round?: string; table?: number; result: 'city' | 'mafia'; seats: FedSeat[] }
/** Dates are YYYY-MM-DD. alsoOn: the same tournament published on another federation. */
export interface FedTournament {
  fed: Fed; tournamentId: string; name: string; dateFrom: string; dateTo: string;
  online?: boolean; alsoOn?: { fed: Fed; id: string }; games: FedGame[];
}
export interface TournamentRef { fed: Fed; tournamentId: string; date?: string }

/** A roster player as data/players.json exports him (aliases: lower-cased name + nicknames). */
export interface ClubPlayer { name: string; slug: string; aliases: string[] }
/** A club rating game from data/games/N.json (the caller leaves out unrated games). A blank seat has no player. */
export interface ClubGame {
  id: string; season: number; date: string | null; result: 'city' | 'mafia';
  seats: { n: number; slug?: string; player?: string; role: string }[];
}
export interface ReviewItem {
  key: string; fed: Fed; tournament: string; tournamentId: string; date: string; round?: string; table?: number;
  matched: number; fedSeats: { seat: number; nick: string; role: FedRole; slug?: string }[];
  club: { season: number; id: string; date: string; seats: { seat: number; player: string; role: string; slug?: string }[] };
}
export interface FedGamesFile {
  generatedAt: string;
  players: Record<string, { games: number; wins: number }>;
  review: ReviewItem[];
  counts: { tournaments: number; games: number; clubDuplicates: number; crossFedDuplicates: number; possible: number; counted: number };
}

/** Partial-match rules (design doc): at least this many seats on player + role, within this many days of the tournament. */
export const PARTIAL_MIN_SEATS = 7;
export const PARTIAL_WINDOW_DAYS = 3;

const CLUB_ROLE: Record<string, FedRole> = { civilian: 'citizen', sheriff: 'sheriff', mafia: 'mafia', don: 'don' };
const shift = (d: string, n: number) => new Date(Date.parse(`${d}T00:00:00Z`) + n * 86400000).toISOString().slice(0, 10);
const cityRole = (r: FedRole) => r === 'citizen' || r === 'sheriff';
const copyGame = (g: FedGame): FedGame => ({ ...g, seats: g.seats.map((s) => ({ ...s })) });

/** Several fetched pages of one tournament (fiim: one per club player) → one tournament, games unioned by key. */
export function mergeParts(parts: FedTournament[]): FedTournament[] {
  const by = new Map<string, FedTournament>();
  for (const p of parts) {
    const k = `${p.fed}:${p.tournamentId}`;
    const t = by.get(k);
    if (!t) {
      by.set(k, { ...p, games: p.games.map(copyGame) });
      continue;
    }
    if (p.dateFrom && (!t.dateFrom || p.dateFrom < t.dateFrom)) t.dateFrom = p.dateFrom;
    if (p.dateTo > t.dateTo) t.dateTo = p.dateTo;
    for (const g of p.games) {
      const have = t.games.find((x) => x.key === g.key);
      if (!have) {
        t.games.push(copyGame(g));
        continue;
      }
      for (const s of g.seats) {
        const into = have.seats.find((x) => x.seat === s.seat);
        if (into && !into.fedPlayerId && s.fedPlayerId) into.fedPlayerId = s.fedPlayerId;
      }
    }
  }
  return [...by.values()];
}

export function computeFedGames(i: { tournaments: FedTournament[]; club: ClubGame[]; players: ClubPlayer[]; doc: FedDoc; now: string }): FedGamesFile {
  const slugByName = new Map(i.players.map((p) => [p.name, p.slug]));
  const owner = new Map<string, string>(); // "fed:id" → slug of the roster player who confirmed that profile
  for (const [name, feds] of Object.entries(i.doc.links)) {
    const slug = slugByName.get(name);
    if (!slug) continue;
    for (const [fed, ids] of Object.entries(feds)) for (const id of ids ?? []) owner.set(`${fed}:${id}`, slug);
  }
  const byAlias = new Map<string, Set<string>>();
  for (const p of i.players) {
    for (const a of [p.name, ...p.aliases]) {
      const k = normNick(a);
      byAlias.set(k, (byAlias.get(k) ?? new Set()).add(p.slug));
    }
  }
  const linked = (fed: Fed, s: FedSeat) => (s.fedPlayerId ? owner.get(`${fed}:${s.fedPlayerId}`) : undefined);
  // Seat identity for matching: the confirmed owner, else a nick that names exactly one roster player, else the nick.
  const slugOf = (fed: Fed, s: FedSeat): string | undefined => {
    const l = linked(fed, s);
    if (l) return l;
    const hits = new Set(nickVariants(s.nick).flatMap((v) => [...(byAlias.get(normNick(v)) ?? [])]));
    return hits.size === 1 ? [...hits][0] : undefined;
  };
  const fedIdents = (fed: Fed, g: FedGame) => g.seats.map((s) => `${slugOf(fed, s) ?? `nick:${normNick(s.nick)}`}:${s.role}`);
  const clubIdents = (g: ClubGame) => g.seats.toSorted((a, b) => a.n - b.n)
    .map((s) => `${s.slug ?? (s.player ? `nick:${normNick(s.player)}` : `blank:${s.n}`)}:${CLUB_ROLE[s.role] ?? s.role}`);

  const tournaments = mergeParts(i.tournaments);
  const counts = { tournaments: tournaments.length, games: 0, clubDuplicates: 0, crossFedDuplicates: 0, possible: 0, counted: 0 };
  const present = new Set(tournaments.map((t) => `${t.fed}:${t.tournamentId}`));

  // 1. Cross-federation: copies of one game collapse into the copy with most ids, keeping the confirmed players of
  // every copy. An alsoOn tournament (eg's marker for an imafia one) whose twin was fetched hands each game to its twin
  // game there (see twinScore); a game with no twin counts on its own.
  type Owner = { seat: number; slug: string; role: FedRole };
  type Item = { t: FedTournament; g: FedGame; idents: string[]; owners: Owner[] };
  const ownersOf = (t: FedTournament, g: FedGame): Owner[] => g.seats.flatMap((s) => {
    const slug = linked(t.fed, s);
    return slug ? [{ seat: s.seat, slug, role: s.role }] : [];
  });
  const addOwners = (into: Item, from: Owner[]) => {
    for (const o of from) if (!into.owners.some((x) => x.slug === o.slug)) into.owners.push(o);
  };
  const best = new Map<string, Item>();
  const byTournament = new Map<string, Item[]>();
  const ids = (x: Item) => x.g.seats.filter((s) => s.fedPlayerId).length;
  const later: Item[] = [];
  for (const t of tournaments) {
    counts.games += t.games.length;
    for (const g of t.games) {
      const x: Item = { t, g, idents: fedIdents(t.fed, g), owners: ownersOf(t, g) };
      if (t.alsoOn && present.has(`${t.alsoOn.fed}:${t.alsoOn.id}`)) {
        later.push(x);
        continue;
      }
      const sig = x.idents.join('|');
      const have = best.get(sig);
      if (!have) best.set(sig, x);
      else {
        counts.crossFedDuplicates++;
        const [keep, drop] = ids(x) > ids(have) ? [x, have] : [have, x];
        addOwners(keep, drop.owners);
        best.set(sig, keep);
      }
    }
  }
  for (const x of best.values()) {
    const k = `${x.t.fed}:${x.t.tournamentId}`;
    byTournament.set(k, [...(byTournament.get(k) ?? []), x]);
  }
  // A twin game: the same roles at every seat, no seat where the two copies name different roster players, and at
  // least one roster player in the same seat (strangers' nicks may be spelled differently on the two sites).
  const roster = (id: string) => (id.startsWith('nick:') ? undefined : id.slice(0, id.lastIndexOf(':')));
  const twinScore = (x: Item, y: Item) => {
    let same = 0;
    for (let k = 0; k < 10; k++) {
      if (x.g.seats[k].role !== y.g.seats[k].role) return 0;
      const [a, b] = [roster(x.idents[k]), roster(y.idents[k])];
      if (a && b && a !== b) return 0;
      if (a && a === b) same++;
    }
    return same;
  };
  for (const x of later) {
    let twin: { y: Item; n: number } | undefined;
    for (const y of byTournament.get(`${x.t.alsoOn!.fed}:${x.t.alsoOn!.id}`) ?? []) {
      const n = twinScore(x, y);
      if (n > 0 && (!twin || n > twin.n)) twin = { y, n };
    }
    const sig = x.idents.join('|');
    const into = twin?.y ?? best.get(sig);
    if (into) {
      counts.crossFedDuplicates++;
      addOwners(into, x.owners);
    } else best.set(sig, x);
  }

  // 2. Club rating games: a full match at any date drops; a partial match near the tournament waits for a decision.
  const clubFull = new Set(i.club.map((g) => clubIdents(g).join('|')));
  const clubByDate = new Map<string, { g: ClubGame; idents: string[] }[]>();
  for (const g of i.club) if (g.date) clubByDate.set(g.date, [...(clubByDate.get(g.date) ?? []), { g, idents: clubIdents(g) }]);

  const players: FedGamesFile['players'] = {};
  const review: ReviewItem[] = [];
  for (const [sig, { t, g, idents, owners }] of best) {
    if (!owners.length) continue;
    if (clubFull.has(sig)) {
      counts.clubDuplicates++;
      continue;
    }
    const key = gameKey(t.fed, t.tournamentId, g.key);
    const decision = i.doc.gameDecisions?.[key];
    let match: { g: ClubGame; n: number } | undefined;
    if (t.dateFrom) {
      const last = shift(t.dateTo || t.dateFrom, PARTIAL_WINDOW_DAYS);
      for (let d = shift(t.dateFrom, -PARTIAL_WINDOW_DAYS); d <= last; d = shift(d, 1)) {
        for (const c of clubByDate.get(d) ?? []) {
          const n = c.idents.filter((x, k) => x === idents[k]).length;
          if (n >= PARTIAL_MIN_SEATS && (!match || n > match.n)) match = { g: c.g, n };
        }
      }
    }
    // Decided games stay listed, so a decision can be undone on /federations/edit/.
    if (match) {
      review.push({
        key, fed: t.fed, tournament: t.name, tournamentId: t.tournamentId, date: t.dateFrom,
        ...(g.round !== undefined && { round: g.round }), ...(g.table !== undefined && { table: g.table }),
        matched: match.n,
        fedSeats: g.seats.map((s) => {
          const slug = slugOf(t.fed, s);
          return { seat: s.seat, nick: s.nick, role: s.role, ...(slug && { slug }) };
        }),
        club: {
          season: match.g.season, id: match.g.id, date: match.g.date!,
          seats: match.g.seats.toSorted((a, b) => a.n - b.n).map((s) => ({ seat: s.n, player: s.player ?? '', role: s.role, ...(s.slug && { slug: s.slug }) })),
        },
      });
    }
    if (decision === 'same') {
      counts.clubDuplicates++;
      continue;
    }
    if (match && decision !== 'different') {
      counts.possible++;
      continue;
    }
    counts.counted++;
    for (const o of owners) {
      const p = (players[o.slug] ??= { games: 0, wins: 0 });
      p.games++;
      if (cityRole(o.role) === (g.result === 'city')) p.wins++;
    }
  }
  review.sort((a, b) => b.date.localeCompare(a.date) || a.key.localeCompare(b.key));
  return { generatedAt: i.now, players, review, counts };
}

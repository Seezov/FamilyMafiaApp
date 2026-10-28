// Roster player ↔ federation profile links (/federations/edit/, Firestore config/federations) and
// the candidates file written by scripts/find-federation-players.ts. Pure: no I/O.
import type { RosterEntry, RosterOp } from '../roster/roster';

export type Fed = 'imafia' | 'eg' | 'fiim' | 'mafgame';
export const FEDS: Fed[] = ['imafia', 'eg', 'fiim', 'mafgame'];
export const FED_TITLES: Record<Fed, string> = { imafia: 'imafia.org', eg: 'emotion.games', fiim: 'fiim.world', mafgame: 'mafgame.org' };

export interface Candidate {
  fed: Fed; id: string; nick: string;
  realName?: string; club?: string; city?: string; games?: number;
  url: string; strength: 'club' | 'nick';
}
export interface CandidatesFile { generatedAt: string; players: Record<string, Candidate[]>; unmatched: Candidate[] }
export type GameDecision = 'same' | 'different';
/** gameDecisions: possible duplicate federation games (key from gameKey) the admin ruled on, see /federations/edit/. */
export interface FedDoc {
  links: Record<string, Partial<Record<Fed, string[]>>>; rejected: Record<string, string[]>;
  gameDecisions?: Record<string, GameDecision>;
}
export type FedOp =
  | { kind: 'link' | 'unlink'; player: string; fed: Fed; id: string }
  | { kind: 'reviewed'; player: string; keys: string[] }
  | { kind: 'unreject'; player: string; key: string }
  | { kind: 'decide'; key: string; value: GameDecision | null };

// Latin letters that look like Cyrillic ones (in either case), so a nick typed in the "wrong" alphabet still
// matches. Mapped after lower-casing, so matching stays case-insensitive.
const LOOKALIKE: Record<string, string> = { a: 'а', b: 'в', c: 'с', e: 'е', h: 'н', i: 'і', k: 'к', m: 'м', o: 'о', p: 'р', t: 'т', x: 'х', y: 'у' };

export const normNick = (s: string) =>
  s.normalize('NFC').trim().replace(/\s+/g, ' ').toLowerCase().replace(/[abcehikmoptxy]/g, (ch) => LOOKALIKE[ch]);

export const candKey = (c: { fed: Fed; id: string }) => `${c.fed}:${c.id}`;
export const gameKey = (fed: Fed, tournamentId: string, key: string) => `${fed}:${tournamentId}:${key}`;

/** "Braun (Браун)" → the whole nick and both halves, so either spelling matches the roster. */
export function nickVariants(nick: string): string[] {
  const m = /^(.+?)\s*\((.+)\)\s*$/.exec(nick);
  return m ? [nick, m[1].trim(), m[2].trim()] : [nick];
}

export function profileUrl(fed: Fed, id: string): string {
  switch (fed) {
    case 'imafia': return `https://imafia.org/u/${id}`;
    case 'eg': return `https://emotion.games/ua/players/${id}`;
    case 'fiim': return `https://fiim.world/user/${id}/show`;
    case 'mafgame': return `https://mafgame.org/user/${id}/view`;
  }
}

const URL_PATTERNS: [Fed, RegExp][] = [
  ['imafia', /^(?:www\.)?imafia\.org\/u\/(\d+)/],
  ['eg', /^(?:www\.)?emotion\.games\/(?:[a-z]{2}\/)?players\/(\d+)/],
  ['fiim', /^(?:www\.)?fiim\.world\/user\/(\d+)/],
  ['mafgame', /^(?:www\.)?mafgame\.org\/user\/(\d+)/],
];

export function parseProfileUrl(url: string): { fed: Fed; id: string } | null {
  const s = url.trim().replace(/^https?:\/\//i, '');
  for (const [fed, re] of URL_PATTERNS) {
    const m = re.exec(s);
    if (m) return { fed, id: m[1] };
  }
  return null;
}

/** Candidates stored under the player's name or any of his nicknames (the file may predate a rename). */
export function candidatesFor(file: CandidatesFile, entry: RosterEntry): Candidate[] {
  const seen = new Set<string>();
  const out: Candidate[] = [];
  for (const n of [entry.name, ...entry.nicknames]) {
    for (const c of file.players[n] ?? []) {
      if (!seen.has(candKey(c))) { seen.add(candKey(c)); out.push(c); }
    }
  }
  return out;
}

const copy = (d: FedDoc): FedDoc => ({
  links: Object.fromEntries(Object.entries(d.links).map(([p, l]) => [p, Object.fromEntries(Object.entries(l).map(([f, ids]) => [f, [...ids!]]))])),
  rejected: Object.fromEntries(Object.entries(d.rejected).map(([p, r]) => [p, [...r]])),
  ...(d.gameDecisions && { gameDecisions: { ...d.gameDecisions } }),
});

export const linkedKeys = (d: FedDoc, player: string): Set<string> =>
  new Set(FEDS.flatMap((f) => (d.links[player]?.[f] ?? []).map((id) => `${f}:${id}`)));

export function applyFedOp(d: FedDoc, op: FedOp): FedDoc {
  const next = copy(d);
  if (op.kind === 'decide') {
    const decisions = (next.gameDecisions ??= {});
    if (op.value) decisions[op.key] = op.value;
    else delete decisions[op.key];
    return next;
  }
  const rejected = (next.rejected[op.player] ??= []);
  switch (op.kind) {
    case 'link': {
      const ids = ((next.links[op.player] ??= {})[op.fed] ??= []);
      if (!ids.includes(op.id)) ids.push(op.id);
      next.rejected[op.player] = rejected.filter((k) => k !== `${op.fed}:${op.id}`);
      break;
    }
    case 'unlink': {
      const l = (next.links[op.player] ??= {});
      l[op.fed] = (l[op.fed] ?? []).filter((id) => id !== op.id);
      break;
    }
    case 'reviewed':
      for (const k of op.keys) if (!rejected.includes(k)) rejected.push(k);
      break;
    case 'unreject':
      next.rejected[op.player] = rejected.filter((k) => k !== op.key);
      break;
  }
  return next;
}

/** Keeps config/federations keyed by the roster's display names through a rename or merge. */
export function moveForRosterOp(d: FedDoc, op: RosterOp): FedDoc {
  if (op.kind !== 'rename' && op.kind !== 'merge') return d;
  // The roster saves a renamed player under the cleaned name; a rename to the same name changes nothing.
  const [from, to] = op.kind === 'rename' ? [op.player, op.to.trim().replace(/\s+/g, ' ')] : [op.from, op.into];
  if (from === to) return d;
  const next = copy(d);
  const links = next.links[from];
  if (links) {
    const into = (next.links[to] ??= {});
    for (const f of FEDS) {
      for (const id of links[f] ?? []) {
        const ids = (into[f] ??= []);
        if (!ids.includes(id)) ids.push(id);
      }
    }
    delete next.links[from];
  }
  const rej = next.rejected[from];
  if (rej) {
    const into = (next.rejected[to] ??= []);
    for (const k of rej) if (!into.includes(k)) into.push(k);
    delete next.rejected[from];
  }
  // A profile one of the merged players confirmed and the other rejected stays confirmed.
  if (next.rejected[to]) {
    const linked = linkedKeys(next, to);
    next.rejected[to] = next.rejected[to].filter((k) => !linked.has(k));
  }
  return next;
}

export function rowStatus(d: FedDoc, player: string, cands: Candidate[]): 'unreviewed' | 'confirmed' | 'nothing' | 'reviewed' {
  const linked = linkedKeys(d, player);
  const rejected = new Set(d.rejected[player] ?? []);
  if (cands.some((c) => !linked.has(candKey(c)) && !rejected.has(candKey(c)))) return 'unreviewed';
  if (linked.size) return 'confirmed';
  return cands.length ? 'reviewed' : 'nothing';
}

/** Candidate key → players, for profiles confirmed for two or more roster players. */
export function sharedLinks(d: FedDoc): Map<string, string[]> {
  const by = new Map<string, string[]>();
  for (const player of Object.keys(d.links)) {
    for (const k of linkedKeys(d, player)) by.set(k, [...(by.get(k) ?? []), player]);
  }
  return new Map([...by].filter(([, ps]) => ps.length >= 2));
}

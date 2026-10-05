// The club's player list (Firestore config/players): validation shared with Dart
// (test/fixtures/roster_cases.json) and the edits /players/edit/ makes. Pure: no I/O.
export interface RosterEntry { name: string; nicknames: string[] }
export type RosterOp =
  | { kind: 'add'; name: string }
  | { kind: 'nick-add'; player: string; nick: string }
  | { kind: 'nick-remove'; player: string; nick: string }
  | { kind: 'rename'; player: string; to: string }
  | { kind: 'merge'; from: string; into: string };

export const MAX_ENTRIES = 2000;
export const MAX_NICKNAMES = 50;
const low = (s: string) => s.toLowerCase();
const names = (e: RosterEntry) => [e.name, ...e.nicknames];
const clean = (s: string) => s.trim().replace(/\s+/g, ' ');
const junk = (n: string) => n.length < 2 || /^[\d/\\.]+$/.test(n);

export function rosterClashes(r: RosterEntry[]): string[] {
  const owner = new Map<string, number>();
  const clashes = new Set<string>();
  r.forEach((e, i) => {
    for (const n of names(e)) {
      const k = low(n);
      if (!owner.has(k)) owner.set(k, i);
      else if (owner.get(k) !== i) clashes.add(k);
    }
  });
  return [...clashes].sort();
}

export function rosterErrors(r: RosterEntry[]): string[] {
  const errors: string[] = [];
  if (r.length > MAX_ENTRIES) errors.push(`${r.length} players, the limit is ${MAX_ENTRIES}`);
  for (const e of r) if (e.nicknames.length > MAX_NICKNAMES) errors.push(`${e.name} has ${e.nicknames.length} nicknames, the limit is ${MAX_NICKNAMES}`);
  const clashes = rosterClashes(r);
  if (clashes.length) errors.push(`names used by two players: ${clashes.join(', ')}`);
  return errors;
}

/** Drops entries whose names are all claimed by earlier ones (unreachable for the resolver). */
export function dedupeRoster(r: RosterEntry[]): RosterEntry[] {
  const seen = new Set<string>();
  return r.filter((e) => {
    const keys = names(e).map(low);
    if (keys.every((k) => seen.has(k))) return false;
    keys.forEach((k) => seen.add(k));
    return true;
  });
}

export const fromAppJson = (list: { displayName: string; nicknames?: string[] }[]): RosterEntry[] =>
  list.map((p) => ({ name: p.displayName, nicknames: [...(p.nicknames ?? [])] }));

export function ownerOf(r: RosterEntry[], name: string): string | undefined {
  const k = low(name.trim());
  return r.find((e) => names(e).some((n) => low(n) === k))?.name;
}

function find(r: RosterEntry[], player: string): number {
  const i = r.findIndex((e) => e.name === player);
  if (i < 0) throw new Error(`${player} is not in the list any more — reload`);
  return i;
}

/** A new name or nickname for entry [self] (or a new entry): long enough, nobody else's. */
function fresh(r: RosterEntry[], raw: string, self: number | null): string {
  const n = clean(raw);
  if (n.length < 2) throw new Error('A name needs at least 2 characters');
  const k = low(n);
  const other = r.findIndex((e, i) => i !== self && names(e).some((x) => low(x) === k));
  if (other >= 0) throw new Error(`"${n}" already belongs to ${r[other].name}`);
  return n;
}

export function applyOp(r: RosterEntry[], op: RosterOp): RosterEntry[] {
  const next = r.map((e) => ({ name: e.name, nicknames: [...e.nicknames] }));
  switch (op.kind) {
    case 'add':
      next.push({ name: fresh(next, op.name, null), nicknames: [] });
      break;
    case 'nick-add': {
      const i = find(next, op.player);
      const n = fresh(next, op.nick, i);
      if (!names(next[i]).some((x) => low(x) === low(n))) next[i].nicknames.push(n);
      break;
    }
    case 'nick-remove': {
      const i = find(next, op.player);
      next[i].nicknames = next[i].nicknames.filter((x) => x !== op.nick);
      break;
    }
    case 'rename': {
      const i = find(next, op.player);
      const to = fresh(next, op.to, i);
      const old = next[i].name;
      const nicks = next[i].nicknames.filter((x) => low(x) !== low(to));
      if (low(old) !== low(to) && !nicks.some((x) => low(x) === low(old))) nicks.unshift(old);
      next[i] = { name: to, nicknames: nicks };
      break;
    }
    case 'merge': {
      const from = find(next, op.from);
      const into = find(next, op.into);
      if (from === into) throw new Error('Pick another player to merge into');
      const have = new Set(names(next[into]).map(low));
      for (const n of names(next[from])) if (!have.has(low(n))) { next[into].nicknames.push(n); have.add(low(n)); }
      next.splice(from, 1);
      break;
    }
  }
  const errors = rosterErrors(next);
  if (errors.length) throw new Error(errors.join('; '));
  return next;
}

/** /host/ autocomplete: every name and nickname, junk left out, Ukrainian order. */
export const autocompleteNames = (r: RosterEntry[]) =>
  [...new Set(r.flatMap(names).map((n) => n.trim()).filter((n) => !junk(n)))].sort((a, b) => a.localeCompare(b, 'uk'));

/** Lower-cased name or nickname → display name, so /host/ catches one player entered twice. */
export const aliasPairs = (r: RosterEntry[]): [string, string][] =>
  r.flatMap((e) => names(e).map((n) => [low(n.trim()), e.name.trim()] as [string, string])).filter(([k]) => k.length >= 2);

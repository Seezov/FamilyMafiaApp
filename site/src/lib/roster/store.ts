// Firebase client for config/players. Access control lives in firestore.rules (public read, admin write).
import { doc, getDoc, runTransaction, serverTimestamp } from 'firebase/firestore';
import { db } from '../firebase';
import type { ClubAdmin } from '../club/store';
import { applyOp, rosterErrors, type RosterEntry, type RosterOp } from './roster';

const ref = () => doc(db, 'config', 'players');
const stamp = (u: ClubAdmin) => ({ updatedAt: serverTimestamp(), updatedBy: u.uid, updatedByEmail: u.email });
const toEntries = (raw: unknown): RosterEntry[] => (Array.isArray(raw) ? raw : []).map((p) => ({
  name: String(p?.name ?? ''),
  nicknames: Array.isArray(p?.nicknames) ? p.nicknames.map(String) : [],
}));

export async function loadRoster(): Promise<RosterEntry[] | null> {
  const snap = await getDoc(ref());
  return snap.exists() ? toEntries(snap.data().players) : null;
}

/** Applies [op] to the current document (retried by Firestore on a concurrent edit) and bumps meta/state. */
export async function saveRosterOp(op: RosterOp, u: ClubAdmin): Promise<RosterEntry[]> {
  return runTransaction(db, async (tx) => {
    const snap = await tx.get(ref());
    if (!snap.exists()) throw new Error('config/players does not exist yet — import it first');
    const next = applyOp(toEntries(snap.data().players), op);
    tx.set(ref(), { players: next, ...stamp(u) });
    tx.set(doc(db, 'meta', 'state'), { updatedAt: serverTimestamp() });
    return next;
  });
}

/** One-time copy of assets/raw/players.json (already deduped by the caller). */
export async function importRoster(list: RosterEntry[], u: ClubAdmin) {
  const errors = rosterErrors(list);
  if (errors.length) throw new Error(errors.join('; '));
  await runTransaction(db, async (tx) => {
    if ((await tx.get(ref())).exists()) throw new Error('config/players already exists');
    tx.set(ref(), { players: list, ...stamp(u) });
    tx.set(doc(db, 'meta', 'state'), { updatedAt: serverTimestamp() });
  });
}

// Firebase client for /debug/'s club config. Access control lives in firestore.rules
// (config/club: public read, admin write).
import { onAuthStateChanged } from 'firebase/auth';
import { doc, getDoc, runTransaction, serverTimestamp } from 'firebase/firestore';
import { auth, db, signIn, signOutUser } from '../firebase';
import { applyOps, clubBody, type ClubDoc, type Op, type SeasonConfigFile } from '../config-edit';

export { signIn, signOutUser };

export type ClubAdmin = { uid: string; email: string; name: string; admin: boolean };

const clubRef = () => doc(db, 'config', 'club');
const stamp = (u: ClubAdmin) => ({ updatedAt: serverTimestamp(), updatedBy: u.uid, updatedByEmail: u.email });

export function onClubUser(cb: (u: ClubAdmin | null | 'not-host') => void) {
  onAuthStateChanged(auth, async (u) => {
    if (!u?.email) return cb(null);
    const host = await getDoc(doc(db, 'hosts', u.email)).catch(() => null);
    if (!host?.exists()) return cb('not-host');
    cb({ uid: u.uid, email: u.email, name: String(host.data().name ?? u.email), admin: host.data().admin === true });
  });
}

export async function loadClub(): Promise<ClubDoc | null> {
  const snap = await getDoc(clubRef());
  if (!snap.exists()) return null;
  const d = snap.data();
  return { tournaments: d.tournaments ?? [], rejectedCandidates: d.rejectedCandidates ?? [], gameLimits: d.gameLimits ?? {} };
}

/** Applies [ops] to the current document and bumps meta/state so the site rebuilds. */
export async function saveClub(ops: Op[], u: ClubAdmin) {
  await runTransaction(db, async (tx) => {
    const snap = await tx.get(clubRef());
    if (!snap.exists()) throw new Error('config/club does not exist yet — import it first');
    const cur = snap.data() as Partial<ClubDoc>;
    const next = applyOps({ tournaments: cur.tournaments ?? [], rejectedCandidates: cur.rejectedCandidates ?? [] }, ops);
    tx.set(clubRef(), { ...clubBody(next, cur.gameLimits ?? {}), ...stamp(u) });
    tx.set(doc(db, 'meta', 'state'), { updatedAt: serverTimestamp() });
  });
}

/** One-time copy of the JSON config's tournament block into config/club. */
export async function importClub(file: SeasonConfigFile, u: ClubAdmin) {
  await runTransaction(db, async (tx) => {
    if ((await tx.get(clubRef())).exists()) throw new Error('config/club already exists');
    tx.set(clubRef(), { ...clubBody(file), ...stamp(u) });
    tx.set(doc(db, 'meta', 'state'), { updatedAt: serverTimestamp() });
  });
}

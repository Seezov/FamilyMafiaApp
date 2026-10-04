// Firebase client for the /host/ page. Thin on purpose: all game logic lives in
// form.ts / validate.ts (unit-tested); access control lives in firestore.rules.
import { initializeApp } from 'firebase/app';
import { GoogleAuthProvider, getAuth, onAuthStateChanged, signInWithPopup, signInWithRedirect, signOut } from 'firebase/auth';
import {
  collection, doc, getDoc, getDocs, getFirestore, query, runTransaction, serverTimestamp, where, type Timestamp,
} from 'firebase/firestore';
import { firebaseConfig } from './firebase-config';
import type { DocBody } from './form';
import type { GameDoc } from './types';

const app = initializeApp(firebaseConfig);
const auth = getAuth(app);
const db = getFirestore(app);

export type HostUser = { uid: string; email: string; name: string; admin: boolean };
export class StaleGameError extends Error {}

export function onUser(cb: (u: HostUser | null | 'not-host') => void) {
  onAuthStateChanged(auth, async (u) => {
    if (!u?.email) return cb(null);
    const host = await getDoc(doc(db, 'hosts', u.email)).catch(() => null);
    if (!host?.exists()) return cb('not-host');
    cb({ uid: u.uid, email: u.email, name: String(host.data().name ?? u.email), admin: host.data().admin === true });
  });
}

export async function signIn() {
  const provider = new GoogleAuthProvider();
  try {
    await signInWithPopup(auth, provider);
  } catch (e) {
    if ((e as { code?: string }).code === 'auth/popup-blocked') await signInWithRedirect(auth, provider);
    else throw e;
  }
}

export const signOutUser = () => signOut(auth);

export async function listSeasonGames(season: number) {
  const snap = await getDocs(query(collection(db, 'games'), where('season', '==', season)));
  return snap.docs.map((d) => ({ ...(d.data() as GameDoc), id: d.id }));
}

export const millis = (t: unknown) => (t as Timestamp | null)?.toMillis?.() ?? 0;

export async function saveGame(
  body: DocBody,
  existing: { id: string; updatedAtMillis: number } | null,
  user: HostUser,
): Promise<string> {
  const ref = existing ? doc(db, 'games', existing.id) : doc(collection(db, 'games'));
  await runTransaction(db, async (tx) => {
    const stamp = { updatedBy: user.uid, updatedAt: serverTimestamp() };
    if (existing) {
      const cur = await tx.get(ref);
      if (!cur.exists() || millis(cur.data().updatedAt) !== existing.updatedAtMillis) throw new StaleGameError();
      const { createdBy, createdByEmail, createdAt } = cur.data();
      tx.set(ref, { ...body, createdBy, createdByEmail, createdAt, ...stamp });
    } else {
      tx.set(ref, { ...body, createdBy: user.uid, createdByEmail: user.email, createdAt: serverTimestamp(), ...stamp });
    }
    tx.set(doc(db, 'meta', 'state'), { updatedAt: serverTimestamp() });
  });
  return ref.id;
}

export function explainError(e: unknown): string {
  if (e instanceof StaleGameError) return 'Гру змінили з іншого пристрою — перезавантаж сторінку.';
  const code = (e as { code?: string }).code ?? '';
  if (code === 'permission-denied') return 'Немає прав зберегти цю гру (не ведучий або чужа гра).';
  if (code === 'unavailable' || code === 'deadline-exceeded' || !navigator.onLine) return 'Немає зʼєднання. Чернетка збережена — спробуй ще.';
  if (code === 'auth/popup-closed-by-user') return 'Вхід скасовано.';
  return `Помилка: ${code || (e as Error).message}`;
}

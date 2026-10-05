// site/src/lib/account/store.ts
// Firestore calls for /account/ and /account/admin/. Shapes must match firestore.rules.
import { onAuthStateChanged } from 'firebase/auth';
import {
  collection, deleteDoc, deleteField, doc, getDoc, getDocs, serverTimestamp, setDoc, writeBatch, type Timestamp,
} from 'firebase/firestore';
import { auth, db } from '../firebase';
import { playerKey } from '../profiles/core';
import type { Claim, Profile } from './state';

export type AccountUser = { uid: string; email: string; name: string; admin: boolean };

export function onAccount(cb: (u: AccountUser | null) => void) {
  onAuthStateChanged(auth, async (u) => {
    if (!u?.email) return cb(null);
    const host = await getDoc(doc(db, 'hosts', u.email)).catch(() => null);
    cb({ uid: u.uid, email: u.email, name: u.displayName ?? u.email, admin: host?.exists() === true && host.data().admin === true });
  });
}

const toClaim = (id: string, d: Record<string, unknown>): Claim => ({
  uid: id, player: String(d.player), playerKey: String(d.playerKey), email: String(d.email),
  googleName: String(d.googleName ?? ''), status: d.status as Claim['status'],
  createdAt: (d.createdAt as Timestamp | undefined)?.toMillis?.(),
});
const toProfile = (id: string, d: Record<string, unknown>): Profile => ({
  key: id, player: String(d.player), uid: String(d.uid),
  ...(typeof d.nick === 'string' ? { nick: d.nick } : {}),
  ...(typeof d.avatar === 'string' ? { avatar: d.avatar } : {}),
});
const bump = (b: ReturnType<typeof writeBatch>) => b.set(doc(db, 'meta', 'state'), { updatedAt: serverTimestamp() });

export async function getClaim(uid: string) {
  const s = await getDoc(doc(db, 'claims', uid));
  return s.exists() ? toClaim(s.id, s.data()) : null;
}

export async function listProfiles() {
  const s = await getDocs(collection(db, 'profiles'));
  return s.docs.map((d) => toProfile(d.id, d.data()));
}

export const submitClaim = (u: AccountUser, player: string) =>
  setDoc(doc(db, 'claims', u.uid), {
    player, playerKey: playerKey(player), email: u.email, googleName: u.name.slice(0, 100),
    status: 'pending', createdAt: serverTimestamp(),
  });

export const cancelClaim = (uid: string) => deleteDoc(doc(db, 'claims', uid));

export async function saveProfile(key: string, patch: { nick: string; avatar: string | null }) {
  const b = writeBatch(db);
  b.update(doc(db, 'profiles', key), {
    nick: patch.nick ? patch.nick : deleteField(),
    avatar: patch.avatar ?? deleteField(),
    updatedAt: serverTimestamp(),
  });
  bump(b);
  await b.commit();
}

export async function listClaims() {
  const s = await getDocs(collection(db, 'claims'));
  return s.docs.map((d) => toClaim(d.id, d.data()));
}

export async function decideClaim(c: Claim, approve: boolean, adminEmail: string) {
  const b = writeBatch(db);
  b.update(doc(db, 'claims', c.uid), { status: approve ? 'approved' : 'rejected', decidedBy: adminEmail, decidedAt: serverTimestamp() });
  if (approve) {
    b.set(doc(db, 'profiles', c.playerKey), { player: c.player, uid: c.uid, updatedAt: serverTimestamp() });
    bump(b);
  }
  await b.commit();
}

export async function resetProfile(key: string, what: 'nick' | 'avatar') {
  const b = writeBatch(db);
  b.update(doc(db, 'profiles', key), { [what]: deleteField(), updatedAt: serverTimestamp() });
  bump(b);
  await b.commit();
}

export async function unlink(p: Profile) {
  const b = writeBatch(db);
  b.delete(doc(db, 'profiles', p.key));
  b.delete(doc(db, 'claims', p.uid));
  bump(b);
  await b.commit();
}

export function explainAccountError(e: unknown): string {
  const code = (e as { code?: string }).code ?? '';
  if (code === 'permission-denied') return 'Немає прав на цю дію (або гравця вже привʼязано).';
  if (code === 'unavailable' || code === 'deadline-exceeded' || !navigator.onLine) return 'Немає зʼєднання — спробуй ще.';
  if (code === 'auth/popup-closed-by-user') return 'Вхід скасовано.';
  return `Помилка: ${code || (e as Error).message}`;
}

// Firestore calls for appeals. Shapes must match firestore.rules (match /appeals).
import {
  collection, deleteDoc, doc, getDoc, getDocs, query, runTransaction, serverTimestamp, setDoc, updateDoc, where, type Timestamp,
} from 'firebase/firestore';
import { db } from '../firebase';
import type { AccountUser } from '../account/store';
import type { GameDoc } from '../hosting/types';
import { appealId, applyGrant, grantedFor, round2, SeatGoneError, type Appeal, type Decision } from './core';

export class StaleAppealError extends Error {}

const ms = (t: unknown) => (t as Timestamp | undefined)?.toMillis?.();
const toAppeal = (id: string, d: Record<string, unknown>): Appeal => ({
  id, gameId: String(d.gameId), season: Number(d.season), date: String(d.date), table: Number(d.table),
  gameNumber: Number(d.gameNumber), host: String(d.host), seat: Number(d.seat), player: String(d.player),
  uid: String(d.uid), email: String(d.email), text: String(d.text), requested: Number(d.requested),
  status: d.status as Appeal['status'],
  ...(typeof d.granted === 'number' ? { granted: d.granted } : {}),
  ...(typeof d.adminComment === 'string' ? { adminComment: d.adminComment } : {}),
  createdAt: ms(d.createdAt),
  ...(typeof d.decidedBy === 'string' ? { decidedBy: d.decidedBy } : {}),
  decidedAt: ms(d.decidedAt),
});

export async function listMyAppeals(uid: string) {
  const s = await getDocs(query(collection(db, 'appeals'), where('uid', '==', uid)));
  return s.docs.map((d) => toAppeal(d.id, d.data()));
}

export async function listAllAppeals() {
  const s = await getDocs(collection(db, 'appeals'));
  return s.docs.map((d) => toAppeal(d.id, d.data()));
}

export async function getGames(ids: string[]) {
  const out = new Map<string, GameDoc>();
  await Promise.all([...new Set(ids)].map(async (id) => {
    const s = await getDoc(doc(db, 'games', id));
    if (s.exists()) out.set(id, s.data() as GameDoc);
  }));
  return out;
}

export const fileAppeal = (u: AccountUser, player: string, g: GameDoc & { id: string }, seat: number, text: string, requested: number) =>
  setDoc(doc(db, 'appeals', appealId(g.id, u.uid)), {
    gameId: g.id, season: g.season, date: g.date, table: g.table, gameNumber: g.gameNumber, host: g.host,
    seat, player, uid: u.uid, email: u.email, text: text.trim(), requested: round2(requested),
    status: 'pending', createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
  });

export const editAppeal = (id: string, text: string, requested: number) =>
  updateDoc(doc(db, 'appeals', id), { text: text.trim(), requested: round2(requested), updatedAt: serverTimestamp() });

export const withdrawAppeal = (id: string) => deleteDoc(doc(db, 'appeals', id));

/** One transaction: the game's seat + comment (accepted/partial), the appeal's decision, meta/state. */
export async function decideAppeal(a: Appeal, d: Decision, admin: AccountUser) {
  const aRef = doc(db, 'appeals', a.id);
  const gRef = doc(db, 'games', a.gameId);
  await runTransaction(db, async (tx) => {
    const cur = await tx.get(aRef);
    const g = await tx.get(gRef);
    if (!cur.exists() || cur.data().status !== 'pending') throw new StaleAppealError();
    const granted = grantedFor(toAppeal(cur.id, cur.data()), d);
    if (granted !== null) {
      if (!g.exists()) throw new SeatGoneError(a.player);
      tx.update(gRef, { ...applyGrant(g.data() as GameDoc, a.player, granted), updatedBy: admin.uid, updatedAt: serverTimestamp() });
    }
    const comment = d.adminComment.trim();
    tx.update(aRef, {
      status: d.status, ...(granted !== null ? { granted } : {}), ...(comment ? { adminComment: comment } : {}),
      decidedBy: admin.email, decidedAt: serverTimestamp(), updatedAt: serverTimestamp(),
    });
    tx.set(doc(db, 'meta', 'state'), { updatedAt: serverTimestamp() });
  });
}

export function explainAppealError(e: unknown): string {
  if (e instanceof StaleAppealError) return 'Апеляцію вже розглянули або відкликали — онови сторінку.';
  if (e instanceof SeatGoneError) return 'Гравця вже немає в цій грі — перевір гру на /host/.';
  const code = (e as { code?: string }).code ?? '';
  if (code === 'permission-denied') return 'Немає прав (сезон закінчився, гру змінили або апеляцію вже розглянули).';
  if (code === 'unavailable' || code === 'deadline-exceeded' || !navigator.onLine) return 'Немає зʼєднання — спробуй ще.';
  return `Помилка: ${code || (e as Error).message}`;
}

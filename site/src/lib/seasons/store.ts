// Firebase client for config/seasons. Access control lives in firestore.rules (public read, admin write).
import { collection, doc, getCountFromServer, getDoc, query, runTransaction, serverTimestamp, where } from 'firebase/firestore';
import { db } from '../firebase';
import type { ClubAdmin } from '../club/store';
import { nextSeasonId, seasonErrors, toSeasons, type ClubSeason } from './seasons';

const ref = () => doc(db, 'config', 'seasons');
const stamp = (u: ClubAdmin) => ({ updatedAt: serverTimestamp(), updatedBy: u.uid, updatedByEmail: u.email });

export async function loadClubSeasons(): Promise<ClubSeason[]> {
  const snap = await getDoc(ref());
  return snap.exists() ? toSeasons(snap.data().seasons) : [];
}

export async function gamesCount(season: number): Promise<number> {
  return (await getCountFromServer(query(collection(db, 'games'), where('season', '==', season)))).data().count;
}

/** Appends the next season (id from the fresh document, so two admins never reuse one) and bumps meta/state. */
export async function createSeason(draft: Omit<ClubSeason, 'id'>, expectedId: number, lastJsonId: number, u: ClubAdmin): Promise<ClubSeason[]> {
  return runTransaction(db, async (tx) => {
    const snap = await tx.get(ref());
    const cur = snap.exists() ? toSeasons(snap.data().seasons) : [];
    const id = nextSeasonId(cur, lastJsonId, expectedId);
    const list = [...cur, { id, title: draft.title.trim(), smallLeagueMinGames: draft.smallLeagueMinGames, startDate: draft.startDate }];
    const errors = seasonErrors(list, lastJsonId);
    if (errors.length) throw new Error(errors.join('; '));
    tx.set(ref(), { seasons: list, ...stamp(u) });
    tx.set(doc(db, 'meta', 'state'), { updatedAt: serverTimestamp() });
    return list;
  });
}

/** Removes the newest season if it still has no games (re-counted right before the write). */
export async function deleteNewestSeason(id: number, u: ClubAdmin): Promise<ClubSeason[]> {
  if ((await gamesCount(id)) > 0) throw new Error(`Season ${id} already has games — it cannot be deleted`);
  return runTransaction(db, async (tx) => {
    const snap = await tx.get(ref());
    const cur = snap.exists() ? toSeasons(snap.data().seasons) : [];
    if (cur.at(-1)?.id !== id) throw new Error(`Season ${id} is not the newest any more — reload`);
    const list = cur.slice(0, -1);
    tx.set(ref(), { seasons: list, ...stamp(u) });
    tx.set(doc(db, 'meta', 'state'), { updatedAt: serverTimestamp() });
    return list;
  });
}

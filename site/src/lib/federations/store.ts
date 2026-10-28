// Firebase client for config/federations. Access control lives in firestore.rules (public read, admin write).
// Link edits do not bump meta/state; a game decision does, so the hourly build applies it.
import { doc, getDoc, runTransaction, serverTimestamp } from 'firebase/firestore';
import { db } from '../firebase';
import type { ClubAdmin } from '../club/store';
import { applyFedOp, type FedDoc, type FedOp } from './core';

export const fedRef = () => doc(db, 'config', 'federations');
export const fedStamp = (u: ClubAdmin) => ({ updatedAt: serverTimestamp(), updatedBy: u.uid, updatedByEmail: u.email });
export const toFedDoc = (raw: Record<string, unknown> | undefined): FedDoc => ({
  links: (raw?.links ?? {}) as FedDoc['links'],
  rejected: (raw?.rejected ?? {}) as FedDoc['rejected'],
  ...(raw?.gameDecisions ? { gameDecisions: raw.gameDecisions as FedDoc['gameDecisions'] } : {}),
});

export async function loadFeds(): Promise<FedDoc> {
  const snap = await getDoc(fedRef());
  return toFedDoc(snap.exists() ? snap.data() : undefined);
}

/** Applies [op] to the current document (created on first save); tx.set keeps odd player names as plain map keys. */
export async function saveFedOp(op: FedOp, u: ClubAdmin): Promise<FedDoc> {
  return runTransaction(db, async (tx) => {
    const snap = await tx.get(fedRef());
    const next = applyFedOp(toFedDoc(snap.exists() ? snap.data() : undefined), op);
    tx.set(fedRef(), { ...next, ...fedStamp(u) });
    if (op.kind === 'decide') tx.set(doc(db, 'meta', 'state'), { updatedAt: serverTimestamp() });
    return next;
  });
}

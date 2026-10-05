// Firebase client for /annual/edit/. Access control lives in firestore.rules (events: public read, admin write).
import { collection, doc, getDocs, limit, query, runTransaction, serverTimestamp, where, writeBatch } from 'firebase/firestore';
import { db } from '../firebase';
import type { ClubAdmin } from '../club/store';
import type { EventDraft } from './validate';

const events = () => collection(db, 'events');
const stamp = (u: ClubAdmin) => ({ updatedAt: serverTimestamp(), updatedBy: u.uid, updatedByEmail: u.email });
const body = (d: EventDraft) => ({
  year: d.year, kind: d.kind, name: d.name.trim(), date: d.date,
  stars: d.kind === 'tournament' ? d.stars : null,
  participants: d.kind === 'tournament' ? d.participants : null,
  results: d.results.map((r) => ({ player: r.player.trim(), place: r.place })),
});

export async function loadEvents(year: number): Promise<{ id: string; data: EventDraft }[]> {
  const snap = await getDocs(query(events(), where('year', '==', year)));
  return snap.docs.map((s) => {
    const d = s.data();
    return { id: s.id, data: { year: d.year, kind: d.kind, name: d.name, date: d.date ?? null, stars: d.stars ?? null, participants: d.participants ?? null, results: d.results ?? [] } };
  });
}

export async function eventsEmpty(): Promise<boolean> {
  return (await getDocs(query(events(), limit(1)))).empty;
}

/** Creates (id null) or replaces an event and bumps meta/state so the site rebuilds. */
export async function saveEvent(id: string | null, d: EventDraft, u: ClubAdmin): Promise<string> {
  const ref = id ? doc(db, 'events', id) : doc(events());
  await runTransaction(db, async (tx) => {
    tx.set(ref, { ...body(d), ...stamp(u) });
    tx.set(doc(db, 'meta', 'state'), { updatedAt: serverTimestamp() });
  });
  return ref.id;
}

export async function deleteEvent(id: string, _u: ClubAdmin) {
  await runTransaction(db, async (tx) => {
    tx.delete(doc(db, 'events', id));
    tx.set(doc(db, 'meta', 'state'), { updatedAt: serverTimestamp() });
  });
}

/** One-time copy of the sheets' events (tool/import/annual_events.json). */
export async function importEvents(list: EventDraft[], u: ClubAdmin) {
  if (!(await eventsEmpty())) throw new Error('events already has documents');
  for (let i = 0; i < list.length; i += 400) {
    const batch = writeBatch(db);
    for (const d of list.slice(i, i + 400)) batch.set(doc(events()), { ...body(d), ...stamp(u) });
    if (i + 400 >= list.length) batch.set(doc(db, 'meta', 'state'), { updatedAt: serverTimestamp() });
    await batch.commit();
  }
}

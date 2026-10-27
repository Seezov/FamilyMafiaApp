// Firebase client for /payments/. Access control lives in firestore.rules: payments/config,
// paymentDays and paymentRecords are admin-only (read and write); games, config/players and
// config/club are public reads.
import {
  addDoc, collection, deleteDoc, doc, getDoc, getDocs, query, serverTimestamp, setDoc, where,
} from 'firebase/firestore';
import { db } from '../firebase';
import type { ClubAdmin } from '../club/store';
import {
  eventDates, isEventType, nameResolver, toConfig,
  type DayDoc, type EventType, type Mark, type PaymentRecord, type PaymentsConfig, type PlayedGame,
} from './payments';

const stamp = (u: ClubAdmin) => ({ updatedAt: serverTimestamp(), updatedBy: u.uid, updatedByEmail: u.email });

export interface PaymentsData {
  cfg: PaymentsConfig; games: PlayedGame[]; days: DayDoc[]; records: PaymentRecord[];
  auto: Map<string, EventType>; roster: string[];
}

function toMark(v: unknown): Mark | null {
  if (!v || typeof v !== 'object') return null;
  const o = v as Record<string, unknown>;
  const m: Mark = {};
  if (o.newbie === true) m.newbie = true;
  if (o.russian === true) m.russian = true;
  if (typeof o.free === 'string') m.free = o.free;
  if (typeof o.amount === 'number' && o.amount >= 0) m.amount = o.amount;
  return Object.keys(m).length ? m : null;
}

export async function loadPayments(): Promise<PaymentsData> {
  const cfgSnap = await getDoc(doc(db, 'payments', 'config'));
  const cfg = toConfig(cfgSnap.exists() ? cfgSnap.data() : undefined);
  const [games, days, records, players, club] = await Promise.all([
    getDocs(query(collection(db, 'games'), where('season', '>=', cfg.startSeason))),
    getDocs(collection(db, 'paymentDays')),
    getDocs(collection(db, 'paymentRecords')),
    getDoc(doc(db, 'config', 'players')),
    getDoc(doc(db, 'config', 'club')),
  ]);
  const rosterList = (players.exists() ? players.data().players : []) as { name: string; nicknames?: string[] }[];
  const resolve = nameResolver(rosterList);
  return {
    cfg,
    games: games.docs.map((d) => {
      const g = d.data();
      return { season: g.season, date: g.date, players: (g.seats as { player: string }[]).map((s) => resolve(s.player)) };
    }),
    days: days.docs.map((d) => {
      const x = d.data();
      const marks: Record<string, Mark> = {};
      for (const [p, v] of Object.entries((x.marks ?? {}) as Record<string, unknown>)) {
        const m = toMark(v);
        if (m) marks[p] = m;
      }
      return { date: d.id, eventType: x.eventType === 'none' || isEventType(x.eventType) ? x.eventType : null, marks };
    }),
    records: records.docs.map((d) => {
      const x = d.data();
      return { id: d.id, player: String(x.player), amount: Number(x.amount), date: String(x.date), note: String(x.note ?? ''), byEmail: String(x.createdByEmail ?? '') };
    }),
    auto: eventDates(club.exists() ? club.data().tournaments ?? [] : [], cfg.startSeason),
    roster: rosterList.map((p) => p.name),
  };
}

export const saveConfig = (cfg: PaymentsConfig, u: ClubAdmin) =>
  setDoc(doc(db, 'payments', 'config'), { ...cfg, ...stamp(u) });

export const saveDay = (d: DayDoc, u: ClubAdmin) =>
  setDoc(doc(db, 'paymentDays', d.date), { eventType: d.eventType, marks: d.marks, ...stamp(u) });

export const addRecord = (r: Omit<PaymentRecord, 'id' | 'byEmail'>, u: ClubAdmin) =>
  addDoc(collection(db, 'paymentRecords'), { ...r, createdAt: serverTimestamp(), createdBy: u.uid, createdByEmail: u.email });

export const deleteRecord = (id: string) => deleteDoc(doc(db, 'paymentRecords', id));

export function explainError(e: unknown): string {
  const code = (e as { code?: string }).code ?? '';
  if (code === 'permission-denied') return 'Немає доступу: сторінка лише для адмінів (або правила Firestore ще не опубліковані).';
  if (code === 'unavailable' || !navigator.onLine) return 'Немає зʼєднання — спробуй ще.';
  return `Помилка: ${code || (e as Error).message}`;
}

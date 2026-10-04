import fs from 'node:fs';
import { afterAll, beforeAll, beforeEach, describe, it } from 'vitest';
import { assertFails, assertSucceeds, initializeTestEnvironment, type RulesTestEnvironment } from '@firebase/rules-unit-testing';
import { deleteDoc, doc, getDoc, serverTimestamp, setDoc, updateDoc } from 'firebase/firestore';

let env: RulesTestEnvironment;
const HOST = { uid: 'u-host', email: 'host@x.com' };
const OTHER = { uid: 'u-other', email: 'other@x.com' };
const ADMIN = { uid: 'u-admin', email: 'admin@x.com' };
const STRANGER = { uid: 'u-stranger', email: 'stranger@x.com' };
type User = typeof HOST;

const seat = (player: string, role: string) => ({ player, role, fouls: 0, additional: 0, penalty: 0, protocolAdditional: 0, protocolPenalty: 0 });
const ROLES = ['Мирний', 'Мирний', 'Мирний', 'Шериф', 'Мафія', 'Мирний', 'Дон', 'Мирний', 'Мафія', 'Мирний'];
const game = (who: User, extra: Record<string, unknown> = {}) => ({
  season: 32, date: '2026-12-03', table: 1, gameNumber: 1, host: 'Серпень',
  seats: ROLES.map((r, i) => seat(`P${i + 1}`, r)),
  firstKilled: 6, supportFive: [1, -5], protocol: [], result: 'city', comments: [],
  createdBy: who.uid, createdByEmail: who.email, createdAt: serverTimestamp(),
  updatedBy: who.uid, updatedAt: serverTimestamp(), ...extra,
});
const as = (u: User) => env.authenticatedContext(u.uid, { email: u.email, email_verified: true }).firestore();

beforeAll(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-family-mafia',
    firestore: { rules: fs.readFileSync(new URL('../../firestore.rules', import.meta.url), 'utf8') },
  });
});
afterAll(() => env.cleanup());
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'hosts', HOST.email), { name: 'Host', admin: false });
    await setDoc(doc(db, 'hosts', OTHER.email), { name: 'Other', admin: false });
    await setDoc(doc(db, 'hosts', ADMIN.email), { name: 'Admin', admin: true });
  });
});

describe('games', () => {
  it('anyone can read', async () => {
    await assertSucceeds(getDoc(doc(env.unauthenticatedContext().firestore(), 'games', 'g1')));
  });
  it('a host can create a valid game', async () => {
    await assertSucceeds(setDoc(doc(as(HOST), 'games', 'g1'), game(HOST)));
  });
  it('a signed-in non-host cannot create', async () => {
    await assertFails(setDoc(doc(as(STRANGER), 'games', 'g1'), game(STRANGER)));
  });
  it('a guest cannot create', async () => {
    await assertFails(setDoc(doc(env.unauthenticatedContext().firestore(), 'games', 'g1'), game(HOST)));
  });
  it('rejects a game without a host', async () => {
    await assertFails(setDoc(doc(as(HOST), 'games', 'g1'), game(HOST, { host: '' })));
  });
  it('rejects 9 seats', async () => {
    await assertFails(setDoc(doc(as(HOST), 'games', 'g1'), game(HOST, { seats: game(HOST).seats.slice(0, 9) })));
  });
  it('rejects createdBy of someone else', async () => {
    await assertFails(setDoc(doc(as(HOST), 'games', 'g1'), game(HOST, { createdBy: OTHER.uid })));
  });

  describe('existing game by HOST', () => {
    beforeEach(async () => { await setDoc(doc(as(HOST), 'games', 'g1'), game(HOST)); });
    const edit = (u: User) => updateDoc(doc(as(u), 'games', 'g1'), { result: 'mafia', updatedBy: u.uid, updatedAt: serverTimestamp() });

    it('the author can edit', async () => { await assertSucceeds(edit(HOST)); });
    it('another host cannot edit', async () => { await assertFails(edit(OTHER)); });
    it('an admin can edit', async () => { await assertSucceeds(edit(ADMIN)); });
    it('nobody can rewrite createdBy', async () => {
      await assertFails(updateDoc(doc(as(ADMIN), 'games', 'g1'), { createdBy: ADMIN.uid, updatedBy: ADMIN.uid, updatedAt: serverTimestamp() }));
    });
    it('the author cannot delete', async () => { await assertFails(deleteDoc(doc(as(HOST), 'games', 'g1'))); });
    it('an admin can delete', async () => { await assertSucceeds(deleteDoc(doc(as(ADMIN), 'games', 'g1'))); });
  });
});

describe('hosts', () => {
  it('a user reads only their own host doc', async () => {
    await assertSucceeds(getDoc(doc(as(HOST), 'hosts', HOST.email)));
    await assertFails(getDoc(doc(as(HOST), 'hosts', OTHER.email)));
  });
  it('nobody writes hosts from the client', async () => {
    await assertFails(setDoc(doc(as(ADMIN), 'hosts', STRANGER.email), { name: 'x', admin: true }));
  });
});

describe('meta/state', () => {
  it('a host bumps updatedAt', async () => {
    await assertSucceeds(setDoc(doc(as(HOST), 'meta', 'state'), { updatedAt: serverTimestamp() }));
  });
  it('a non-host cannot', async () => {
    await assertFails(setDoc(doc(as(STRANGER), 'meta', 'state'), { updatedAt: serverTimestamp() }));
  });
  it('no extra fields', async () => {
    await assertFails(setDoc(doc(as(HOST), 'meta', 'state'), { updatedAt: serverTimestamp(), x: 1 }));
  });
});

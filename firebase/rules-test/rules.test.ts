import fs from 'node:fs';
import { afterAll, beforeAll, beforeEach, describe, it } from 'vitest';
import { assertFails, assertSucceeds, initializeTestEnvironment, type RulesTestEnvironment } from '@firebase/rules-unit-testing';
import { deleteDoc, deleteField, doc, getDoc, serverTimestamp, setDoc, updateDoc, writeBatch } from 'firebase/firestore';

let env: RulesTestEnvironment;
// Firestore auto ids: 20 letters/digits. The rules accept nothing else.
const G1 = 'AbCdEfGhIj0123456789';
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
    await assertSucceeds(getDoc(doc(env.unauthenticatedContext().firestore(), 'games', G1)));
  });
  it('a host can create a valid game', async () => {
    await assertSucceeds(setDoc(doc(as(HOST), 'games', G1), game(HOST)));
  });
  it('a signed-in non-host cannot create', async () => {
    await assertFails(setDoc(doc(as(STRANGER), 'games', G1), game(STRANGER)));
  });
  it('a guest cannot create', async () => {
    await assertFails(setDoc(doc(env.unauthenticatedContext().firestore(), 'games', G1), game(HOST)));
  });
  it('rejects a game without a host', async () => {
    await assertFails(setDoc(doc(as(HOST), 'games', G1), game(HOST, { host: '' })));
  });
  it('rejects 9 seats', async () => {
    await assertFails(setDoc(doc(as(HOST), 'games', G1), game(HOST, { seats: game(HOST).seats.slice(0, 9) })));
  });
  it('rejects a custom document id (ids are rendered in the page)', async () => {
    await assertFails(setDoc(doc(as(HOST), 'games', '"><img src=x onerror=alert(1)>'), game(HOST)));
  });
  it('rejects an unknown role', async () => {
    const seats = game(HOST).seats.map((s, i) => (i === 0 ? { ...s, role: 'Шпигун' } : s));
    await assertFails(setDoc(doc(as(HOST), 'games', G1), game(HOST, { seats })));
  });
  it('rejects a seat without a player', async () => {
    const seats = game(HOST).seats.map((s, i) => (i === 9 ? { ...s, player: '' } : s));
    await assertFails(setDoc(doc(as(HOST), 'games', G1), game(HOST, { seats })));
  });
  it('rejects unknown top-level fields', async () => {
    await assertFails(setDoc(doc(as(HOST), 'games', G1), game(HOST, { extra: 1 })));
  });
  it('rejects createdBy of someone else', async () => {
    await assertFails(setDoc(doc(as(HOST), 'games', G1), game(HOST, { createdBy: OTHER.uid })));
  });

  describe('existing game by HOST', () => {
    beforeEach(async () => { await setDoc(doc(as(HOST), 'games', G1), game(HOST)); });
    const edit = (u: User) => updateDoc(doc(as(u), 'games', G1), { result: 'mafia', updatedBy: u.uid, updatedAt: serverTimestamp() });

    it('the author can edit', async () => { await assertSucceeds(edit(HOST)); });
    it('another host cannot edit', async () => { await assertFails(edit(OTHER)); });
    it('an admin can edit', async () => { await assertSucceeds(edit(ADMIN)); });
    it('nobody can rewrite createdBy', async () => {
      await assertFails(updateDoc(doc(as(ADMIN), 'games', G1), { createdBy: ADMIN.uid, updatedBy: ADMIN.uid, updatedAt: serverTimestamp() }));
    });
    it('the author cannot delete', async () => { await assertFails(deleteDoc(doc(as(HOST), 'games', G1))); });
    it('an admin can delete', async () => { await assertSucceeds(deleteDoc(doc(as(ADMIN), 'games', G1))); });
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

const PLAYER = { uid: 'u-player', email: 'player@x.com' };
const RIVAL = { uid: 'u-rival', email: 'rival@x.com' };
const claim = (who: User, extra: Record<string, unknown> = {}) => ({
  player: 'Braun', playerKey: 'braun', email: who.email, googleName: 'B', status: 'pending',
  createdAt: serverTimestamp(), ...extra,
});
const approve = (db: ReturnType<typeof as>, who: User, key = 'braun', player = 'Braun') => {
  const b = writeBatch(db);
  b.update(doc(db, 'claims', who.uid), { status: 'approved', decidedBy: ADMIN.email, decidedAt: serverTimestamp() });
  b.set(doc(db, 'profiles', key), { player, uid: who.uid, updatedAt: serverTimestamp() });
  return b.commit();
};
const seedApproved = (who: User, extra: Record<string, unknown> = {}) =>
  env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'claims', who.uid), { ...claim(who), status: 'approved', createdAt: new Date() });
    await setDoc(doc(db, 'profiles', 'braun'), { player: 'Braun', uid: who.uid, updatedAt: new Date(), ...extra });
  });

describe('claims', () => {
  it('a signed-in user claims a player for themselves', async () => {
    await assertSucceeds(setDoc(doc(as(PLAYER), 'claims', PLAYER.uid), claim(PLAYER)));
  });
  it('not for another uid', async () => {
    await assertFails(setDoc(doc(as(PLAYER), 'claims', RIVAL.uid), claim(PLAYER)));
  });
  it('not with someone else’s email, a non-pending status or extra fields', async () => {
    await assertFails(setDoc(doc(as(PLAYER), 'claims', PLAYER.uid), claim(PLAYER, { email: RIVAL.email })));
    await assertFails(setDoc(doc(as(PLAYER), 'claims', PLAYER.uid), claim(PLAYER, { status: 'approved' })));
    await assertFails(setDoc(doc(as(PLAYER), 'claims', PLAYER.uid), claim(PLAYER, { admin: true })));
  });
  it('a guest cannot claim', async () => {
    await assertFails(setDoc(doc(env.unauthenticatedContext().firestore(), 'claims', PLAYER.uid), claim(PLAYER)));
  });
  it('owner and admin read; others do not', async () => {
    await setDoc(doc(as(PLAYER), 'claims', PLAYER.uid), claim(PLAYER));
    await assertSucceeds(getDoc(doc(as(PLAYER), 'claims', PLAYER.uid)));
    await assertSucceeds(getDoc(doc(as(ADMIN), 'claims', PLAYER.uid)));
    await assertFails(getDoc(doc(as(RIVAL), 'claims', PLAYER.uid)));
    await assertFails(getDoc(doc(as(HOST), 'claims', PLAYER.uid)));
  });
  it('owner cancels or re-claims while pending or rejected', async () => {
    await setDoc(doc(as(PLAYER), 'claims', PLAYER.uid), claim(PLAYER));
    await assertSucceeds(setDoc(doc(as(PLAYER), 'claims', PLAYER.uid), claim(PLAYER, { player: 'Floppy', playerKey: 'floppy' })));
    await updateDoc(doc(as(ADMIN), 'claims', PLAYER.uid), { status: 'rejected', decidedBy: ADMIN.email, decidedAt: serverTimestamp() });
    await assertSucceeds(setDoc(doc(as(PLAYER), 'claims', PLAYER.uid), claim(PLAYER)));
    await assertSucceeds(deleteDoc(doc(as(PLAYER), 'claims', PLAYER.uid)));
  });
  it('owner cannot touch an approved claim', async () => {
    await seedApproved(PLAYER);
    await assertFails(setDoc(doc(as(PLAYER), 'claims', PLAYER.uid), claim(PLAYER, { player: 'Floppy', playerKey: 'floppy' })));
    await assertFails(deleteDoc(doc(as(PLAYER), 'claims', PLAYER.uid)));
  });
  it('only an admin rejects, with their own email', async () => {
    await setDoc(doc(as(PLAYER), 'claims', PLAYER.uid), claim(PLAYER));
    const reject = (who: User, by = who.email) =>
      updateDoc(doc(as(who), 'claims', PLAYER.uid), { status: 'rejected', decidedBy: by, decidedAt: serverTimestamp() });
    await assertFails(reject(HOST));
    await assertFails(reject(PLAYER));
    await assertFails(reject(ADMIN, HOST.email));
    await assertSucceeds(reject(ADMIN));
  });
});

describe('profiles', () => {
  it('admin approves: claim and profile in one batch', async () => {
    await setDoc(doc(as(PLAYER), 'claims', PLAYER.uid), claim(PLAYER));
    await assertSucceeds(approve(as(ADMIN), PLAYER));
  });
  it('approval without a profile, or a profile without approval, fails', async () => {
    await setDoc(doc(as(PLAYER), 'claims', PLAYER.uid), claim(PLAYER));
    await assertFails(updateDoc(doc(as(ADMIN), 'claims', PLAYER.uid), { status: 'approved', decidedBy: ADMIN.email, decidedAt: serverTimestamp() }));
    await assertFails(setDoc(doc(as(ADMIN), 'profiles', 'braun'), { player: 'Braun', uid: PLAYER.uid, updatedAt: serverTimestamp() }));
  });
  it('profile key and player must match the claim', async () => {
    await setDoc(doc(as(PLAYER), 'claims', PLAYER.uid), claim(PLAYER));
    await assertFails(approve(as(ADMIN), PLAYER, 'floppy', 'Braun'));
    await assertFails(approve(as(ADMIN), PLAYER, 'braun', 'Floppy'));
  });
  it('a non-admin cannot approve', async () => {
    await setDoc(doc(as(PLAYER), 'claims', PLAYER.uid), claim(PLAYER));
    await assertFails(approve(as(HOST), PLAYER));
    await assertFails(approve(as(PLAYER), PLAYER));
  });
  it('a second account cannot get the same player', async () => {
    await seedApproved(PLAYER);
    await setDoc(doc(as(RIVAL), 'claims', RIVAL.uid), claim(RIVAL));
    await assertFails(approve(as(ADMIN), RIVAL));
  });
  it('everyone reads profiles', async () => {
    await seedApproved(PLAYER);
    await assertSucceeds(getDoc(doc(env.unauthenticatedContext().firestore(), 'profiles', 'braun')));
  });
  it('owner sets and clears nick and avatar', async () => {
    await seedApproved(PLAYER);
    const ref = doc(as(PLAYER), 'profiles', 'braun');
    await assertSucceeds(updateDoc(ref, { nick: 'Boss', avatar: 'data:image/webp;base64,UklGRg==', updatedAt: serverTimestamp() }));
    await assertSucceeds(updateDoc(ref, { nick: deleteField(), avatar: deleteField(), updatedAt: serverTimestamp() }));
  });
  it('owner limits: nick length, avatar type and size, no other fields', async () => {
    await seedApproved(PLAYER);
    const ref = doc(as(PLAYER), 'profiles', 'braun');
    const up = (d: Record<string, unknown>) => updateDoc(ref, { ...d, updatedAt: serverTimestamp() });
    await assertFails(up({ nick: 'X' }));
    await assertFails(up({ nick: 'X'.repeat(25) }));
    await assertFails(up({ avatar: 'data:image/png;base64,iVBO' }));
    await assertFails(up({ avatar: `data:image/webp;base64,${'A'.repeat(140_000)}` }));
    await assertFails(up({ player: 'Floppy' }));
    await assertFails(up({ uid: RIVAL.uid }));
  });
  it('others cannot edit a profile', async () => {
    await seedApproved(PLAYER);
    await assertFails(updateDoc(doc(as(RIVAL), 'profiles', 'braun'), { nick: 'Boss', updatedAt: serverTimestamp() }));
    await assertFails(updateDoc(doc(as(HOST), 'profiles', 'braun'), { nick: 'Boss', updatedAt: serverTimestamp() }));
  });
  it('admin resets nick/avatar but cannot set them', async () => {
    await seedApproved(PLAYER, { nick: 'Boss', avatar: 'data:image/webp;base64,UklGRg==' });
    const ref = doc(as(ADMIN), 'profiles', 'braun');
    await assertFails(updateDoc(ref, { nick: 'Admin-made', updatedAt: serverTimestamp() }));
    await assertSucceeds(updateDoc(ref, { nick: deleteField(), avatar: deleteField(), updatedAt: serverTimestamp() }));
  });
  it('admin unlinks: profile and claim deleted together; owner cannot delete', async () => {
    await seedApproved(PLAYER);
    await assertFails(deleteDoc(doc(as(PLAYER), 'profiles', 'braun')));
    const db = as(ADMIN);
    const b = writeBatch(db);
    b.delete(doc(db, 'profiles', 'braun'));
    b.delete(doc(db, 'claims', PLAYER.uid));
    await assertSucceeds(b.commit());
  });
});

describe('meta/state by players', () => {
  it('an approved player bumps updatedAt', async () => {
    await seedApproved(PLAYER);
    await assertSucceeds(setDoc(doc(as(PLAYER), 'meta', 'state'), { updatedAt: serverTimestamp() }));
  });
  it('a pending player cannot', async () => {
    await setDoc(doc(as(PLAYER), 'claims', PLAYER.uid), claim(PLAYER));
    await assertFails(setDoc(doc(as(PLAYER), 'meta', 'state'), { updatedAt: serverTimestamp() }));
  });
});

describe('config/club', () => {
  const body = (who: User, extra: Record<string, unknown> = {}) => ({
    tournaments: [{ season: 31, type: 'minicap', name: 'Cup', games: 4, podium: ['A'] }],
    rejectedCandidates: [], gameLimits: {},
    updatedAt: serverTimestamp(), updatedBy: who.uid, updatedByEmail: who.email, ...extra,
  });
  const club = (db: ReturnType<typeof as>) => doc(db, 'config', 'club');

  it('anyone reads', async () => {
    await assertSucceeds(getDoc(club(env.unauthenticatedContext().firestore())));
  });
  it('admin writes', async () => {
    await assertSucceeds(setDoc(club(as(ADMIN)), body(ADMIN)));
  });
  it('a host who is not an admin cannot', async () => {
    await assertFails(setDoc(club(as(HOST)), body(HOST)));
  });
  it('a signed-in stranger and anonymous cannot', async () => {
    await assertFails(setDoc(club(as(STRANGER)), body(STRANGER)));
    await assertFails(setDoc(club(env.unauthenticatedContext().firestore()), body(ADMIN)));
  });
  it('extra keys, wrong types or a forged author are denied', async () => {
    await assertFails(setDoc(club(as(ADMIN)), body(ADMIN, { seasons: [] })));
    await assertFails(setDoc(club(as(ADMIN)), body(ADMIN, { tournaments: 'x' })));
    await assertFails(setDoc(club(as(ADMIN)), body(ADMIN, { gameLimits: [] })));
    await assertFails(setDoc(club(as(ADMIN)), body(ADMIN, { updatedBy: HOST.uid })));
    await assertFails(setDoc(club(as(ADMIN)), body(ADMIN, { updatedByEmail: HOST.email })));
  });
  it('admin cannot delete it', async () => {
    await env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), 'config', 'club'), { tournaments: [] }));
    await assertFails(deleteDoc(club(as(ADMIN))));
  });
});

describe('events', () => {
  const body = (who: User, extra: Record<string, unknown> = {}) => ({
    year: 2026, kind: 'tournament', name: 'Cup', date: '2026-02-28', stars: 2, participants: 30,
    results: [{ player: 'A', place: 1 }],
    updatedAt: serverTimestamp(), updatedBy: who.uid, updatedByEmail: who.email, ...extra,
  });
  const ev = (db: ReturnType<typeof as>, id = 'E1') => doc(db, 'events', id);

  it('anyone reads', async () => {
    await assertSucceeds(getDoc(ev(env.unauthenticatedContext().firestore())));
  });
  it('admin creates, updates and deletes', async () => {
    await assertSucceeds(setDoc(ev(as(ADMIN)), body(ADMIN)));
    await assertSucceeds(setDoc(ev(as(ADMIN)), body(ADMIN, { kind: 'series', stars: null, participants: null, date: null })));
    await assertSucceeds(deleteDoc(ev(as(ADMIN))));
  });
  it('a season event without optional fields is fine', async () => {
    const { date, stars, participants, ...rest } = body(ADMIN, { kind: 'season' });
    await assertSucceeds(setDoc(ev(as(ADMIN)), rest));
  });
  it('a host who is not an admin, a stranger and anonymous cannot', async () => {
    await assertFails(setDoc(ev(as(HOST)), body(HOST)));
    await assertFails(setDoc(ev(as(STRANGER)), body(STRANGER)));
    await assertFails(setDoc(ev(env.unauthenticatedContext().firestore()), body(ADMIN)));
    await env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), 'events', 'E2'), { year: 2026 }));
    await assertFails(deleteDoc(ev(as(HOST), 'E2')));
  });
  it('bad fields or a forged author are denied', async () => {
    for (const extra of [
      { kind: 'cup' }, { year: '2026' }, { name: '' }, { results: 'x' }, { stars: '2' },
      { participants: 1.5 }, { date: 5 }, { extra: 1 }, { updatedBy: HOST.uid }, { updatedByEmail: HOST.email },
    ]) await assertFails(setDoc(ev(as(ADMIN)), body(ADMIN, extra)));
  });
  it('documents the build would reject are denied', async () => {
    for (const extra of [
      { year: 1999 }, { year: 2101 }, { stars: 6 }, { stars: -1 }, { stars: null }, { participants: null },
      { participants: 0 }, { date: '"><img src=x onerror=alert(1)>' }, { date: '28.02.2026' },
    ]) await assertFails(setDoc(ev(as(ADMIN)), body(ADMIN, extra)));
  });
});

describe('config/players', () => {
  const ref = (db: ReturnType<typeof as>) => doc(db, 'config', 'players');
  const body = (u: User, extra: Record<string, unknown> = {}) => ({
    players: [{ name: 'Braun', nicknames: ['Браун'] }], updatedAt: serverTimestamp(), updatedBy: u.uid, updatedByEmail: u.email, ...extra,
  });
  it('anyone can read', async () => {
    await assertSucceeds(getDoc(doc(env.unauthenticatedContext().firestore(), 'config', 'players')));
  });
  it('an admin can create and update', async () => {
    await assertSucceeds(setDoc(ref(as(ADMIN)), body(ADMIN)));
    await assertSucceeds(setDoc(ref(as(ADMIN)), body(ADMIN, { players: [] })));
  });
  it('a host who is not admin cannot write', async () => {
    await assertFails(setDoc(ref(as(HOST)), body(HOST)));
  });
  it('a guest cannot write', async () => {
    await assertFails(setDoc(doc(env.unauthenticatedContext().firestore(), 'config', 'players'), body(ADMIN)));
  });
  it('rejects extra keys, a non-list, a forged author and a client timestamp', async () => {
    await assertFails(setDoc(ref(as(ADMIN)), body(ADMIN, { extra: 1 })));
    await assertFails(setDoc(ref(as(ADMIN)), body(ADMIN, { players: 'x' })));
    await assertFails(setDoc(ref(as(ADMIN)), body(ADMIN, { updatedBy: 'someone' })));
    await assertFails(setDoc(ref(as(ADMIN)), body(ADMIN, { updatedByEmail: 'x@x.com' })));
    await assertFails(setDoc(ref(as(ADMIN)), body(ADMIN, { updatedAt: new Date(0) })));
  });
  it('rejects more than 2000 players', async () => {
    const players = Array.from({ length: 2001 }, (_, i) => ({ name: `p${i}`, nicknames: [] }));
    await assertFails(setDoc(ref(as(ADMIN)), body(ADMIN, { players })));
  });
  it('nobody can delete it', async () => {
    await env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), 'config', 'players'), { players: [] }));
    await assertFails(deleteDoc(ref(as(ADMIN))));
  });
});

describe('config/seasons', () => {
  const ref = (db: ReturnType<typeof as>) => doc(db, 'config', 'seasons');
  const body = (u: User, extra: Record<string, unknown> = {}) => ({
    seasons: [{ id: 32, title: 'Season 32', smallLeagueMinGames: 15, startDate: '2026-12-01' }],
    updatedAt: serverTimestamp(), updatedBy: u.uid, updatedByEmail: u.email, ...extra,
  });
  it('anyone can read', async () => {
    await assertSucceeds(getDoc(doc(env.unauthenticatedContext().firestore(), 'config', 'seasons')));
  });
  it('an admin can create and update', async () => {
    await assertSucceeds(setDoc(ref(as(ADMIN)), body(ADMIN)));
    await assertSucceeds(setDoc(ref(as(ADMIN)), body(ADMIN, { seasons: [] })));
  });
  it('a host who is not admin cannot write', async () => {
    await assertFails(setDoc(ref(as(HOST)), body(HOST)));
  });
  it('a guest cannot write', async () => {
    await assertFails(setDoc(doc(env.unauthenticatedContext().firestore(), 'config', 'seasons'), body(ADMIN)));
  });
  it('rejects extra keys, a non-list, a forged author and a client timestamp', async () => {
    await assertFails(setDoc(ref(as(ADMIN)), body(ADMIN, { extra: 1 })));
    await assertFails(setDoc(ref(as(ADMIN)), body(ADMIN, { seasons: 'x' })));
    await assertFails(setDoc(ref(as(ADMIN)), body(ADMIN, { updatedBy: 'someone' })));
    await assertFails(setDoc(ref(as(ADMIN)), body(ADMIN, { updatedByEmail: 'x@x.com' })));
    await assertFails(setDoc(ref(as(ADMIN)), body(ADMIN, { updatedAt: new Date(0) })));
  });
  it('rejects more than 100 seasons', async () => {
    const seasons = Array.from({ length: 101 }, (_, i) => ({ id: 32 + i, title: 'S', smallLeagueMinGames: 15, startDate: '2026-12-01' }));
    await assertFails(setDoc(ref(as(ADMIN)), body(ADMIN, { seasons })));
  });
  it('nobody can delete it', async () => {
    await env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), 'config', 'seasons'), { seasons: [] }));
    await assertFails(deleteDoc(ref(as(ADMIN))));
  });
});

describe('appeals', () => {
  // Braun (PLAYER, approved) sits in seat 1 of G1, season 32 which started and is the newest.
  const AID = `${G1}_${PLAYER.uid}`;
  const seasons = (list: { id: number; startDate: string }[]) =>
    env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), 'config', 'seasons'),
      { seasons: list.map((s) => ({ ...s, title: `Season ${s.id}`, smallLeagueMinGames: 15 })) }));
  const seedGame = (extra: Record<string, unknown> = {}) =>
    env.withSecurityRulesDisabled((ctx) => {
      const g = game(HOST, extra);
      g.seats[0] = seat('Braun', 'Мирний');
      return setDoc(doc(ctx.firestore(), 'games', G1), { ...g, createdAt: new Date(), updatedAt: new Date() });
    });
  const appeal = (extra: Record<string, unknown> = {}) => ({
    gameId: G1, season: 32, date: '2026-12-03', table: 1, gameNumber: 1, host: 'Серпень', seat: 1,
    player: 'Braun', uid: PLAYER.uid, email: PLAYER.email, text: 'Знайшов шерифа', requested: 0.5,
    status: 'pending', createdAt: serverTimestamp(), updatedAt: serverTimestamp(), ...extra,
  });
  const file = (u: User, extra: Record<string, unknown> = {}, id = AID) => setDoc(doc(as(u), 'appeals', id), appeal(extra));
  const decide = (u: User, d: Record<string, unknown>) =>
    updateDoc(doc(as(u), 'appeals', AID), { decidedBy: u.email, decidedAt: serverTimestamp(), updatedAt: serverTimestamp(), ...d });
  const grant = (u: User, d: Record<string, unknown>, additional = 0.5) => {
    const db = as(u);
    const b = writeBatch(db);
    const seats = game(HOST).seats.map((s, i) => (i === 0 ? { ...seat('Braun', 'Мирний'), additional } : s));
    b.update(doc(db, 'games', G1), { seats, updatedBy: u.uid, updatedAt: serverTimestamp() });
    b.update(doc(db, 'appeals', AID), { decidedBy: u.email, decidedAt: serverTimestamp(), updatedAt: serverTimestamp(), ...d });
    return b.commit();
  };

  beforeEach(async () => {
    await seasons([{ id: 32, startDate: '2026-01-01' }]);
    await seedGame();
    await seedApproved(PLAYER);
  });

  it('an approved player files on their own current-season game', async () => {
    await assertSucceeds(file(PLAYER));
  });
  it('id must be gameId_uid', async () => {
    await assertFails(file(PLAYER, {}, `${G1}_${RIVAL.uid}`));
    await assertFails(file(PLAYER, {}, 'whatever'));
  });
  it('not for someone else’s seat or name', async () => {
    await assertFails(file(PLAYER, { seat: 2 }));
    await assertFails(file(PLAYER, { player: 'P2', seat: 2 }));
  });
  it('not without an approved claim', async () => {
    await setDoc(doc(as(RIVAL), 'claims', RIVAL.uid), claim(RIVAL));
    await assertFails(file(RIVAL, { uid: RIVAL.uid, email: RIVAL.email }, `${G1}_${RIVAL.uid}`));
  });
  it('not on an unrated game', async () => {
    await seedGame({ result: 'unrated' });
    await assertFails(file(PLAYER));
  });
  it('not on a past or not-yet-started season', async () => {
    await seasons([{ id: 32, startDate: '2026-01-01' }, { id: 33, startDate: '2026-02-01' }]);
    await assertFails(file(PLAYER));
    await seasons([{ id: 32, startDate: '2099-01-01' }]);
    await assertFails(file(PLAYER));
  });
  it('snapshot must match the game', async () => {
    await assertFails(file(PLAYER, { host: 'Інший' }));
    await assertFails(file(PLAYER, { gameNumber: 2 }));
    await assertFails(file(PLAYER, { season: 33 }));
  });
  it('bad text, amount, status or extra fields are denied', async () => {
    for (const extra of [{ text: '' }, { text: 'x'.repeat(1001) }, { requested: 0 }, { requested: 5.5 },
      { requested: '1' }, { status: 'accepted' }, { granted: 1 }, { extra: 1 }, { email: RIVAL.email }])
      await assertFails(file(PLAYER, extra));
  });
  it('owner and admins read; others do not', async () => {
    await file(PLAYER);
    await assertSucceeds(getDoc(doc(as(PLAYER), 'appeals', AID)));
    await assertSucceeds(getDoc(doc(as(ADMIN), 'appeals', AID)));
    await assertFails(getDoc(doc(as(RIVAL), 'appeals', AID)));
    await assertFails(getDoc(doc(as(HOST), 'appeals', AID)));
  });
  it('owner edits text and amount while pending, nothing else', async () => {
    await file(PLAYER);
    const ref = doc(as(PLAYER), 'appeals', AID);
    await assertSucceeds(updateDoc(ref, { text: 'Інакше', requested: 0.3, updatedAt: serverTimestamp() }));
    await assertFails(updateDoc(ref, { seat: 2, updatedAt: serverTimestamp() }));
    await assertFails(updateDoc(ref, { status: 'accepted', updatedAt: serverTimestamp() }));
    await assertFails(updateDoc(ref, { requested: 9, updatedAt: serverTimestamp() }));
  });
  it('owner withdraws while pending; not after a decision', async () => {
    await file(PLAYER);
    await assertSucceeds(deleteDoc(doc(as(PLAYER), 'appeals', AID)));
    await file(PLAYER);
    await decide(ADMIN, { status: 'rejected' });
    await assertFails(deleteDoc(doc(as(PLAYER), 'appeals', AID)));
    await assertFails(updateDoc(doc(as(PLAYER), 'appeals', AID), { text: 'x', updatedAt: serverTimestamp() }));
  });
  it('admin rejects, with a comment; not with granted or a forged decidedBy', async () => {
    await file(PLAYER);
    await assertFails(decide(ADMIN, { status: 'rejected', granted: 0.5 }));
    await assertFails(decide(ADMIN, { status: 'rejected', decidedBy: HOST.email }));
    await assertSucceeds(decide(ADMIN, { status: 'rejected', adminComment: 'Ні' }));
  });
  it('non-admins cannot decide', async () => {
    await file(PLAYER);
    await assertFails(decide(HOST, { status: 'rejected' }));
    await assertFails(decide(PLAYER, { status: 'rejected' }));
  });
  it('admin accepts with the game written in the same batch', async () => {
    await file(PLAYER);
    await assertFails(decide(ADMIN, { status: 'accepted', granted: 0.5 }));
    await assertFails(grant(ADMIN, { status: 'accepted', granted: 0.4 }));
    await assertSucceeds(grant(ADMIN, { status: 'accepted', granted: 0.5 }));
  });
  it('partial: 0 < granted < requested', async () => {
    await file(PLAYER);
    await assertFails(grant(ADMIN, { status: 'partial', granted: 0.5 }));
    await assertFails(grant(ADMIN, { status: 'partial', granted: 0 }));
    await assertSucceeds(grant(ADMIN, { status: 'partial', granted: 0.2 }, 0.2));
  });
  it('a decided appeal cannot be decided again', async () => {
    await file(PLAYER);
    await decide(ADMIN, { status: 'rejected' });
    await assertFails(grant(ADMIN, { status: 'accepted', granted: 0.5 }));
  });
  it('admin decides on a past season', async () => {
    await file(PLAYER);
    await seasons([{ id: 32, startDate: '2026-01-01' }, { id: 33, startDate: '2026-02-01' }]);
    await assertSucceeds(decide(ADMIN, { status: 'rejected' }));
  });
  it('admin may delete any appeal', async () => {
    await file(PLAYER);
    await assertSucceeds(deleteDoc(doc(as(ADMIN), 'appeals', AID)));
  });
});

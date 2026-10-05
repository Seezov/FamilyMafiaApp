// Pure account logic for /account/ (unit-tested); Firestore calls live in store.ts.
import { playerKey } from '../profiles/core';
export interface Claim {
  uid: string; player: string; playerKey: string; email: string; googleName: string;
  status: 'pending' | 'approved' | 'rejected'; createdAt?: number;
}
export interface Profile { key: string; player: string; uid: string; nick?: string; avatar?: string }
export type AccountView = 'signed-out' | 'pick' | 'pending' | 'rejected' | 'settings';

export function accountView(signedIn: boolean, claim: Claim | null, profile: Profile | null): AccountView {
  if (!signedIn) return 'signed-out';
  if (!claim) return 'pick';
  if (claim.status === 'pending') return 'pending';
  if (claim.status === 'rejected') return 'rejected';
  return profile ? 'settings' : 'pick';
}

export const takenKeys = (profiles: Profile[]) => new Set(profiles.map((p) => p.key));

export function pickList(
  players: { name: string; slug: string; games: number; seasons: number }[], taken: Set<string>, query: string,
) {
  const q = query.trim().toLowerCase();
  return players
    .filter((p) => !q || p.name.toLowerCase().includes(q))
    .sort((a, b) => b.games - a.games)
    .slice(0, 30)
    .map((p) => ({ ...p, taken: taken.has(playerKey(p.name)) }));
}

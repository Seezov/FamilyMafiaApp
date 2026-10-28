import { describe, expect, it } from 'vitest';
import { scopeStats, shown } from './scope';

describe('scopeStats', () => {
  it('adds federation games to season games for players who have them', () => {
    const s = scopeStats(
      [{ slug: 'braun', games: 100, winRate: 0.55 }, { slug: 'alpha', games: 10, winRate: 0.5 }],
      { braun: { games: 20, wins: 5 }, ghost: { games: 3, wins: 3 } },
    );
    expect(s).toEqual({ braun: { games: 100, wins: 55, tGames: 120, tWins: 60 } });
  });
});

describe('shown', () => {
  const s = { games: 100, wins: 55, tGames: 120, tWins: 60 };
  it('season values', () => expect(shown(s, false)).toEqual({ games: 100, wr: 0.55 }));
  it('with tournaments', () => expect(shown(s, true)).toEqual({ games: 120, wr: 0.5 }));
  it('zero games has zero win rate', () => expect(shown({ games: 0, wins: 0, tGames: 0, tWins: 0 }, true)).toEqual({ games: 0, wr: 0 }));
});

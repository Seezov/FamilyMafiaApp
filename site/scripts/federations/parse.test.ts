import fs from 'node:fs';
import { describe, expect, it } from 'vitest';
import {
  nickVariants, parseEgClub, parseEgSummary, parseFiimSearch, parseImafiaProfile, parseImafiaSearch, parseMafgameMembers, parseMafgameRating,
} from './parse.ts';

const fx = (f: string) => fs.readFileSync(new URL(`./fixtures/${f}`, import.meta.url), 'utf8');
const json = (f: string) => JSON.parse(fx(f));

describe('emotion.games', () => {
  it('club members are strong candidates keyed by player_id', () => {
    const { members, totalPages } = parseEgClub(json('eg-club-13-p1.json'));
    expect(totalPages).toBe(6);
    expect(members[0]).toEqual({ fed: 'eg', id: '87', nick: 'Seezov', club: 'Family Mafia Club', city: 'Cherkasy', games: 6, url: 'https://emotion.games/ua/players/87', strength: 'club' });
    expect(members.find((m) => m.nick === 'Пустой')?.id).toBe('1669');   // profile_id = the summary's player_id = the page URL id
  });
  it('year summary marks club 13 as strong, others as nick', () => {
    const rows = parseEgSummary(json('eg-summary-2026.json'));
    expect(rows.find((r) => r.id === '87')).toMatchObject({ nick: 'Seezov', club: 'Family Mafia Club', strength: 'club' });
    expect(rows.find((r) => r.id === '95')).toMatchObject({ nick: 'Скорпіон', club: 'Rocky Mafia Club', strength: 'nick' });
  });
});

describe('empty nicks', () => {
  it('rows without a nick are dropped, never returned without one', () => {
    expect(parseEgSummary([{ player_id: 1, nickname: null, club_id: 2 }, { player_id: 2, nickname: ' ', club_id: 2 }])).toEqual([]);
    expect(parseEgClub({ members: [{ player_id: 3, nickname: '' }], members_pagination: { total_pages: 1 } }).members).toEqual([]);
  });
});

describe('mafgame.org', () => {
  it('club members carry the first name', () => {
    const { members, lastPage } = parseMafgameMembers(fx('mafgame-members-9.html'));
    expect(lastPage).toBe(1);
    expect(members).toHaveLength(11);
    expect(members.find((m) => m.nick === 'Majest')).toMatchObject({ fed: 'mafgame', id: '899', realName: 'Anton', club: 'Family Mafia Club', strength: 'club', url: 'https://mafgame.org/user/899/view' });
  });
  it('rating rows are weak candidates with tournament counts', () => {
    const { rows, lastPage, years } = parseMafgameRating(fx('mafgame-rating.html'));
    expect(lastPage).toBe(80);
    expect(years).toEqual([2026, 2025, 2024]);
    expect(rows[0]).toMatchObject({ id: '101', nick: 'YeS', realName: 'Ievgen Sokolskyi', games: 15, strength: 'nick' });
  });
});

describe('fiim.world', () => {
  it('search rows carry real name, club and city; our club is strong', () => {
    const [s] = parseFiimSearch(json('fiim-search-seezov.json'));
    expect(s).toEqual({ fed: 'fiim', id: '9169', nick: 'Seezov', realName: 'Олександр Сізов', club: 'Family Mafia Club', city: 'Черкассы, Украина', games: 23, url: 'https://fiim.world/user/9169/show', strength: 'club' });
    expect(parseFiimSearch(json('fiim-search-braun.json')).find((r) => r.id === '13376')).toMatchObject({ nick: 'Braun (Браун)', realName: 'Микола Баранов', strength: 'club' });
  });
});

describe('imafia.org', () => {
  it('search rows carry nick and real name', () => {
    expect(parseImafiaSearch(fx('imafia-search-seezov.html'))).toEqual([
      { fed: 'imafia', id: '1003', nick: 'Seezov', realName: 'Олександр Сізов', url: 'https://imafia.org/u/1003', strength: 'nick' },
    ]);
  });
  it('profile gives club (none for «Поза клубом»), country and games', () => {
    expect(parseImafiaProfile(fx('imafia-u-1003.html'))).toEqual({ realName: 'Сізов Олександр', country: 'Україна', club: undefined, games: 86 });
    expect(parseImafiaProfile(fx('imafia-u-640.html')).club).toBe('Big Ben Mafia Club');
  });
});

describe('nickVariants', () => {
  it('splits a nick with a bracketed alternative', () => {
    expect(nickVariants('Braun (Браун)')).toEqual(['Braun (Браун)', 'Braun', 'Браун']);
    expect(nickVariants('Seezov')).toEqual(['Seezov']);
  });
});

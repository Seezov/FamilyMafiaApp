// Parsers for the four federation sites (see the design doc for the URLs). Pure: text in, candidates out.
import { profileUrl, type Candidate, type Fed } from '../../src/lib/federations/core.ts';

const decode = (s: string) => s
  .replace(/&#(\d+);/g, (_, n) => String.fromCodePoint(+n))
  .replace(/&#x([0-9a-f]+);/gi, (_, n) => String.fromCodePoint(parseInt(n, 16)))
  .replace(/&quot;/g, '"').replace(/&#039;|&apos;/g, "'").replace(/&lt;/g, '<').replace(/&gt;/g, '>')
  .replace(/&nbsp;/g, ' ').replace(/&amp;/g, '&');
const text = (html: string) => decode(html.replace(/<[^>]+>/g, ' ')).replace(/\s+/g, ' ').trim();

function cand(fed: Fed, id: unknown, nick: unknown, strength: Candidate['strength'], extra: Partial<Candidate> = {}): Candidate {
  const c: Candidate = { fed, id: String(id), nick: String(nick ?? '').trim(), ...extra, url: profileUrl(fed, String(id)), strength };
  for (const k of Object.keys(c) as (keyof Candidate)[]) if (c[k] === undefined || c[k] === '') delete c[k];
  return c;
}

// Some federation rows have no nickname at all; such a row can't match anyone.
const named = (c: Candidate) => !!c.nick;

/** "Braun (Браун)" → the whole nick and both halves, so either spelling matches the roster. */
export function nickVariants(nick: string): string[] {
  const m = /^(.+?)\s*\((.+)\)\s*$/.exec(nick);
  return m ? [nick, m[1].trim(), m[2].trim()] : [nick];
}

// emotion.games — api-v1.emotion.games JSON.
export function parseEgClub(j: any): { members: Candidate[]; totalPages: number } {
  const place = j.club?.place ?? {};
  return {
    members: (j.members ?? []).map((m: any) => cand('eg', m.player_id, m.nickname, 'club', { club: j.club?.title, city: place.city, games: m.tournaments })).filter(named),
    totalPages: Number(j.members_pagination?.total_pages ?? 1),
  };
}

export const parseEgSummary = (j: any[]): Candidate[] =>
  j.map((r) => cand('eg', r.player_id, r.nickname, r.club_id === 13 ? 'club' : 'nick', { club: r.club ?? undefined })).filter(named);

// mafgame.org — Laravel + Inertia: the page's props are JSON in the data-page attribute.
export function inertiaProps(html: string): any {
  const m = /data-page="([^"]*)"/.exec(html);
  if (!m) throw new Error('mafgame: no data-page in the response');
  return JSON.parse(decode(m[1])).props;
}

export function parseMafgameMembers(html: string): { members: Candidate[]; lastPage: number } {
  const p = inertiaProps(html);
  return {
    members: p.search_results.data.map((m: any) => cand('mafgame', m.id, m.nickname, 'club', { realName: m.display_name ?? undefined, club: p.club?.name })).filter(named),
    lastPage: Number(p.search_results.last_page ?? 1),
  };
}

export function parseMafgameRating(html: string): { rows: Candidate[]; lastPage: number; years: number[] } {
  const p = inertiaProps(html);
  return {
    rows: p.search_results.data.map((r: any) => cand('mafgame', r.user.id, r.user.nickname, 'nick', { realName: r.user.display_name ?? undefined, games: r.participated_count })).filter(named),
    lastPage: Number(p.search_results.last_page ?? 1),
    years: (p.years ?? []).map(Number),
  };
}

// fiim.world — /rating/search returns {success: html}; one ".row.with-avatar" per player.
export function parseFiimSearch(j: { success: string }): Candidate[] {
  return j.success.split(/<div class="row with-avatar">/).slice(1).map((row) => {
    const head = /<div class="col-md-4 header-col">([\s\S]*?)<\/div>/.exec(row)?.[1] ?? '';
    const links = [...head.matchAll(/<a href="https:\/\/fiim\.world\/user\/(\d+)\/show">([\s\S]*?)<\/a>/g)];
    const club = text(/<span>([\s\S]*?)<\/span>\s*\(/.exec(head)?.[1] ?? '');
    const city = text(/<\/span>\s*\(([^)]*)\)/.exec(head)?.[1] ?? '');
    const games = /Всего:\s*(\d+)/.exec(row)?.[1];
    const ours = club.toLowerCase().includes('family mafia') || /черкас/i.test(city);
    return cand('fiim', links[0]?.[1], text(links[0]?.[2] ?? ''), ours ? 'club' : 'nick', {
      realName: links[1] ? text(links[1][2]) : undefined, club: club || undefined, city: city || undefined, games: games ? +games : undefined,
    });
  }).filter((c) => c.id !== 'undefined' && named(c));
}

// imafia.org — server-rendered HTML.
export function parseImafiaSearch(html: string): Candidate[] {
  return [...html.matchAll(/<a href="\/u\/(\d+)" class="player_link">([\s\S]*?)<\/a>/g)].map((m) => {
    const nick = text(/class="player_link_name">([\s\S]*?)<\/span>/.exec(m[2])?.[1] ?? '');
    const full = text(/class="player_link_full_name">([\s\S]*?)<\/span>/.exec(m[2])?.[1] ?? '').replace(/^\(|\)$/g, '').trim();
    return cand('imafia', m[1], nick, 'nick', { realName: full || undefined });
  }).filter(named);
}

export function parseImafiaProfile(html: string): { realName?: string; club?: string; country?: string; games?: number } {
  const field = (label: string) => {
    const m = new RegExp(`<td>${label}</td>\\s*<td>([\\s\\S]*?)</td>`).exec(html);
    return m ? text(m[1]) || undefined : undefined;
  };
  const club = field('Клуб');
  const games = /G\/S\/T\s*(\d+)\//.exec(html)?.[1];
  return { realName: field("Прізвище Ім'я"), country: field('Країна'), club: club === 'Поза клубом' ? undefined : club, games: games ? +games : undefined };
}

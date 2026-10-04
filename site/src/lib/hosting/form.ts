import type { FormSeat, FormState, GameDoc } from './types';

export type DocBody = Omit<GameDoc, 'createdBy' | 'createdByEmail' | 'createdAt' | 'updatedBy' | 'updatedAt'>;

export const parseNumber = (s: string) => {
  const v = Number.parseFloat(s.replace(',', '.'));
  return Number.isFinite(v) ? v : 0;
};
const neg = (s: string) => -Math.abs(parseNumber(s)) || 0; // `|| 0` turns -0 into 0
const show = (v: number) => (v === 0 ? '' : String(Math.abs(v)));

const emptySeat = (): FormSeat => ({
  player: '', role: 'Мирний', fouls: 0, additional: '', penalty: '', protocolAdditional: '', protocolPenalty: '',
});

export const emptyForm = (season: number | null, date: string): FormState => ({
  season, date, table: 1, gameNumber: null, host: '',
  seats: Array.from({ length: 10 }, emptySeat),
  firstKilled: 0, supportFive: [], protocol: [], result: null, comments: [],
});

export function formToDoc(f: FormState): DocBody {
  return {
    season: f.season ?? 0, date: f.date, table: f.table, gameNumber: f.gameNumber ?? 0, host: f.host.trim(),
    seats: f.seats.map((s) => ({
      player: s.player.trim(), role: s.role, fouls: s.fouls,
      additional: parseNumber(s.additional), penalty: neg(s.penalty),
      protocolAdditional: parseNumber(s.protocolAdditional), protocolPenalty: neg(s.protocolPenalty),
    })),
    firstKilled: f.firstKilled,
    supportFive: f.supportFive.filter((x) => x !== 0),
    protocol: f.protocol,
    result: f.result ?? 'unrated',
    comments: f.comments.map((c) => ({ slot: c.slot, text: c.text.trim() })).filter((c) => c.text),
  };
}

export function docToForm(d: GameDoc): FormState {
  return {
    season: d.season, date: d.date, table: d.table, gameNumber: d.gameNumber, host: d.host,
    seats: d.seats.map((s) => ({
      player: s.player, role: s.role, fouls: s.fouls,
      additional: s.additional ? String(s.additional) : '', penalty: show(s.penalty),
      protocolAdditional: s.protocolAdditional ? String(s.protocolAdditional) : '', protocolPenalty: show(s.protocolPenalty),
    })),
    firstKilled: d.firstKilled, supportFive: [...d.supportFive], protocol: d.protocol.map((p) => ({ ...p })),
    result: d.result, comments: d.comments.map((c) => ({ ...c })),
  };
}

export const nextGameNumber = (games: Pick<GameDoc, 'date' | 'table' | 'gameNumber'>[], date: string, table: 1 | 2) =>
  1 + Math.max(0, ...games.filter((g) => g.date === date && g.table === table).map((g) => g.gameNumber));

export const draftKey = (gameId: string | null) => `fm-host-draft:${gameId ?? 'new'}`;

export type Role = 'Мирний' | 'Мафія' | 'Дон' | 'Шериф';
export type Result = 'city' | 'mafia' | 'unrated';
export const ROLES: Role[] = ['Мирний', 'Мафія', 'Дон', 'Шериф'];

export interface Seat {
  player: string; role: Role; fouls: number;
  additional: number; penalty: number; protocolAdditional: number; protocolPenalty: number;
}
export interface ProtocolEntry { slot: number; version: number | null; color: { slot: number; black: boolean } | null }
export interface GameDoc {
  season: number; date: string; table: 1 | 2; gameNumber: number; host: string;
  seats: Seat[]; firstKilled: number; supportFive: number[]; protocol: ProtocolEntry[];
  result: Result; comments: { slot: number; text: string }[];
  createdBy: string; createdByEmail: string; createdAt: unknown; updatedBy: string; updatedAt: unknown;
}

/** What the inputs hold: numbers may be blank, penalties are typed positive. */
export interface FormSeat {
  player: string; role: Role; fouls: number;
  additional: string; penalty: string; protocolAdditional: string; protocolPenalty: string;
}
export interface FormState {
  season: number | null; date: string; table: 1 | 2; gameNumber: number | null; host: string;
  seats: FormSeat[]; firstKilled: number; supportFive: number[]; protocol: ProtocolEntry[];
  result: Result | null; comments: { slot: number; text: string }[];
}

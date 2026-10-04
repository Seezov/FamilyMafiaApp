import { parseNumber } from './form';
import { supportFivePoints } from './points';
import type { FormState } from './types';

export function validate(f: FormState) {
  const errors: string[] = [];
  const warnings: string[] = [];
  const fields = new Set<string>();
  const fail = (msg: string, ...names: string[]) => {
    if (!errors.includes(msg)) errors.push(msg);
    names.forEach((n) => fields.add(n));
  };

  if (f.season === null || !Number.isInteger(f.season)) fail('Вкажіть сезон', 'season');
  if (!/^\d{4}-\d{2}-\d{2}$/.test(f.date)) fail('Вкажіть дату', 'date');
  if (f.gameNumber === null || f.gameNumber < 1) fail('Вкажіть номер гри', 'gameNumber');
  if (!f.host.trim()) fail('Оберіть ведучого', 'host');
  if (f.result === null) fail('Оберіть переможця', 'result');

  const seen = new Map<string, number>();
  f.seats.forEach((s, i) => {
    const name = s.player.trim();
    if (!name) { fail('Заповніть усіх 10 гравців', `seat-${i + 1}-player`); return; }
    const key = name.toLowerCase();
    if (seen.has(key)) fail(`Гравець «${f.seats[seen.get(key)!].player.trim()}» записаний двічі`, `seat-${i + 1}-player`);
    else seen.set(key, i);
  });

  const count = (r: string) => f.seats.filter((s) => s.role === r).length;
  if (count('Мирний') !== 6 || count('Мафія') !== 2 || count('Дон') !== 1 || count('Шериф') !== 1) {
    fail('Ролі мають бути 6 мирних, 2 мафії, 1 дон, 1 шериф', 'roles');
  }

  const isSlot = (n: number) => Number.isInteger(n) && n >= 1 && n <= 10;
  const slots = f.protocol.map((p) => p.slot);
  if (f.protocol.some((p) => !isSlot(p.slot) || (p.version !== null && !isSlot(p.version)) || (p.color && !isSlot(p.color.slot)))
      || new Set(slots).size !== slots.length) {
    fail('Протокол: невірний номер вбитого', 'protocol');
  }
  if (f.supportFive.length > 5 || f.supportFive.some((x) => !isSlot(Math.abs(x)))) fail('Опорна 5: невірні номери', 'supportFive');

  // Sheet checks (warnings only): SUM(ОП + Доп) > 3.6, COUNT(ОП, Доп cells) > 7.
  const op = f.firstKilled ? supportFivePoints(f.supportFive, f.seats.map((s) => s.role)) : 0;
  const addSum = f.seats.reduce((a, s) => a + parseNumber(s.additional), 0);
  if (op + addSum > 3.6 + 1e-9) warnings.push('Сума Доп + ОП більша за 3.6');
  const cells = f.seats.filter((s) => parseNumber(s.additional) !== 0).length + (f.firstKilled ? 1 : 0);
  if (cells > 7) warnings.push('Бали мають більше ніж 7 клітинок');

  return { errors, warnings, fields };
}

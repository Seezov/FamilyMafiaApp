// HTML for /payments/. Every name and note is escaped.
import { esc } from '../appeals/render';
import { EVENT_TYPES, type DayView, type EventType, type Mark, type PaymentsConfig, type PlayerLedger } from './payments';

export const uah = (n: number) => `${Math.round(n * 100) / 100} ₴`;
const WEEKDAYS = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Нд'];
export function dayTitle(date: string) {
  const [y, m, d] = date.split('-').map(Number);
  const wd = new Date(Date.UTC(y, m - 1, d)).getUTCDay() || 7;
  return `${WEEKDAYS[wd - 1]}, ${String(d).padStart(2, '0')}.${String(m).padStart(2, '0')}.${y}`;
}
const notes = (c: { notes: string[]; warning?: string }) =>
  `${esc(c.notes.join(', '))}${c.warning ? ` <span class="warn">⚠ ${esc(c.warning)}</span>` : ''}`;

export function debtRows(list: PlayerLedger[], o: { open: string | null; paying: string | null; onlyDebtors: boolean; today: string }): string {
  const shown = o.onlyDebtors ? list.filter((l) => l.debt !== 0) : list;
  if (!shown.length) return `<tr><td colspan="5" class="muted">${o.onlyDebtors ? 'Боржників немає.' : 'Ще немає вечорів.'}</td></tr>`;
  return shown.map((l) => {
    const p = esc(l.player);
    const tone = l.debt > 0 ? 'neg' : l.debt < 0 ? 'pos' : '';
    let html = `<tr class="row"><td><button type="button" class="link" data-act="open" data-p="${p}">${p}</button></td>
      <td class="num ${tone}">${uah(l.debt)}</td><td class="num">${uah(l.charged)}</td><td class="num">${uah(l.paid)}</td>
      <td class="act"><button type="button" class="btn" data-act="pay" data-p="${p}">Оплатив</button></td></tr>`;
    if (o.paying === l.player) {
      html += `<tr class="sub"><td colspan="5"><form class="pay" data-p="${p}">
        <label>Сума <input name="amount" type="number" min="1" step="1" required value="${Math.max(l.debt, 0) || ''}"></label>
        <label>Дата <input name="date" type="date" required value="${o.today}"></label>
        <label class="grow">Примітка <input name="note" maxlength="200" placeholder="готівка / карта…"></label>
        <button type="submit" class="btn primary">Зберегти оплату</button> <button type="button" class="btn" data-act="pay-cancel">Скасувати</button>
      </form></td></tr>`;
    }
    if (o.open === l.player) {
      const ev = l.evenings.map((e) => `<li><span>${dayTitle(e.date)} · ${e.games} ${e.games === 1 ? 'гра' : e.games < 5 ? 'гри' : 'ігор'}</span><span class="num">${uah(e.charge.amount)}</span><span class="muted">${notes(e.charge)}</span></li>`).join('');
      const rec = l.records.map((r) => `<li><span>${esc(r.date)} · ${esc(r.note) || '—'} <span class="muted">(${esc(r.byEmail)})</span></span><span class="num pos">${uah(r.amount)}</span>
        <span><button type="button" class="btn danger small" data-act="del-record" data-id="${esc(r.id)}">Видалити</button></span></li>`).join('');
      html += `<tr class="sub"><td colspan="5"><div class="detail">
        <div><h3 class="label">Вечори</h3><ul class="lines">${ev || '<li class="muted">—</li>'}</ul></div>
        <div><h3 class="label">Оплати</h3><ul class="lines">${rec || '<li class="muted">—</li>'}</ul></div></div></td></tr>`;
    }
    return html;
  }).join('');
}

const markMode = (m?: Mark) => (m?.newbie ? 'newbie' : m?.free !== undefined ? 'free' : m?.amount !== undefined ? 'amount' : '');

export function dayCard(d: DayView, open: boolean): string {
  const typeLabel = d.eventType ? EVENT_TYPES[d.eventType] : 'звичайний вечір';
  const opts = [
    `<option value=""${d.override === null ? ' selected' : ''}>Авто: ${d.auto ? EVENT_TYPES[d.auto] : 'звичайний'}</option>`,
    `<option value="none"${d.override === 'none' ? ' selected' : ''}>Звичайний вечір</option>`,
    ...Object.entries(EVENT_TYPES).map(([k, v]) => `<option value="${k}"${d.override === k ? ' selected' : ''}>${v}</option>`),
  ].join('');
  const rows = d.players.map((p) => {
    const mode = markMode(p.mark);
    const val = p.mark?.free ?? (p.mark?.amount !== undefined ? String(p.mark.amount) : '');
    return `<tr data-p="${esc(p.player)}"><td>${esc(p.player)}</td><td class="num">${p.games}</td><td class="num">${uah(p.charge.amount)}</td>
      <td><select name="mode" aria-label="Виняток">
        <option value=""${mode === '' ? ' selected' : ''}>—</option>
        <option value="newbie"${mode === 'newbie' ? ' selected' : ''}>Привів новачка</option>
        <option value="free"${mode === 'free' ? ' selected' : ''}>Безкоштовно</option>
        <option value="amount"${mode === 'amount' ? ' selected' : ''}>Своя сума</option></select>
        <input name="val" value="${esc(val)}" placeholder="причина / сума" aria-label="Причина або сума" maxlength="200"></td>
      <td><label class="chk"><input type="checkbox" name="russian"${p.mark?.russian ? ' checked' : ''}> рос.</label></td>
      <td class="muted">${notes(p.charge)}</td></tr>`;
  }).join('');
  return `<details class="day"${open ? ' open' : ''} data-date="${d.date}"><summary><b>${dayTitle(d.date)}</b> · ${esc(typeLabel)} · ${d.players.length} гравців · <span class="num">${uah(d.total)}</span></summary>
    <form class="day-form" data-date="${d.date}">
      <label>Тип вечора <select name="eventType">${opts}</select></label>
      <table class="list"><thead><tr><th>Гравець</th><th class="num">Ігор</th><th class="num">Сума</th><th>Виняток</th><th></th><th></th></tr></thead><tbody>${rows}</tbody></table>
      <button type="submit" class="btn primary">Зберегти вечір</button>
    </form></details>`;
}

export function configForm(c: PaymentsConfig): string {
  const n = (name: string, v: number | undefined, label: string) =>
    `<label>${label} <input name="${name}" type="number" min="0" step="1" value="${v ?? ''}"></label>`;
  const tg = Object.entries(c.telegram).map(([p, h]) => `${p} ${h}`).join('\n');
  return `<fieldset><legend>Ціни за вечір</legend><div class="fields">
      ${WEEKDAYS.map((w, i) => n(`wd${i + 1}`, c.prices.weekday[String(i + 1)], w)).join('')}
      ${n('student', c.prices.student, 'Студент')}${n('single', c.prices.single, '1 гра')}</div></fieldset>
    <fieldset><legend>Особливі вечори (без знижок; порожньо = ціну не задано)</legend><div class="fields">
      ${Object.entries(EVENT_TYPES).map(([k, v]) => n(`ev-${k}`, c.prices.events[k as EventType], v)).join('')}</div></fieldset>
    <div class="cols">
      <label>Студенти (по одному в рядку)<textarea name="students" rows="6">${esc(c.students.join('\n'))}</textarea></label>
      <label>Організатори — не платять<textarea name="organizers" rows="6">${esc(c.organizers.join('\n'))}</textarea></label>
      <label>Telegram для бота («Ім'я @нік» у рядку)<textarea name="telegram" rows="6">${esc(tg)}</textarea></label>
    </div>
    ${n('startSeason', c.startSeason, 'Рахувати з сезону')}
    <button type="submit" class="btn primary">Зберегти налаштування</button>`;
}

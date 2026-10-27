// /payments/: admins see who owes for club evenings, mark payments and per-evening exceptions.
import { onClubUser, signIn, signOutUser, type ClubAdmin } from '../lib/club/store';
import { buildLedger, isEventType, type DayDoc, type EventType, type Mark, type PaymentsConfig } from '../lib/payments/payments';
import { configForm, dayCard, debtRows } from '../lib/payments/render';
import { addRecord, deleteRecord, explainError, loadPayments, saveConfig, saveDay, type PaymentsData } from '../lib/payments/store';

const $ = <T extends HTMLElement>(id: string) => document.getElementById(id) as T;
const today = () => new Date().toLocaleDateString('sv-SE');

let user: ClubAdmin | null | 'not-host' = null;
let data: PaymentsData | null = null;
let open: string | null = null;
let paying: string | null = null;
const openDays = new Set<string>();
let busy = false;
const isAdmin = () => typeof user === 'object' && user !== null && user.admin;

function say(text: string, error = false) {
  $('msg').textContent = text;
  $('msg').classList.toggle('error', error);
}

async function refresh() {
  if (!isAdmin()) { data = null; render(); return; }
  $('state').textContent = 'Завантаження…';
  try {
    data = await loadPayments();
  } catch (e) {
    data = null;
    say(explainError(e), true);
  }
  render();
}

function render() {
  $('who').textContent = user === null ? 'Не увійшов' : user === 'not-host' ? 'Не ведучий — немає доступу'
    : `${user.name}${user.admin ? ' (адмін)' : ' — не адмін, немає доступу'}`;
  $('sign-in').hidden = user !== null;
  $('sign-out').hidden = user === null;
  $('content').hidden = !data;
  if (!data) { $('state').textContent = isAdmin() ? '' : 'Лише для адмінів'; return; }
  const l = buildLedger(data);
  const debt = l.players.reduce((s, p) => s + Math.max(p.debt, 0), 0);
  const debtors = l.players.filter((p) => p.debt > 0).length;
  $('state').textContent = `${debtors} боржників · разом ${Math.round(debt)} ₴ · з сезону ${data.cfg.startSeason}`;
  $('debts').innerHTML = debtRows(l.players, { open, paying, onlyDebtors: ($('only-debtors') as HTMLInputElement).checked, today: today() });
  $('days').innerHTML = l.days.length ? l.days.map((d) => dayCard(d, openDays.has(d.date))).join('') : '<p class="muted">Ще немає вечорів у цих сезонах.</p>';
  const cf = $('config') as HTMLFormElement;
  if (!cf.dataset.filled) { cf.innerHTML = configForm(data.cfg); cf.dataset.filled = '1'; }
  $('roster').innerHTML = data.roster.map((n) => `<option value="${n.replace(/"/g, '&quot;')}">`).join('');
  for (const b of document.querySelectorAll<HTMLButtonElement>('#content button')) b.disabled = busy;
}

async function run(work: () => Promise<unknown>, done: string) {
  if (!isAdmin() || busy) return;
  busy = true;
  render();
  try {
    await work();
    say(done);
  } catch (e) {
    say(explainError(e), true);
  } finally {
    busy = false;
    await refresh();
  }
}

document.addEventListener('click', (ev) => {
  const b = (ev.target as HTMLElement).closest<HTMLElement>('[data-act]');
  if (!b || busy) return;
  const p = b.dataset.p ?? null;
  switch (b.dataset.act) {
    case 'open': open = open === p ? null : p; break;
    case 'pay': paying = paying === p ? null : p; break;
    case 'pay-cancel': paying = null; break;
    case 'del-record':
      if (confirm('Видалити цю оплату?')) void run(() => deleteRecord(b.dataset.id!), 'Оплату видалено.');
      return;
    default: return;
  }
  render();
});

document.addEventListener('toggle', (ev) => {
  const d = ev.target as HTMLElement;
  if (d instanceof HTMLDetailsElement && d.dataset.date) {
    if (d.open) openDays.add(d.dataset.date); else openDays.delete(d.dataset.date);
  }
}, true);

document.addEventListener('submit', (ev) => {
  const f = ev.target as HTMLFormElement;
  const v = (n: string) => (f.elements.namedItem(n) as HTMLInputElement | null)?.value.trim() ?? '';
  if (f.classList.contains('pay')) {
    ev.preventDefault();
    const amount = Number(v('amount'));
    if (!(amount > 0)) return say('Сума має бути більшою за 0.', true);
    const player = f.dataset.p!;
    void run(async () => { await addRecord({ player, amount, date: v('date'), note: v('note') }, user as ClubAdmin); paying = null; },
      `Оплату ${amount} ₴ від ${player} збережено.`);
  } else if (f.classList.contains('day-form')) {
    ev.preventDefault();
    const date = f.dataset.date!;
    const t = v('eventType');
    const marks: Record<string, Mark> = {};
    for (const tr of f.querySelectorAll<HTMLTableRowElement>('tbody tr')) {
      const mode = (tr.querySelector('[name=mode]') as HTMLSelectElement).value;
      const val = (tr.querySelector('[name=val]') as HTMLInputElement).value.trim();
      const m: Mark = {};
      if (mode === 'newbie') m.newbie = true;
      if (mode === 'free') m.free = val;
      if (mode === 'amount') {
        const a = Number(val.replace(',', '.'));
        if (!(a >= 0) || val === '') return say(`${tr.dataset.p}: «Своя сума» — введи число.`, true);
        m.amount = a;
      }
      if ((tr.querySelector('[name=russian]') as HTMLInputElement).checked) m.russian = true;
      if (Object.keys(m).length) marks[tr.dataset.p!] = m;
    }
    const day: DayDoc = { date, eventType: t === 'none' ? 'none' : isEventType(t) ? t : null, marks };
    void run(() => saveDay(day, user as ClubAdmin), 'Вечір збережено.');
  } else if (f.id === 'config') {
    ev.preventDefault();
    const num = (n: string) => (v(n) === '' ? undefined : Number(v(n)));
    const lines = (n: string) => [...new Set(v(n).split('\n').map((s) => s.trim()).filter(Boolean))];
    const weekday: Record<string, number> = {};
    for (let i = 1; i <= 7; i++) weekday[String(i)] = num(`wd${i}`) ?? 0;
    const events: PaymentsConfig['prices']['events'] = {};
    for (const k of ['marathon', 'series', 'minicap', 'bigcap', 'maxicap', 'tournament'] as EventType[]) {
      const x = num(`ev-${k}`);
      if (x !== undefined) events[k] = x;
    }
    const telegram: Record<string, string> = {};
    for (const line of lines('telegram')) {
      const m = line.match(/^(.*\S)\s+(@?[A-Za-z0-9_]{3,})$/);
      if (!m) return say(`Telegram: не розібрав рядок «${line}» — потрібно «Ім'я @нік».`, true);
      telegram[m[1]] = m[2].startsWith('@') ? m[2] : `@${m[2]}`;
    }
    const cfg: PaymentsConfig = {
      prices: { weekday, student: num('student') ?? 0, single: num('single') ?? 0, events },
      students: lines('students'), organizers: lines('organizers'), telegram, startSeason: num('startSeason') ?? 32,
    };
    const known = new Set(data?.roster ?? []);
    const unknown = [...cfg.students, ...cfg.organizers, ...Object.keys(telegram)].filter((n) => !known.has(n));
    void run(async () => { await saveConfig(cfg, user as ClubAdmin); delete f.dataset.filled; },
      `Налаштування збережено.${unknown.length ? ` Увага, немає в ростері: ${unknown.join(', ')}.` : ''}`);
  }
});

$('only-debtors').addEventListener('change', render);
$('sign-in').addEventListener('click', () => void signIn().catch((e) => say(String(e), true)));
$('sign-out').addEventListener('click', () => void signOutUser());
onClubUser((u) => { user = u; void refresh(); });
render();

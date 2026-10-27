# Player debts (/payments/) — design

**Goal:** organizers see who owes for club evenings and how much; later a Telegram bot DMs reminders.

## Decisions (owner, 2026-10-27)
- Admins only (Firestore rules: read and write `isAdmin()`); debts never reach the public static build.
- Counting starts with season 32 (Firestore games). `startSeason` is editable.
- A player is charged once per game day they played at least one game. A host who did not play pays nothing.
- Prices: Tue/Thu 150, Sat/Sun 200 (all seven weekdays editable), student 100, a single game 50 —
  an ordinary evening costs the **cheapest** that applies. Playing in Russian (per-evening mark) doubles it.
- Special evenings (marathon, series, minicap, bigcap, maxicap, tournament) have their own price and **no discounts**;
  Russian still doubles. The type comes from `config/club.tournaments` by date (a multi-day `tournament` = series)
  and can be overridden per day. An unset type price falls back to the weekday price with a warning.
- Free: organizers (list in settings), «привів новачка» and «безкоштовно: <reason>» per player per evening; or a manual amount.
- Payments: an admin records an amount (default = whole debt), date and note. Debt = charged − paid.

## Data
- `payments/config` — `{prices: {weekday: {'1'..'7'}, student, single, events}, students[], organizers[], telegram{name: '@handle'}, startSeason}` + stamp.
- `paymentDays/{YYYY-MM-DD}` — `{eventType: null | 'none' | type, marks: {player: {newbie?, russian?, free?, amount?}}}` + stamp.
- `paymentRecords/{auto}` — `{player, amount, date, note, createdAt, createdBy, createdByEmail}`; no updates, admins delete mistakes.
- Seat names resolve to roster display names through `config/players` nicknames.

## Code
- `site/src/lib/payments/payments.ts` — pure rules (`chargeFor`, `buildLedger`, `eventDates`); a Node bot can import it.
- `store.ts` (Firebase), `render.ts` (escaped HTML), `site/src/scripts/payments.ts`, `site/src/pages/payments/index.astro`.
- Rules in `firestore.rules`, tests in `firebase/rules-test/rules.test.ts`.

## Later: Telegram bot
Reads the same collections with a service account, computes `buildLedger`, DMs players with a debt via
`telegram` handles (the bot needs each player's chat id: they must /start it once).

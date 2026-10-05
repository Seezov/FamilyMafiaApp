# Game appeals — design

Date: 2026-10-05. Status: approved in chat, awaiting spec review.

## Goal

A player who thinks they deserved an additional point («дод бал») in a game can file an
appeal; an admin accepts it, accepts it partially, or rejects it. An accepted appeal changes the
game itself, so the rating picks it up on the next build. Admins see the full history: who
appealed, against which host, what was asked and what was decided.

## Decisions (from the user)

- **Accepting changes the game automatically.** So appeals exist only for games recorded on
  `/host/` (Firestore `games/{id}`), i.e. season 32+. Sheet seasons (≤ 31) get no appeals.
- **Only the current season's games.** Current = the newest club season whose start date has come
  (`hostDefaultSeason` in `site/src/lib/seasons/seasons.ts`). When the next season starts, appeals
  on the previous one close.
- **A player appeals only for themselves**, only on a game they sat in.
- Any player with an **approved claim** (`/account/`) may appeal — that is how we know who they are.
- The player writes a **description** (their reasoning) and the **expected additional point**.
- **History** for admins: filter by player, host, status, season; per-host totals.

## Data

New collection `appeals/{gameId}_{uid}`:

| field | type | notes |
|---|---|---|
| `gameId` | string | `games/{gameId}` |
| `season` | int | copied from the game |
| `date`, `table`, `gameNumber`, `host` | | snapshot of the game at filing time, so history survives later edits |
| `seat` | int 1–10 | the appellant's seat at filing time |
| `player` | string | the claim's `player` (display name) |
| `uid`, `email` | string | appellant |
| `text` | string | 1–1000 chars |
| `requested` | number | 0 < x ≤ 5 |
| `status` | `pending` \| `accepted` \| `partial` \| `rejected` | |
| `granted` | number | accepted: = `requested`; partial: 0 < x < `requested`; absent otherwise |
| `adminComment` | string | optional, ≤ 1000 |
| `createdAt`, `updatedAt` | timestamp | |
| `decidedBy`, `decidedAt` | string (admin email), timestamp | set on decision |

One appeal per player per game: rules can't enforce uniqueness by query, so the id is
`${gameId}_${uid}` — a second appeal on the same game is an update of the first (refused once
decided), not a new doc. A withdrawn (deleted) pending appeal can be filed again.

## Filing (player) — `/account/`

New «Апеляції» section, shown when the claim is approved and a current Firestore season exists:

- Lists the current season's games (rated: `result != 'unrated'`) where a seat's `player` equals
  the claim's `player`, newest first, each with its appeal state.
- «Подати апеляцію» opens a small form: description (textarea) + expected additional point
  (number input, step 0.1). Save creates `appeals/{gameId}_{uid}`.
- While `pending` the player can edit or withdraw (delete) it. After a decision it is read-only
  and shows status, granted amount and the admin's comment.

## Review (admin) — `/account/admin/`

New «Апеляції» section with two tabs:

- **Нові** — pending appeals, oldest first. Card: game (date, table, №, host, link to the game
  card on `/season/N/games/`), player, seat, the game's current additional for that seat,
  description, requested. Optional admin comment field; buttons **Прийняти**, **Частково**
  (asks for the amount, 0 < x < requested), **Відхилити**.
- **Історія** — every appeal, newest first: filed date, player, game, host, requested, status,
  granted, decided by, decided at, admin comment. Filters (player, host, status, season) live in
  the URL query like the records page. Above the table: per-host totals (appeals / accepted /
  partial / rejected / points granted) for the current filter.

### What a decision writes

Accept / partial is one Firestore transaction:

1. read the game and the appeal (appeal must still be `pending`);
2. find the seat whose `player` equals the appeal's `player` (the seat may have moved if the
   host edited the game; if the player is no longer in the game → error, nothing written);
3. game: `seats[i].additional = round2(additional + granted)`, append to `comments`
   `{ slot: i+1, text: "Апеляція: +X" }`, `updatedBy`/`updatedAt` as every game save;
4. appeal: `status`, `granted`, `adminComment`, `decidedBy`, `decidedAt`, `updatedAt`.

Reject writes only the appeal. Every decision then bumps `meta/state`, so `games-watch.yml`
rebuilds the site within an hour (same as other admin saves).

## Rules (`firestore.rules`)

`match /appeals/{id}`:

- **read**: the appellant (`resource.data.uid == request.auth.uid`) or `isAdmin()`.
- **create / update by the player**: `approvedPlayer()`; `id == gameId + '_' + uid`; doc
  `uid`/`email`/`player` equal the caller and their approved claim; `status == 'pending'` (and on
  update the existing doc is still pending); field set and types as in the table; the game exists,
  `get(game).seats[seat-1].player == player`, `game.season == season`, `game.result != 'unrated'`,
  and the snapshot fields equal the game's; the season is current (below).
- **delete**: the appellant while `pending`, or `isAdmin()`.
- **update by an admin (decision)**: existing `status == 'pending'`; only `status`, `granted`,
  `adminComment`, `decidedBy`, `decidedAt`, `updatedAt` change; `decidedBy == email()`,
  `decidedAt == request.time`; `rejected` ⇒ no `granted`; `accepted` ⇒ `granted == requested`;
  `partial` ⇒ `0 < granted < requested`; accepted/partial ⇒ the game is written in the same
  transaction (`getAfter(game).updatedAt == request.time`).

**Current season in rules:** `config/seasons.seasons` is ordered by id and contiguous, so the
game's season sits at index `season - seasons[0].id`. It is current when its `startDate` ≤ today
and either it is the last entry or the next entry's `startDate` > today. Today comes from
`request.time` (compared as `YYYY-MM-DD` built from `request.time.year()/month()/day()`). The
client uses the same logic via `hostDefaultSeason`; a unit test pins them together on the same
cases.

Game writes need no rule change: an admin is a host and may update any game.

## Code layout (site only; the app is unaffected)

- `site/src/lib/appeals/core.ts` — pure: types, validation (`validateAppeal`, `validateDecision`),
  `applyDecision(game, appeal, decision)` → new game seats/comments, `round2`, history filtering
  and per-host totals. Unit tests next to it.
- `site/src/lib/appeals/store.ts` — Firestore calls (file/update/withdraw, list own, list all,
  decide transaction).
- `site/src/lib/appeals/render.ts` — HTML for cards / history rows (escaped), tested like
  `seasons/render.ts`.
- `site/src/scripts/account.ts`, `account-admin.ts` + their pages — wire the sections.
- `firestore.rules` + `firebase/rules-test/rules.test.ts` — new cases.

## Testing

- Unit (vitest): validation bounds, `applyDecision` (rounding, seat lookup after a move, missing
  player), history filters and totals, render escaping.
- Rules (emulator): player can file on own current-season game; not on another's seat, an unrated
  game, a past season, or without an approved claim; can edit/withdraw only while pending; cannot
  set status; admin decisions with each status; partial bounds; accept without a game write is
  refused; non-admin cannot decide.
- Manual on the deployed site once a season-32 game exists.

## Deploy

Publish the new rules in the console **before** pushing the code (lesson from season creation);
then push `feature/flutter_migration` and fast-forward `master`. Nothing in the build reads
`appeals`, so no prefetch change.

## Out of scope

- Appeals on sheet seasons (≤ 31).
- Notifications (Telegram/e-mail) on new appeals or decisions.
- Public history on the site; reopening a decided appeal (an admin can edit the game on `/host/`).
- Appeals about penalties or anything other than the additional point.

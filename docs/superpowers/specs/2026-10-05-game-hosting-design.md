# Game hosting on the site (stage 1: game protocol form) — design

Date: 2026-10-05
Status: approved in chat, awaiting written-spec review

## Goal

Replace Google Sheets as the club's game database. Hosts record finished games on a new
site page (`/host/`, menu item «Провести гру»); games are stored in Firebase Firestore and
flow into the app and the stats site exactly like sheet games do today.

Background: games are currently hosted on app.emotion.games, which cannot export to our
sheet. Its referee client (`logic_test.js`) has no Sheets export at all — it POSTs to
`api.emotion.games`; it also loses games on refresh. Our own form removes that dependency.

## Scope

**Stage 1 (this spec):** a protocol form — the digital version of one game block of the
season-30 sheet. No live phases, timers or voting.

**Stage 2 (later, separate spec):** live hosting (phases, timer, nominations, voting, night,
fouls flow) that fills the same form/document. Out of scope here.

**Cut-over:** season 32 (Dec 2026) is the first season recorded only in Firestore. Season 31
stays in its sheet. No import of old seasons.

## Decisions

| Topic | Decision |
|---|---|
| Storage | Firebase Firestore, free Spark plan, no Cloud Functions |
| Auth | Google sign-in (Firebase Auth) |
| Who writes | allowlist `hosts/{email}`; author edits own games without time limit; admin edits/deletes any |
| Reads | public (stats are public anyway) |
| Stats pipeline | app and build read Firestore directly via REST (new season source `firestore`) |
| Protocol points (ПрДод/ПрШтраф) | entered manually; protocol is recorded, not auto-scored |
| ОП and win point | computed in code from the stored data, never stored |
| Tables | up to 2 tables per evening; game number counts per table per day |

## Architecture

1. **Firebase project** — Firestore + Auth (Google provider). Created by the owner (step-by-step
   guide provided during implementation).
2. **`/host/` page** in `site/` — client script using the Firebase JS SDK (modular, tree-shaken):
   sign-in, game list, form, save/edit. Static page; all data is loaded at runtime.
3. **`firestore` season source** — `season_config.json` / `remote_config.json` get
   `{id: 32, ..., source: "firestore", projectId: "<id>"}`. Dart reads games through the
   Firestore REST API with Dio (no Firebase SDK in the app), like `SheetsService`.
4. **Site rebuilds** — an hourly check rebuilds the site only when Firestore changed.

## Data model (Firestore)

```
games/{autoId}
  season: 32
  date: "2026-12-03"             // evening date, ISO yyyy-mm-dd
  table: 1 | 2
  gameNumber: 3                  // per table per date, starts at 1
  host: "Серпень"                // required
  seats: [ ×10, index = slot-1
    { player: "Німфа",
      role: "Мирний" | "Мафія" | "Дон" | "Шериф",
      fouls: 0..4,
      additional: 0.3,           // Доп
      penalty: 0,                // Штраф (negative or 0, stored as entered)
      protocolAdditional: 0,     // ПрДод
      protocolPenalty: 0 }       // ПрШтраф
  ]
  firstKilled: 6                 // ПУ slot, 0 = none
  supportFive: [1, -5, 7]        // Опорна 5: up to 5 slots, sign = colour (+ red, − black)
  protocol: [                    // only players killed at night
    { slot: 6,
      version: 4 | null,         // whom they believe is the sheriff
      color: { slot: 5, black: true } | null }   // exactly one player + colour
  ]
  result: "city" | "mafia" | "unrated"
  comments: [{ slot: 2, text: "..." }]           // коментарі до дод. балів
  createdBy, createdAt, updatedBy, updatedAt     // uid/email + server timestamps

hosts/{email}  { name: "Seezov", admin: true }   // edited by the owner in the console
meta/state     { updatedAt }                     // bumped on every game write
```

Season order of games: `date`, then `table`, then `gameNumber`.

Role strings match the season-29+ sheet values so the existing `Role` enum parses them.
Penalty sign follows the existing convention: penalties are stored negative and added,
never subtracted.

## Security rules

- `games`: `read` — anyone. `create` — signed-in user whose email has a `hosts` doc, with
  `createdBy == request.auth.uid`. `update` — the creator or an admin; `createdBy/createdAt`
  immutable. `delete` — admin only. Field shape validated in rules (10 seats, enums, numbers).
- `hosts`: `read` — the signed-in user for their own doc (to show "not a host"); no client writes.
- `meta/state`: `read` — anyone; `write` — hosts, only the `updatedAt` field set to `request.time`.

## `/host/` page

**Sign-in:** «Увійти через Google». Not in `hosts` → «Немає прав ведучого — звернись до адміна».

**List:** recent games (date, table, number, host, winner); host sees own games and the
current evening, admin sees all. Open → edit. «Нова гра» button.

**Form** (mobile-first, single column, 10 seat cards), same order as the sheet block:

1. Header: date (default today), table (1/2), game number (suggested: next for that
   table + date), host (autocomplete, **empty by default, required** — highlighted, blocks save).
2. 10 seats: player (autocomplete over the club player list incl. nicknames; a new name is
   allowed with a «новий гравець» warning), role toggle, fouls 0–4, Доп, Штраф, ПрДод, ПрШтраф.
3. ПУ + Опорна 5: first-killed slot; up to 5 slots each with a red/black toggle; computed ОП
   shown next to the ПУ player live.
4. Protocol: «+ Вбитий гравець» → slot, version (sheriff guess), colour (one slot + red/black).
   The first entry is prefilled with the ПУ slot.
5. Result: Місто / Мафія / Не рейтинг; comments to extra points.
6. «Зберегти».

**Validation — blocks save:** host empty; roles not 6 Мирний / 2 Мафія / 1 Дон / 1 Шериф;
duplicate player; empty player; result not chosen; protocol slot not a valid seat.
**Warnings only (as in the sheet):** Доп + ОП sum > 3.6; more than 7 players with points.

**Draft:** form state autosaved to `localStorage` (keyed by game id or `new`) on every change;
restored on reload; cleared after a successful save.

**After save:** «Гру збережено. У статистиці з'явиться протягом години.»

**Player list for autocomplete:** exported at build time from `assets/raw/players.json`
(displayName + nicknames, junk entries filtered) into the page's data.

## Computed values (shared formulas, TS + Dart)

**Win point:** 1 if `result == city` and role is Мирний/Шериф, or `result == mafia` and role
is Мафія/Дон; else 0; none for `unrated`.

**ОП (best-move points of the ПУ player)** — port of the season-30 sheet formula:

```
g = supportFive (non-empty); role(x) = role of slot |x|
Nmaf = count(g < 0); Kmaf = count(g < 0 and role is Мафія/Дон)
Ncit = count(g > 0); Kcit = count(g > 0 and role not Мафія/Дон)
mSucc = [0, 0.25, 0.55, 0.9, 0.9, 0.9][Kmaf]
mMiss = [0, -0.1, -0.25, -0.45, -1.45, -2.45]
cMiss = [0, -0.1, -0.2, -0.35, -0.55, -0.8]
score = mSucc + (mMiss[Nmaf] - mMiss[Kmaf]) + 0.1*Kcit + (cMiss[Ncit] - cMiss[Kcit])
ОП = (Nmaf + Ncit == 0) ? -0.1 : score       // only for the ПУ player
```

## Dart side

- `SeasonConfig` gets `FirestoreSource{projectId}` (`source: "firestore"`).
- `FirestoreService` (Dio): one `runQuery` (`games where season == N`) over REST; sort locally;
  returns documents as plain maps. Cache + fallback mirror `SheetsService` (row count →
  document count + max `updatedAt`).
- `gameFromFirestore(map)` builds `Game` directly (no sheet-row format): players, roles,
  `cityWon`, `firstKilled`, `bestMovePoints` (ОП formula), `supportFive`, additional /
  penalty / protocol columns, host, date.
- `Game` gains `List<int>? fouls`; `ProtocolEntry` gains `int? version` and a single-colour
  field, keeping the old `colorGuesses` for seasons 29–31.
- `tool/prefetch_seasons.dart` snapshots firestore seasons into `assets/prefetched/` too, so
  the site build keeps working offline from the snapshot.

## Site build

- `site/src/layouts/Base.astro` nav gets `host` («Провести гру»).
- `.github/workflows/games-watch.yml`: hourly cron reads `meta/state.updatedAt` via REST,
  compares to the value in `actions/cache`, dispatches `web.yml` when it changed (needs
  `actions: write`). Must also exist on `master` for the schedule to run.
- `site/scripts/check-dist.mjs`: allow exactly the Firebase web API key (explicit allowlist
  constant); any other `AIza` string still fails the build.
- Season 32 entry is added to both config files ahead of the season.

## Error handling

- Offline / network failure on save: draft kept, «Спробувати ще» button.
- Rules rejection: readable message (no rights / not your game).
- Concurrent edit: save in a transaction that checks the loaded `updatedAt`; on mismatch
  «Гру змінили з іншого пристрою — перезавантаж».
- Auth popup blocked: fall back to redirect sign-in.

## Testing

- ОП formula: unit tests in TS and Dart against season-30 sheet values (e.g. ПУ 6 with
  Опорна 5 `[1, 5, 7]` → `-0.15`) and edge cases (empty → -0.1, all mafia found).
- Form validation: TS unit tests (role composition, duplicates, host required, warnings).
- `gameFromFirestore`: Dart tests on fixture documents.
- Security rules: `@firebase/rules-unit-testing` against the emulator — guest, non-host,
  host-author, host-non-author, admin.
- Before launch: end-to-end run on a test season 999 — enter a game → appears on the site
  and in the app.

## Owner tasks

- Create the Firebase project, enable Google sign-in and Firestore (guided).
- Add host emails to `hosts`.

# Season creation — design

Date: 2026-10-05
Status: approved in chat, awaiting written-spec review

## Goal

Admins open a new club season on the site instead of a commit to `remote_config.json` and
`assets/raw/season_config.json`. From season 32 the games are recorded on `/host/` into
Firestore, so «creating a season» no longer means copying a Google Sheet — it means adding the
season's config entry.

## How it works today (verified 2026-10-05)

- The season list is `remote_config.json` (served from GitHub raw, `feature/flutter_migration`)
  with the bundled `assets/raw/season_config.json` as fallback; 32 entries (0–31). The prefetch
  snapshots it to `assets/prefetched/remote_config.json`; the app reads URL → cache → bundled.
- A Firestore season is `{"id", "title", "gameLimitRule": "top3", "gamesMultiplier": 0.0,
  "smallLeagueMinGames": 15, "source": "firestore", "projectId": "familymafiaapp"}`.
- A season's bounds come from its games' dates (`seasonInProgress`: the median game's calendar
  quarter); there is no start date in the config.
- `/host/` defaults its season field to the newest `firestore` season in the build-time config;
  hosts can type another number.
- The app loads `configs.last` first; a season with no games would show as an empty season.

## Decisions

| Topic | Decision |
|---|---|
| Who | Admins (`hosts/{email}.admin == true`), Google sign-in. |
| Storage | Firestore `config/seasons`. Seasons 0–31 stay in the JSON config untouched; Firestore holds 32+, appended after the JSON list. |
| Admin sets | Title, small-league minimum games, start date. Everything else is fixed. |
| Number | Always the largest existing id + 1 (JSON and Firestore together). |
| Start date | From that day the season is `/host/`'s default. It does not set the season's bounds. |
| Empty season | A season with no games is not shown in the app or on the site. |
| Mistakes | A created season with no games can be deleted on the page. No other editing (out of scope). |
| Publishing | Every save also sets `meta/state.updatedAt`. |

## Data

`config/seasons`:

```
{
  seasons: [ { id: int, title: string, smallLeagueMinGames: int, startDate: 'YYYY-MM-DD' } ],
  updatedAt: timestamp, updatedBy: uid, updatedByEmail: string
}
```

Each entry becomes the `SeasonConfig` JSON
`{id, title, gameLimitRule: 'top3', gamesMultiplier: 0.0, smallLeagueMinGames, source: 'firestore',
projectId: 'familymafiaapp'}` when read. `startDate` is kept for `/host/` only.

## Validation (Dart and TS, shared fixture)

A season list is valid when every entry has: `id` int greater than the JSON config's last id (31 today) and unique;
`title` a string of 1–40 characters after trim; `smallLeagueMinGames` int 1–100; `startDate` a
real `YYYY-MM-DD` date. Entries are in increasing id order with no gaps after the JSON's last
id (32, 33, …). At most 100 entries.

The build fails on an invalid document (naming the problem) or an id that the JSON config also
has. The editor refuses to save one.

## Rules (`firestore.rules`)

```
match /config/seasons {
  allow read: if true;
  allow create, update: if isAdmin()
    && keys hasOnly ['seasons', 'updatedAt', 'updatedBy', 'updatedByEmail']
    && seasons is list && seasons.size() <= 100
    && updatedAt == request.time && updatedBy == uid && updatedByEmail == email();
  allow delete: if false;
}
```

Entry contents are validated by the editor and the build (rules cannot loop over a list).

## Build and app

- `tool/prefetch_seasons.dart` reads `config/seasons` over REST, validates it, and
  - fetches each Firestore season's games like the JSON's `firestore` seasons;
  - writes the merged season list into the `remote_config.json` snapshot it already writes
    (JSON seasons + Firestore seasons), so every reader of the snapshot sees one list;
  - a missing document is fine (no extra seasons); a malformed one, or an id clash with the
    JSON, fails the build.
- The app's `parsedConfigProvider` appends Firestore seasons the same way:
  `FirestoreService.fetchSeasons` live → cached → none. A cached merged config already contains
  them; seasons are de-duplicated by id (the JSON wins on a clash).
- Empty seasons: after the season JSONs load, a `firestore` season with zero games is dropped
  from the loaded configs (app, web export). The initial load then shows the newest season with
  games.

## Pages

**`/seasons/edit/`** — admin page, signed out → read-only with a sign-in button.
- Table of every season: id, title, source (sheet / app / Firestore), games recorded, start
  date (Firestore seasons).
- «Create season N» form: title (default `Season N`), small-league minimum (default: the
  previous season's), start date (default: today). Save validates, writes `config/seasons` in a
  transaction (re-reading the document, so a concurrent create cannot reuse N) and bumps
  `meta/state`.
- «Delete» on the newest Firestore season when it has no games (checked with a `games` query
  just before the write); confirm in page, no browser dialog.

**`/host/`** — the default season = the newest Firestore season whose `startDate` ≤ today,
read live from `config/seasons` on load; fallback the build-time default as today.

## Tests

- Dart: validation (shared fixture with TS); merge with the JSON list (append, clash → error,
  order); `fetchSeasons` (valid, missing, malformed); prefetch writes a merged config and the new
  seasons' games; `parsedConfigProvider` live → cache → none; an empty Firestore season is
  dropped from the loaded configs.
- TS: next-season defaults (id, title, min games), validation fixture, delete allowed only for
  the newest empty season, `/host/` default season by start date.
- Rules: admin create/update; non-admin and signed-out denied; extra keys, wrong
  `updatedAt`/author, oversized list denied; delete denied.

## Out of scope

- Editing a season after creation (title, min games) — later if needed.
- Moving seasons 0–31 to Firestore.
- Season start/end dates driving the season's bounds.

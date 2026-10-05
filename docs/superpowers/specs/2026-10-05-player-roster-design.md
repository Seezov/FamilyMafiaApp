# Player roster — design

Date: 2026-10-05
Status: approved in chat, awaiting written-spec review

## Goal

Move the club's player list (the sheet tab «Змінні», column «Гравці», and the repo file
`assets/raw/players.json`) to Firestore so admins edit it on the site: add players, manage
nicknames, rename and merge. The site, the app and the `/host/` form all read the same list,
so a new player or a glued alias shows up everywhere without a commit or an APK release.

The other «Змінні» lists (roles, seats, results, penalties, bonuses) are already fixed in the
`/host/` form; hosts stay in `hosts/{email}` (console). Neither is in scope.

## How it works today (verified 2026-10-05)

- `assets/raw/players.json`: 609 entries `{id: 0, displayName, nicknames?}`, including junk
  names (`"/"`, `"17"`, blanks); 12 players have nicknames (25 in total).
- The app numbers players by **list position** (`Player.copyWith(id: index)`), and
  `PlayerResolver` maps a raw game name to the first player whose `displayName` or nickname
  equals it, ignoring case (`putIfAbsent` — a name claimed twice silently goes to the first).
- Readers: the app (`rootBundle` → `appDataProvider`), the site export (same providers),
  `/host/` autocomplete (`assets/raw/players.json` read at build time), the profile matcher
  (`site/scripts/fetch-profiles.ts`, by display name).
- Player URLs (`/players/<slug>/`) and profile keys (`profiles/{lowercased, URI-encoded name}`)
  derive from the display name.

## Decisions

| Topic | Decision |
|---|---|
| Who edits | Admins (`hosts/{email}.admin == true`), Google sign-in, as on `/debug/`. |
| Storage | One document `config/players` holding the ordered list. Every edit is one atomic write; order (= the app's ids) is kept; one REST read for the app and the build. |
| Readers | Site build, app (REST + cache, bundled file as fallback), `/host/` (live read). |
| History | One-time import of `assets/raw/players.json`, junk included, duplicate entries dropped (see Validation), so every stat stays the same. |
| Rename | Old name becomes a nickname automatically (old sheets still resolve). URL changes; the page warns. |
| Merge A → B | A's name and nicknames become B's nicknames; A is removed from the list. |
| Profiles | Not moved. The profile matcher resolves `profile.player` through the roster, so a profile made under an old name follows the rename/merge. |
| Unresolved names | The edit page lists game names that resolve to no player, with «attach to…». |
| Publishing | Every save also sets `meta/state.updatedAt`; `games-watch.yml` rebuilds within the hour. |

## Data

`config/players`:

```
{
  players: [ { name: string, nicknames: [string] } ],   // ordered; ≤ 2000
  updatedAt: timestamp, updatedBy: uid, updatedByEmail: string
}
```

`name` is the display name. `nicknames` may be empty. New players are appended. A merge
removes an entry, which shifts later positions; positions are not stored anywhere, they only
order slug collision suffixes (an existing deferred minor).

## Validation (shared rules, Dart and TS)

A roster is valid when:
- every `name` and nickname is a string (`name` may be any non-null string, so the imported
  junk stays valid; the editor itself refuses names shorter than 2 characters after trim);
- no lower-cased name or nickname belongs to two different entries (a nickname equal to its
  own entry's name is allowed — the import has those);
- at most 2000 entries, nickname lists at most 50.

The build fails on an invalid roster, naming the clashing names. The editor refuses to save
one. Today's file has exactly two clashes — `Night` and `Volus` each appear as two entries.
The second entry of each is unreachable (the resolver and the export already pick the first),
so the import drops an entry whose every name is already claimed by an earlier one; stats do
not change. A test pins this on the real file.

## Rules (`firestore.rules`)

```
match /config/players {
  allow read: if true;
  allow create, update: if isAdmin()
    && keys hasOnly ['players', 'updatedAt', 'updatedBy', 'updatedByEmail']
    && players is list && players.size() <= 2000
    && updatedAt == request.time && updatedBy == uid && updatedByEmail == email();
  allow delete: if false;
}
```

Entry contents are validated by the build and the editor (rules cannot loop over a list).

## Build

- `tool/prefetch_seasons.dart` reads `config/players` over REST, validates it, and writes
  `assets/prefetched/players.json` in today's format (`[{id: 0, displayName, nicknames}]`),
  so every existing reader keeps working. A missing document is allowed (the bundled file is
  used; needed until the import is done); a malformed one fails the build.
- The export and the app use the snapshot when it exists, else `assets/raw/players.json`.
- `site/data/players.json` gains each player's `aliases` (lower-cased name + nicknames);
  `fetch-profiles.ts` matches `profile.player` against them instead of the display name only.
  Two profiles landing on one player: the one whose `player` equals the display name wins,
  the other is reported as a warning.
- The export writes `site/data/unresolved.json`: names from games that resolve to no player
  (junk filtered as on `/host/`), with game count and last season, most games first.

## App

`playersJsonProvider`: `FirestoreService.fetchPlayers` (REST) → validated → cached via
`SeasonCacheService`; on failure the cached copy; else `assets/raw/players.json`. Same shape as
`clubConfigProvider`.

## Pages

**`/players/edit/`** — admin page, signed out → sign-in button. Reads `config/players` live.
- Search box filtering by name or nickname; list rows show name + nicknames.
- Actions per player: add/remove nickname, rename, merge into… (pick target by search).
  Rename and merge show what changes (URL, profile follows) and confirm in page, no browser
  dialog.
- «Add player» (name, optional nicknames).
- «Unresolved names» section from `unresolved.json` (as of the last build): each name with its
  game count and «attach to…» (adds it as a nickname) or «new player».
- Every action validates the whole roster first and saves in one transaction that also
  bumps `meta/state`; a concurrent edit makes the transaction retry on fresh data.
- «Import from players.json» shown only while `config/players` does not exist; reads the file
  from the repo's raw GitHub URL and writes it.

**`/host/`** — the autocomplete and alias check read `config/players` live (fallback: the
build-time list baked into the page, as today).

**`/account/`** — the claim list still comes from `site/data/players.json` (build time).

## Tests

- Dart: roster validation (clash, limits, junk allowed); the current `assets/raw/players.json`
  is valid; prefetch writes the snapshot / accepts a missing doc / fails on a malformed one;
  `playersJsonProvider` live → cache → bundled fallback.
- Dart: export with the snapshot equals export with the bundled file (same input).
- Dart: `unresolved.json` lists a name missing from the roster and not a resolved one.
- TS: editor operations — add, nickname add/remove, rename keeps old name as nickname, merge
  moves names and removes the source, every clash refused; shared validation cases fixture
  run by both Dart and TS.
- TS: profile matching through aliases; two profiles on one player.
- Rules: admin create/update; non-admin and signed-out denied; extra keys, wrong
  `updatedAt`/`updatedBy`, oversized list denied; delete denied.

## Out of scope

- Hosts and admins editing (still in the Firestore console).
- The other «Змінні» lists.
- Stable player ids independent of list order.
- Season creation — a separate spec next.

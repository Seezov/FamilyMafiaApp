# Tournaments and thresholds in Firestore — design

Date: 2026-10-05
Status: approved in chat, awaiting written-spec review

## Goal

Admins edit the club's tournament list (minicaps, maxicaps, marathons, …) and a finished season's
main-league threshold on `/debug/` with their Google sign-in, like `/host/`, instead of a GitHub
token. Any host with `admin: true` in `hosts/{email}` can save; everyone else sees the page
read-only.

## Decisions

| Topic | Decision |
|---|---|
| Who edits | Admins only (`hosts/{email}.admin == true`). |
| Storage | One Firestore document `config/club`. |
| Source of truth | Firestore for tournaments, rejected candidates and final thresholds. Seasons stay in `remote_config.json` on GitHub. |
| Migration | One-time script copies the current `tournaments` + `rejectedCandidates` from `remote_config.json` into `config/club`; then both blocks are removed from `remote_config.json` and `assets/raw/season_config.json`. |
| Concurrency | `/debug/` saves in a Firestore transaction: re-reads the doc, re-applies the pending ops, writes. Same op semantics as today (`applyOps`), so a stale page still fails loudly on a vanished entry. |
| Publishing | A save also sets `meta/state.updatedAt`; `games-watch.yml` rebuilds the site within the hour. |
| Thresholds | Admin's final value lives in `config/club.gameLimits` (`{"31": 41}`), not in the season config. The threshold plan (`2026-10-05-dynamic-threshold*`) is revised to read and write there. |

## Document

`config/club`:

```
{
  tournaments: [{ season, type, name, games, date?, status?, podium: [string] }],   // as today
  rejectedCandidates: [string],
  gameLimits: { "<seasonId>": int },
  updatedAt: timestamp, updatedBy: uid, updatedByEmail: string
}
```

Order of `tournaments` is kept as today (by season, then date; `insertAt`).

## Rules (`firestore.rules`)

```
match /config/club {
  allow read: if true;
  allow write: if isAdmin()
    && request.resource.data.keys().hasOnly(['tournaments', 'rejectedCandidates', 'gameLimits',
         'updatedAt', 'updatedBy', 'updatedByEmail'])
    && request.resource.data.tournaments is list
    && request.resource.data.rejectedCandidates is list
    && request.resource.data.gameLimits is map
    && request.resource.data.updatedAt == request.time
    && request.resource.data.updatedBy == request.auth.uid
    && request.resource.data.updatedByEmail == email();
}
```

`meta/state` already lets hosts (admins are hosts) bump `updatedAt`. Tests in
`firebase/rules-test/`: anyone reads; admin writes; non-admin host, player and anonymous are
denied; extra keys or a forged `updatedBy` are denied.

## Readers

- **App** (`parsedConfigProvider` / `tournamentsProvider`): `FirestoreService.fetchClubConfig()`
  reads `config/club` over REST (public, no key) and caches it like the remote config. Order:
  live → cached → empty list (no bundled copy after the migration; the app works without
  tournaments, they only add awards).
- **Site build**: `tool/prefetch_seasons.dart` also snapshots `config/club` to
  `assets/prefetched/club_config.json`; the export reads it through the same parser. A failed
  fetch fails the prefetch (no partial deploy), as for seasons.
- One parser, `ClubConfig.fromFirestoreJson` (decoded fields → tournaments, rejected, gameLimits),
  used by both.

## `/debug/`

- The «GitHub access» panel becomes «Sign in with Google» (the Firebase setup `/host/` uses,
  `site/src/lib/hosting/firebase-config.ts`). Signed in as an admin → Save enabled; otherwise
  read-only with the reason («Sign in» / «Not an admin»).
- The page loads the live `config/club` with the Firebase SDK (replaces `loadLive` from GitHub).
- Save: transaction on `config/club` applying the pending ops, then `meta/state.updatedAt`;
  status line «Saved. The site rebuilds within an hour (Actions → Run workflow for now).»
- `rewriteConfig`, `describe`, `site/src/lib/github.ts` and the GitHub token storage are removed
  (and their tests); `applyOps`, `normalize`, `entryKey` stay.

## Migration

When `config/club` doesn't exist and an admin is signed in, `/debug/` offers «Import from the
config file»: it writes the build's tournaments and rejected candidates (the JSON blocks, 1:1)
into `config/club` with empty `gameLimits`. No tokens or scripts.

Order of rollout: rules published → page deployed → admin imports → JSON blocks removed in the
same push that switches the readers.

## Error handling

- `config/club` missing (before import): app and build use the JSON's tournaments if present,
  else none; `/debug/` shows the import button to admins.
- A transaction conflict retries once (Firestore does this), then shows «Not saved: …».
- Prefetch: `config/club` 404 is not an error until the JSON blocks are removed; after that the
  build requires it.

## Testing

- Rules tests (above).
- Dart: `ClubConfig.fromFirestoreJson` on a fixture; `tournamentsProvider` with live / cached /
  missing; prefetch writes `club_config.json` (fake Dio).
- Site: `applyOps` tests stay; the import maps the JSON blocks 1:1 (vitest).
- Manual: admin signs in on `/debug/`, confirms a detected entry, sees it in Firestore and on the
  site after the rebuild; a non-admin host cannot save.

## Out of scope

- Moving the season list to Firestore (season creation is a separate item).
- Instant rebuild on save (needs a GitHub token or a backend).

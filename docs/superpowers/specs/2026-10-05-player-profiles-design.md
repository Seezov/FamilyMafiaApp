# Player profiles on the site — design

Date: 2026-10-05
Status: approved in chat, awaiting written-spec review

## Goal

Club players sign in on the site with Google, claim their player from the list, and — once an
admin approves the claim — choose an avatar and the nickname the site shows for them.

## Decisions

| Topic | Decision |
|---|---|
| Scope | Site only. The Flutter app is unchanged. |
| Auth | Google sign-in (Firebase Auth), the same as `/host/` |
| Linking | One account ↔ one player. A claim is pending until an admin approves it. |
| Nickname | Display-only. Stats, games and `/host/` keep the sheet name. |
| Moderation | No approval for nick/avatar changes; an admin can reset them or unlink the account |
| Avatar storage | Square WebP 256×256 made in the browser, stored as a data URL in Firestore (Spark plan has no Storage) |
| Freshness | Applied at build time. The hourly games-watch rebuild picks up changes (≤ 1 h). |
| Admin | Existing `hosts/{email}.admin == true` |

## Data model (Firestore)

### `claims/{uid}` — private

```
{ player: string,        // sheet name as in players.json
  playerKey: string,     // playerKey(player), see below
  email: string,         // == auth email
  googleName: string,
  status: 'pending' | 'approved' | 'rejected',
  createdAt: timestamp,
  decidedBy?: string,    // admin email
  decidedAt?: timestamp }
```

### `profiles/{playerKey}` — public

```
{ player: string, uid: string,
  nick?: string,         // 2..24 chars after trim
  avatar?: string,       // 'data:image/webp;base64,…', ≤ 140 000 chars (~100 KB)
  updatedAt: timestamp }
```

`uid` is public; that is acceptable (a Firebase uid grants nothing by itself), but the build
never copies it into `dist` (see Build).

### `playerKey(name)`

`encodeURIComponent(name.trim().toLowerCase())`. Deterministic, a valid document id (no `/`),
case-insensitive like the app's `PlayerResolver`. Slugs are not used: they depend on
`players.json` order.

## Security rules

Added to `firestore.rules`; existing helpers `signedIn()`, `email()`, `isAdmin()` reused.

**claims/{uid}**
- read: owner (`uid == request.auth.uid`) or admin (admin may list).
- create / update by owner: when the stored claim is absent or not `approved`; new data has only
  `player, playerKey, email, googleName, status, createdAt`; `status == 'pending'`;
  `email == email()`; `createdAt == request.time`; `player`/`playerKey` non-empty strings.
- delete by owner: only when not `approved` (cancel a claim).
- update by admin: only `status, decidedBy, decidedAt` change; `status in ['approved','rejected']`;
  `decidedBy == email()`; `decidedAt == request.time`.
- delete by admin: allowed (used by unlink).

**profiles/{key}**
- read: everyone.
- create: admin only, and `getAfter(claims/{data.uid}).status == 'approved'` with
  `getAfter(...).playerKey == key` and `.player == data.player`. So a profile only appears in the
  same batch that approves the claim. A second profile for the same player fails because the
  document already exists (create, not update).
- update by owner (`resource.data.uid == request.auth.uid`): `affectedKeys().hasOnly(['nick','avatar','updatedAt'])`,
  nick and avatar valid or absent, `updatedAt == request.time`.
- update by admin: may remove `nick` / `avatar` (reset) and set `updatedAt`; `player`/`uid` unchanged.
- delete: admin only (unlink, batched with deleting the claim).

**meta/state**: write also allowed for a signed-in user whose `claims/{uid}.status == 'approved'`
(same shape check as today), so profile edits trigger the hourly rebuild.

Rules are published by the owner via the Firebase console (as before).

## Pages

### `/account/` — «Мій профіль»

One page, five states driven by auth + the user's claim + their profile:

1. **Signed out** — «Увійти через Google».
2. **No claim** — searchable player list from the build's `players.json` (name, games, last
   season). Players with a profile are shown as taken and cannot be picked. «Це я» creates the
   claim.
3. **Pending** — «Чекає схвалення адміна», «Скасувати» (deletes the claim).
4. **Rejected** — notice and the player list again (re-claim overwrites the claim).
5. **Approved — settings**
   - Nick field, hint «порожньо — показувати ім'я з таблиць». Client checks: 2–24 chars; not equal
     (case-insensitive) to another player's sheet name or another profile's nick.
   - Avatar: file input → square crop (centre + zoom slider) → preview → WebP 256×256 via canvas.
     If the data URL exceeds the limit, retry at lower quality (0.85 → 0.7 → 0.5), else error.
     «Видалити» removes the avatar.
   - «Зберегти» writes the profile and bumps `meta/state`; note «на сайті з'явиться протягом години».
   - Link to the player's public page.

### `/account/admin/` — admins only

- **Claims** (pending first): email, Google name, chosen player, date. «Схвалити» runs one batch:
  claim → `approved` + create `profiles/{playerKey}` `{player, uid, updatedAt}` + bump `meta/state`.
  Disabled with «вже прив'язаний» when that profile exists. «Відхилити» sets `rejected`.
- **Linked profiles**: player, nick, avatar; «Скинути нік», «Скинути аватарку», «Відв'язати»
  (batch: delete profile + delete claim + bump `meta/state`).
- Non-admins see «Немає доступу».

### Header

A small account item next to the theme toggle: «Увійти» → `/account/`; after sign-in, the user's
avatar (or initial). Firebase loads on static pages only if a `localStorage` flag says the visitor
has signed in before (set on sign-in, cleared on sign-out, wrapped in try/catch); otherwise the
item is a plain link and pages stay JS-free as today. The admin link shows in the account page,
not the header.

## Public display (build time)

`site/src/lib/profiles.ts` loads `data/profiles.json` and exposes `displayName(sheetName)` and
`avatarFor(sheetName)` (lookup by `playerKey`). Used wherever a player name is rendered: season
tables (main + small), records, tournaments, overview, players list, player page, OG titles.

- Player page: heading = nick + large avatar; under it «у таблицях: <sheet name>» when a nick is set.
- Tables/lists: nick; a 20 px avatar next to the name when one exists, nothing otherwise.
- Players-list search matches both nick and sheet name.
- `/host/` keeps sheet names (games are recorded under them).
- Player URLs (`/players/<slug>/`) stay derived from the sheet name; a nick never changes a URL.

## Build

New `site/scripts/fetch-profiles.mjs`, run before `astro build` (`npm run build`):

- Reads all `profiles` via the public Firestore REST API (paged).
- Keeps a profile only if its `player` is in `players.json`; drops a nick that collides
  (case-insensitive) with another sheet name or an earlier nick, logging a warning.
- Writes `data/profiles.json` `{ [playerKey]: { nick?, avatar?: 'avatars/<hash>.webp' } }` and
  the decoded images to `public/avatars/<sha1-8>.webp`. No uid, no email.
- On a network/API error: warns, writes an empty `profiles.json`, build continues.

`check-dist.mjs` additionally fails on an email-like string or `"uid"` in `dist`.

## Error handling

- Claiming a taken player: not offered; if it races, the admin's batch fails on create and the
  admin page shows «вже прив'язаний».
- Unreadable image: «Не вдалося прочитати зображення».
- Write failure/offline: message shown, form input kept.
- A profiled player later excluded from stats: the build ignores that profile.

## Testing

- **Rules** (`firebase/rules-test`, emulator): own-uid-only claims; no reading/writing others'
  claims; only admin approves/rejects; profile only in the approval batch; second profile for a
  player denied; owner edits only nick/avatar within limits; admin reset/unlink; approved
  owner may bump `meta/state`, a pending one may not.
- **Unit (vitest)**: `playerKey`, nick validation incl. collisions, `displayName`/`avatarFor`,
  `fetch-profiles` REST parsing + collision dropping, crop geometry.
- **check-dist**: no emails/uids in `dist`.
- **Manual**: full flow on the live site — second account claims, admin approves, nick and
  avatar change, appear after the rebuild, admin resets and unlinks.

## Out of scope

The Flutter app; live (client-side) name updates; renaming players in stats; notifications to
admins about new claims (admins check `/account/admin/`).

# Stats Site Redesign (stage 2) — Design

**Date:** 2026-10-04
**Status:** approved in chat, awaiting spec review
**Supersedes:** the Flutter Web approach of `2026-09-25-web-site-design.md` (stage 1)

## Goal

https://seezov.github.io/FamilyMafiaApp/ should look and feel like a modern
statistics site, not like the phone app running in a browser. Today the web is
the Flutter UI squeezed into a 600 px column (`lib/widgets/web_frame.dart`) with
a bottom `NavigationBar`, Material cards and chips.

**Audience:** both desktop and phone, desktop-led. Links are still mostly shared
in Telegram, so phones must work well, but the layout is designed wide first.

**Success criteria**

1. The site is a static, pre-rendered website: native scrolling, selectable
   text, Ctrl+F, browser Back, no loading spinner.
2. Every view has its own URL (season + league, player, records category with
   filters) and can be shared.
3. Everything the web shows today (Season, Players + profile, Dashboard,
   Records) is on the site, with the same numbers as the app.
4. Dark, data-dense look (HLTV / esports-stats style) per the visual system
   below, usable from 390 px to 1440 px+.
5. Deploy triggers are unchanged (push to `feature/flutter_migration`, nightly,
   manual) and the build contains no API key.
6. Telegram link previews show per-page title and description.

**Out of scope**

- Changes to the Flutter app's UI. The app stays as it is.
- Chat (Gemini) and Debug: still app-only.
- Light theme / theme toggle.
- Removing the `web/` folder and `kIsWeb` branches from the app.
- Moving the stats logic that lives inside Riverpod providers into pure
  services (possible later without changing the JSON shape).

## Approach

A separate static site (Astro) rendered from JSON that the existing Dart code
computes. Alternatives rejected in chat:

- **A — web-only shell inside Flutter.** Keeps one codebase but remains a
  canvas app (~3 MB JS, spinner, non-native scroll, no text search).
- **C — reskin only.** Still "our app on a dark background".

The Dart code stays the single source of truth for every number; only the
presentation is new.

## Architecture

```
Google Sheets ──prefetch──▶ assets/prefetched/*.json ─┐
assets/raw/*.json ────────────────────────────────────┤
                                                      ▼
                tool/export_site_data.dart (flutter test harness,
                ProviderContainer reading the app's providers)
                                                      │
                                                      ▼
                         site/public/data/*.json
                                                      │
                                                      ▼
                       site/ (Astro, static build) ──▶ site/dist ──▶ GitHub Pages
```

### Data export

`tool/export_site_data.dart` runs under `flutter test` so `rootBundle` and
assets work without decoupling Flutter imports (`role.dart`, `tournament.dart`,
`season_data_service.dart`, `season_loader.dart`). It:

1. Creates a `ProviderContainer` with the overrides the web uses today
   (asset-backed `SeasonCacheService`, no Sheets API key, config read from the
   snapshot).
2. Awaits `appDataProvider` (all seasons loaded, percentiles recomputed).
3. Iterates seasons × leagues and players, setting the selection providers
   (`selectedSeasonProvider`, `selectedLeagueProvider`, selected player) and
   reading the same providers the screens read.
4. Writes JSON to `site/public/data/` (output dir overridable for tests).

Files (raw numbers plus minimal labels; formatting is done by the site):

| File | Contents | Source providers / services |
|---|---|---|
| `index.json` | seasons list (id, title, gameLimit, smallLeagueMinGames, latest flag); club overview; role WR; role leaderboards (top 10, ≥140 rating games); protocol guesses; seasons table rows | `loadedSeasonConfigsProvider`, `clubOverviewProvider`, `roleWinRateProvider`, `topPlayersByRoleProvider`, `protocolGuessLeaderboardProvider`, `seasonRowsProvider` |
| `season/<id>.json` | per league (`main`, `small`): summary (games, players, city/mafia WR), league counts, tournaments; awards with full rankings (main only); extra stats (most games, top ПУ %, hosts, no-host count; host stats main only); tournament type counts; player ratings rows with every field of the expanded card incl. per-role W/G/± and season-29+ fields | `seasonSummaryProvider`, `seasonLeagueCountsProvider`, `tournamentsProvider`, `currentSeasonStatsProvider`, `seasonExtraStatsProvider` |
| `players.json` | directory: id, slug, name, initials, games, all-time WR, seasons played, latest rating | `playersListProvider`, `playerStatsMapProvider`, `seasonGamesProvider`, `latestSeasonRatingProvider` |
| `player/<slug>.json` | hero; accomplishments; league per season; games per season; role games/wins/percentile; first kill; best moves | `playerAccomplishmentsProvider`, `playerLeaguesProvider`, `seasonGamesProvider`, `playerRoleGamesProvider`, `playerRoleWinsProvider`, `roleWinRatePercentilesProvider`, `playerFirstKillProvider`, `playerBestMovesProvider` |
| `records.json` | every category × role × period × scope, pre-ranked, with scope label | `services/stats/records.dart`, `win_streaks.dart` via the records providers |

The award "avg pts" / "record" strings currently formatted inside
`season_header_card.dart` / `season_stats_card.dart` are exported as the raw
numbers they are built from (wins, games, points); the site formats them.

**Slugs:** transliterated `displayName` (Ukrainian → Latin, lowercase,
hyphenated). On collision, append `-<id>` to every colliding player. Junk
entries (blank, `.`, `..`, `/`, empty `nicknames`) are excluded exactly as
`playersListProvider` excludes them.

## Site

`site/` — Astro, static output, `base: '/FamilyMafiaApp/'`, TypeScript.
Pages ship near-zero JS; interactive parts are small islands (vanilla TS):
sortable tables, player search, records filters, chart tooltips.

### Pages

Top nav on every page: logo · Season · Players · Overview · Records · player
search box.

| URL | Page |
|---|---|
| `/` | redirect (meta refresh + link) to the latest season |
| `/season/<id>/`, `/season/<id>/small/` | Season page |
| `/players/` | Player directory |
| `/players/<slug>/` | Player profile |
| `/overview/` | All-time club dashboard (formerly Dashboard) |
| `/records/<category>/` | Records; category ∈ mvp, roles, games, hosts, pu, penalties, streaks. Role / period / scope as query params, updated via `history.replaceState` |

**Season page.** A season picker dropdown and a Main / Small segmented control,
both plain links. A KPI strip: Games, Players, City WR, Mafia WR, Main / Small
counts, Tournaments. Desktop: two columns. Left (≈⅔) is the full player ratings
table with every field visible and sortable, and per-role columns grouped under
"By role". Right holds the awards (six winners, each with a top-5 mini table;
main league only) and the season stats as compact ranked lists, plus tournament
pills. Phone: single column, the table shows Rank / Player / G / WR / Rating,
and tapping a row expands the rest. Empty-league messages match the app's.

**Players.** A sortable table (name, games, WR, seasons, latest rating) with
instant search filter, sorted by games by default.

**Player profile.** Header: initials, name, three KPIs (WR, rating, seasons),
and accomplishment badges in one row. Grid: games-by-season chart with a
league colour band per season (merging today's Leagues and Games by Season
sections), role bars with a "Top X%" marker, first kill, and best moves.

**Overview.** Club KPIs; role WR rings; four role leaderboards side by side;
protocol guesses; the full seasons table (wide on desktop, horizontal scroll on
phones; no "Expand" button).

**Records.** Category tabs, filter pills, and one ranked table with the scope
label.

Removed relative to the app: loading spinner, background-loading banner,
tap-to-expand awards, bottom nav.

### Visual system

- **Theme:** dark only. Background `#0B0D10`, panel `#12161B`, border
  `#1F252D`, text `#E6E8EB`, muted `#8B95A1`. Flat panels, 1 px border, 8 px
  radius, no shadows.
- **Colour carries data:** brand accent mafia red `#E5484D` (logo, active nav,
  focus). City blue `#4C9AFF` vs mafia red wherever city/mafia appear. Role hues
  from `role.dart`, re-tuned for contrast on dark (≥ 4.5:1 for text). Win rate
  is coloured text (green ≥ 50, amber ≥ 35, red below) plus a thin inline bar in
  tables. Top-3 ranks get a gold / silver / bronze marker.
- **Type (Google Fonts, Cyrillic):** Unbounded for logo, page titles and big
  KPI numbers; Inter for everything else; `tabular-nums` on all numbers. Small
  uppercase letter-spaced labels above KPIs.
- **Tables:** 32 px rows (40 px on touch), sticky header and first column,
  right-aligned numbers, row hover, highlighted sort column, tooltips on
  abbreviated headers (CI, ПУ, доп).
- **Charts:** hand-written SVG Astro components (no chart library): line with
  league band, rings, bars, distribution; hover tooltips.
- **Layout:** max width 1280 px, 12-column grid, 24 px gutters. Below 900 px
  one column, 16 px gutter, compact top bar with a horizontally scrolling tab
  row (no hamburger). No horizontal page scroll; wide tables scroll inside
  their own container.
- **Telegram / OG:** per-page `og:title` / `og:description` (e.g. "Sasha — 61%
  WR · 312 games"), one site-wide dark OG image.

## Build and deploy

`.github/workflows/web.yml`, same triggers and Pages deploy job:

1. Checkout `feature/flutter_migration`, Flutter setup, empty
   `assets/.env.json`, `flutter pub get`, prefetch remote seasons (unchanged).
2. `flutter test` (existing suite + export tests).
3. `flutter test tool/export_site_data.dart` → `site/public/data/`.
4. Node 22: `npm ci && npm run build` in `site/`.
5. Guards on `site/dist`: no `AIza`; `index.html` exists; a page exists for
   every player in `players.json`; internal link check passes.
6. Upload `site/dist` as the Pages artifact.

`flutter build web` is removed from CI. Push both `feature/flutter_migration`
and `master`.

## Testing

- **Export (Dart, `flutter test`):** from a small fixture season, check JSON
  shape per file; season ratings equal `currentSeasonStatsProvider` for both
  leagues; slugs unique and stable; junk players excluded.
- **Site:** `astro check`; Vitest for formatters, slugging helpers on the site
  side and sortable-table logic; post-build internal link check.
- **Visual:** run the built site locally and walk every page in Chrome at
  1440 px and 390 px; spot-check several numbers against the app.

## Risks

- **Reading providers headlessly** may hit an assumption about a widget binding
  (e.g. `compute`). It is low risk because they already run under
  `flutter test`. The first implementation task is a spike proving the export
  can await `appDataProvider` and write one file.
- **Slugs change when a player is renamed** in `players.json`; old links 404.
  Accepted.
- **Two places to touch for a new stat** (export + site). Accepted trade-off.

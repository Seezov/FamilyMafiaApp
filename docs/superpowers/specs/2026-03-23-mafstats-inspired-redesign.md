# MafStats-Inspired UI Redesign

**Date:** 2026-03-23
**Status:** Approved
**Scope:** Full visual overhaul of all 4 screens — HomeScreen, PlayersScreen, PlayerProfileScreen, DashboardScreen

## Design Direction

MafStats-inspired with our own polish. Adopt MafStats' design patterns (hero cards, stat tiles, section cards, role colors) but with slightly different measurements (16px card radius vs 20px) to give the app its own identity.

---

## 1. Color System

### Role Colors (from MafStats)

| Role     | Primary   | Light     |
|----------|-----------|-----------|
| Civilian | `#E53935` | `#FFEBEE` |
| Mafia    | `#616161` | `#F5F5F5` |
| Sheriff  | `#00BCD4` | `#E0F7FA` |
| Don      | `#212121` | `#EEEEEE` |

### Hero Card Gradients

| Screen         | From      | To        |
|----------------|-----------|-----------|
| HomeScreen     | `#E53935` | `#B71C1C` |
| PlayerProfile  | `#1565C0` | `#0D47A1` |
| Dashboard      | `#00897B` | `#004D40` |

Direction: top-left to bottom-right (135deg).
Shadow: role color with alpha 0.35, blur 18, offset(0, 6).

### Global

- **Scaffold background:** White (`#FFFFFF`) — replaces Material 3 surface
- **Seed color:** `#E53935` (red) — replaces `Colors.deepPurple`
- **Material 3:** Keep `useMaterial3: true`
- **Text colors:** `Colors.black87` primary, `Colors.black54` secondary, `Colors.black38` tertiary
- **Navigation bar:** Keep 3 tabs (Season, Players, Dashboard), keep frosted glass effect (backdrop blur 16, surface alpha 0.82)

### Win Rate Pills (unchanged logic)

- Green (`#2E7D32` on `rgba(76,175,80,0.12)`) — win rate >= 50%
- Amber (`#F57F17` on `rgba(255,193,7,0.12)`) — win rate 35-50%
- Red (`#C62828` on `rgba(229,57,53,0.12)`) — win rate < 35%

### Medal Colors (unchanged)

- 1st: Gold `#FFD700`
- 2nd: Silver `#B0BEC5`
- 3rd: Bronze `#BF8970`
- 4th+: Gray `#EEEEEE`

---

## 2. Shared Components

### Section Card

- Background: white
- Border radius: 16px
- Padding: `fromLTRB(18, 16, 18, 16)`
- Shadow: `BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: Offset(0, 4))`
- Title: 15px, fontWeight w700, `Colors.black87`

### Hero Card

- Border radius: 16px
- Padding: 20px all
- Background: `LinearGradient` (135deg, see gradient table)
- Shadow: gradient start color with alpha 0.35, blur 18, offset(0, 6)
- Label: white with 0.7 opacity, 9px, w600, uppercase, letter-spacing 1
- Title: white, 18-20px, w800, letter-spacing 0.2
- Stat tiles inside: `rgba(255,255,255,0.15)` background, 10px radius, white text

### Stat Tile

- Border radius: 12px
- Padding: `symmetric(horizontal: 12, vertical: 14)`
- Value: 22px, w700
- Label: 11px, `Colors.black54`
- Variants:
  - Neutral: `Colors.grey.shade50` background
  - Positive: `rgba(76,175,80,0.09)` background, value in `#2E7D32`
  - Negative: `rgba(229,57,53,0.09)` background, value in `#C62828`

### Season Chips

- Selected: `#E53935` background, white text
- Unselected: `#FFEBEE` background, `#E53935` text
- Border radius: 16px
- Font: 10px, w600 (selected), w500 (unselected)

### Game Limit Chips

- Same styling as season chips but smaller: `padding(3px, 9px)`, 8px font
- Placed inline in the Player Ratings section card header (right-aligned)
- If chips overflow the header row, they scroll horizontally (wrap in a small `SingleChildScrollView(scrollDirection: Axis.horizontal)`)

---

## 3. HomeScreen

### Layout (top to bottom)

1. **Pinned app bar** — frosted glass, "Family Mafia" title
2. **Season chips** — horizontal scrollable row
3. **Hero card** — red gradient with season summary
   - 4 stat tiles: Games, Players, City WR, Mafia WR
   - **Data source:** Games count = sum of `gamesPlayed` across all `RatingPlayerStats` / 10 (10 players per game). Players count = `playerStats.length`. City WR / Mafia WR = computed from `GamesRepository.games` for the selected season: count games where `cityWon == true` vs `false`. Add a new `seasonSummaryProvider` in `home_providers.dart`.
4. **Season Awards card** — white section card
   - 2x3 grid of award badges (MVP, Best Sheriff, Best Civilian, Best Mafia, Best Don, Most Killed)
   - Each badge: Material Icon in a 32x32 rounded-square container (8px radius) with role-tinted background + label + winner name
   - Icons: `star` (MVP), `local_police` (Sheriff), `person` (Civilian), `theater_comedy` (Mafia — changed from `thumb_down`), `gps_fixed` (Don), `close` (Most Killed)
5. **Player Ratings card** — white section card
   - Header: "Player Ratings" title + inline game limit chips (right-aligned)
   - Player rows (not individual cards — rows within the section card):
     - Rank circle (medal colors for 1-3, gray for 4+)
     - Player name
     - Win rate pill
     - Rating coefficient in `#E53935` (replaces purple)
   - Tap to expand: expanded stats use stat tile grid (neutral/positive/negative variants)
   - Keep existing expanded stats content (games, add pts, penalty, by-role breakdown, etc.)

### What Changes from Current

- Header card → gradient hero card with stat tiles
- Award badges → separate section card with Material Icons in rounded containers
- Game limit picker → inline chips in ratings card header
- Player list → rows inside a section card (not individual Card widgets)
- Purple accent → red accent throughout
- White scaffold background

---

## 4. PlayersScreen

### Layout

1. **Pinned app bar** — frosted glass, "Players" title
2. **Search bar** — pill-shaped (24px radius), `#F5F5F5` fill, search icon prefix, clear button suffix
3. **3-column grid** — `GridView.builder`
   - Spacing: 8px horizontal, 8px vertical
   - Card design:
     - White background, 16px radius, subtle shadow
     - `CircleAvatar` (radius 22, 44px) with hash-based color (keep existing 8-color palette)
     - Player name (11px, w600, 2 lines max, ellipsis)
     - Game count ("X games", 10px, `Colors.black54`)
     - Win rate pill below
   - **Data source:** Add a `playerStatsMapProvider` in `players_providers.dart` that aggregates total games and overall win rate per player across all loaded seasons from `RatingRepository`. The `filteredPlayersProvider` result is enriched with stats at the widget level by looking up each player in this map.

### What Changes from Current

- Card elevation 2 → shadow (0.05, blur 12)
- No stats → game count + win rate pill added
- Aspect ratio: adjusted to fit new content (approximately 0.75 instead of 0.85)
- White scaffold background

---

## 5. PlayerProfileScreen

### Layout

1. **App bar** — frosted glass, back arrow + player name
2. **Hero card** — blue gradient
   - Avatar (56px, semi-transparent white bg with border) + name + "X games played"
   - 3 stat tiles: Win Rate, Rating, Seasons (count of distinct seasons the player appears in, derived from `playerAccomplishmentsProvider`)
3. **Accomplishments card** — white section card
   - Title + count pill (`#FFEBEE` bg, `#E53935` text)
   - 4-column grid of badge tiles
   - Each: colored background + border, Material Icon, count, label
   - Colors: Gold (1st), Silver (2nd), Bronze (3rd), Red (MVP), Cyan (Sheriff), Gray (Mafia), Dark (Don)
4. **Season Chart card** — white section card
   - Keep existing custom painted bar chart
   - Restyle bars with red gradient coloring (light → dark red based on game count)
   - Keep interactive tap/pan selection with tooltip
5. **Role Distribution card** — white section card
   - Per-role horizontal bars with role colors
   - Bar background: role light variant
   - Bar fill: role primary color
   - Right side: count (pct%) + WR pill
   - Role color dot indicator (8px circle)
6. **First Kill card** — white section card, restyle with stat tiles
7. **Best Moves card** — white section card
   - Keep existing black-count card design
   - Restyle with 16px radius, borders, grayscale progression

### What Changes from Current

- Plain header → blue gradient hero card with stat tiles
- All sections → white section cards with consistent shadow
- Role bars → MafStats role colors (red civilian, gray mafia, cyan sheriff, dark don)
- Season chart bars → red gradient coloring
- Accomplishment badges → role-tinted backgrounds with borders

---

## 6. DashboardScreen

### Layout (top to bottom)

1. **Pinned app bar** — frosted glass, "Dashboard" title
2. **Hero card** — teal gradient
   - "All Time" label, "Club Overview" title
   - 4 stat tiles: Seasons, Games, Players, City WR
   - **Data source:** Add a new `clubOverviewProvider` in `dashboard_providers.dart`. Seasons = `loadedSeasonConfigsProvider.length`. Games = sum all games across all seasons from `GamesRepository`. Players = unique player names across all seasons from `PlayersRepository`. City WR = count `cityWon == true` / total games across all seasons.
3. **Win Rate by Role card** — white section card
   - 4 circular progress rings (conic gradient) with role colors
   - Each: ring with percentage inside, role name below
   - **Data source:** Add a `roleWinRateProvider` in `dashboard_providers.dart`. Iterate all games across all seasons, count wins/losses per role. This is a new view-layer provider, not a service change.
4. **Protocol Guesses leaderboard** — white section card (purple theme `#7B1FA2`)
   - Header: psychology icon + "Protocol Guesses" + column labels (Acc, G)
   - Rows: rank (medal colors) + name + accuracy% + game count
5. **Best Civilian leaderboard** — white section card (red theme `#E53935`)
   - Header: person icon + "Best Civilian" + column labels (WR, G)
   - Rows: rank + name + win rate% + game count
6. **Best Sheriff leaderboard** — white section card (cyan theme `#00BCD4`)
7. **Best Mafia leaderboard** — white section card (gray theme `#616161`)
8. **Best Don leaderboard** — white section card (dark theme `#212121`)

### What Changes from Current

- Added teal hero card with club-wide stats
- Added win rate rings section (new)
- Protocol Guesses moved to top (before role leaderboards)
- Leaderboards restyled: role-colored header bars with icons
- Info dialog for rules stays, triggered from app bar or hero card
- White scaffold background

---

## 7. Files to Modify

### Theme / Global
- `lib/main.dart` — seed color, scaffold bg, nav bar styling

### New Shared Widgets (create new files)
- `lib/widgets/hero_card.dart` — reusable gradient hero card
- `lib/widgets/section_card.dart` — reusable white section card with shadow
- `lib/widgets/stat_tile.dart` — reusable stat tile (neutral/positive/negative)

### New Providers (view-layer only)
- `lib/screens/home/src/home_providers.dart` — `seasonSummaryProvider` (games, players, city/mafia WR for selected season)
- `lib/screens/dashboard/dashboard_providers.dart` — `clubOverviewProvider`, `roleWinRateProvider`
- `lib/screens/players/players_providers.dart` — add `playerStatsMapProvider` (all-time games + win rate per player)

### HomeScreen
- `lib/screens/home/home_screen.dart` — restructure layout
- `lib/screens/home/src/season_header_card.dart` → hero card + awards card
- `lib/screens/home/src/game_limit_picker.dart` → inline chips
- `lib/screens/home/src/player_card.dart` — restyle rows + expanded stats
- `lib/screens/home/src/season_chips.dart` — red color scheme

### PlayersScreen
- `lib/screens/players/players_screen.dart` — 2-col → stays 3-col, add stats, restyle cards

### PlayerProfileScreen
- `lib/screens/players/player_profile_screen.dart` — add hero card
- `lib/screens/players/src/accomplishments_section.dart` — restyle badges
- `lib/screens/players/src/season_chart.dart` — red gradient bars
- `lib/screens/players/src/role_distribution_section.dart` — MafStats role colors
- `lib/screens/players/src/first_kill_section.dart` — section card wrapper
- `lib/screens/players/src/best_moves_section.dart` — restyle cards

### DashboardScreen
- `lib/screens/dashboard/dashboard_screen.dart` — full restructure: hero card + rings + reordered leaderboards

### Enums
- `lib/enums/role.dart` — add color properties (primary + light variant) to Role enum

---

## 8. What Stays the Same

- **Data flow** — all repositories, services, and models unchanged. New screen-level providers may be added to derive view data (e.g., `seasonSummaryProvider`, `clubOverviewProvider`, `roleWinRateProvider`, `playerStatsMapProvider`)
- **Navigation** — 3 tabs, IndexedStack, frosted glass nav bar
- **Expandable player cards** — tap-to-expand behavior in HomeScreen
- **Season chart** — custom painter logic, interactive selection
- **Search** — PlayersScreen search functionality
- **Loading states** — skeleton shimmer, background loading banner
- **Avatar colors** — hash-based 8-color palette for player initials
- **Best moves** — grayscale progression cards
- **Business logic** — no changes to any service, repository, or model
- **Animations** — preserve existing expand/collapse on player cards, chart interactions. No new animations added.
- **Dark mode** — not supported; design hardcodes white scaffold and specific colors
- **PlayersScreen and DashboardScreen** — convert from `SafeArea` + `Column` to `CustomScrollView` with `SliverAppBar` for frosted glass consistency

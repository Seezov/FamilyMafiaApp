# MafStats-Inspired UI Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Full visual overhaul of all 4 screens adopting MafStats' design language (role-based colors, gradient hero cards, section cards, stat tiles) while keeping existing data flow and business logic intact.

**Architecture:** UI-layer only changes. New shared widgets (`HeroCard`, `SectionCard`, `StatTile`) provide the design system. New view-layer providers compute aggregate stats for hero cards. All existing services, repositories, and models stay untouched.

**Tech Stack:** Flutter 3.x, Material 3, Riverpod 2.6.1

**Spec:** `docs/superpowers/specs/2026-03-23-mafstats-inspired-redesign.md`

---

## File Structure

### New Files (create)
- `lib/widgets/hero_card.dart` — Reusable gradient hero card with stat tiles
- `lib/widgets/section_card.dart` — Reusable white section card with shadow
- `lib/widgets/stat_tile.dart` — Reusable stat tile (neutral/positive/negative variants)

### Modified Files
- `lib/enums/role.dart` (26 lines) — Add `color` and `lightColor` properties to Role enum
- `lib/main.dart` (86 lines) — Change seed color to red, scaffold bg to white
- `lib/screens/home/home_screen.dart` (124 lines) — Restructure layout with hero card + section cards
- `lib/screens/home/home_providers.dart` (45 lines) — Add `seasonSummaryProvider`
- `lib/screens/home/src/season_chips.dart` (34 lines) — Red color scheme
- `lib/screens/home/src/season_header_card.dart` (137 lines) — Rewrite as hero card + awards section card
- `lib/screens/home/src/game_limit_picker.dart` (59 lines) — Rewrite as inline chips in ratings header
- `lib/screens/home/src/player_card.dart` (362 lines) — Restyle as rows in section card + restyled expanded stats
- `lib/screens/players/players_screen.dart` (218 lines) — Restyle grid cards, add stats, convert to CustomScrollView
- `lib/screens/players/players_providers.dart` (237 lines) — Add `playerStatsMapProvider`
- `lib/screens/players/player_profile_screen.dart` (142 lines) — Add hero card, wrap sections in section cards
- `lib/screens/players/src/accomplishments_section.dart` (141 lines) — Restyle badges with role-tinted backgrounds
- `lib/screens/players/src/role_distribution_section.dart` (161 lines) — MafStats role colors
- `lib/screens/players/src/season_chart.dart` (119 lines) — Section card wrapper
- `lib/screens/players/season_chart_painter.dart` (135 lines) — Red gradient bar colors
- `lib/screens/players/src/first_kill_section.dart` (100 lines) — Section card wrapper + stat tiles
- `lib/screens/players/src/best_moves_section.dart` (137 lines) — Section card wrapper + restyle
- `lib/screens/dashboard/dashboard_screen.dart` (425 lines) — Full restructure with hero card + rings + reordered leaderboards
- `lib/screens/dashboard/dashboard_providers.dart` (129 lines) — Add `clubOverviewProvider`, `roleWinRateProvider`

---

## Task 1: Role Colors + Theme Foundation

**Files:**
- Modify: `lib/enums/role.dart`
- Modify: `lib/main.dart`

- [ ] **Step 1: Add color properties to Role enum**

In `lib/enums/role.dart`, add `color` and `lightColor` to each enum value:

```dart
import 'package:flutter/material.dart';

enum Role {
  sheriff(sheetValues: ['Шериф'], isBlack: false, chanceToDraw: 0.1,
      color: Color(0xFF00BCD4), lightColor: Color(0xFFE0F7FA)),
  don(sheetValues: ['Дон'], isBlack: true, chanceToDraw: 0.1,
      color: Color(0xFF212121), lightColor: Color(0xFFEEEEEE)),
  civilian(sheetValues: ['Мирный', 'Мирний'], isBlack: false, chanceToDraw: 0.6,
      color: Color(0xFFE53935), lightColor: Color(0xFFFFEBEE)),
  mafia(sheetValues: ['Мафия', 'Мафія'], isBlack: true, chanceToDraw: 0.2,
      color: Color(0xFF616161), lightColor: Color(0xFFF5F5F5));

  const Role({
    required this.sheetValues,
    required this.isBlack,
    required this.chanceToDraw,
    required this.color,
    required this.lightColor,
  });

  final List<String> sheetValues;
  final bool isBlack;
  final double chanceToDraw;
  final Color color;
  final Color lightColor;

  String get sheetValue => sheetValues.last;

  static Role? findByValue(String value) {
    for (final role in values) {
      if (role.sheetValues.contains(value)) return role;
    }
    return null;
  }
}
```

- [ ] **Step 2: Update theme in main.dart**

Change seed color and scaffold background:

```dart
// In MyApp.build(), change:
colorSchemeSeed: Colors.deepPurple,
// To:
colorSchemeSeed: const Color(0xFFE53935),
scaffoldBackgroundColor: Colors.white,
```

- [ ] **Step 3: Verify app builds and runs**

Run: `flutter analyze`
Expected: No new errors

- [ ] **Step 4: Commit**

```bash
git add lib/enums/role.dart lib/main.dart
git commit -m "feat: add role colors and switch theme to red seed"
```

---

## Task 2: Shared Widgets (HeroCard, SectionCard, StatTile)

**Files:**
- Create: `lib/widgets/hero_card.dart`
- Create: `lib/widgets/section_card.dart`
- Create: `lib/widgets/stat_tile.dart`

- [ ] **Step 1: Create SectionCard widget**

`lib/widgets/section_card.dart`:

```dart
import 'package:flutter/material.dart';

class SectionCard extends StatelessWidget {
  const SectionCard({super.key, this.title, this.trailing, required this.child});

  final String? title;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: title == null
            ? child
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title!,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xDD000000), // black87
                          ),
                        ),
                      ),
                      if (trailing != null) trailing!,
                    ],
                  ),
                  const SizedBox(height: 12),
                  child,
                ],
              ),
      ),
    );
  }
}
```

- [ ] **Step 2: Create HeroCard widget**

`lib/widgets/hero_card.dart`:

```dart
import 'package:flutter/material.dart';

class HeroCard extends StatelessWidget {
  const HeroCard({
    super.key,
    required this.label,
    required this.title,
    required this.gradientStart,
    required this.gradientEnd,
    required this.statTiles,
  });

  final String label;
  final String title;
  final Color gradientStart;
  final Color gradientEnd;
  final List<HeroStatTile> statTiles;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [gradientStart, gradientEnd],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gradientStart.withValues(alpha:0.35),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: TextStyle(
                color: Colors.white.withValues(alpha:0.7),
                fontSize: 9,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: statTiles
                  .expand((tile) => [
                        Expanded(child: tile),
                        if (tile != statTiles.last) const SizedBox(width: 8),
                      ])
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class HeroStatTile extends StatelessWidget {
  const HeroStatTile({super.key, required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha:0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha:0.7),
              fontSize: 8,
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: Create StatTile widget**

`lib/widgets/stat_tile.dart`:

```dart
import 'package:flutter/material.dart';

enum StatTileVariant { neutral, positive, negative }

class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.value,
    required this.label,
    this.variant = StatTileVariant.neutral,
  });

  final String value;
  final String label;
  final StatTileVariant variant;

  @override
  Widget build(BuildContext context) {
    final (bg, valueColor) = switch (variant) {
      StatTileVariant.neutral => (
          Colors.grey.shade50,
          const Color(0xDD000000),
        ),
      StatTileVariant.positive => (
          const Color(0xFF4CAF50).withValues(alpha:0.09),
          const Color(0xFF2E7D32),
        ),
      StatTileVariant.negative => (
          const Color(0xFFE53935).withValues(alpha:0.09),
          const Color(0xFFC62828),
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: valueColor,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.black.withValues(alpha:0.54),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Verify build**

Run: `flutter analyze`
Expected: No errors (widgets not yet used but should compile)

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/hero_card.dart lib/widgets/section_card.dart lib/widgets/stat_tile.dart
git commit -m "feat: add shared design system widgets (HeroCard, SectionCard, StatTile)"
```

---

## Task 3: HomeScreen — Providers + Hero Card + Season Chips

**Files:**
- Modify: `lib/screens/home/home_providers.dart`
- Modify: `lib/screens/home/src/season_chips.dart`
- Modify: `lib/screens/home/home_screen.dart`
- Modify: `lib/screens/home/src/season_header_card.dart`

- [ ] **Step 1: Add seasonSummaryProvider to home_providers.dart**

Add import to top of `lib/screens/home/home_providers.dart`:
```dart
import 'package:family_mafia_app/repositories/games_repository.dart';
```

Then append provider. Note: `gamesRepositoryProvider` exposes a flat `List<Game>` — filter by `seasonId`:

```dart
/// Aggregate stats for the season hero card.
final seasonSummaryProvider = Provider<({int games, int players, double cityWR, double mafiaWR})?>((ref) {
  final season = ref.watch(selectedSeasonProvider);
  if (season == null) return null;
  final allGames = ref.watch(gamesRepositoryProvider)
      .where((g) => g.seasonId == season.id)
      .toList();
  if (allGames.isEmpty) return null;

  int cityWins = 0;
  int mafiaWins = 0;
  int decided = 0;
  for (final g in allGames) {
    if (g.cityWon == true) {
      cityWins++;
      decided++;
    } else if (g.cityWon == false) {
      mafiaWins++;
      decided++;
    }
  }

  final uniquePlayers = <String>{};
  for (final g in allGames) {
    uniquePlayers.addAll(g.players.where((p) => p.isNotEmpty));
  }

  return (
    games: allGames.length,
    players: uniquePlayers.length,
    cityWR: decided > 0 ? cityWins / decided : 0.0,
    mafiaWR: decided > 0 ? mafiaWins / decided : 0.0,
  );
});
```

- [ ] **Step 2: Restyle season chips with red colors**

In `lib/screens/home/src/season_chips.dart`, update the `ChoiceChip` styling to use red:

- Selected: `backgroundColor: const Color(0xFFE53935)`, `selectedColor: const Color(0xFFE53935)`, white label
- Unselected: `backgroundColor: const Color(0xFFFFEBEE)`, label color `Color(0xFFE53935)`

Use `ChoiceChip`'s `selectedColor`, `backgroundColor`, `labelStyle`, and `side: BorderSide.none` properties. Set `shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))`. Font sizes: 10px w600 (selected), 10px w500 (unselected).

- [ ] **Step 3: Rewrite season_header_card.dart as hero card + awards card**

Replace `_SeasonHeaderCard` in `lib/screens/home/src/season_header_card.dart` with two widgets:

1. `_SeasonHeroCard` — uses `HeroCard` with red gradient, watches `seasonSummaryProvider` for stats (Games, Players, City WR %, Mafia WR %)
2. `_SeasonAwardsCard` — uses `SectionCard` with title "Season Awards", 2×3 grid of award badges. **Data source:** receives `SeasonStats` from parent (same as current `_SeasonHeaderCard`), accesses `stats.mvpPlayerId`, `stats.bestSheriffPlayerId`, etc. for winner names.

Award badges use these icon/color combos:
- MVP: `Icons.star`, `Color(0xFFF9A825)` on `Color(0xFFFFF8E1)`
- Sheriff: `Icons.local_police`, `Color(0xFF00BCD4)` on `Color(0xFFE0F7FA)`
- Civilian: `Icons.person`, `Color(0xFFE53935)` on `Color(0xFFFFEBEE)`
- Mafia: `Icons.theater_comedy`, `Color(0xFF616161)` on `Color(0xFFF5F5F5)`
- Don: `Icons.gps_fixed`, `Color(0xFF212121)` on `Color(0xFFEEEEEE)`
- Most Killed: `Icons.close`, `Color(0xFFFF9800)` on `Color(0xFFFFF3E0)`

- [ ] **Step 4: Update home_screen.dart to use new hero + awards cards**

Replace `_SeasonHeaderCard` usage in the sliver list with `_SeasonHeroCard` followed by `_SeasonAwardsCard`, with `SizedBox(height: 10)` spacing between them.

Also add required imports to `home_screen.dart` (these will be visible to all `part` files):
```dart
import 'package:family_mafia_app/widgets/hero_card.dart';
import 'package:family_mafia_app/widgets/section_card.dart';
import 'package:family_mafia_app/widgets/stat_tile.dart';
```

- [ ] **Step 5: Verify build and visual**

Run: `flutter analyze`
Expected: No errors

- [ ] **Step 6: Commit**

```bash
git add lib/screens/home/
git commit -m "feat: HomeScreen hero card + awards card + red season chips"
```

---

## Task 4: HomeScreen — Player Ratings Card with Inline Chips

**Files:**
- Modify: `lib/screens/home/src/game_limit_picker.dart`
- Modify: `lib/screens/home/src/player_card.dart`
- Modify: `lib/screens/home/home_screen.dart`

- [ ] **Step 1: Convert game_limit_picker to inline chips widget**

Rewrite `_GameLimitPicker` in `lib/screens/home/src/game_limit_picker.dart` to be a compact row of small chips (no wrapping card). It should return a `SingleChildScrollView(scrollDirection: Axis.horizontal)` containing a `Row` of styled chips matching spec: red selected (`#E53935` bg, white text), light red unselected (`#FFEBEE` bg, `#E53935` text), padding `(3, 9)`, font 8px.

- [ ] **Step 2: Restructure home_screen.dart player list into a section card**

In `lib/screens/home/home_screen.dart`:
- Remove the separate `_GameLimitPicker` sliver
- Wrap the player list in a `SectionCard` with title "Player Ratings" and `trailing:` set to the inline game limit chips widget
- Player items render as rows inside the card (not individual Card widgets). Use `SliverToBoxAdapter` containing the `SectionCard`, with player rows as a `Column` inside.

- [ ] **Step 3: Restyle player_card.dart rows**

In `lib/screens/home/src/player_card.dart`:
- Remove the outer `Card` widget — the row is now inside the parent `SectionCard`
- Add `border-bottom: 1px solid #f5f5f5` (via `Container` with `BoxDecoration` border) between rows
- Rating coefficient color: change from `colorScheme.primary` to `const Color(0xFFE53935)`
- Remove the expand chevron icon (expand on tap of entire row)
- Restyle `_ExpandedStats` to use `StatTile` widgets in a grid layout (4 per row) with `Wrap` or `GridView`
- Keep `_RoleBreakdown` but update role colors to use `Role.color` and `Role.lightColor`

- [ ] **Step 4: Verify build**

Run: `flutter analyze`
Expected: No errors

- [ ] **Step 5: Commit**

```bash
git add lib/screens/home/
git commit -m "feat: HomeScreen player ratings section card with inline limit chips"
```

---

## Task 5: PlayersScreen — Stats + Restyle

**Files:**
- Modify: `lib/screens/players/players_providers.dart`
- Modify: `lib/screens/players/players_screen.dart`

- [ ] **Step 1: Add playerStatsMapProvider**

Append to `lib/screens/players/players_providers.dart`:

Note: `ref.watch(ratingRepositoryProvider)` returns `Map<int, List<RatingPlayerStats>>` directly (the state IS the map).

```dart
/// All-time game count + win rate per player for PlayersScreen grid cards.
final playerStatsMapProvider = Provider<Map<String, ({int games, double winRate})>>((ref) {
  final allStats = ref.watch(ratingRepositoryProvider); // Map<int, List<RatingPlayerStats>>
  final aggregated = <String, ({int totalGames, int totalWins})>{};

  for (final seasonStats in allStats.values) {
    for (final ps in seasonStats) {
      final prev = aggregated[ps.name];
      final games = ps.gamesPlayed;
      final wins = ps.wins;
      if (prev != null) {
        aggregated[ps.name] = (totalGames: prev.totalGames + games, totalWins: prev.totalWins + wins);
      } else {
        aggregated[ps.name] = (totalGames: games, totalWins: wins);
      }
    }
  }

  return aggregated.map((name, v) => MapEntry(
    name,
    (games: v.totalGames, winRate: v.totalGames > 0 ? v.totalWins / v.totalGames : 0.0),
  ));
});
```

- [ ] **Step 2: Convert PlayersScreen to CustomScrollView with SliverAppBar**

In `lib/screens/players/players_screen.dart`:
- Replace `SafeArea` + `Column` with `CustomScrollView`
- Add pinned `SliverAppBar` with frosted glass (same pattern as HomeScreen): `flexibleSpace: ClipRect(child: BackdropFilter(...))`, `backgroundColor: colorScheme.surface.withValues(alpha: 0.82)`, `title: Text('Players')`
- Move search bar into a `SliverToBoxAdapter`
- Move grid into `SliverPadding` + `SliverGrid`

- [ ] **Step 3: Restyle grid cards with stats**

Update `_PlayerCard` in `players_screen.dart`:
- Replace `Card(elevation: 2)` with `Container` using `BoxDecoration(color: Colors.white, borderRadius: 16, boxShadow: [shadow(0.05, blur 12, offset 4)])`
- Add game count text ("X games", fontSize 10, `Colors.black54`) below name
- Add win rate pill below game count: colored background + bold percentage
- Watch `playerStatsMapProvider` to get games and win rate for each player
- Keep avatar at radius 22 (44px), hash-based colors, existing initials logic
- Change `childAspectRatio` from `0.85` to `0.75` to fit the added content

- [ ] **Step 4: Restyle search bar**

Update `_SearchBar`:
- Keep pill shape but ensure `borderRadius: 24` and `fillColor: Color(0xFFF5F5F5)` (hardcoded instead of theme-derived)

- [ ] **Step 5: Verify build**

Run: `flutter analyze`
Expected: No errors

- [ ] **Step 6: Commit**

```bash
git add lib/screens/players/players_screen.dart lib/screens/players/players_providers.dart
git commit -m "feat: PlayersScreen restyle with stats and frosted app bar"
```

---

## Task 6: PlayerProfileScreen — Hero Card + Section Wrappers

**Files:**
- Modify: `lib/screens/players/player_profile_screen.dart`
- Modify: `lib/screens/players/src/accomplishments_section.dart`
- Modify: `lib/screens/players/src/role_distribution_section.dart`
- Modify: `lib/screens/players/src/season_chart.dart`
- Modify: `lib/screens/players/season_chart_painter.dart`
- Modify: `lib/screens/players/src/first_kill_section.dart`
- Modify: `lib/screens/players/src/best_moves_section.dart`

- [ ] **Step 1: Add hero card to player_profile_screen.dart**

First add required imports to `lib/screens/players/player_profile_screen.dart`:
```dart
import 'package:family_mafia_app/widgets/hero_card.dart';
import 'package:family_mafia_app/widgets/section_card.dart';
import 'package:family_mafia_app/widgets/stat_tile.dart';
```

Replace the header section (CircleAvatar + name + games) with a blue gradient `HeroCard`:
- `gradientStart: Color(0xFF1565C0)`, `gradientEnd: Color(0xFF0D47A1)`
- Label: "{totalGames} games played"
- Title: player.displayName
- Add avatar to the left of title (custom layout — may need to use `HeroCard` child slot or build inline)
- 3 stat tiles: Win Rate (from all-time stats), Rating (latest season or best), Seasons (count of seasons from `seasonGamesProvider`)

Also convert to `CustomScrollView` with frosted `SliverAppBar` if not already.

- [ ] **Step 2: Restyle accomplishments_section.dart**

In `lib/screens/players/src/accomplishments_section.dart`:
- Wrap in `SectionCard` with title "Accomplishments" and trailing count pill (`Container` with `#FFEBEE` bg, `#E53935` text)
- Restyle badges: each uses role-tinted background + border (1px, color.withValues(alpha:0.3)) + Material Icon
- Colors: Gold `#FFF8E1` (1st), Silver `#ECEFF1` (2nd), Bronze `#EFEBE9` (3rd), Red `#FFEBEE` (MVP), Cyan `#E0F7FA` (Sheriff), Gray `#F5F5F5` (Mafia), Dark `#EEEEEE` (Don)

- [ ] **Step 3: Wrap season chart in SectionCard and restyle bars**

In `lib/screens/players/src/season_chart.dart`:
- Wrap in `SectionCard` with title "Games by Season"

In `lib/screens/players/season_chart_painter.dart`:
- Change bar/line colors from blue/red to red gradient
- Use `Color(0xFFE53935)` for bars/lines, `Color(0xFFFFCDD2)` for unselected/lighter bars
- Selected highlight: `Color(0xFFB71C1C)` (darker red)

- [ ] **Step 4: Restyle role_distribution_section.dart**

In `lib/screens/players/src/role_distribution_section.dart`:
- Wrap in `SectionCard` with title "Role Distribution"
- Update role colors to use `Role.color` and `Role.lightColor` for bars and dots
- Remove hardcoded color constants, use `Role.findByValue()` or match by role enum

- [ ] **Step 5: Restyle first_kill_section and best_moves_section**

In `lib/screens/players/src/first_kill_section.dart`:
- Wrap in `SectionCard` with title "First Kill"
- Restyle `_StatCard`s to use 16px radius, white bg, subtle border

In `lib/screens/players/src/best_moves_section.dart`:
- Wrap in `SectionCard` with title "Best Moves" (move title into section card header)
- Keep info icon as trailing widget in section card
- Restyle `_BlackCard` with 16px radius

- [ ] **Step 6: Verify build**

Run: `flutter analyze`
Expected: No errors

- [ ] **Step 7: Commit**

```bash
git add lib/screens/players/
git commit -m "feat: PlayerProfileScreen hero card + section card wrappers + role colors"
```

---

## Task 7: DashboardScreen — Full Restructure

**Files:**
- Modify: `lib/screens/dashboard/dashboard_providers.dart`
- Modify: `lib/screens/dashboard/dashboard_screen.dart`

- [ ] **Step 1: Add clubOverviewProvider and roleWinRateProvider**

Add imports to top of `lib/screens/dashboard/dashboard_providers.dart`:
```dart
import 'package:family_mafia_app/enums/role.dart';
import 'package:family_mafia_app/repositories/games_repository.dart';
```

Note: `gamesRepositoryProvider` returns a flat `List<Game>` — iterate directly, no season keying needed.

```dart
/// All-time club stats for the dashboard hero card.
final clubOverviewProvider = Provider<({int seasons, int games, int players, double cityWR})>((ref) {
  final configs = ref.watch(loadedSeasonConfigsProvider);
  final allGames = ref.watch(gamesRepositoryProvider); // flat List<Game>

  int cityWins = 0;
  int decided = 0;
  final uniquePlayers = <String>{};

  for (final g in allGames) {
    if (g.cityWon == true) { cityWins++; decided++; }
    else if (g.cityWon == false) { decided++; }
    uniquePlayers.addAll(g.players.where((p) => p.isNotEmpty));
  }

  return (
    seasons: configs.length,
    games: allGames.length,
    players: uniquePlayers.length,
    cityWR: decided > 0 ? cityWins / decided : 0.0,
  );
});

/// All-time win rate per role for the circular rings.
final roleWinRateProvider = Provider<Map<Role, double>>((ref) {
  final allGames = ref.watch(gamesRepositoryProvider); // flat List<Game>
  final winsPerRole = <Role, int>{};
  final gamesPerRole = <Role, int>{};

  for (final g in allGames) {
    if (g.cityWon == null) continue;
    for (int i = 0; i < g.players.length; i++) {
      final role = Role.findByValue(g.roles[i]);
      if (role == null) continue;
      gamesPerRole[role] = (gamesPerRole[role] ?? 0) + 1;
      final won = role.isBlack ? !g.cityWon! : g.cityWon!;
      if (won) winsPerRole[role] = (winsPerRole[role] ?? 0) + 1;
    }
  }

  return {
    for (final role in Role.values)
      role: gamesPerRole[role] != null && gamesPerRole[role]! > 0
          ? (winsPerRole[role] ?? 0) / gamesPerRole[role]!
          : 0.0,
  };
});
```

- [ ] **Step 2: Convert DashboardScreen to CustomScrollView with hero card**

Rewrite `lib/screens/dashboard/dashboard_screen.dart`:
- Replace `SafeArea` + `SingleChildScrollView` with `CustomScrollView`
- Add pinned frosted `SliverAppBar` with title "Dashboard" (keep info icon for rules dialog)
- Add teal `HeroCard` (gradientStart: `#00897B`, gradientEnd: `#004D40`) watching `clubOverviewProvider`
- 4 stat tiles: Seasons, Games (format with "k" if >1000), Players, City WR%

- [ ] **Step 3: Add Win Rate by Role rings section**

Below the hero card, add a `SectionCard` with title "Win Rate by Role" containing a `Row` of 4 circular progress indicators:
- Each uses `SizedBox(width: 52, height: 52)` with `CustomPaint` or `Stack` with `CircularProgressIndicator` to show the percentage ring
- Role color for filled portion, `Role.lightColor` for background
- Percentage text centered inside
- Role name below

Watch `roleWinRateProvider` for data.

- [ ] **Step 4: Reorder and restyle leaderboard cards**

Order: Protocol Guesses first, then Civilian, Sheriff, Mafia, Don.

Each leaderboard card uses `SectionCard` (no title — custom header instead):
- Header row inside card: tinted background (`role.color.withValues(alpha:0.08)`), role icon + title in role color + "WR"/"Acc" + "G" column labels
- Rows: rank number (medal colors for 1-3), player name, stat value (1st place in role color, rest black87), game count

**Icon changes from current code:** Mafia changes from `Icons.thumb_down` to `Icons.theater_comedy`. Protocol changes from `Icons.visibility` to `Icons.psychology`. Update the existing `_roleIcon` helper method if present.

Icons per leaderboard:
- Protocol: `Icons.psychology`, color `#7B1FA2`
- Civilian: `Icons.person`, color `#E53935`
- Sheriff: `Icons.local_police`, color `#00BCD4`
- Mafia: `Icons.theater_comedy`, color `#616161`
- Don: `Icons.gps_fixed`, color `#212121`

- [ ] **Step 5: Verify build**

Run: `flutter analyze`
Expected: No errors

- [ ] **Step 6: Commit**

```bash
git add lib/screens/dashboard/
git commit -m "feat: DashboardScreen hero card + role rings + restyled leaderboards"
```

---

## Task 8: Final Polish + Verification

**Files:**
- All modified files from Tasks 1-7

- [ ] **Step 1: Run full static analysis**

Run: `flutter analyze`
Expected: No errors or warnings related to our changes

- [ ] **Step 2: Run existing tests**

Run: `flutter test`
Expected: All tests pass (we changed no business logic)

- [ ] **Step 3: Visual smoke test**

Run on emulator/device: `flutter run`
Verify each screen:
- HomeScreen: red gradient hero card, awards with icons, red chips, player ratings in section card
- PlayersScreen: 3-col grid with stats, frosted app bar, search works
- PlayerProfileScreen: blue hero card, section card wrappers, role colors correct
- DashboardScreen: teal hero card, role rings, protocol guesses first, restyled leaderboards

- [ ] **Step 4: Fix any visual issues found**

Address spacing, overflow, color inconsistencies.

- [ ] **Step 5: Final commit**

```bash
git add -A
git commit -m "fix: polish redesign visual details"
```

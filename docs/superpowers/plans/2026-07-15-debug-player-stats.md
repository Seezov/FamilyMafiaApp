# Debug Player Stats Screen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Debug tab showing win rate by player slot (1–10) for a hardcoded player (Seezov), computed from rating games in the database.

**Architecture:** A pure, testable function computes per-slot stats from a `List<Game>`. A Riverpod `Provider` wraps it, reading `gamesRepositoryProvider` and passing the hardcoded player. A `ConsumerWidget` screen renders the results. The screen is added as a new destination in the `main.dart` `NavigationBar` + `IndexedStack`.

**Tech Stack:** Dart / Flutter, Riverpod 2.6.1, freezed `Game` model, flutter_test.

---

## File Structure

- Create `lib/screens/debug/debug_providers.dart` — hardcoded player constant, pure `winRateBySlot` function, `SlotWinRate` record typedef, `debugSlotWinRateProvider`.
- Create `lib/screens/debug/debug_screen.dart` — `DebugScreen` `ConsumerWidget` rendering totals header + 10 slot rows with bars.
- Modify `lib/main.dart` — add `DebugScreen()` to `_screens` and a `NavigationDestination` labelled "Debug".
- Create `test/screens/debug/debug_providers_test.dart` — unit tests for `winRateBySlot`.

---

### Task 1: Pure win-rate-by-slot function + provider

**Files:**
- Create: `lib/screens/debug/debug_providers.dart`
- Test: `test/screens/debug/debug_providers_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/screens/debug/debug_providers_test.dart`:

```dart
import 'package:family_mafia_app/models/game.dart';
import 'package:family_mafia_app/screens/debug/debug_providers.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds a minimal rating game. `players` are slot 0..n names, `roles`
/// parallel to players. `cityWon` null => non-rating game.
Game _game({
  required List<String> players,
  required List<String> roles,
  required bool? cityWon,
}) {
  return Game(
    seasonId: 5,
    players: players,
    roles: roles,
    cityWon: cityWon,
    firstKilled: 0,
    bestMovePoints: 0.0,
    bestMove: const [],
  );
}

// Roles used by Game.hasPlayerWon via Role.findByValue.
const _civ = 'Мирный';
const _maf = 'Мафия';

void main() {
  group('winRateBySlot', () {
    test('returns 10 slots numbered 1..10 in order', () {
      final result = winRateBySlot(const [], 'Seezov');
      expect(result.length, 10);
      expect(result.map((s) => s.slot).toList(),
          [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
    });

    test('empty games => zero played, zero winRate for every slot', () {
      final result = winRateBySlot(const [], 'Seezov');
      for (final s in result) {
        expect(s.played, 0);
        expect(s.wins, 0);
        expect(s.winRate, 0.0);
      }
    });

    test('counts played and wins in the correct slot', () {
      // Seezov in slot index 0 (slot 1), civilian, city won => win.
      final games = [
        _game(
          players: ['Seezov', 'B', 'C'],
          roles: [_civ, _maf, _civ],
          cityWon: true,
        ),
        // Seezov in slot index 0 again, civilian, city lost => loss.
        _game(
          players: ['Seezov', 'B', 'C'],
          roles: [_civ, _maf, _civ],
          cityWon: false,
        ),
      ];
      final result = winRateBySlot(games, 'Seezov');
      expect(result[0].slot, 1);
      expect(result[0].played, 2);
      expect(result[0].wins, 1);
      expect(result[0].winRate, 0.5);
      // Other slots untouched.
      expect(result[1].played, 0);
    });

    test('ignores non-rating games (cityWon == null)', () {
      final games = [
        _game(
          players: ['Seezov'],
          roles: [_civ],
          cityWon: null,
        ),
      ];
      final result = winRateBySlot(games, 'Seezov');
      expect(result[0].played, 0);
    });

    test('ignores games where the player is absent', () {
      final games = [
        _game(
          players: ['X', 'Y'],
          roles: [_civ, _maf],
          cityWon: true,
        ),
      ];
      final result = winRateBySlot(games, 'Seezov');
      for (final s in result) {
        expect(s.played, 0);
      }
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/screens/debug/debug_providers_test.dart`
Expected: FAIL — `debug_providers.dart` / `winRateBySlot` not defined.

- [ ] **Step 3: Write minimal implementation**

Create `lib/screens/debug/debug_providers.dart`:

```dart
import 'package:family_mafia_app/models/game.dart';
import 'package:family_mafia_app/repositories/games_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The player this debug screen reports on. Change here when inspecting
/// a different player.
const kDebugPlayer = 'Seezov';

/// Win-rate stats for a single player slot (1..10).
typedef SlotWinRate = ({int slot, int played, int wins, double winRate});

/// Computes win rate per player slot (slots 1..10) for [player] over the
/// rating games in [games] (games where `isRatingGame()` is true).
///
/// Slot index i (0..9) maps to displayed slot i + 1. Games where the player
/// is absent or in a slot >= 10 are skipped.
List<SlotWinRate> winRateBySlot(List<Game> games, String player) {
  final played = List<int>.filled(10, 0);
  final wins = List<int>.filled(10, 0);

  for (final game in games) {
    if (!game.isRatingGame()) continue;
    final idx = game.getPlayerSlot(player);
    if (idx < 0 || idx >= 10) continue;
    played[idx]++;
    if (game.hasPlayerWon(player)) wins[idx]++;
  }

  return [
    for (var i = 0; i < 10; i++)
      (
        slot: i + 1,
        played: played[i],
        wins: wins[i],
        winRate: played[i] == 0 ? 0.0 : wins[i] / played[i],
      ),
  ];
}

/// Per-slot win-rate stats for [kDebugPlayer], recomputed when games change.
final debugSlotWinRateProvider = Provider<List<SlotWinRate>>((ref) {
  final games = ref.watch(gamesRepositoryProvider);
  return winRateBySlot(games, kDebugPlayer);
});
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/screens/debug/debug_providers_test.dart`
Expected: PASS (all 5 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/screens/debug/debug_providers.dart test/screens/debug/debug_providers_test.dart
git commit -m "feat: add win-rate-by-slot computation for debug screen"
```

---

### Task 2: Debug screen widget

**Files:**
- Create: `lib/screens/debug/debug_screen.dart`

- [ ] **Step 1: Write the screen**

Create `lib/screens/debug/debug_screen.dart`:

```dart
import 'package:family_mafia_app/providers/app_providers.dart';
import 'package:family_mafia_app/screens/debug/debug_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DebugScreen extends ConsumerWidget {
  const DebugScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataState = ref.watch(appDataProvider);
    return dataState.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (_) => const _DebugContent(),
    );
  }
}

class _DebugContent extends ConsumerWidget {
  const _DebugContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slots = ref.watch(debugSlotWinRateProvider);
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    final totalPlayed = slots.fold<int>(0, (a, s) => a + s.played);
    final totalWins = slots.fold<int>(0, (a, s) => a + s.wins);
    final overallWr = totalPlayed == 0 ? 0.0 : totalWins / totalPlayed;

    return Scaffold(
      appBar: AppBar(title: Text('Debug · $kDebugPlayer')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          MediaQuery.paddingOf(context).bottom + 80,
        ),
        children: [
          Text('Win rate by slot', style: tt.titleMedium),
          const SizedBox(height: 4),
          Text(
            totalPlayed == 0
                ? 'No rating games found for $kDebugPlayer.'
                : 'Overall: $totalWins/$totalPlayed · '
                    '${(overallWr * 100).toStringAsFixed(1)}%',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          for (final s in slots) ...[
            _SlotRow(slot: s),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _SlotRow extends StatelessWidget {
  final SlotWinRate slot;
  const _SlotRow({required this.slot});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final hasGames = slot.played > 0;
    final pct = (slot.winRate * 100).toStringAsFixed(1);
    final color = hasGames ? cs.primary : cs.onSurfaceVariant;

    return Row(
      children: [
        SizedBox(
          width: 56,
          child: Text(
            'Slot ${slot.slot}',
            style: tt.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: hasGames ? null : cs.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: slot.winRate,
              minHeight: 8,
              backgroundColor: cs.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 88,
          child: Text(
            hasGames ? '${slot.wins}/${slot.played} · $pct%' : '—',
            textAlign: TextAlign.end,
            style: tt.bodySmall?.copyWith(
              color: hasGames ? null : cs.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `flutter analyze lib/screens/debug/debug_screen.dart`
Expected: No errors (info/warnings only, if any).

- [ ] **Step 3: Commit**

```bash
git add lib/screens/debug/debug_screen.dart
git commit -m "feat: add debug screen showing win rate by slot"
```

---

### Task 3: Wire Debug tab into navigation

**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 1: Add the import**

In `lib/main.dart`, add alongside the other screen imports:

```dart
import 'package:family_mafia_app/screens/debug/debug_screen.dart';
```

- [ ] **Step 2: Add screen to `_screens`**

Change the `_screens` list from:

```dart
  static const _screens = [
    HomeScreen(),
    PlayersScreen(),
    DashboardScreen(),
    ChatScreen(),
  ];
```

to:

```dart
  static const _screens = [
    HomeScreen(),
    PlayersScreen(),
    DashboardScreen(),
    ChatScreen(),
    DebugScreen(),
  ];
```

- [ ] **Step 3: Add the navigation destination**

In the `destinations:` list of `NavigationBar`, after the Chat destination, add:

```dart
              NavigationDestination(
                icon: Icon(Icons.bug_report_outlined),
                selectedIcon: Icon(Icons.bug_report),
                label: 'Debug',
              ),
```

- [ ] **Step 4: Verify it compiles**

Run: `flutter analyze lib/main.dart`
Expected: No errors.

- [ ] **Step 5: Commit**

```bash
git add lib/main.dart
git commit -m "feat: add Debug tab to bottom navigation"
```

---

### Task 4: Full verification

- [ ] **Step 1: Run analyzer**

Run: `flutter analyze`
Expected: No new errors introduced by the debug screen files.

- [ ] **Step 2: Run all tests**

Run: `flutter test`
Expected: PASS, including `test/screens/debug/debug_providers_test.dart`.

- [ ] **Step 3: Manual smoke test on emulator**

Run: `flutter run -d emulator-5554`
Verify: A "Debug" tab appears; tapping it shows "Debug · Seezov", an overall line, and 10 slot rows with bars/percentages (or "—" for empty slots).

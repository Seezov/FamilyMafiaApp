# Player Selector on Stats Screen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a searchable player selector to the stats screen so the user can pick a player to see their win-rate-by-slot, defaulting to global per-slot win rate across all players when none is selected.

**Architecture:** Two pure computation functions (`winRateBySlotGlobal`, `winRateBySlotForPlayer`) in `debug_providers.dart`, driven by a `selectedPlayerProvider` StateProvider. The `debugSlotWinRateProvider` picks global vs per-player. The screen adds a Flutter `Autocomplete<Player>` field sourced from `playersListProvider`; the AppBar title reflects the selection.

**Tech Stack:** Flutter, Dart, Riverpod, Material 3. Tests via `flutter test`.

---

### Task 1: Rework computation + selection provider

**Files:**
- Modify: `lib/screens/debug/debug_providers.dart` (full rewrite of logic)
- Test: `test/screens/debug/debug_providers_test.dart` (rewrite)

- [ ] **Step 1: Rewrite the test file**

Replace the entire contents of `test/screens/debug/debug_providers_test.dart` with:

```dart
import 'package:family_mafia_app/models/game.dart';
import 'package:family_mafia_app/models/player.dart';
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
  group('winRateBySlotForPlayer', () {
    final seezov = const Player(id: 1, displayName: 'Seezov');

    test('returns 10 slots numbered 1..10 in order', () {
      final result = winRateBySlotForPlayer(const [], seezov);
      expect(result.length, 10);
      expect(result.map((s) => s.slot).toList(),
          [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
    });

    test('empty games => zero played, zero winRate for every slot', () {
      final result = winRateBySlotForPlayer(const [], seezov);
      for (final s in result) {
        expect(s.played, 0);
        expect(s.wins, 0);
        expect(s.winRate, 0.0);
      }
    });

    test('counts played and wins in the correct slot', () {
      final games = [
        _game(players: ['Seezov', 'B', 'C'], roles: [_civ, _maf, _civ], cityWon: true),
        _game(players: ['Seezov', 'B', 'C'], roles: [_civ, _maf, _civ], cityWon: false),
      ];
      final result = winRateBySlotForPlayer(games, seezov);
      expect(result[0].slot, 1);
      expect(result[0].played, 2);
      expect(result[0].wins, 1);
      expect(result[0].winRate, 0.5);
      expect(result[1].played, 0);
    });

    test('ignores non-rating games (cityWon == null)', () {
      final games = [
        _game(players: ['Seezov'], roles: [_civ], cityWon: null),
      ];
      final result = winRateBySlotForPlayer(games, seezov);
      expect(result[0].played, 0);
    });

    test('ignores games where the player is absent', () {
      final games = [
        _game(players: ['X', 'Y'], roles: [_civ, _maf], cityWon: true),
      ];
      final result = winRateBySlotForPlayer(games, seezov);
      for (final s in result) {
        expect(s.played, 0);
      }
    });

    test('counts a mafia (black-role) win when city loses', () {
      final games = [
        _game(players: ['Seezov', 'B', 'C'], roles: [_maf, _civ, _civ], cityWon: false),
      ];
      final result = winRateBySlotForPlayer(games, seezov);
      expect(result[0].played, 1);
      expect(result[0].wins, 1);
      expect(result[0].winRate, 1.0);
    });

    test('matches a player via a secondary nickname', () {
      // Player displayName is "Seezov" but appears in games as "Seez".
      final player = const Player(id: 1, displayName: 'Seezov', nicknames: ['Seezov', 'Seez']);
      final games = [
        _game(players: ['A', 'Seez', 'C'], roles: [_civ, _civ, _maf], cityWon: true),
      ];
      final result = winRateBySlotForPlayer(games, player);
      // "Seez" is at slot index 1 (slot 2), civilian, city won => win.
      expect(result[1].slot, 2);
      expect(result[1].played, 1);
      expect(result[1].wins, 1);
    });
  });

  group('winRateBySlotGlobal', () {
    test('returns 10 slots numbered 1..10 in order', () {
      final result = winRateBySlotGlobal(const []);
      expect(result.map((s) => s.slot).toList(),
          [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
    });

    test('empty games => zeros', () {
      final result = winRateBySlotGlobal(const []);
      for (final s in result) {
        expect(s.played, 0);
        expect(s.wins, 0);
      }
    });

    test('counts every seat across rating games', () {
      final games = [
        // slot0 civ win, slot1 maf loss, slot2 civ win
        _game(players: ['A', 'B', 'C'], roles: [_civ, _maf, _civ], cityWon: true),
        // slot0 civ loss, slot1 maf win, slot2 civ loss
        _game(players: ['D', 'E', 'F'], roles: [_civ, _maf, _civ], cityWon: false),
      ];
      final result = winRateBySlotGlobal(games);
      expect(result[0].played, 2);
      expect(result[0].wins, 1); // A won, D lost
      expect(result[1].played, 2);
      expect(result[1].wins, 1); // B (maf) lost, E (maf) won
      expect(result[2].played, 2);
      expect(result[2].wins, 1); // C won, F lost
    });

    test('ignores non-rating games', () {
      final games = [
        _game(players: ['A', 'B'], roles: [_civ, _maf], cityWon: null),
      ];
      final result = winRateBySlotGlobal(games);
      for (final s in result) {
        expect(s.played, 0);
      }
    });
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd "C:/Users/user/AndroidStudioProjects/FamilyMafiaApp" && flutter test test/screens/debug/debug_providers_test.dart`
Expected: FAIL — `winRateBySlotForPlayer` / `winRateBySlotGlobal` are not defined.

- [ ] **Step 3: Rewrite `debug_providers.dart`**

Replace the entire contents of `lib/screens/debug/debug_providers.dart` with:

```dart
import 'package:family_mafia_app/models/game.dart';
import 'package:family_mafia_app/models/player.dart';
import 'package:family_mafia_app/repositories/games_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Win-rate stats for a single player slot (1..10).
typedef SlotWinRate = ({int slot, int played, int wins, double winRate});

/// Currently selected player on the stats screen. `null` => global stats.
final selectedPlayerProvider = StateProvider<Player?>((ref) => null);

List<SlotWinRate> _toSlots(List<int> played, List<int> wins) {
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

/// Per-slot win rate across ALL players over rating games. For each seat
/// index 0..9 with a non-empty name, counts the seat as played and a win
/// if that seat won.
List<SlotWinRate> winRateBySlotGlobal(List<Game> games) {
  final played = List<int>.filled(10, 0);
  final wins = List<int>.filled(10, 0);
  for (final game in games) {
    if (!game.isRatingGame()) continue;
    for (var i = 0; i < game.players.length && i < 10; i++) {
      final name = game.players[i];
      if (name.isEmpty) continue;
      played[i]++;
      if (game.hasPlayerWon(name)) wins[i]++;
    }
  }
  return _toSlots(played, wins);
}

/// Per-slot win rate for [player], matching any of the player's nicknames
/// (falling back to displayName) over the rating games in [games].
List<SlotWinRate> winRateBySlotForPlayer(List<Game> games, Player player) {
  final names = player.nicknames ?? [player.displayName];
  final played = List<int>.filled(10, 0);
  final wins = List<int>.filled(10, 0);
  for (final game in games) {
    if (!game.isRatingGame()) continue;
    String? matched;
    for (final n in names) {
      if (game.players.contains(n)) {
        matched = n;
        break;
      }
    }
    if (matched == null) continue;
    final idx = game.getPlayerSlot(matched);
    if (idx < 0 || idx >= 10) continue;
    played[idx]++;
    if (game.hasPlayerWon(matched)) wins[idx]++;
  }
  return _toSlots(played, wins);
}

/// Per-slot win-rate stats. Global when no player is selected, otherwise for
/// the selected player. Recomputed when games or selection change.
final debugSlotWinRateProvider = Provider<List<SlotWinRate>>((ref) {
  final games = ref.watch(gamesRepositoryProvider);
  final player = ref.watch(selectedPlayerProvider);
  return player == null
      ? winRateBySlotGlobal(games)
      : winRateBySlotForPlayer(games, player);
});
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd "C:/Users/user/AndroidStudioProjects/FamilyMafiaApp" && flutter test test/screens/debug/debug_providers_test.dart`
Expected: PASS — all 11 tests green.

- [ ] **Step 5: Commit**

```bash
cd "C:/Users/user/AndroidStudioProjects/FamilyMafiaApp"
git add lib/screens/debug/debug_providers.dart test/screens/debug/debug_providers_test.dart
git commit -m "feat: global + nickname-aware per-slot win rate providers"
```

---

### Task 2: Wire the search field and dynamic AppBar into the screen

**Files:**
- Modify: `lib/screens/debug/debug_screen.dart`

Note: `_DebugContent` is a `ConsumerWidget`. `playersListProvider` lives in
`lib/screens/players/players_providers.dart` and returns `List<Player>` sorted
by total games. `selectedPlayerProvider` is defined in Task 1.

- [ ] **Step 1: Replace `debug_screen.dart` contents**

Replace the entire contents of `lib/screens/debug/debug_screen.dart` with:

```dart
import 'package:family_mafia_app/models/player.dart';
import 'package:family_mafia_app/providers/app_providers.dart';
import 'package:family_mafia_app/screens/debug/debug_providers.dart';
import 'package:family_mafia_app/screens/players/players_providers.dart';
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
    final selected = ref.watch(selectedPlayerProvider);
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    final totalPlayed = slots.fold<int>(0, (a, s) => a + s.played);
    final totalWins = slots.fold<int>(0, (a, s) => a + s.wins);
    final overallWr = totalPlayed == 0 ? 0.0 : totalWins / totalPlayed;

    return Scaffold(
      appBar: AppBar(title: Text(selected?.displayName ?? 'Statistics')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          MediaQuery.paddingOf(context).bottom + 80,
        ),
        children: [
          const _PlayerSearchField(),
          const SizedBox(height: 16),
          Text('Win rate by slot', style: tt.titleMedium),
          const SizedBox(height: 4),
          Text(
            totalPlayed == 0
                ? 'No rating games found.'
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

class _PlayerSearchField extends ConsumerWidget {
  const _PlayerSearchField();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final players = ref.watch(playersListProvider);
    final selected = ref.watch(selectedPlayerProvider);

    return Autocomplete<Player>(
      displayStringForOption: (p) => p.displayName,
      optionsBuilder: (TextEditingValue value) {
        final q = value.text.toLowerCase().trim();
        if (q.isEmpty) return const Iterable<Player>.empty();
        return players
            .where((p) => p.displayName.toLowerCase().contains(q));
      },
      onSelected: (p) =>
          ref.read(selectedPlayerProvider.notifier).state = p,
      fieldViewBuilder:
          (context, controller, focusNode, onFieldSubmitted) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            hintText: 'Search player…',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: selected != null
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      controller.clear();
                      ref.read(selectedPlayerProvider.notifier).state = null;
                    },
                  )
                : null,
            border: const OutlineInputBorder(),
          ),
        );
      },
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
            overflow: TextOverflow.ellipsis,
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

- [ ] **Step 2: Analyze**

Run: `cd "C:/Users/user/AndroidStudioProjects/FamilyMafiaApp" && flutter analyze lib/screens/debug`
Expected: "No issues found!" (no unused imports; `kDebugPlayer` no longer referenced anywhere).

- [ ] **Step 3: Full test run**

Run: `cd "C:/Users/user/AndroidStudioProjects/FamilyMafiaApp" && flutter test`
Expected: All tests pass (no other file referenced `kDebugPlayer` or `winRateBySlot`).

- [ ] **Step 4: Build + redeploy to emulator (standing user preference)**

```bash
export PATH="$PATH:/c/Users/user/AppData/Local/Android/Sdk/platform-tools"
cd "C:/Users/user/AndroidStudioProjects/FamilyMafiaApp"
flutter build apk --debug
adb -s emulator-5554 install -r build/app/outputs/flutter-apk/app-debug.apk
adb -s emulator-5554 shell monkey -p com.example.family_mafia_app -c android.intent.category.LAUNCHER 1
```
Expected: build exit 0, install "Success". Then capture a screenshot to verify:
the Stats tab opens on "Statistics" (global), typing a name shows a dropdown,
selecting shows that player's slots and updates the AppBar title, and the clear
button returns to global.

- [ ] **Step 5: Commit**

```bash
cd "C:/Users/user/AndroidStudioProjects/FamilyMafiaApp"
git add lib/screens/debug/debug_screen.dart
git commit -m "feat: searchable player selector on stats screen"
```

---

## Notes for the implementer

- Do NOT reintroduce `kDebugPlayer`; it is intentionally removed.
- `game.players` is `List<String>`; `game.getPlayerSlot(name)` returns
  `players.indexOf(name)`; `game.hasPlayerWon(name)` and
  `game.isRatingGame()` already exist.
- Follow existing search UX conventions (see `players_screen.dart` `_SearchBar`).

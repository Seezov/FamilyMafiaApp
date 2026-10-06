# Annual all-star tournaments page Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `/allstars/` («Річні турніри») and `/allstars/<year>/` on the stats site: every yearly all-star tournament (Royal Battle '19, Family All Stars 2022–2025) with winner, full final table and four nominations.

**Architecture:** A committed snapshot `assets/raw/allstars.json` holds each event's final table, its games (sheet years) or official nominations (federation years). A pure Dart function computes nominations from games; `allstars_export.dart` turns the snapshot into display-ready `site/data/allstars.json`; two Astro pages render it. A one-off Python script (like `tool/import/make_annual_import.py`) writes the sheet years into the snapshot and refuses to if its checks fail.

**Tech Stack:** Dart / flutter_test (export), Python 3 stdlib (snapshot script), Astro + TypeScript (site).

**Spec:** `docs/superpowers/specs/2026-10-06-allstars-page-design.md`

## Global Constraints

- URL `/allstars/`, page title «Річні турніри»; nav label «All Stars» between Tournaments and Annual.
- Final tables are copied as they are, in their order ("sheets are truth"); never recomputed.
- Nominations (top 3 + anything tied with 3rd): `mvp` 🏅 MVP; `firstKilled` 💀 Найчастіше убитий першим; `bestRed` 👍 Кращий червоний; `bestMafia` 👎 Краща мафія. MVP = Σ(add + bestMove), add includes negative penalties; red = civilian/sheriff games, mafia = mafia/don games; Ci never counts. FAS 2023's `АД` column is not additional points.
- Ties inside a nomination keep final-table order (better-placed first).
- 2024–2025 nominations are the federation's, unchanged; 2019–2023 are computed and labelled «пораховано з ігор».
- Out of scope: fantasy, Rookie of the Year 2019, per-game cards, Firestore `config/club`, the app UI.
- Nothing fetched at build time; no API key in the repo or the built site.

## Review Focus

- A player name in a final table that the roster doesn't know (federation spellings «StoneCold Steve Austin 316», «Malina», «Frau», «DonTright») → must still render (plain text) and must not break `check-dist`; the snapshot stores roster spellings for federation years. Pinned in Task 3 (unresolved name renders unlinked) and Task 1 (snapshot names resolve).
- Three-way tie at 3rd place in a nomination → all tied rows shown, ordered by final table. Pinned in Task 2.
- A player with zero first-kills → not listed in «Найчастіше убитий першим». Pinned in Task 2.
- Event without host/date/source (Royal Battle '19) → page renders without empty «Ведучий:» labels or a dead link. Pinned in Task 3 (export omits null fields) and Task 4 (template guards).
- Year page order and the index's newest-first order stay stable when a new year is appended out of order in the JSON. Pinned in Task 3.

---

## File Structure

- Create `tool/import/make_allstars.py` — one-off: reads the three sheets, writes the 2019/2022/2023 entries into `assets/raw/allstars.json`, keeps every other entry as is.
- Create `assets/raw/allstars.json` — the snapshot (2024/2025 entries hand-written from the federation pages).
- Create `lib/models/allstars.dart` — `AllstarsEvent`, `AllstarsGame`, `AllstarsSeat`, `AllstarsNomination`, `parseAllstars()`.
- Create `lib/services/stats/allstars_nominations.dart` — `NominationKind`, `NominationRow`, `computeNominations()`.
- Create `lib/site_export/allstars_export.dart` — `allstarsJson(ExportContext, List<AllstarsEvent>)`.
- Modify `lib/site_export/site_exporter.dart` — `allstarsEvents` parameter, writes `allstars.json`.
- Modify `tool/export_site_data_test.dart` — reads `assets/raw/allstars.json`.
- Create `test/models/allstars_test.dart`, `test/services/stats/allstars_nominations_test.dart`, `test/site_export/allstars_export_test.dart`, `test/site_export/allstars_snapshot_test.dart`.
- Modify `site/src/lib/types.ts`, `site/src/lib/data.ts`.
- Create `site/src/components/NominationCards.astro`, `site/src/components/AllstarsEvent.astro`, `site/src/pages/allstars/index.astro`, `site/src/pages/allstars/[year].astro`.
- Modify `site/src/layouts/Base.astro` (nav), `CLAUDE.md`.

---

### Task 1: Snapshot of the five events

**Files:**
- Create: `tool/import/make_allstars.py`
- Create: `assets/raw/allstars.json`

**Interfaces:**
- Produces: `assets/raw/allstars.json` in this shape (all later tasks read it):

```jsonc
{
  "events": [
    {
      "year": 2019,                       // int, unique
      "name": "Royal Battle '19",
      "date": null,                       // string or null
      "hostLabel": "Ведучий",             // "Ведучий" | "Суддя"
      "host": null,                       // string or null
      "source": null,                     // URL or null
      "gameCount": 15,                    // games played (tables), int
      "columns": [{"label": "Балы"}, {"label": "Ci", "tip": "…"}],
      "standings": [{"player": "Рауль", "values": ["16.2", "15", …]}],  // one value per column
      "nominations": null,                // or [{"key": "mvp", "top": [{"player": "Tina", "value": "4.30"}]}]
      "games": [                          // [] for federation years
        {"firstKilled": 5,                // seat 1–10 or null
         "seats": [{"player": "Тян", "role": "civilian", "add": 0.0, "bestMove": 0.0}]}
      ]
    }
  ]
}
```

`role` ∈ `civilian | sheriff | mafia | don`. `bestMove` is the best-move points of the first-killed seat (0 elsewhere).

- [ ] **Step 1: Write the script**

`tool/import/make_allstars.py`:

```python
"""One-off: snapshot Royal Battle '19, FAS 2022 and FAS 2023 from the club sheets
into assets/raw/allstars.json. Other entries in the file (FAS 2024+, copied by hand
from emotion.games) are kept as they are.

Usage: SHEETS_API_KEY=... python tool/import/make_allstars.py

Refuses to write when a check fails: every game player must be in the final table,
their game count must equal the table's, and their summed additional / best-move
points must equal the table's columns.
"""
import json, os, sys, urllib.parse, urllib.request

KEY = os.environ.get('SHEETS_API_KEY') or sys.exit('SHEETS_API_KEY must be set')
OUT = os.path.join(os.path.dirname(__file__), '..', '..', 'assets', 'raw', 'allstars.json')

ROLES = {'мирный': 'civilian', 'мирний': 'civilian', 'шериф': 'sheriff',
         'мафия': 'mafia', 'мафія': 'mafia', 'дон': 'don'}


def values(sheet, rng):
    url = (f'https://sheets.googleapis.com/v4/spreadsheets/{sheet}/values/'
           f'{urllib.parse.quote(rng)}?key={KEY}')
    rows = json.load(urllib.request.urlopen(url)).get('values', [])
    return [[c.strip() for c in r] for r in rows]


def cell(r, i):
    return r[i] if i < len(r) else ''


def num(s):
    s = s.replace(',', '.').strip()
    return float(s) if s else 0.0


def standings(rows, header_row):
    """The final table: header at header_row (0-based), one row per player
    until the first row without a name. Column 0 is the place, 1 the player."""
    head = rows[header_row]
    labels = head[2:]
    # Old tables label both civilian and mafia «М».
    seen_m = 0
    for i, l in enumerate(labels):
        if l == 'М':
            labels[i] = 'Мирн.' if seen_m == 0 else 'Маф.'
            seen_m += 1
    out = []
    for r in rows[header_row + 1:]:
        if not cell(r, 1):
            break
        out.append({'player': r[1], 'values': [cell(r, 2 + i) for i in range(len(labels))]})
    return [{'label': l} for l in labels], out


def old_layout_games(rows, slot, label, val, player, role, lh, add):
    """Royal Battle '19 / FAS 2022: 10-row blocks; ПУ row holds the first-killed
    seat in `val`, Ведущий/Дата rows the host and date."""
    games, hosts, dates = [], set(), set()
    i = 0
    while i + 9 < len(rows):
        block = rows[i:i + 10]
        if [cell(r, slot) for r in block] != [str(n) for n in range(1, 11)] or \
                not all(cell(r, player) and cell(r, role) for r in block):
            i += 1
            continue
        first = None
        for r in block:
            lbl = cell(r, label)
            if lbl == 'ПУ' and cell(r, val):
                first = int(float(cell(r, val)))
            if lbl == 'Ведущий' and cell(r, val):
                hosts.add(cell(r, val))
            if lbl == 'Дата' and cell(r, val):
                dates.add(cell(r, val))
        games.append({'firstKilled': first, 'seats': [
            {'player': cell(r, player), 'role': ROLES[cell(r, role).lower()],
             'add': num(cell(r, add)), 'bestMove': num(cell(r, lh))} for r in block]})
        i += 10
    return games, hosts, dates


def fas2023_games(rows):
    """S17+ layout: slot in A, player B, role C, КХ I, Доп J; the row after
    seat 10 is «ПУ | <seat>»."""
    games = []
    i = 0
    while i + 10 < len(rows):
        block = rows[i:i + 10]
        if [cell(r, 0) for r in block] != [str(n) for n in range(1, 11)] or \
                not all(cell(r, 1) and cell(r, 2) for r in block):
            i += 1
            continue
        pu = rows[i + 10]
        first = int(float(cell(pu, 1))) if cell(pu, 0) == 'ПУ' and cell(pu, 1) else None
        games.append({'firstKilled': first, 'seats': [
            {'player': cell(r, 1), 'role': ROLES[cell(r, 2).lower()],
             'add': num(cell(r, 9)), 'bestMove': num(cell(r, 8))} for r in block]})
        i += 11
    return games


def check(name, columns, table, games, games_col, add_col, bm_col):
    labels = [c['label'] for c in columns]
    gi, ai, bi = labels.index(games_col), labels.index(add_col), labels.index(bm_col)
    by_name = {s['player'].lower(): s for s in table}
    agg = {}
    for g in games:
        for s in g['seats']:
            if s['player'].lower() not in by_name:
                sys.exit(f'{name}: «{s["player"]}» plays but is not in the final table')
            a = agg.setdefault(s['player'].lower(), [0, 0.0, 0.0])
            a[0] += 1
            a[1] += s['add']
            a[2] += s['bestMove']
    for key, s in by_name.items():
        n, add, bm = agg.get(key, [0, 0.0, 0.0])
        want = (int(num(s['values'][gi])), num(s['values'][ai]), num(s['values'][bi]))
        if n != want[0] or abs(add - want[1]) > 0.011 or abs(bm - want[2]) > 0.011:
            sys.exit(f'{name}: {s["player"]} games/add/best move {n}/{add:.2f}/{bm:.2f}, '
                     f'table says {want[0]}/{want[1]}/{want[2]}')


def event(year, name, date, host, columns, table, games):
    return {'year': year, 'name': name, 'date': date, 'hostLabel': 'Ведучий', 'host': host,
            'source': None, 'gameCount': len(games), 'columns': columns,
            'standings': table, 'nominations': None, 'games': games}


def main():
    built = []

    s09 = '1lTFSzQINByKKOM8QWxhQQpctgaI1r_CUkmvAsLeGws0'
    cols, table = standings(values(s09, "'Royal Battle ''19'!A1:Z40"), 4)
    games, _, _ = old_layout_games(values(s09, "'Royal Battle 2019 Games'!A1:Z400"),
                                   slot=0, label=1, val=2, player=6, role=19, lh=21, add=22)
    check("Royal Battle '19", cols, table, games, 'Игр сыграно', 'Допы', 'ЛХ')
    built.append(event(2019, "Royal Battle '19", None, None, cols, table, games))

    f22 = '1ITv-laaBJnzoSTPsTPrPkkyJJI6MZBaMFljx8PJf0AY'
    cols, table = standings(values(f22, 'Рейтинг!A1:Z40'), 4)
    games, hosts, dates = old_layout_games(values(f22, 'Игры!A1:Z400'),
                                           slot=2, label=3, val=4, player=8, role=21, lh=23, add=24)
    check('FAS 2022', cols, table, games, 'Игр сыграно', 'Допы', 'ЛХ')
    built.append(event(2022, 'Family All Stars 2022', '14–15.01.2023',
                       ', '.join(sorted(hosts)) or None, cols, table, games))

    s20 = '1cRrvDXlYOCyrEKSVAzfn916MsLecfgWKYdcTUpuATFM'
    cols, table = standings(values(s20, "'FAS 2023'!A1:R40"), 0)
    games = fas2023_games(values(s20, "'FAS 2023 Ігри'!A1:J800"))
    check('FAS 2023', cols, table, games, 'Ігри', 'ДБ', 'КХ')
    # Its game dates are the template's 05.09.2023; it was played in December 2023.
    built.append(event(2023, 'Family All Stars 2023', '12.2023', 'Катана', cols, table, games))

    old = json.load(open(OUT, encoding='utf-8'))['events'] if os.path.exists(OUT) else []
    years = {e['year'] for e in built}
    events = sorted(built + [e for e in old if e['year'] not in years], key=lambda e: e['year'])
    with open(OUT, 'w', encoding='utf-8', newline='\n') as f:
        json.dump({'events': events}, f, ensure_ascii=False, indent=1)
        f.write('\n')
    print(f'wrote {len(events)} events: ' + ', '.join(f"{e['year']} ({e['gameCount']} games)" for e in events))


main()
```

- [ ] **Step 2: Write the federation entries**

Create `assets/raw/allstars.json` with the two hand-copied events (the script keeps them). Names use the club roster's spelling: «StoneCold Steve Austin 316» → «Stone Cold», «Malina» → «Малина», «Frau» → «Фрау», «DonTright» → «Don`Tright». Values exactly as on https://emotion.games/ua/tournament/385/results and /572/results; column order Σ first.

```json
{
 "events": [
  {
   "year": 2024, "name": "Family All Stars 2024", "date": "17–19.01.2025",
   "hostLabel": "Суддя", "host": "Jf",
   "source": "https://emotion.games/ua/tournament/385/results", "gameCount": 21,
   "columns": [
    {"label": "Σ", "tip": "Сума балів турніру"},
    {"label": "W/G", "tip": "Перемоги / ігри"},
    {"label": "Σap", "tip": "Сума +, − і КХ"},
    {"label": "+", "tip": "Додаткові бали"},
    {"label": "−", "tip": "Штрафи і дисциплінарні штрафи"},
    {"label": "BM", "tip": "Бали за кращий хід"},
    {"label": "Ci", "tip": "Компенсація за першу смерть"},
    {"label": "L/K", "tip": "Програні ігри / убитий першим"}
   ],
   "standings": [
    {"player": "Braun", "values": ["14.83", "10/15", "4.5", "4.5", "0", "0", "0.33", "2/2"]},
    {"player": "Stone Cold", "values": ["13.87", "9/15", "4.2", "4.1", "0.3", "0.4", "0.67", "2/4"]},
    {"player": "Тян", "values": ["13.4", "10/15", "3.4", "3.4", "0", "0", "0", "0/0"]},
    {"player": "Малина", "values": ["10.87", "8/15", "2.7", "3", "0.3", "0", "0.17", "1/2"]},
    {"player": "Валькірія", "values": ["10.7", "8/15", "2.7", "3", "0.3", "0", "0", "0/0"]},
    {"player": "Аглая", "values": ["10", "8/15", "2", "2.8", "0.8", "0", "0", "0/2"]},
    {"player": "Don`Tright", "values": ["9.87", "7/15", "2.7", "3", "0.3", "0", "0.17", "1/2"]},
    {"player": "Залізний", "values": ["9.5", "6/15", "3", "2.6", "0", "0.4", "0.5", "2/3"]},
    {"player": "Хоттабич", "values": ["9.1", "7/15", "2.1", "2", "0.3", "0.4", "0", "0/2"]},
    {"player": "Малишка", "values": ["8.7", "8/15", "0.7", "0.7", "0", "0", "0", "0/0"]},
    {"player": "Seezov", "values": ["8.28", "6/15", "2.2", "2.2", "0", "0", "0.08", "1/1"]},
    {"player": "Серпень", "values": ["8.1", "8/15", "0.1", "0.4", "0.3", "0", "0", "0/0"]},
    {"player": "Majest", "values": ["7.88", "6/15", "1.8", "2.4", "1", "0.4", "0.08", "1/1"]},
    {"player": "Найт", "values": ["6.2", "6/15", "0.2", "1", "0.8", "0", "0", "0/0"]}
   ],
   "nominations": [
    {"key": "mvp", "top": [{"player": "Braun", "value": "4.50"}, {"player": "Stone Cold", "value": "4.20"}, {"player": "Тян", "value": "3.40"}]},
    {"key": "firstKilled", "top": [{"player": "Stone Cold", "value": "4"}, {"player": "Залізний", "value": "3"}, {"player": "Малина", "value": "2"}]},
    {"key": "bestRed", "top": [{"player": "Stone Cold", "value": "3.50"}, {"player": "Braun", "value": "3.20"}, {"player": "Тян", "value": "2.60"}]},
    {"key": "bestMafia", "top": [{"player": "Braun", "value": "1.30"}, {"player": "Don`Tright", "value": "1.10"}, {"player": "Малина", "value": "1.00"}]}
   ],
   "games": []
  },
  {
   "year": 2025, "name": "Family All Stars 2025", "date": "16–18.01.2026",
   "hostLabel": "Суддя", "host": "Темна Фурія",
   "source": "https://emotion.games/ua/tournament/572/results", "gameCount": 21,
   "columns": [
    {"label": "Σ", "tip": "Сума балів турніру"},
    {"label": "W/G", "tip": "Перемоги / ігри"},
    {"label": "Σap", "tip": "Сума +, − і КХ"},
    {"label": "+", "tip": "Додаткові бали"},
    {"label": "−", "tip": "Штрафи і дисциплінарні штрафи"},
    {"label": "BM", "tip": "Бали за кращий хід"},
    {"label": "Ci", "tip": "Компенсація за першу смерть"},
    {"label": "L/K", "tip": "Програні ігри / убитий першим"}
   ],
   "standings": [
    {"player": "Tina", "values": ["11.3", "7/15", "4.3", "4.3", "0", "0", "0", "0/0"]},
    {"player": "Хоттабич", "values": ["10.33", "6/15", "4", "4", "0", "0", "0.33", "2/2"]},
    {"player": "Floppy", "values": ["10.1", "7/15", "3.1", "4.2", "1.1", "0", "0", "0/1"]},
    {"player": "Фурія", "values": ["9.98", "7/15", "2.9", "2.9", "0", "0", "0.08", "1/1"]},
    {"player": "Малина", "values": ["9.75", "6/15", "3", "2.9", "0.3", "0.4", "0.75", "3/3"]},
    {"player": "Аватар", "values": ["9.33", "5/15", "4", "4", "0", "0", "0.33", "2/2"]},
    {"player": "Валькірія", "values": ["9.27", "6/15", "3.1", "3", "0.3", "0.4", "0.17", "1/2"]},
    {"player": "Аглая", "values": ["9", "7/15", "2", "3.3", "1.3", "0", "0", "0/0"]},
    {"player": "Сирник", "values": ["8.67", "6/15", "2.5", "2.5", "0", "0", "0.17", "1/2"]},
    {"player": "Малишка", "values": ["8.38", "5/15", "3.3", "2.9", "0", "0.4", "0.08", "1/1"]},
    {"player": "Seezov", "values": ["7.55", "5/15", "1.8", "1.7", "0.3", "0.4", "0.75", "3/3"]},
    {"player": "Фрау", "values": ["7.2", "7/15", "0.2", "1.1", "0.9", "0", "0", "0/0"]},
    {"player": "Kulav", "values": ["5.78", "5/15", "0.7", "2.2", "1.9", "0.4", "0.08", "1/1"]},
    {"player": "Залізний", "values": ["4.77", "4/15", "0.6", "1.4", "0.8", "0", "0.17", "1/2"]}
   ],
   "nominations": [
    {"key": "mvp", "top": [{"player": "Tina", "value": "4.30"}, {"player": "Хоттабич", "value": "4.00"}, {"player": "Аватар", "value": "4.00"}]},
    {"key": "firstKilled", "top": [{"player": "Малина", "value": "3"}, {"player": "Seezov", "value": "3"}, {"player": "Хоттабич", "value": "2"}]},
    {"key": "bestRed", "top": [{"player": "Tina", "value": "3.00"}, {"player": "Аватар", "value": "2.40"}, {"player": "Фурія", "value": "2.30"}]},
    {"key": "bestMafia", "top": [{"player": "Аглая", "value": "2.90"}, {"player": "Хоттабич", "value": "2.40"}, {"player": "Малишка", "value": "2.40"}]}
   ],
   "games": []
  }
 ]
}
```

- [ ] **Step 3: Run the script**

Run (Git Bash, from repo root): `SHEETS_API_KEY=$(grep -o '"SHEETS_API_KEY"[^,}]*' assets/.env.json | sed 's/.*: *"//;s/"//') PYTHONIOENCODING=utf-8 python tool/import/make_allstars.py`
Expected: `wrote 5 events: 2019 (15 games), 2022 (… games), 2023 (… games), 2024 (21 games), 2025 (21 games)`.

If a check fails, the message names the event, player and the three numbers. Fix the column indices in the call (dump the tab with the Sheets API to see the real layout) — never loosen the check. Royal Battle '19 lists 15 games per player with 10 players, so its `gameCount` must be 15.

- [ ] **Step 4: Spot-check the output**

Run: `PYTHONIOENCODING=utf-8 python -c "import json;d=json.load(open('assets/raw/allstars.json',encoding='utf-8'));[print(e['year'],e['standings'][0]['player'],e['gameCount'],len(e['games']),[c['label'] for c in e['columns']]) for e in d['events']]"`
Expected winners in order: Рауль, Луна, Seezov, Braun, Tina; no `"М"` label left in 2019/2022.

- [ ] **Step 5: Commit**

```bash
git add tool/import/make_allstars.py assets/raw/allstars.json
git commit -m "data: snapshot of the yearly all-star tournaments"
```

---

### Task 2: Model and nominations

**Files:**
- Create: `lib/models/allstars.dart`
- Create: `lib/services/stats/allstars_nominations.dart`
- Test: `test/models/allstars_test.dart`, `test/services/stats/allstars_nominations_test.dart`

**Interfaces:**
- Consumes: the JSON shape from Task 1.
- Produces:

```dart
// lib/models/allstars.dart
enum AllstarsRole { civilian, sheriff, mafia, don }   // .isRed: civilian | sheriff
class AllstarsSeat { final String player; final AllstarsRole role; final double add; final double bestMove; }
class AllstarsGame { final int? firstKilled; final List<AllstarsSeat> seats; }
class AllstarsColumn { final String label; final String? tip; }
class AllstarsStanding { final String player; final List<String> values; }
class AllstarsNomination { final String key; final List<({String player, String value})> top; }
class AllstarsEvent {
  final int year; final String name; final String? date; final String hostLabel;
  final String? host; final String? source; final int gameCount;
  final List<AllstarsColumn> columns; final List<AllstarsStanding> standings;
  final List<AllstarsNomination>? nominations; final List<AllstarsGame> games;
}
List<AllstarsEvent> parseAllstars(String json);   // throws FormatException naming the year

// lib/services/stats/allstars_nominations.dart
enum NominationKind { mvp, firstKilled, bestRed, bestMafia }
class NominationRow { final String player; final double value; }
Map<NominationKind, List<NominationRow>> computeNominations(
    List<AllstarsGame> games, List<String> tableOrder);
```

- [ ] **Step 1: Write the failing tests**

`test/models/allstars_test.dart`:

```dart
import 'package:family_mafia_app/models/allstars.dart';
import 'package:flutter_test/flutter_test.dart';

const _json = '''
{"events": [{
  "year": 2019, "name": "RB", "date": null, "hostLabel": "Ведучий", "host": null,
  "source": null, "gameCount": 1,
  "columns": [{"label": "Балы"}, {"label": "Ci", "tip": "Компенсація"}],
  "standings": [{"player": "A", "values": ["1", "0"]}],
  "nominations": null,
  "games": [{"firstKilled": 2, "seats": [
    {"player": "A", "role": "civilian", "add": 0.3, "bestMove": 0},
    {"player": "B", "role": "don", "add": -0.5, "bestMove": 0.4}]}]
}]}''';

void main() {
  test('parses an event with games', () {
    final e = parseAllstars(_json).single;
    expect(e.year, 2019);
    expect(e.host, isNull);
    expect(e.columns[1].tip, 'Компенсація');
    expect(e.standings.single.values, ['1', '0']);
    expect(e.nominations, isNull);
    final g = e.games.single;
    expect(g.firstKilled, 2);
    expect(g.seats[1].role, AllstarsRole.don);
    expect(g.seats[1].add, -0.5);
    expect(AllstarsRole.sheriff.isRed, isTrue);
    expect(AllstarsRole.don.isRed, isFalse);
  });

  test('a standings row with the wrong number of values names the year', () {
    final bad = _json.replaceFirst('"values": ["1", "0"]', '"values": ["1"]');
    expect(() => parseAllstars(bad),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('2019'))));
  });

  test('an unknown role names the year', () {
    final bad = _json.replaceFirst('"don"', '"boss"');
    expect(() => parseAllstars(bad), throwsA(isA<FormatException>()));
  });
}
```

`test/services/stats/allstars_nominations_test.dart`:

```dart
import 'package:family_mafia_app/models/allstars.dart';
import 'package:family_mafia_app/services/stats/allstars_nominations.dart';
import 'package:flutter_test/flutter_test.dart';

AllstarsSeat s(String p, AllstarsRole r, {double add = 0, double bm = 0}) =>
    AllstarsSeat(player: p, role: r, add: add, bestMove: bm);

const civ = AllstarsRole.civilian, sher = AllstarsRole.sheriff,
    maf = AllstarsRole.mafia, don = AllstarsRole.don;

List<(String, double)> rows(List<NominationRow> l) => [for (final r in l) (r.player, r.value)];

void main() {
  test('MVP sums additional and best-move points, penalties included', () {
    final games = [
      AllstarsGame(firstKilled: 1, seats: [s('A', civ, add: 0.3, bm: 0.4), s('B', maf, add: 0.5)]),
      AllstarsGame(firstKilled: null, seats: [s('A', maf, add: -0.5), s('B', sher, add: 0.2)]),
    ];
    final n = computeNominations(games, ['A', 'B']);
    expect(rows(n[NominationKind.mvp]!).map((r) => (r.$1, r.$2.toStringAsFixed(2))),
        [('B', '0.70'), ('A', '0.20')]);
  });

  test('red counts civilian and sheriff games, mafia counts mafia and don', () {
    final games = [
      AllstarsGame(firstKilled: null, seats: [s('A', civ, add: 0.3), s('B', don, add: 0.4)]),
      AllstarsGame(firstKilled: null, seats: [s('A', sher, add: 0.2), s('B', maf, add: 0.1)]),
      AllstarsGame(firstKilled: null, seats: [s('A', maf, add: 0.6), s('B', civ, add: 0.1)]),
    ];
    final n = computeNominations(games, ['A', 'B']);
    expect(rows(n[NominationKind.bestRed]!).first.$1, 'A');
    expect(n[NominationKind.bestRed]!.first.value, closeTo(0.5, 1e-9));
    expect(rows(n[NominationKind.bestMafia]!).first.$1, 'A');
    expect(n[NominationKind.bestMafia]!.first.value, closeTo(0.6, 1e-9));
    expect(n[NominationKind.bestMafia]![1].value, closeTo(0.5, 1e-9));
  });

  test('first killed counts seats; players never killed first are left out', () {
    final games = [
      AllstarsGame(firstKilled: 2, seats: [s('A', civ), s('B', civ)]),
      AllstarsGame(firstKilled: 2, seats: [s('A', civ), s('B', civ)]),
      AllstarsGame(firstKilled: 1, seats: [s('A', civ), s('B', civ)]),
      AllstarsGame(firstKilled: null, seats: [s('C', civ), s('B', civ)]),
    ];
    final n = computeNominations(games, ['A', 'B', 'C']);
    expect(rows(n[NominationKind.firstKilled]!), [('B', 2.0), ('A', 1.0)]);
  });

  test('ties keep final-table order and a tie at 3rd shows every tied player', () {
    final games = [
      AllstarsGame(firstKilled: null, seats: [
        s('E', civ, add: 0.9), s('D', civ, add: 0.3), s('C', civ, add: 0.3),
        s('B', civ, add: 0.3), s('A', civ, add: 0.1),
      ]),
    ];
    final n = computeNominations(games, ['A', 'B', 'C', 'D', 'E']);
    expect(rows(n[NominationKind.mvp]!).map((r) => r.$1), ['E', 'B', 'C', 'D']);
  });

  test('names match the table case-insensitively for ordering', () {
    final games = [AllstarsGame(firstKilled: null, seats: [s('tina', civ, add: 0.3), s('Braun', civ, add: 0.3)])];
    final n = computeNominations(games, ['Tina', 'Braun']);
    expect(rows(n[NominationKind.mvp]!).map((r) => r.$1), ['tina', 'Braun']);
  });
}
```

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/models/allstars_test.dart test/services/stats/allstars_nominations_test.dart`
Expected: FAIL — `allstars.dart` / `allstars_nominations.dart` not found.

- [ ] **Step 3: Implement the model**

`lib/models/allstars.dart`:

```dart
// Pure Dart: read by the site export and its tests.
import 'dart:convert';

/// A seat's role in an all-star game.
enum AllstarsRole {
  civilian,
  sheriff,
  mafia,
  don;

  bool get isRed => this == civilian || this == sheriff;
}

class AllstarsSeat {
  const AllstarsSeat(
      {required this.player, required this.role, required this.add, required this.bestMove});

  /// The name as written in the event's sheet.
  final String player;
  final AllstarsRole role;

  /// Additional points; penalties are stored negative, as in the sheets.
  final double add;

  /// Best-move points (only the first-killed seat has any).
  final double bestMove;
}

class AllstarsGame {
  const AllstarsGame({required this.firstKilled, required this.seats});

  /// Seat 1–10, or null when nobody was killed first.
  final int? firstKilled;
  final List<AllstarsSeat> seats;
}

class AllstarsColumn {
  const AllstarsColumn(this.label, {this.tip});
  final String label;
  final String? tip;
}

class AllstarsStanding {
  const AllstarsStanding(this.player, this.values);
  final String player;

  /// One display string per column, as in the source table.
  final List<String> values;
}

/// An official nomination copied from the federation's results page.
class AllstarsNomination {
  const AllstarsNomination(this.key, this.top);
  final String key;
  final List<({String player, String value})> top;
}

/// One yearly all-star tournament from `assets/raw/allstars.json`.
class AllstarsEvent {
  const AllstarsEvent({
    required this.year,
    required this.name,
    required this.date,
    required this.hostLabel,
    required this.host,
    required this.source,
    required this.gameCount,
    required this.columns,
    required this.standings,
    required this.nominations,
    required this.games,
  });

  final int year;
  final String name;
  final String? date;

  /// «Ведучий» or «Суддя».
  final String hostLabel;
  final String? host;

  /// The federation's results page, when the event is there.
  final String? source;
  final int gameCount;
  final List<AllstarsColumn> columns;

  /// The final table in its own order: index 0 is the winner.
  final List<AllstarsStanding> standings;

  /// Official nominations, or null when they are computed from [games].
  final List<AllstarsNomination>? nominations;
  final List<AllstarsGame> games;
}

const _nominationKeys = {'mvp', 'firstKilled', 'bestRed', 'bestMafia'};

List<AllstarsEvent> parseAllstars(String json) {
  final root = jsonDecode(json) as Map<String, dynamic>;
  return [
    for (final e in (root['events'] as List).cast<Map<String, dynamic>>()) _event(e)
  ];
}

AllstarsEvent _event(Map<String, dynamic> e) {
  final year = e['year'] as int;
  Never bad(String what) => throw FormatException('all-stars $year: $what');

  final columns = [
    for (final c in (e['columns'] as List).cast<Map<String, dynamic>>())
      AllstarsColumn(c['label'] as String, tip: c['tip'] as String?)
  ];
  final standings = [
    for (final s in (e['standings'] as List).cast<Map<String, dynamic>>())
      AllstarsStanding(s['player'] as String, (s['values'] as List).cast<String>())
  ];
  for (final s in standings) {
    if (s.values.length != columns.length) {
      bad('${s.player} has ${s.values.length} values for ${columns.length} columns');
    }
  }
  if (standings.isEmpty) bad('empty final table');

  final noms = e['nominations'] as List?;
  final nominations = noms == null
      ? null
      : [
          for (final n in noms.cast<Map<String, dynamic>>())
            if (_nominationKeys.contains(n['key']))
              AllstarsNomination(n['key'] as String, [
                for (final t in (n['top'] as List).cast<Map<String, dynamic>>())
                  (player: t['player'] as String, value: t['value'] as String)
              ])
            else
              bad('unknown nomination "${n['key']}"')
        ];

  AllstarsRole role(String r) => AllstarsRole.values
      .firstWhere((v) => v.name == r, orElse: () => bad('unknown role "$r"'));

  return AllstarsEvent(
    year: year,
    name: e['name'] as String,
    date: e['date'] as String?,
    hostLabel: e['hostLabel'] as String,
    host: e['host'] as String?,
    source: e['source'] as String?,
    gameCount: e['gameCount'] as int,
    columns: columns,
    standings: standings,
    nominations: nominations,
    games: [
      for (final g in (e['games'] as List).cast<Map<String, dynamic>>())
        AllstarsGame(
          firstKilled: g['firstKilled'] as int?,
          seats: [
            for (final s in (g['seats'] as List).cast<Map<String, dynamic>>())
              AllstarsSeat(
                player: s['player'] as String,
                role: role(s['role'] as String),
                add: (s['add'] as num).toDouble(),
                bestMove: (s['bestMove'] as num).toDouble(),
              )
          ],
        )
    ],
  );
}
```

- [ ] **Step 4: Implement the nominations**

`lib/services/stats/allstars_nominations.dart`:

```dart
import 'package:family_mafia_app/models/allstars.dart';

/// The federation's four nominations (emotion.games results page).
enum NominationKind { mvp, firstKilled, bestRed, bestMafia }

class NominationRow {
  const NominationRow(this.player, this.value);
  final String player;
  final double value;
}

/// Nominations of one all-star event computed from its games, the way the
/// federation counts them: MVP = Σ(additional + best move) — penalties are
/// negative additional points, first-kill compensation (Ci) is not counted;
/// best red / best mafia = the same sum in civilian+sheriff / mafia+don games;
/// first killed = times killed first (players never killed first are left out).
///
/// Each list is the top 3 plus every player tied with the 3rd; ties keep
/// [tableOrder] (the final table, matched ignoring case).
Map<NominationKind, List<NominationRow>> computeNominations(
    List<AllstarsGame> games, List<String> tableOrder) {
  final names = <String, String>{}; // lower-case key → name as first seen
  final sums = {for (final k in NominationKind.values) k: <String, double>{}};
  void add(NominationKind k, String key, double v) =>
      sums[k]![key] = (sums[k]![key] ?? 0) + v;

  for (final g in games) {
    for (var i = 0; i < g.seats.length; i++) {
      final s = g.seats[i];
      final key = s.player.toLowerCase();
      names.putIfAbsent(key, () => s.player);
      final points = s.add + s.bestMove;
      add(NominationKind.mvp, key, points);
      add(s.role.isRed ? NominationKind.bestRed : NominationKind.bestMafia, key, points);
      if (g.firstKilled == i + 1) add(NominationKind.firstKilled, key, 1);
    }
  }

  final rank = {
    for (var i = 0; i < tableOrder.length; i++) tableOrder[i].toLowerCase(): i
  };
  int place(String key) => rank[key] ?? tableOrder.length;

  return {
    for (final k in NominationKind.values) k: _top(sums[k]!, names, place),
  };
}

List<NominationRow> _top(Map<String, double> sums, Map<String, String> names,
    int Function(String) place) {
  final keys = sums.keys.toList()
    ..sort((a, b) {
      final c = _round(sums[b]!).compareTo(_round(sums[a]!));
      return c != 0 ? c : place(a).compareTo(place(b));
    });
  final out = <NominationRow>[];
  for (final key in keys) {
    final v = sums[key]!;
    if (out.length >= 3 && _round(v) != _round(out.last.value)) break;
    out.add(NominationRow(names[key]!, v));
  }
  return out;
}

/// Sums of 0.1-steps carry float noise; compare at 2 decimals, as shown.
int _round(double v) => (v * 100).round();
```

The first-killed sums only hold players who were killed first (only they get `add(...)` for it), so zero-count players never appear.

- [ ] **Step 5: Run the tests to verify they pass**

Run: `flutter test test/models/allstars_test.dart test/services/stats/allstars_nominations_test.dart`
Expected: PASS (8 tests).

- [ ] **Step 6: Commit**

```bash
git add lib/models/allstars.dart lib/services/stats/allstars_nominations.dart test/models/allstars_test.dart test/services/stats/allstars_nominations_test.dart
git commit -m "feat: all-star event model and federation-style nominations"
```

---

### Task 3: Site export

**Files:**
- Create: `lib/site_export/allstars_export.dart`
- Modify: `lib/site_export/site_exporter.dart` (signature + one `write`)
- Modify: `tool/export_site_data_test.dart`
- Test: `test/site_export/allstars_export_test.dart`, `test/site_export/allstars_snapshot_test.dart`

**Interfaces:**
- Consumes: `parseAllstars`, `AllstarsEvent` (Task 2), `computeNominations`, `NominationKind` (Task 2), `ExportContext`, `SiteTable`, `SiteCell`, `SiteColumn`, `playerResolverProvider`, `personKey`.
- Produces: `Map<String, Object?> allstarsJson(ExportContext x, List<AllstarsEvent> events)` writing this JSON (consumed by Task 4):

```jsonc
{
  "events": [                // newest year first
    {
      "year": 2025, "name": "Family All Stars 2025",
      "date": "16–18.01.2026",                    // omitted when null
      "hostLabel": "Суддя", "host": "Темна Фурія", // host omitted when null
      "source": "https://…",                      // omitted when null
      "players": 14, "games": 21,
      "podium": [ {"t": "Tina", "link": "tina"}, … ],   // SiteCell, up to 3
      "table": { …SiteTable… },
      "nominations": [ {"key": "mvp", "icon": "🏅", "label": "MVP",
                        "official": true, "rows": [ {"player": {SiteCell}, "value": "4.30"} ]} ]
    }
  ],
  "champions": { …SiteTable… }
}
```

`writeSiteData(..., {List<AllstarsEvent> allstarsEvents = const []})` writes `allstars.json`.

- [ ] **Step 1: Write the failing export test**

`test/site_export/allstars_export_test.dart`:

```dart
import 'dart:convert';

import 'package:family_mafia_app/models/allstars.dart';
import 'package:family_mafia_app/site_export/allstars_export.dart';
import 'package:family_mafia_app/site_export/export_context.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixture.dart';

AllstarsEvent ev(int year, List<String> order,
        {List<AllstarsGame> games = const [], List<AllstarsNomination>? noms, String? host, String? source}) =>
    AllstarsEvent(
      year: year,
      name: 'Event $year',
      date: null,
      hostLabel: 'Ведучий',
      host: host,
      source: source,
      gameCount: games.length,
      columns: const [AllstarsColumn('Бали')],
      standings: [for (var i = 0; i < order.length; i++) AllstarsStanding(order[i], ['${10 - i}'])],
      nominations: noms,
      games: games,
    );

void main() {
  late Map json;
  setUp(() async {
    final c = await fixtureContainer();
    final events = [
      ev(2019, ['Железный', 'Nobody Known', 'Аглая'], games: [
        AllstarsGame(firstKilled: 2, seats: const [
          AllstarsSeat(player: 'Железный', role: AllstarsRole.civilian, add: 0.3, bestMove: 0),
          AllstarsSeat(player: 'Nobody Known', role: AllstarsRole.mafia, add: 0, bestMove: 0.4),
          AllstarsSeat(player: 'Аглая', role: AllstarsRole.don, add: -0.5, bestMove: 0),
        ]),
      ]),
      ev(2025, ['Аглая', 'Залізний'], host: 'Суддя Х', source: 'https://example.org/r', noms: [
        const AllstarsNomination('mvp', [(player: 'Аглая', value: '4.30')]),
      ]),
    ];
    json = jsonDecode(jsonEncode(allstarsJson(ExportContext(c), events))) as Map;
  });

  test('events newest first, null fields omitted', () {
    final events = json['events'] as List;
    expect([for (final e in events) e['year']], [2025, 2019]);
    expect(events[1].containsKey('host'), isFalse);
    expect(events[1].containsKey('source'), isFalse);
    expect(events[1].containsKey('date'), isFalse);
    expect(events[0]['source'], 'https://example.org/r');
    expect(events[0]['players'], 2);
  });

  test('podium resolves nicknames and leaves unknown names unlinked', () {
    final podium = (json['events'] as List)[1]['podium'] as List;
    expect(podium[0]['t'], 'Залізний');
    expect(podium[0]['link'], isNotNull);
    expect(podium[1], {'t': 'Nobody Known'});
  });

  test('official nominations pass through; computed ones are flagged', () {
    final e25 = (json['events'] as List)[0]['nominations'] as List;
    expect(e25.single['official'], isTrue);
    expect(e25.single['rows'][0]['value'], '4.30');

    final e19 = (json['events'] as List)[1]['nominations'] as List;
    expect([for (final n in e19) n['key']], ['mvp', 'firstKilled', 'bestRed', 'bestMafia']);
    expect(e19.every((n) => n['official'] == false), isTrue);
    final killed = e19[1]['rows'] as List;
    expect(killed.single['player']['t'], 'Nobody Known');
    expect(killed.single['value'], '1');
    expect((e19[0]['rows'] as List).first['value'], '0.40');
  });

  test('the final table keeps its order and is not re-sortable', () {
    final table = (json['events'] as List)[1]['table'] as Map;
    expect(table.containsKey('sortColumn'), isFalse);
    expect(table['showRank'], isTrue);
    expect([for (final r in table['rows'] as List) r[0]['t']], ['Залізний', 'Nobody Known', 'Аглая']);
  });

  test('champions merge nicknames across years', () {
    final rows = (json['champions'] as Map)['rows'] as List;
    final aglaya = rows.firstWhere((r) => r[0]['t'] == 'Аглая');
    final zal = rows.firstWhere((r) => r[0]['t'] == 'Залізний');
    expect([aglaya[1]['t'], aglaya[3]['t']], ['1', '1']); // 1st 2025, 3rd 2019
    expect([zal[1]['t'], zal[2]['t']], ['1', '1']);      // 1st 2019, 2nd 2025
    expect(aglaya[5]['t'], '2025');
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/site_export/allstars_export_test.dart`
Expected: FAIL — `allstars_export.dart` not found.

- [ ] **Step 3: Implement the export**

`lib/site_export/allstars_export.dart`:

```dart
import 'package:family_mafia_app/models/allstars.dart';
import 'package:family_mafia_app/screens/home/home_providers.dart';
import 'package:family_mafia_app/services/stats/allstars_nominations.dart';
import 'package:family_mafia_app/services/stats/player_resolver.dart';
import 'package:family_mafia_app/site_export/export_context.dart';
import 'package:family_mafia_app/site_export/formats.dart';
import 'package:family_mafia_app/site_export/site_table.dart';

const _nominations = {
  NominationKind.mvp: ('🏅', 'MVP'),
  NominationKind.firstKilled: ('💀', 'Найчастіше убитий першим'),
  NominationKind.bestRed: ('👍', 'Кращий червоний'),
  NominationKind.bestMafia: ('👎', 'Краща мафія'),
};

/// The «Річні турніри» pages: every yearly all-star tournament, newest first,
/// and the players with the most podiums across them.
Map<String, Object?> allstarsJson(ExportContext x, List<AllstarsEvent> events) {
  final resolver = x.read(playerResolverProvider);
  SiteCell cell(String raw) {
    final p = resolver.resolve(raw);
    return x.slugs[p.id] == null ? SiteCell(raw) : x.name(p);
  }

  final sorted = [...events]..sort((a, b) => b.year.compareTo(a.year));
  return {
    'events': [for (final e in sorted) _event(e, cell)],
    'champions': _champions(sorted, resolver, cell).toJson(),
  };
}

Map<String, Object?> _event(AllstarsEvent e, SiteCell Function(String) cell) => {
      'year': e.year,
      'name': e.name,
      if (e.date != null) 'date': e.date,
      'hostLabel': e.hostLabel,
      if (e.host != null) 'host': e.host,
      if (e.source != null) 'source': e.source,
      'players': e.standings.length,
      'games': e.gameCount,
      'podium': [for (final s in e.standings.take(3)) cell(s.player).toJson()],
      'table': SiteTable(
        showRank: true,
        columns: [
          const SiteColumn('Гравець', numeric: false),
          for (final c in e.columns) SiteColumn(c.label, tip: c.tip),
        ],
        rows: [
          for (final s in e.standings)
            [cell(s.player), for (final v in s.values) SiteCell(v)]
        ],
      ).toJson(),
      'nominations': e.nominations != null
          ? [
              for (final n in e.nominations!)
                _nomination(NominationKind.values.byName(n.key), true, [
                  for (final r in n.top) {'player': cell(r.player).toJson(), 'value': r.value}
                ])
            ]
          : [
              for (final MapEntry(key: k, value: rows) in computeNominations(
                      e.games, [for (final s in e.standings) s.player])
                  .entries)
                _nomination(k, false, [
                  for (final r in rows)
                    {
                      'player': cell(r.player).toJson(),
                      'value': k == NominationKind.firstKilled
                          ? '${r.value.round()}'
                          : f2(r.value),
                    }
                ])
            ],
    };

Map<String, Object?> _nomination(
        NominationKind k, bool official, List<Map<String, Object?>> rows) =>
    {
      'key': k.name,
      'icon': _nominations[k]!.$1,
      'label': _nominations[k]!.$2,
      'official': official,
      'rows': rows,
    };

SiteTable _champions(List<AllstarsEvent> events, PlayerResolver resolver,
    SiteCell Function(String) cell) {
  final places = <String, (SiteCell, List<int>, List<int>)>{};
  for (final e in events) {
    for (var i = 0; i < e.standings.length && i < 3; i++) {
      final raw = e.standings[i].player;
      final key = personKey(resolver.resolve(raw));
      final (c, counts, wonYears) = places[key] ?? (cell(raw), [0, 0, 0], <int>[]);
      counts[i]++;
      if (i == 0) wonYears.add(e.year);
      places[key] = (c, counts, wonYears);
    }
  }
  return SiteTable(
    sortColumn: 1,
    showRank: true,
    columns: const [
      SiteColumn('Гравець', numeric: false),
      SiteColumn('1'),
      SiteColumn('2'),
      SiteColumn('3'),
      SiteColumn('Подіуми'),
      SiteColumn('Перемоги', numeric: false),
    ],
    rows: [
      for (final (c, n, years) in places.values)
        [
          c,
          // Ties on wins are broken by 2nd, then 3rd places.
          SiteCell('${n[0]}', s: n[0] * 10000 + n[1] * 100 + n[2]),
          SiteCell('${n[1]}', s: n[1]),
          SiteCell('${n[2]}', s: n[2]),
          SiteCell('${n[0] + n[1] + n[2]}', s: n[0] + n[1] + n[2]),
          SiteCell((years..sort()).join(', ')),
        ]
    ],
  );
}
```

Check `playerResolverProvider`'s import: `tournaments_export.dart` imports it from `package:family_mafia_app/screens/home/home_providers.dart`; if that import doesn't resolve it, grep `final playerResolverProvider` and import that file instead.

- [ ] **Step 4: Run the export test to verify it passes**

Run: `flutter test test/site_export/allstars_export_test.dart`
Expected: PASS (5 tests). If the champions test fails on the «Аглая» row's `[3]`, check that the 2019 table order in the test is `Железный, Nobody Known, Аглая` (Аглая 3rd).

- [ ] **Step 5: Wire it into `writeSiteData` and the export entry point**

In `lib/site_export/site_exporter.dart` add the import and parameter and the write:

```dart
import 'package:family_mafia_app/models/allstars.dart';
import 'package:family_mafia_app/site_export/allstars_export.dart';
```

```dart
Future<void> writeSiteData(ProviderContainer container, Directory out,
    {Future<String?> Function(SeasonConfig)? seasonJson,
    List<AnnualEvent> annualEvents = const [],
    List<AllstarsEvent> allstarsEvents = const []}) async {
```

```dart
  write('annual.json', annualJson(x, annualEvents));
  write('allstars.json', allstarsJson(x, allstarsEvents));
```

In `tool/export_site_data_test.dart`, after `annualEvents`:

```dart
    final allstarsEvents =
        parseAllstars(File('assets/raw/allstars.json').readAsStringSync());
    await writeSiteData(container, out,
        annualEvents: annualEvents, allstarsEvents: allstarsEvents);
```

(replace the existing `await writeSiteData(container, out, annualEvents: annualEvents);` and add `import 'package:family_mafia_app/models/allstars.dart';`).

- [ ] **Step 6: Write the snapshot test**

`test/site_export/allstars_snapshot_test.dart`:

```dart
import 'dart:io';

import 'package:family_mafia_app/models/allstars.dart';
import 'package:family_mafia_app/models/player.dart';
import 'package:family_mafia_app/services/stats/allstars_nominations.dart';
import 'package:family_mafia_app/services/stats/player_resolver.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';

/// The columns whose sum is each computed year's MVP.
const _mvpColumns = {
  2019: ['Допы', 'ЛХ'],
  2022: ['Допы', 'ЛХ'],
  2023: ['ДБ', 'КХ'],
};

double _num(String s) => s.trim().isEmpty ? 0 : double.parse(s.replaceAll(',', '.'));

void main() {
  final events = parseAllstars(File('assets/raw/allstars.json').readAsStringSync());

  test('the five events and their winners', () {
    expect({for (final e in events) e.year: e.standings.first.player}, {
      2019: 'Рауль',
      2022: 'Луна',
      2023: 'Seezov',
      2024: 'Braun',
      2025: 'Tina',
    });
  });

  test('official nominations only for federation years, games for the rest', () {
    for (final e in events) {
      expect(e.nominations == null, _mvpColumns.containsKey(e.year), reason: '${e.year}');
      expect(e.games.isEmpty, e.nominations != null, reason: '${e.year}');
    }
  });

  test('computed MVP equals the final table\'s additional + best-move columns', () {
    for (final e in events.where((e) => _mvpColumns.containsKey(e.year))) {
      final labels = [for (final c in e.columns) c.label];
      final [addCol, bmCol] = [for (final l in _mvpColumns[e.year]!) labels.indexOf(l)];
      final mvp = <String, double>{};
      for (final g in e.games) {
        for (final s in g.seats) {
          mvp[s.player.toLowerCase()] = (mvp[s.player.toLowerCase()] ?? 0) + s.add + s.bestMove;
        }
      }
      for (final s in e.standings) {
        final want = _num(s.values[addCol]) + _num(s.values[bmCol]);
        expect(mvp[s.player.toLowerCase()] ?? 0, closeTo(want, 0.011),
            reason: '${e.year} ${s.player}');
      }
      final n = computeNominations(e.games, [for (final s in e.standings) s.player]);
      expect(n[NominationKind.mvp], isNotEmpty, reason: '${e.year}');
    }
  });

  test('every final-table name is a roster player', () {
    final players = [
      for (final p in (jsonDecode(File('assets/raw/players.json').readAsStringSync()) as List)
          .cast<Map<String, dynamic>>())
        Player.fromJson(p)
    ];
    final resolver = PlayerResolver(players);
    for (final e in events) {
      for (final s in e.standings) {
        expect(resolver.resolve(s.player).id, greaterThanOrEqualTo(0),
            reason: '${e.year}: «${s.player}» is not in assets/raw/players.json');
      }
    }
  });
}
```

If `Player.fromJson` doesn't exist, use whatever `fixture.dart`'s loader uses to parse `players.json` (grep `players.json` in `lib/`), not a hand-rolled parser.

- [ ] **Step 7: Run the snapshot and export tests**

Run: `flutter test test/site_export/allstars_snapshot_test.dart test/site_export/allstars_export_test.dart test/site_export/site_exporter_test.dart`
Expected: PASS. A failing roster name in a sheet year (e.g. «Joi», «Кантариан») means the roster lacks it: add it as a nickname of the right player on `/players/edit/` only if the user confirms who it is; otherwise list it in the test as a known non-roster name with a comment — do not rename it in the snapshot.

- [ ] **Step 8: Commit**

```bash
git add lib/site_export/allstars_export.dart lib/site_export/site_exporter.dart tool/export_site_data_test.dart test/site_export/allstars_export_test.dart test/site_export/allstars_snapshot_test.dart
git commit -m "feat: export the all-star tournaments for the site"
```

---

### Task 4: Pages

**Files:**
- Modify: `site/src/lib/types.ts`, `site/src/lib/data.ts`, `site/src/layouts/Base.astro`
- Create: `site/src/components/NominationCards.astro`, `site/src/components/AllstarsEvent.astro`, `site/src/pages/allstars/index.astro`, `site/src/pages/allstars/[year].astro`

**Interfaces:**
- Consumes: `site/data/allstars.json` (Task 3 shape), `DataTable`, `Panel`, `PlayerName`, `Base`, `href`.
- Produces: routes `/allstars/` and `/allstars/<year>/` for every year.

- [ ] **Step 1: Types and loader**

Append to `site/src/lib/types.ts`:

```ts
export interface AllstarsNomination {
  key: 'mvp' | 'firstKilled' | 'bestRed' | 'bestMafia';
  icon: string; label: string; official: boolean;
  rows: { player: SiteCell; value: string }[];
}
export interface AllstarsEventData {
  year: number; name: string; date?: string; hostLabel: string; host?: string; source?: string;
  players: number; games: number; podium: SiteCell[]; table: SiteTable; nominations: AllstarsNomination[];
}
export interface AllstarsData { events: AllstarsEventData[]; champions: SiteTable }
```

In `site/src/lib/data.ts` add `AllstarsData` to the type import and:

```ts
export const loadAllstars = () => read<AllstarsData>('allstars.json');
```

- [ ] **Step 2: Nomination cards**

`site/src/components/NominationCards.astro`:

```astro
---
import type { AllstarsNomination } from '../lib/types';
import PlayerName from './PlayerName.astro';

interface Props { nominations: AllstarsNomination[] }
const { nominations } = Astro.props;
---
<div class="cards">
  {nominations.map((n) => (
    <article class={`card n-${n.key}`}>
      <div class="title"><span class="icon" aria-hidden="true">{n.icon}</span><span>{n.label}</span></div>
      <ol>
        {n.rows.map((r, i) => (
          <li class={i === 0 ? 'first' : undefined}>
            <span class="who">{r.player.link ? <PlayerName slug={r.player.link} name={r.player.t} /> : r.player.t}</span>
            <span class="num">{r.value}</span>
          </li>
        ))}
      </ol>
      {!n.official && <div class="note">пораховано з ігор</div>}
    </article>
  ))}
</div>

<style>
  .cards { display: grid; grid-template-columns: repeat(auto-fill, minmax(200px, 1fr)); gap: 10px; }
  .n-mvp { --c: var(--award-mvp); } .n-firstKilled { --c: var(--city); }
  .n-bestRed { --c: var(--award-civilian); } .n-bestMafia { --c: var(--mafia); }
  .card { border: 1px solid color-mix(in srgb, var(--c) 35%, var(--border)); border-radius: 10px;
    background: linear-gradient(160deg, color-mix(in srgb, var(--c) 13%, var(--panel)) 0%, var(--panel) 70%);
    padding: 12px 14px; display: grid; gap: 8px; align-content: start; min-width: 0; }
  .title { display: flex; gap: 8px; align-items: center; font-weight: 600; }
  .icon { font-size: 18px; }
  ol { list-style: none; margin: 0; padding: 0; display: grid; gap: 4px; }
  li { display: flex; justify-content: space-between; gap: 8px; color: var(--muted); }
  li.first { color: var(--text); font-weight: 600; }
  .who { min-width: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .note { color: var(--muted); font-size: 11px; }
</style>
```

- [ ] **Step 3: Year page component and routes**

`site/src/components/AllstarsEvent.astro`:

```astro
---
import Base from '../layouts/Base.astro';
import DataTable from './DataTable.astro';
import NominationCards from './NominationCards.astro';
import Panel from './Panel.astro';
import type { AllstarsData, AllstarsEventData } from '../lib/types';
import { href } from '../lib/url';

interface Props { data: AllstarsData; e: AllstarsEventData }
const { data, e } = Astro.props;
const meta = [e.date, e.host && `${e.hostLabel}: ${e.host}`, `${e.players} гравців · ${e.games} ігор`].filter(Boolean);
---
<Base title={`${e.name} — Річні турніри`} description={`${e.name}: переможець ${e.podium[0]?.t ?? '—'}, підсумкова таблиця і номінації.`} active="allstars">
  <div class="pagehead">
    <h1 class="display">{e.name}</h1>
    <p class="meta">{meta.join(' · ')}{e.source && <> · <a href={e.source} rel="noopener">Результати на emotion.games</a></>}</p>
    <nav class="years">
      <a href={href('allstars/')}>Усі роки</a>
      {data.events.map((o) => (
        <a href={href(`allstars/${o.year}/`)} aria-current={o.year === e.year ? 'page' : undefined}>{o.year}</a>
      ))}
    </nav>
  </div>
  <div class="grid">
    <Panel title="Номінації" class="span-12"><NominationCards nominations={e.nominations} /></Panel>
    <Panel title="Підсумкова таблиця" class="span-12"><DataTable table={e.table} /></Panel>
  </div>
</Base>

<style>
  .meta { color: var(--muted); margin: 4px 0 0; }
  .years { display: flex; flex-wrap: wrap; gap: 6px 12px; margin-top: 10px; }
  .years a[aria-current] { font-weight: 700; color: var(--text); }
</style>
```

`site/src/pages/allstars/[year].astro`:

```astro
---
import AllstarsEvent from '../../components/AllstarsEvent.astro';
import { loadAllstars } from '../../lib/data';

export function getStaticPaths() {
  const data = loadAllstars();
  return data.events.map((e) => ({ params: { year: String(e.year) }, props: { data, e } }));
}
const { data, e } = Astro.props;
---
<AllstarsEvent data={data} e={e} />
```

- [ ] **Step 4: Index page**

`site/src/pages/allstars/index.astro`:

```astro
---
import Base from '../../layouts/Base.astro';
import DataTable from '../../components/DataTable.astro';
import Panel from '../../components/Panel.astro';
import PlayerName from '../../components/PlayerName.astro';
import { loadAllstars } from '../../lib/data';
import { href } from '../../lib/url';

const d = loadAllstars();
---
<Base title="Річні турніри" description="Royal Battle і Family All Stars: переможці, підсумкові таблиці й номінації кожного року." active="allstars">
  <div class="pagehead"><h1 class="display">Річні турніри</h1></div>
  <div class="years">
    {d.events.map((e) => (
      <a class="year" href={href(`allstars/${e.year}/`)}>
        <div class="top"><span class="display y">{e.year}</span><span class="label">{e.name}</span></div>
        <ol class="podium">
          {e.podium.map((p, k) => (
            <li class={`p${k + 1}`}><i aria-hidden="true">{k + 1}</i>{p.t}</li>
          ))}
        </ol>
        <div class="meta label">{[e.date, e.host && `${e.hostLabel}: ${e.host}`, `${e.players} гравців · ${e.games} ігор`].filter(Boolean).join(' · ')}</div>
      </a>
    ))}
  </div>
  <div class="grid">
    <Panel title="Чемпіони" note="За перемогами, далі за 2-ми і 3-ми місцями" class="span-12">
      <DataTable table={d.champions} compact />
    </Panel>
  </div>
</Base>

<style>
  .years { display: grid; grid-template-columns: repeat(auto-fill, minmax(240px, 1fr)); gap: 10px; margin-bottom: 16px; }
  .year { display: grid; gap: 8px; padding: 14px 16px; border: 1px solid var(--border); border-radius: var(--radius);
    background: var(--panel); color: inherit; text-decoration: none; min-width: 0; }
  .year:hover { border-color: var(--gold); }
  .top { display: flex; align-items: baseline; gap: 10px; }
  .y { font-size: 22px; }
  .podium { list-style: none; margin: 0; padding: 0; display: grid; gap: 2px; }
  .podium li { display: flex; gap: 8px; align-items: center; color: var(--muted); }
  .podium li.p1 { color: var(--text); font-weight: 700; font-size: 17px; }
  .podium i { font-style: normal; width: 18px; height: 18px; border-radius: 50%; display: grid; place-items: center; font-size: 11px; }
  .p1 i { background: var(--gold); color: #000; } .p2 i { background: var(--silver); color: #000; } .p3 i { background: var(--bronze); color: #000; }
  .meta { color: var(--muted); }
</style>
```

The cards are links themselves, so podium names are plain text here (no nested links); the year page and the champions table link to profiles.

Check that `--bronze` exists in `site/src/styles/global.css` (grep `--bronze`); `AwardCards.astro` uses `--bronze-text`. Use whichever background token the tournaments page uses for its 3rd-place badge (`.place.p3 i` in `tournaments/index.astro`) — copy those three rules instead of the ones above if they differ.

- [ ] **Step 5: Nav**

In `site/src/layouts/Base.astro`, after the `tournaments` entry:

```ts
  { key: 'allstars', label: 'All Stars', url: href('allstars/') },
```

If `active` is typed as a union of keys, add `'allstars'` to it.

- [ ] **Step 6: Export data, type-check, test and build**

Run (repo root): `flutter test tool/export_site_data_test.dart`
Expected: PASS; `site/data/allstars.json` exists with 5 events.

Run: `cd site && npm run check && npm test && npm run build`
Expected: `astro check` 0 errors; vitest passes; `check-dist: … all links resolve`.

- [ ] **Step 7: Look at it**

Run `cd site && npm run preview`, open `/FamilyMafiaApp/allstars/` and `/FamilyMafiaApp/allstars/2023/`, `/2025/` in Chrome: dark and light theme (header toggle), and at 390 px width — no horizontal page scroll, the final table scrolls inside its panel, nomination cards stack. Stop `astro preview` afterwards (it locks a `.node` file on Windows).

- [ ] **Step 8: Commit**

```bash
git add site/src
git commit -m "feat: Річні турніри pages on the site"
```

---

### Task 5: Docs and ship

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Document**

Add under "## Web site", after the **Annual rating** bullet:

```markdown
- **All-star tournaments («Річні турніри»):** `/allstars/` (+ `/allstars/<year>/`) from
  `site/data/allstars.json` (`lib/site_export/allstars_export.dart`). Source is the committed
  `assets/raw/allstars.json`: Royal Battle '19 and FAS 2022–2023 written once from the sheets by
  `tool/import/make_allstars.py` (final table as is + games for the nominations, computed by
  `lib/services/stats/allstars_nominations.dart` the federation's way); FAS 2024+ copied by hand from
  emotion.games results pages with their official nominations, names in the roster's spelling. A new
  year = append an entry by hand (`"games": []`, `"nominations"` from the federation page).
```

- [ ] **Step 2: Full test run**

Run: `flutter analyze && flutter test`
Expected: no new analyzer issues; all tests pass.

- [ ] **Step 3: Commit and push both branches**

```bash
git add CLAUDE.md
git commit -m "docs: all-star tournaments in CLAUDE.md"
git push origin feature/flutter_migration
git checkout master && git merge --ff-only feature/flutter_migration && git push origin master && git checkout feature/flutter_migration
```

If `--ff-only` fails, master has diverged: stop and ask the user (no force-push).

- [ ] **Step 4: Verify the deploy**

Wait for the `web.yml` run on `feature/flutter_migration` to finish (`gh run list --workflow web.yml --limit 1`), then open https://seezov.github.io/FamilyMafiaApp/allstars/ and one year page.

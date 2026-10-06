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

# Sheet spellings the roster doesn't know, written in the roster's spelling
# (the federation years are copied by hand the same way).
ALIASES = {'StoneCold': 'Stone Cold'}


def alias(name):
    return ALIASES.get(name, name)


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
        out.append({'player': alias(r[1]), 'values': [cell(r, 2 + i) for i in range(len(labels))]})
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
            {'player': alias(cell(r, player)), 'role': ROLES[cell(r, role).lower()],
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
            {'player': alias(cell(r, 1)), 'role': ROLES[cell(r, 2).lower()],
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

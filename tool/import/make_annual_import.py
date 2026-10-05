# One-time: snapshot the sheets' «Турніри» blocks (2024–2026) for the annual-rating import.
# Usage: SHEETS_API_KEY=... python tool/import/make_annual_import.py
import datetime, json, os, urllib.parse, urllib.request

KEY = os.environ['SHEETS_API_KEY']
YEARS = {2024: '1Vhw0fURnqQyluJYJEuwJeq5amicGWk3jXsId3gxYoys',   # S23 sheet
         2025: '1J1PwfQvCai21fa_rDRkC10bXIeaVCBiHsC0onXXYXBU',   # S27 sheet
         2026: '1vSyEfRhBowqfzpsPkcQYmlFFnjO819kL1fhC8jo7D5k'}   # S31 sheet
KINDS = {'Турнір': 'tournament', 'Серія': 'series', 'Марафон': 'marathon', 'Сезон': 'season'}


def grid(sheet, tab, rng):
    url = (f'https://sheets.googleapis.com/v4/spreadsheets/{sheet}?ranges='
           f'{urllib.parse.quote(tab)}!{rng}&includeGridData=true'
           f'&fields=sheets.data.rowData.values(formattedValue,effectiveValue)&key={KEY}')
    data = json.load(urllib.request.urlopen(url))
    out = []
    for r in data['sheets'][0]['data'][0].get('rowData', []):
        row = []
        for v in r.get('values', []):
            ev = v.get('effectiveValue', {})
            row.append(ev.get('numberValue', ev.get('stringValue', v.get('formattedValue', ''))))
        out.append(row)
    return out


def cell(r, j):
    return r[j] if j < len(r) else ''


def as_int(v):
    if v in ('', None):
        return None
    return int(float(v))


def as_date(v):
    if v in ('', None):
        return None
    if isinstance(v, (int, float)):  # sheet serial day
        return (datetime.date(1899, 12, 30) + datetime.timedelta(days=int(v))).isoformat()
    s = str(v).strip()
    for fmt in ('%Y-%m-%d', '%m/%d/%Y', '%d.%m.%Y'):
        try:
            return datetime.datetime.strptime(s, fmt).date().isoformat()
        except ValueError:
            pass
    raise ValueError(f'unknown date {s!r}')


events, seasons2026, totals, cases = [], [], {}, {}
for year, sheet in YEARS.items():
    g = grid(sheet, 'Турніри', 'A1:J1600')
    i = 0
    while i < len(g):
        r = g[i]
        if cell(r, 2) != 'Дата' or cell(r, 0) not in KINDS:
            i += 1
            continue
        kind = KINDS[cell(r, 0)]
        meta = g[i + 1] if i + 1 < len(g) else []
        stars, n = as_int(cell(meta, 1)), as_int(cell(meta, 3))
        results, j = [], i + 3
        while j < len(g) and cell(g[j], 2) != 'Дата':
            name, place, pts = cell(g[j], 0), cell(g[j], 1), cell(g[j], 3)
            if isinstance(name, str) and name.strip() and place != '':
                results.append({'player': name.strip(), 'place': int(place)})
                key = (kind, int(place), stars if kind == 'tournament' else None,
                       n if kind == 'tournament' else None)
                cases[key] = pts
            j += 1
        if results:
            if kind == 'tournament':
                assert stars is not None and n, f'{year} {cell(r, 1)}: tournament without stars/participants'
            ev = {'year': year, 'kind': kind, 'name': str(cell(r, 1)).strip() or f'{cell(r, 0)} {year}',
                  'date': as_date(cell(r, 3)),
                  'stars': stars if kind == 'tournament' else None,
                  'participants': n if kind == 'tournament' else None,
                  'results': results}
            (seasons2026 if year == 2026 and kind == 'season' else events).append(ev)
        i = j
    a = grid(sheet, 'Річний рейтинг', 'B6:C200')
    totals[str(year)] = {str(r[0]).strip(): r[1] for r in a
                         if len(r) > 1 and str(r[0]).strip() and isinstance(r[1], (int, float)) and r[1] > 0}

os.makedirs('tool/import', exist_ok=True)


def dump(path, obj):
    with open(path, 'w', encoding='utf-8', newline='\n') as f:
        json.dump(obj, f, ensure_ascii=False, indent=1)
        f.write('\n')


dump('tool/import/annual_events.json', events)
dump('test/fixtures/annual_2026_seasons.json', seasons2026)
dump('test/fixtures/annual_totals.json', totals)
dump('test/fixtures/annual_points_cases.json',
     [{'kind': k, 'place': p, 'stars': s, 'participants': n, 'points': v}
      for (k, p, s, n), v in sorted(cases.items(), key=lambda x: (x[0][0], x[0][1], x[0][2] or 0, x[0][3] or 0))])
print(len(events), 'events,', len(seasons2026), '2026 season blocks,', len(cases), 'point cases')

#!/usr/bin/env python3
"""Сверка двух трасс tools/trace.js: python3 tools/trace_cmp.py A.json B.json [--ru] -> 0 = совпали.
--noscreen: экран не сверяется (дисковая сборка в 16 цветах против картриджа: хэши экрана разные).
--ru: A — трасса английской сборки, B — русской. Экран и текстовые переменные не сверяются
(RU_SKIP: строки сообщений, имена, названия наборов — другой язык), коды клавиш K$/KQ$/K2$/KA
из A переводятся по раскладке русской версии (Z -> A авто, X -> B буй, Q -> M меню);
все числовые переменные, точки ожидания и нажатые клавиши — как обычно."""
import json, sys
RU = '--ru' in sys.argv
NOSCREEN = RU or '--noscreen' in sys.argv
RU_SKIP = {'sMS', 'sSS', 'sES', 'sT', 'bRT', 'sRN', 'sBM', 'ARR_N'}
RU_KEYS = {'bK_', 'bKQ', 'bK2', 'bKA'}   # K$, KQ$, K2$, KA=ASC(K$)
KMAP = {'5a': '41', '58': '42', '51': '4d'}
a, b = (json.load(open(f)) for f in [x for x in sys.argv[1:] if not x.startswith('--')][:2])
ta, tb = a['trace'], b['trace']
n = min(len(ta), len(tb))
for i in range(n):
    x, y = ta[i], tb[i]
    diffs = []
    if x['where'] != y['where']: diffs.append('ожидание %s / %s' % (x['where'], y['where']))
    kx = {'z': 'a', 'x': 'b', 'q': 'm'}.get(x.get('key'), x.get('key')) if RU else x.get('key')
    if kx != y.get('key'): diffs.append('клавиша %s / %s' % (x.get('key'), y.get('key')))
    if x['vram'] != y['vram'] and not NOSCREEN: diffs.append('экран')
    for k in sorted(set(x['vars']) | set(y['vars'])):
        vx, vy = x['vars'].get(k), y['vars'].get(k)
        if RU and k in RU_SKIP: continue
        if RU and k in RU_KEYS and isinstance(vx, str): vx = KMAP.get(vx, vx)
        if vx != vy: diffs.append('переменная ' + k)
    if diffs:
        print('правило %s, шаг %d: %s' % (a['rules'], i, ', '.join(diffs[:12]))); sys.exit(1)
if len(ta) != len(tb):
    print('правило %s: длина трасс %d / %d' % (a['rules'], len(ta), len(tb))); sys.exit(1)
print('правило %s: совпало %d шагов' % (a['rules'], n))

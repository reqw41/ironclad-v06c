#!/usr/bin/env python3
"""Сверка двух трасс tools/trace.js: python3 tools/trace_cmp.py A.json B.json -> 0 = совпали."""
import json, sys
a, b = (json.load(open(f)) for f in sys.argv[1:3])
ta, tb = a['trace'], b['trace']
n = min(len(ta), len(tb))
for i in range(n):
    x, y = ta[i], tb[i]
    diffs = []
    if x['where'] != y['where']: diffs.append('ожидание %s / %s' % (x['where'], y['where']))
    if x.get('key') != y.get('key'): diffs.append('клавиша %s / %s' % (x.get('key'), y.get('key')))
    if x['vram'] != y['vram']: diffs.append('экран')
    for k in sorted(set(x['vars']) | set(y['vars'])):
        if x['vars'].get(k) != y['vars'].get(k): diffs.append('переменная ' + k)
    if diffs:
        print('правило %s, шаг %d: %s' % (a['rules'], i, ', '.join(diffs[:12]))); sys.exit(1)
if len(ta) != len(tb):
    print('правило %s: длина трасс %d / %d' % (a['rules'], len(ta), len(tb))); sys.exit(1)
print('правило %s: совпало %d шагов' % (a['rules'], n))

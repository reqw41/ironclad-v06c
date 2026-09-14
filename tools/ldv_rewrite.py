#!/usr/bin/env python3
"""Перевод обращений к байтам страницы переменных на LDV/STV (см. src/macros.asm):
   ld a,(v[+n]) -> LDV v[+n];  ld (v[+n]),a -> STV v[+n]  — для меток из build/ironclad.sld,
   лежащих в [varpage, varpage_end). Файлы — аргументами. Печатает число замен."""
import re, sys
L = {}
for l in open('build/ironclad.sld', encoding='latin1'):
    p = l.rstrip('\n').split('|')
    if len(p) >= 8 and p[6] == 'L':
        n = p[7].split(',')[1]
        if n and n not in L: L[n] = int(p[5])
lo, hi = L['varpage'], L['varpage_end']
page = {n for n, a in L.items() if lo <= a < hi and n not in ('varpage', 'varpage_end')}
ld = re.compile(r'^(\s*(?:[A-Za-z_]\w*:)?\s*)ld\s+a,\(\s*([A-Za-z_]\w*)(\s*\+\s*\d+)?\s*\)(\s*(?:;.*)?)$')
st = re.compile(r'^(\s*(?:[A-Za-z_]\w*:)?\s*)ld\s+\(\s*([A-Za-z_]\w*)(\s*\+\s*\d+)?\s*\),\s*a(\s*(?:;.*)?)$')
tot = 0
for f in sys.argv[1:]:
    out = []; n = 0
    for line in open(f, encoding='utf8').read().split('\n'):
        for rx, op in ((ld, 'LDV'), (st, 'STV')):
            m = rx.match(line)
            if m and m.group(2) in page:
                arg = m.group(2) + (m.group(3) or '').replace(' ', '')
                pre = m.group(1)
                line = pre + op + '  ' + arg + m.group(4)
                n += 1
                break
        out.append(line)
    open(f, 'w', encoding='utf8').write('\n'.join(out))
    print(f, n); tot += n
print('всего', tot)

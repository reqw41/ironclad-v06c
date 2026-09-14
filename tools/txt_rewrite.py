#!/usr/bin/env python3
"""Перевод строк db "...",0 на TXT "..." (сжатие словарём, см. src/macros.asm).
Не трогаются: метки sh_*, rs_*, sm_* (имена кораблей, наборов, матчей — стенд трассы
читает их по указателям как есть), строки без 0 сразу за ними. Смешанные db (числа и
строки) разбиваются: числа — db, каждая "строка",0 — отдельной TXT."""
import re, sys
SKIP = re.compile(r'^(sh_|rs_|sm_)')
def ops(s):
    out, cur, q = [], '', False
    for ch in s:
        if ch == '"': q = not q
        if ch == ',' and not q: out.append(cur.strip()); cur = ''
        else: cur += ch
    if cur.strip(): out.append(cur.strip())
    return out
tot = 0
for f in sys.argv[1:]:
    res = []
    for line in open(f, encoding='utf8').read().split('\n'):
        code, sep, com = line.partition(';') if '"' not in line.partition(';')[2] else (line, '', '')
        m = re.match(r'^(\s*)([A-Za-z_]\w*:)?(\s*)db\s+(.*?)\s*$', code)
        if not m or '"' not in m.group(4) or (m.group(2) and SKIP.match(m.group(2))):
            res.append(line); continue
        o = ops(m.group(4))
        if not any(o[i].startswith('"') and i + 1 < len(o) and o[i+1] == '0' for i in range(len(o))):
            res.append(line); continue
        ind = ' ' * len(m.group(1) + (m.group(2) or '') + m.group(3))
        lab = m.group(1) + (m.group(2) or '') + m.group(3)
        parts = []; nums = []; i = 0
        while i < len(o):
            if o[i].startswith('"') and i + 1 < len(o) and o[i+1] == '0':
                if nums: parts.append('db   ' + ','.join(nums)); nums = []
                parts.append('TXT  ' + o[i]); i += 2; tot += 1
            else: nums.append(o[i]); i += 1
        if nums: parts.append('db   ' + ','.join(nums))
        for k, p in enumerate(parts):
            res.append((lab if k == 0 else ind) + p + (('  ;' + com) if (sep and k == 0) else ''))
    open(f, 'w', encoding='utf8').write('\n'.join(res))
print('строк TXT:', tot)

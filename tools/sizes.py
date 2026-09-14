#!/usr/bin/env python3
"""Размеры образа по файлам исходника (по листингу build/ironclad.lst): python3 tools/sizes.py [-l] 
   -l — ещё и по меткам верхнего уровня (самые крупные)."""
import re, sys, collections
stack = []; cur = None; prev = None; sz = collections.Counter(); lab = collections.Counter(); curlab = None
rx = re.compile(r'^\s*\d+\+*\s+([0-9A-F]{4})')
for l in open('build/ironclad.lst', encoding='utf8', errors='replace'):
    if l.startswith('# file opened: '): stack.append(l[15:].strip()); continue
    if l.startswith('# file closed: '): stack.pop(); continue
    m = rx.match(l)
    if not m: continue
    a = int(m.group(1), 16)
    if prev is not None and cur is not None and 0x100 <= prev[0] < 0x8000 and a > prev[0] and a - prev[0] < 0x2000:
        sz[prev[1]] += a - prev[0]
        if prev[2]: lab[prev[2]] += a - prev[0]
    rest = l[m.end():]
    mm = re.match(r'(?:\s[0-9A-F]{2})*(?:\.\.\.)?\s+([A-Za-z_][A-Za-z0-9_]*):', rest)
    if mm: curlab = (stack[-1].split('/')[-1] if stack else '?') + ':' + mm.group(1)
    cur = stack[-1] if stack else None
    prev = (a, cur, curlab)
tot = 0
for f, n in sz.most_common(): print('%6d  %s' % (n, f)); tot += n
print('%6d  всего' % tot)
if '-l' in sys.argv:
    for k, n in lab.most_common(int(sys.argv[-1]) if sys.argv[-1].isdigit() else 60): print('%6d  %s' % (n, k))

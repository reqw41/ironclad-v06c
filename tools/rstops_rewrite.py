#!/usr/bin/env python3
"""Перевод пар команд на RST-операции страницы переменных (см. src/macros.asm, util.asm):
   ld hl,v / inc (hl)   -> INCV v      (HL = &v, флаги — от inc)
   LDV v / cp K         -> CPV v,K     (A = v, флаги — от cp)
   ld a,K / STV v       -> SETV v,K    (A = K, флаги не меняются)
   xor a / STV v        -> ZEROV v     (A = 0, флаги — как у xor a)
   rst 10h/18h/20h/28h  -> call gfx_pset/gfx_puts/gfx_fill/ms_set
Вторая команда пары не должна нести метку. v — метка страницы переменных (по build/ironclad.sld)."""
import re, sys
L = {}
for l in open('build/ironclad.sld', encoding='latin1'):
    p = l.rstrip('\n').split('|')
    if len(p) >= 8 and p[6] == 'L':
        n = p[7].split(',')[1]
        if n and n not in L: L[n] = int(p[5])
lo, hi = L['varpage'], L['varpage_end']
page = {n for n, a in L.items() if lo <= a < hi and n not in ('varpage', 'varpage_end')}
LAB = r'^(\s*(?:[A-Za-z_]\w*:)?\s*)'
def split(line):
    code, sep, com = line.partition(';')
    return code.rstrip(), (sep + com)
RST = {'10h': 'gfx_pset', '18h': 'gfx_puts', '20h': 'gfx_fill', '28h': 'ms_set'}
tot = {}
for f in sys.argv[1:]:
    src = open(f, encoding='utf8').read().split('\n')
    out = []; i = 0
    while i < len(src):
        a = src[i]; ca, coma = split(a)
        m = re.match(LAB + r'rst\s+(10h|18h|20h|28h)$', ca)
        if m:
            out.append(m.group(1) + 'call ' + RST[m.group(2)] + (' ' + coma if coma else '')); tot['call'] = tot.get('call', 0) + 1; i += 1; continue
        if i + 1 < len(src):
            b = src[i + 1]; cb, comb = split(b)
            if not re.match(r'^\s*[A-Za-z_]\w*:', cb):
                com = ' '.join(x for x in (coma.strip(), comb.strip()) if x)
                com = ('  ' + com) if com else ''
                m1 = re.match(LAB + r'ld\s+hl,([A-Za-z_]\w*)$', ca); m2 = re.match(r'^\s*inc\s+\(hl\)$', cb)
                if m1 and m2 and m1.group(2) in page:
                    out.append(m1.group(1) + 'INCV ' + m1.group(2) + com); tot['INCV'] = tot.get('INCV', 0) + 1; i += 2; continue
                m1 = re.match(LAB + r'LDV\s+(\S+)$', ca); m2 = re.match(r'^\s*cp\s+(\S+)$', cb)
                if m1 and m2 and not re.match(r'^(a|b|c|d|e|h|l|\(hl\))$', m2.group(1)):
                    out.append(m1.group(1) + 'CPV  ' + m1.group(2) + ',' + m2.group(1) + com); tot['CPV'] = tot.get('CPV', 0) + 1; i += 2; continue
                m1 = re.match(LAB + r'ld\s+a,(\S+)$', ca); m2 = re.match(r'^\s*STV\s+(\S+)$', cb)
                if m1 and m2 and not re.match(r'^(a|b|c|d|e|h|l|\(.*\))$', m1.group(2)):
                    out.append(m1.group(1) + 'SETV ' + m2.group(1) + ',' + m1.group(2) + com); tot['SETV'] = tot.get('SETV', 0) + 1; i += 2; continue
                m1 = re.match(LAB + r'xor\s+a$', ca)
                if m1 and m2:
                    out.append(m1.group(1) + 'ZEROV ' + m2.group(1) + com); tot['ZEROV'] = tot.get('ZEROV', 0) + 1; i += 2; continue
        out.append(a); i += 1
    open(f, 'w', encoding='utf8').write('\n'.join(out))
print(tot)

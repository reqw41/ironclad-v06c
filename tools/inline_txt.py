#!/usr/bin/env python3
"""Однократные строки TXT переносятся прямо за вызов (строка после call, продолжение — за ней):
   ld hl,s / call ms_set / call L1305 -> call msg1i / TXT "..."
   ld hl,s / call ms_set / call L1315 -> call msg2i / TXT "..."
   ld hl,s / call ms_set              -> call ms_seti / TXT "..."
   ld hl,s / call ms_cat              -> call ms_cati / TXT "..."
   ld hl,s / call gfx_puts            -> call putsi / TXT "..."
Строка-определение (метка: TXT "...") удаляется, если на метку больше нет ссылок."""
import re, sys, glob
files = sys.argv[1:]
src = {f: open(f, encoding='utf8').read().split('\n') for f in files}
alltext = '\n'.join('\n'.join(v) for v in src.values())
defs = {}
for f, L in src.items():
    for i, l in enumerate(L):
        m = re.match(r'^([A-Za-z_]\w*):\s*TXT\s+("[^"]*")\s*(;.*)?$', l)
        if m: defs[m.group(1)] = (f, i, m.group(2))
def refs(name): return len(re.findall(r'\b%s\b' % name, alltext)) - 1
def code(l): return l.split(';')[0].strip()
PAT = [(['call ms_set', 'call L1305'], 'msg1i'), (['call ms_set', 'call L1315'], 'msg2i'),
       (['call ms_set'], 'ms_seti'), (['call ms_cat'], 'ms_cati'), (['call gfx_puts'], 'putsi')]
done = 0; drop = []
for f, L in src.items():
    out = []; i = 0
    while i < len(L):
        l = L[i]
        m = re.match(r'^(\s*(?:[A-Za-z_]\w*:)?\s*)ld\s+hl,([A-Za-z_]\w*)\s*(;.*)?$', l)
        if m and m.group(2) in defs and refs(m.group(2)) == 1:
            for seq, h in PAT:
                nxt = [code(x) for x in L[i+1:i+1+len(seq)]]
                nxl = [re.match(r'^\s*[A-Za-z_]\w*:', x) for x in L[i+1:i+1+len(seq)]]
                if [re.sub(r'\s+', ' ', x) for x in nxt] == seq and not any(nxl):
                    pre = m.group(1); com = (' ' + m.group(3)) if m.group(3) else ''
                    ind = ' ' * len(pre)
                    out.append(pre + 'call ' + h + com)
                    out.append(ind + 'TXT  ' + defs[m.group(2)][2])
                    drop.append(m.group(2)); i += 1 + len(seq); done += 1
                    break
            else:
                out.append(l); i += 1
            continue
        out.append(l); i += 1
    src[f] = out
for name in drop:
    for f, L in src.items():
        src[f] = [l for l in L if not re.match(r'^%s:\s*TXT\s' % name, l)]
for f, L in src.items(): open(f, 'w', encoding='utf8').write('\n'.join(L))
print('перенесено строк:', done)

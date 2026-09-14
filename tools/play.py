#!/usr/bin/env python3
"""Автопартия на стенде: выбрать правила в меню, авторасстановка, стрельба змейкой по сетке.

    python3 tools/play.py [--rules N] [--shots K] [--every M] [--out build/play]
      --rules N  : сколько раз нажать «вправо» в меню (0 SALVO, 1 SALVO PLUS, 2 BARRAGE,
                   3 CLASSIC, 4 PURSUIT, 5 STEALTH, 6 ANKA)
      --shots K  : сколько выстрелов сделать (по умолчанию 100)
      --every M  : снимок каждые M выстрелов
Синхронизация — по метке L1410 (игра ждёт клавишу), а не по времени.
"""
import argparse, subprocess, sys, os

ap = argparse.ArgumentParser()
ap.add_argument('--rules', type=int, default=3)
ap.add_argument('--shots', type=int, default=100)
ap.add_argument('--every', type=int, default=20)
ap.add_argument('--out', default='build/play')
ap.add_argument('--rom', default='build/ironclad.rom')
ap.add_argument('--tail', default='')
a = ap.parse_args()
os.makedirs(a.out, exist_ok=True)
cmd = ['until S3540 900']
cmd += ['k right'] * a.rules
cmd += ['w 5', 's %s/menu.png' % a.out, 'k space', 'until L1410 3000', 'w 2', 'k z']
# змейка: по строке вправо, на следующей строке влево
order = []
for r in range(10):
    cols = range(10) if r % 2 == 0 else range(9, -1, -1)
    for c in cols:
        order.append((c, r))
# курсор после Z стоит где попало: сначала в угол A1
cmd += ['until L1410 3000'] + ['k left 2', 'until L1410 3000'] * 9 + ['k up 2', 'until L1410 3000'] * 9
cx, cy = 0, 0
for n, (c, r) in enumerate(order[:a.shots]):
    while cx < c:
        cmd += ['k right 2', 'until L1410 3000']; cx += 1
    while cx > c:
        cmd += ['k left 2', 'until L1410 3000']; cx -= 1
    while cy < r:
        cmd += ['k down 2', 'until L1410 3000']; cy += 1
    cmd += ['k space 2', 'until L1410 6000']
    if (n + 1) % a.every == 0:
        cmd += ['s %s/shot%03d.png' % (a.out, n + 1)]
if a.tail:
    cmd += a.tail.split(';')
cmd += ['w 30', 's %s/end.png' % a.out]
r = subprocess.run(['node', 'tools/vshot.js', a.rom, ';'.join(cmd)], capture_output=True, text=True)
lines = [l for l in (r.stdout + r.stderr).splitlines() if 'НЕ достигнута' in l or 'снимок' in l or 'итого' in l or 'Error' in l]
print('\n'.join(lines[-30:]))

#!/usr/bin/env python3
# Синтетические потоки ZX0 для проверки распаковщика (tools/zx0test.js ... build/zx0synth):
# данные с краевыми случаями -> build/zx0synth/*.bin, сжатие tools/salvador (ZX0 v2) -> *.zx0.
# Каждый поток разбирается эталонным декодером (здесь же, на Python): он сверяет распаковку
# с .bin и считает, какие краевые случаи в потоках действительно встретились. Если какой-то
# случай не встретился ни разу — выход 1 (проверка была бы неполной).
#   python3 tools/zx0synth.py
import os, random, subprocess, sys, collections

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'build', 'zx0synth')
SALVADOR = os.path.join(ROOT, 'tools', 'salvador')
MAXOUT = 32768                      # приёмник стенда — $8000..$FFFF

def parse(d, cov):
    """эталонный декодер ZX0 v2; cov — счётчик краевых случаев"""
    pos = 0; mask = 0; bv = 0; out = bytearray(); last = 1; prev = 'start'
    def bit():
        nonlocal pos, mask, bv
        if mask == 0: bv = d[pos]; pos += 1; mask = 0x80
        b = 1 if bv & mask else 0; mask >>= 1; return b
    def elias(v=1, inv=0):
        while not bit(): v = (v << 1) | (bit() ^ inv)
        return v
    def copy(off, n):
        if off > len(out): raise ValueError('смещение за началом')
        for _ in range(n): out.append(out[-off])
    while True:
        n = elias(); cov['литералы'] += 1
        if n > 255: cov['литералы > 255'] += 1
        if n == 256: cov['литералы = 256'] += 1
        if n > 256: cov['литералы > 256'] += 1
        out += d[pos:pos + n]; pos += n; prev = 'lit'
        if not bit():
            n = elias(); copy(last, n); cov['повтор смещения после литералов'] += 1
            if n == 1: cov['повтор длины 1'] += 1
            if n > 255: cov['повтор длиннее 255'] += 1
            prev = 'rep'
            if not bit(): continue
        while True:
            v = elias(1, 1)
            if v == 256:
                cov['конец после ' + {'lit': 'литералов', 'rep': 'повтора', 'new': 'нового смещения'}[prev]] += 1
                if pos != len(d): raise ValueError('хвост после конца потока')
                return bytes(out)
            lsb = d[pos]; pos += 1
            off = v * 128 - (lsb >> 1)
            n = (1 if lsb & 1 else elias(2 | bit())) + 1
            copy(off, n); last = off
            cov['новое смещение'] += 1
            if prev == 'new': cov['новое смещение сразу после совпадения'] += 1
            if n == 2: cov['новое смещение, длина 2 (минимум)'] += 1
            if n == 256: cov['совпадение = 256'] += 1
            if n > 256: cov['совпадение > 256'] += 1
            if n > 1000: cov['совпадение > 1000'] += 1
            for o in (1, 2, 127, 128, 129, 255, 256, 257):
                if off == o: cov['смещение %d' % o] += 1
            if off > 256: cov['смещение > 256'] += 1
            if off > 16384: cov['смещение > 16384'] += 1
            if off >= 32000: cov['смещение >= 32000 (у максимума)'] += 1
            prev = 'new'
            if not bit(): break

def datasets():
    R = random.Random(20260915)
    rnd = lambda n, excl=(): bytes(R.choice([b for b in range(256) if b not in excl]) for _ in range(n))
    for n in (1, 2, 3, 7, 64, 255, 256, 257, 258, 300, 511, 512, 1000, 4096):
        yield 'rnd_%05d' % n, rnd(n)
    for n in (1, 2, 3, 4, 255, 256, 257, 258, 259, 512, 513, 1000, 1001, 32767):
        yield 'zero_%05d' % n, bytes(n)
    # R, заполнитель, R ещё раз на расстоянии D: совпадение со смещением ровно D
    for D in (1, 2, 3, 127, 128, 129, 130, 254, 255, 256, 257, 258, 383, 384, 385, 1000, 4095, 4096,
              8191, 8192, 16383, 16384, 16385, 24000, 32000, 32639):
        for m in ((2, 3, 32, 257) if D in (1, 128, 129, 256, 32639) else (32,)):
            if D < m:
                blk = rnd(D, (0x55,)); data = rnd(5, (0x55,)) + blk * (m // D + 2)
            else:
                blk = rnd(m, (0x55,)); data = rnd(5, (0x55,)) + blk + b'\x55' * (D - m) + blk + rnd(3, (0x55,))
            if len(data) <= MAXOUT: yield 'off_%05d_len%03d' % (D, m), data
    # строки ширины W, каждая — прежняя с редкими правками: повторы смещения W между литералами
    for W, p in ((32, 0.1), (32, 0.5), (256, 0.05), (7, 0.3), (100, 0.9)):
        row = bytearray(rnd(W)); data = bytearray()
        while len(data) < 6000:
            for i in range(W):
                if R.random() < p * 0.3: row[i] = R.randrange(256)
            data += row
        yield 'rows_w%03d_p%02d' % (W, int(p * 100)), bytes(data)
    # правка каждого второго байта: повтор длины 1
    base = rnd(64); data = bytearray(base)
    for k in range(40):
        row = bytearray(data[-64:])
        for i in range(0, 64, 2): row[i] = R.randrange(256)
        data += row
    yield 'alt_every2', bytes(data)
    # период P
    for P in (1, 2, 3, 5, 8, 13, 31, 64, 127, 128, 129, 255, 256, 257):
        blk = rnd(P); yield 'per_%03d' % P, (blk * (3000 // P + 1))[:3000]
    # случайный LZ-подобный поток: литералы и копии со случайными смещениями и длинами
    for seed, size, lmax in ((1, 100, 8), (2, 1000, 20), (3, 5000, 40), (4, 20000, 300), (5, 30000, 2000),
                             (6, 9000, 5), (7, 3000, 600), (8, 32000, 700)):
        Q = random.Random(seed); data = bytearray(bytes(Q.randrange(256) for _ in range(4)))
        while len(data) < size:
            r = Q.random()
            if r < 0.25:
                data += bytes(Q.randrange(256) for _ in range(Q.choice((1, 1, 2, 3, 5, 17, 70))))
            else:
                off = Q.choice((1, 2, 3, 32, 128, 129, 256, 257, Q.randrange(1, len(data) + 1), Q.randrange(1, len(data) + 1)))
                off = min(off, len(data)); n = Q.choice((1, 2, 2, 3, 4, 7, 16, Q.randrange(1, lmax + 1)))
                for _ in range(n): data.append(data[-off])
        yield 'lz_s%d_%05d' % (seed, size), bytes(data[:size])
    # образ-подобное: столбцы по 256 байт, редкие точки
    Q = random.Random(9); data = bytearray(8192)
    for _ in range(600): data[Q.randrange(8192)] = Q.choice((0xFF, 0x0F, 0xF0, 0x81, Q.randrange(256)))
    for c in range(1, 32):
        if Q.random() < 0.5: data[c * 256:(c + 1) * 256] = data[(c - 1) * 256:c * 256]
    yield 'plane_8k', bytes(data)

def main():
    os.makedirs(OUT, exist_ok=True)
    for f in os.listdir(OUT): os.remove(os.path.join(OUT, f))
    cov = collections.Counter(); n = 0; zmax = 0
    for name, data in datasets():
        assert 0 < len(data) <= MAXOUT, name
        b, z = os.path.join(OUT, name + '.bin'), os.path.join(OUT, name + '.zx0')
        open(b, 'wb').write(data)
        subprocess.run([SALVADOR, b, z], check=True, stdout=subprocess.DEVNULL)
        zd = open(z, 'rb').read(); zmax = max(zmax, len(zd))
        if parse(zd, cov) != data: print('ОШИБКА эталонного разбора:', name); sys.exit(1)
        n += 1
    need = ['литералы > 255', 'литералы = 256', 'литералы > 256', 'повтор смещения после литералов', 'повтор длины 1',
            'повтор длиннее 255', 'новое смещение, длина 2 (минимум)', 'новое смещение сразу после совпадения',
            'совпадение = 256', 'совпадение > 256', 'совпадение > 1000', 'смещение 1', 'смещение 2', 'смещение 127',
            'смещение 128', 'смещение 129', 'смещение 255', 'смещение 256', 'смещение 257', 'смещение > 256',
            'смещение > 16384', 'смещение >= 32000 (у максимума)', 'конец после литералов', 'конец после нового смещения']
    for k in need + sorted(set(cov) - set(need)): print('  %-40s %6d' % (k, cov[k]))
    miss = [k for k in need if not cov[k]]
    print('zx0synth: %d потоков в %s, сжатых до %d Б' % (n, os.path.relpath(OUT, ROOT), zmax))
    if miss: print('НЕ ПОКРЫТО:', ', '.join(miss)); sys.exit(1)

main()

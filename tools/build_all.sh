#!/bin/sh
# Все четыре образа одной командой и таблица размеров и запасов:
#   build/ironclad.rom      — картридж, русский        (./build.sh)
#   build/ironclad_en.rom   — картридж, английский     (DEFS=-DLANG_EN ./build.sh)
#   build/ironclad.fdd      — дискета, русская         (tools/build_disk.sh)
#   build/ironclad_en.fdd   — дискета, английская      (DEFS=-DLANG_EN tools/build_disk.sh)
# Русские образы сверяются с эталонами main 8dd8976 (md5 ниже): до языковой правки они были такими же.
set -e
cd "$(dirname "$0")/.."
Q() { grep -E "error|ОШИБКА|Errors: [1-9]" || true; }
./build.sh 2>&1 | Q
DEFS=-DLANG_EN ./build.sh 2>&1 | Q
tools/build_disk.sh 2>&1 | Q
DEFS=-DLANG_EN tools/build_disk.sh 2>&1 | Q
python3 - <<'EOF'
import hashlib
REF = {'build/ironclad.rom': 'fc3daf48bbe8248da7d50fd12d13005c', 'build/ironclad.fdd': '258d44743f32bcb80db7f2e12cc71b44'}
def labels(sld):
    L = {}
    for l in open(sld, encoding='latin1'):
        p = l.rstrip('\n').split('|')
        if len(p) >= 8 and p[6] == 'L':
            n = p[7].split(',')[1]
            if n and n not in L: L[n] = int(p[5])
    return L
rows = [('картридж RU', 'build/ironclad.rom', 'build/ironclad.sld', 0x8000, 0x10000),
        ('картридж EN', 'build/ironclad_en.rom', 'build/ironclad_en.sld', 0x8000, 0x10000),
        ('дискета RU', 'build/ironclad.fdd', 'build/disk/game.sld', None, 0x8000),
        ('дискета EN', 'build/ironclad_en.fdd', 'build/disk_en/game.sld', None, 0x8000)]
print('%-12s %7s %8s %7s %11s %6s %8s  %s' % ('образ', 'код+дан', 'до края', 'BSS', 'BSS', 'стек', 'свободно', 'md5'))
for nm, f, sld, lim, top in rows:
    L = labels(sld)
    ie, bs, be = L['image_end'], L['bss_start'], L['bss_end']
    lim = lim or bs                           # дисковая: образ — до BSS ($5000)
    md5 = hashlib.md5(open(f, 'rb').read()).hexdigest()
    ref = ('  = эталон' if REF[f] == md5 else '  != ЭТАЛОН %s' % REF[f]) if f in REF else ''
    print('%-12s %7d %8d %7d %04X..%04X %6d %8d  %s%s' % (nm, ie - 0x100, lim - ie, be - bs, bs, be, 256,
                                                       top - 256 - be, md5, ref))
print('код+дан — образ $0100..image_end; до края — свободно до $8000 (картридж) / до BSS $5000 (дискета);')
print('свободно — между концом BSS и стеком (256 Б под $10000 у картриджа, под $8000 у дискеты).')
EOF

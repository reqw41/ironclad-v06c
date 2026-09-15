#!/usr/bin/env python3
"""Загрузочная дискета дисковой версии: build/ironclad.fdd (+ стенд картинок build/disk/pictest.fdd).

    tools/build_disk.sh               # собирает игру -DDISK и зовёт этот скрипт
    python3 tools/build_fdd.py --layout   # только build/disk/layout.inc (до сборки игры)
    --en — английская дискета build/ironclad_en.fdd: игра, загрузчик и layout.inc — в build/disk_en/,
           картинки — те же, из build/disk/ (стенд картинок pictest.fdd — только у русской)

Образ — 800 КБ, геометрия MicroDOS Вектора: 80 дорожек x 2 стороны x 5 секторов x 1024 Б; в файле
.fdd секторы идут подряд: (дорожка*2 + сторона)*5 + (сектор-1). Здесь «сектор в дорожке» 0..9 —
это (сторона*5 + сектор-1), так же считает драйвер src/fdd.asm.

Загрузка — по конвенции штатного ПЗУ Вектора (проверена в порте Ianna): дескриптор 32 Б в начале
дорожки 0, байт 4 = сколько КБ грузить, байт 31 = сумма байтов 0..30 с затравкой $66; байт дискеты
X ложится в $0080+X, вход — $0100 (БЛК+СБР). Грузим 1 КБ — загрузчик src/boot.asm, остальное он
читает сам. Раскладка (номер сектора от начала дискеты; дорожка = 10 секторов):

    0         загрузочный сектор: дескриптор + загрузчик (build/disk/boot.bin, до 896 Б)
    1..32     заставка 16 цв. — 32 КБ видеопамяти $8000..$FFFF (из образа картриджа)
    33..64    игра — образ $0100.. дисковой версии build/disk/game.rom (под неё всегда 32 сектора)
    65..96    титул 16 цв.     (build/disk/title.vram, tools/mkdisk.py)
    97..128   победа 16 цв.    (victory.vram)
    129..160  поражение 16 цв. (defeat.vram)

Позиции пишутся в build/disk/layout.inc (FD_x = дорожка*256 + сектор в дорожке, FD_x_N — секторов),
загрузчик собирается уже с ними: таблица размещения прошита в код, файловой системы нет.
"""
import os, re, subprocess, sys
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
SEC = 1024
DISK = 80 * 2 * 5 * SEC
OUTD = os.path.join(ROOT, 'build', 'disk')      # картинки (от языка не зависят), русская игра
EN = '--en' in sys.argv                         # английская дискета: игра, загрузчик, раскладка —
GAMED = os.path.join(ROOT, 'build', 'disk_en' if EN else 'disk')   # в build/disk_en/
FDD_OUT = os.path.join(ROOT, 'build', 'ironclad_en.fdd' if EN else 'ironclad.fdd')
SJASM = os.path.join(ROOT, 'tools', 'sjasmplus')

LAYOUT = [                      # имя, первый сектор, секторов
    ('SPLASH', 1, 32),
    ('GAME', 33, 32),
    ('TITLE', 65, 32),
    ('VICTORY', 97, 32),
    ('DEFEAT', 129, 32),
]


def pos(lba):
    return lba // 10, lba % 10


def label(sld, name):
    for l in open(sld, encoding='latin1'):
        p = l.rstrip('\n').split('|')
        if len(p) >= 8 and p[6] == 'L' and p[7].split(',')[1] == name:
            return int(p[5])
    sys.exit('!! нет метки %s в %s' % (name, sld))


def write_layout(n_game=32):
    inc = ['; сгенерировано tools/build_fdd.py: позиции на дискете (дорожка*256 + сектор в дорожке 0..9)']
    for nm, lba, n in LAYOUT:
        if nm == 'GAME':
            n = n_game
        t, s = pos(lba)
        inc.append('FD_%s equ %d*256+%d' % (nm, t, s))
        inc.append('FD_%s_N equ %d' % (nm, n))
    inc.append('FD_PIC_N equ 32')
    txt = '\n'.join(inc) + '\n'
    f = os.path.join(GAMED, 'layout.inc')
    if not os.path.exists(f) or open(f).read() != txt:
        open(f, 'w').write(txt)


def main():
    os.makedirs(OUTD, exist_ok=True)
    os.makedirs(GAMED, exist_ok=True)
    if '--layout' in sys.argv:
        write_layout()
        return
    # --- данные
    import mkdisk
    mkdisk.build()
    rom = open(os.path.join(GAMED, 'game.rom'), 'rb').read()
    iend = label(os.path.join(GAMED, 'game.sld'), 'image_end')
    game_len = iend - 0x100
    assert len(rom) == game_len, (len(rom), game_len)
    splash = open(os.path.join(ROOT, 'build', 'data', 'splash.bin'), 'rb').read()
    assert len(splash) == 0x8000
    n_game = (game_len + SEC - 1) // SEC
    # последний сектор игры пишет байты до $0100 + n*1024; если это за $8000 — там должны
    # лежать байты заставки (экран уже на месте)
    mem = bytearray(rom.ljust(0xFF00, b'\0'))
    mem[0x7F00:0xFF00] = splash
    assert n_game <= 32 and not any(rom[0x7F00:]), n_game
    game = bytes(mem[:n_game * SEC])
    over = 0x100 + n_game * SEC - 0x8000
    files = {
        'SPLASH': splash,
        'GAME': game,
        'TITLE': open(os.path.join(OUTD, 'title.vram'), 'rb').read(),
        'VICTORY': open(os.path.join(OUTD, 'victory.vram'), 'rb').read(),
        'DEFEAT': open(os.path.join(OUTD, 'defeat.vram'), 'rb').read(),
    }
    # --- таблица размещения -> layout.inc (для загрузчика — с настоящей длиной игры; игра берёт
    # из неё только позиции картинок, они от длины не зависят)
    write_layout(n_game)
    # --- загрузчик: обычный и стенд картинок
    boots = {}
    gd = os.path.relpath(GAMED, ROOT)
    for tag, defs in ((('boot', ['-DLANG_EN']),) if EN else (('boot', []), ('boot_pictest', ['-DPICTEST']))):
        r = subprocess.run([SJASM, '--i8080', '--fullpath'] + defs +
                           ['--sld=%s/%s.sld' % (gd if tag == 'boot' else 'build/disk', tag),
                            '--lst=%s/%s.lst' % (gd if tag == 'boot' else 'build/disk', tag), 'src/boot.asm'],
                           cwd=ROOT, capture_output=True, text=True)
        msg = [l for l in (r.stdout + r.stderr).splitlines() if 'загрузчик' in l or 'rror' in l]
        if r.returncode:
            sys.exit('\n'.join(msg) or r.stdout + r.stderr)
        print(tag + ':', ' '.join(m.strip('> ') for m in msg if 'загрузчик' in m))
        boots[tag] = open(os.path.join(GAMED if tag == 'boot' else OUTD, tag + '.bin'), 'rb').read()
        assert len(boots[tag]) <= SEC - 0x80
    # --- образы
    def image(bootbin, out):
        img = bytearray(DISK)
        desc = bytearray(32)
        desc[4] = 1                             # 1 КБ: $0080..$047F, код с $0100
        s = 0x66
        for b in desc[:31]:
            s = (s + b) & 0xFF
        desc[31] = s
        img[0:32] = desc
        img[0x80:0x80 + len(bootbin)] = bootbin
        used = [(0, 1)]
        for nm, lba, n in LAYOUT:
            d = files[nm]
            assert len(d) <= n * SEC, (nm, len(d))
            for a, b in used:
                assert lba + n <= a or lba >= a + b, ('наложение', nm)
            used.append((lba, n))
            img[lba * SEC:lba * SEC + len(d)] = d
        open(out, 'wb').write(img)
        return img
    image(boots['boot'], FDD_OUT)
    if not EN:
        image(boots['boot_pictest'], os.path.join(OUTD, 'pictest.fdd'))
    # --- отчёт
    print('дискета: %s (%d Б)%s' % (os.path.relpath(FDD_OUT, ROOT), DISK, '' if EN else '; стенд картинок: build/disk/pictest.fdd'))
    print('  %-8s %6s %8s  %s' % ('файл', 'сектор', 'байт', 'дорожка/сектор (начало..конец)'))
    print('  %-8s %6d %8d  0/0' % ('boot', 0, len(boots['boot'])))
    for nm, lba, n in LAYOUT:
        nn = n_game if nm == 'GAME' else n
        (t0, s0), (t1, s1) = pos(lba), pos(lba + nn - 1)
        print('  %-8s %6d %8d  %d/%d..%d/%d' % (nm.lower(), lba, len(files[nm]) if nm != 'GAME' else game_len,
                                            t0, s0, t1, s1))
    last = max(l + n for _, l, n in LAYOUT)
    print('  занято %d секторов из 800 (%d КБ), игра %d Б = %d секторов%s' % (
        last, last, game_len, n_game,
        ', хвост последнего сектора (%d Б) ложится на заставку её же байтами' % over if over > 0 else ''))


if __name__ == '__main__':
    main()

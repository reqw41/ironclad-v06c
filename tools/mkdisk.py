#!/usr/bin/env python3
"""Картинки дисковой версии в 16 цветах: образы видеопамяти для чтения с дискеты прямо в экран.

    python3 tools/mkdisk.py        # -> build/disk/{title,victory,defeat}.vram, pics.inc, *_src.png (для глаз)

Формат файла: 4 плоскости подряд = 32 КБ, ровно как видеопамять $8000..$FFFF (байт = $8000 +
плоскость*$2000 + столбец*256 + строка памяти). Индекс Вектора = номер цвета MSX как есть
(бит 3 -> $8000 ... бит 0 -> $E000), cmap тождественный. Экран MSX 256x212 стоит со сдвигом
TOP = 22 строки сверху, как в картридже (mkdata.memrow); поля вокруг — нули, то есть индекс 0.
Цвет 0 в SC5 прозрачный — на MSX на его месте виден цвет бордюра, поэтому индекс 0 палитры
Вектора = цвет бордюра MSX: у титула цвет 5 (COLOR 1,5,5), у итога цвет 1 палитры 9042 (белый,
COLOR 15,1,1). Бордюр Вектора — индекс 0.

Как в картридже (mkdata.build_images):
  * титул — окно меню LINE(34,150)-(222,210),5,BF стёрто (SETUP 3422), в нём и QR;
  * итог — полоса подписей 162..211 залита цветом 5, подписи печатает программа;
  * победа — по 3 крайних столбца с каждой стороны в строках 0..161 заделаны зеркалом соседних:
    x -> 5-x слева, x -> 505-x справа (решение владельца).
Палитры и загрузчик SC5 берутся из tools/mkdata.py (один источник на обе версии).
"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import mkdata
from mkdata import load_sc5, line_bf, msxpal, vecbyte, PAL_MENU, PAL_END, TOP

ROOT = os.path.dirname(HERE)
OUT = os.path.join(ROOT, 'build', 'disk')


def vram16(px):
    """Экран MSX (212 строк по 256 цветов 0..15) -> 32 КБ видеопамяти Вектора, 4 плоскости."""
    v = bytearray(0x8000)
    for p in range(4):
        sh = 3 - p
        for col in range(32):
            base = p * 0x2000 + col * 256
            for y in range(212):
                row = px[y]
                b = 0
                for i in range(8):
                    if (row[col * 8 + i] >> sh) & 1:
                        b |= 0x80 >> i
                v[base + 255 - TOP - y] = b
    return v


def pal16(p, backdrop):
    """16 байт палитры Вектора (BBGGGRRR): [0] = цвет бордюра MSX, [1..15] = COLOR=(i,...)."""
    return [vecbyte(p[backdrop - 1])] + [vecbyte(c) for c in p]


def png(name, v, pal):
    from PIL import Image
    rgb = [((c & 7) * 255 // 7, ((c >> 3) & 7) * 255 // 7, ((c >> 6) & 3) * 255 // 3) for c in pal]
    im = Image.new('RGB', (256, 256))
    for sy in range(256):
        mrow = 255 - sy
        for col in range(32):
            b = [v[p * 0x2000 + col * 256 + mrow] for p in range(4)]
            for bit in range(8):
                idx = sum(((b[p] >> (7 - bit)) & 1) << (3 - p) for p in range(4))
                im.putpixel((col * 8 + bit, sy), rgb[idx])
    im.resize((512, 512), Image.NEAREST).save(os.path.join(OUT, name + '_src.png'))


# ---------------------------------------------------------------- палитры дисковой версии
# Точные, как в оригинале, cmap тождественный (индекс Вектора = номер цвета MSX), индекс 0 =
# цвет бордюра MSX. Смена решения — одна строка здесь. (Картридж: свои 8 слотов, вариант «Д».)
GRAY_SPLIT = False          # True: развести серые 4 (4,4,4) и 7 (4,4,5), которые синий Вектора
                            # (2 бита) сливает: у цвета 4 синий 1 вместо 2
def pal16x(p, backdrop):
    pal = pal16(p, backdrop)
    if GRAY_SPLIT and p is not PAL_GAME:
        pal[4] = vecbyte((4, 4, 2))
    return pal
def palettes():
    return {
        'game':    pal16x(mkdata.PAL_GAME, 1),   # 9040 (2505), бордюр — цвет 1 (COLOR 15,1,1)
        'menu':    pal16x(PAL_MENU, 5),          # SETUP 3430, бордюр — цвет 5 (COLOR 1,5,5)
        'victory': pal16x(PAL_END, 1),           # 9042 (2508), бордюр белый — цвет 1
        'defeat':  pal16x(PAL_END, 1),
    }


# ---------------------------------------------------------------- тайлы в 4 плоскостях
def build_tiles16():
    """Тайлы 0..22 для 16 цветов: 4 плоскости x 2 столбца x 16 строк = 128 Б на тайл, цвет MSX
    как есть (0 — прозрачность TPSET, как у MSX), за ними те же глифы 8x10, что в картридже.
    Лист TILES.SC5 с буями (SETUP 3008-3009) строится так же, как в mkdata.build_tiles; сверка:
    та же сборка в 3 плоскостях по слотам картриджа обязана дать build/data/tiles.bin байт в байт."""
    m = mkdata
    px = load_sc5('TILES.SC5')
    m.line_bf(px,160,0,175,15,0); m.line_bf(px,165,10,171,14,5); m.line_bf(px,166,7,170,9,5)
    m.line_b(px,165,10,171,14,4); m.line(px,168,2,168,6,15); m.line_bf(px,169,2,171,3,8)
    m.line_bf(px,176,0,191,15,0); m.line_bf(px,181,10,187,14,7); m.line_bf(px,182,7,186,9,7)
    m.line_b(px,181,10,187,14,6); m.line(px,184,2,184,6,15); m.line_bf(px,185,2,187,3,8)
    NT = 23
    gp = m.mpal(m.PAL_GAME)
    tp_cols = set(px[y][x] for t in range(2, NT) for y in range((t//16)*16, (t//16)*16+16)
                  for x in range((t%16)*16, (t%16)*16+16)) - {0}
    cm8 = m.cmap_of(m.GAME_SLOTS, gp, avoid0=tp_cols, force=m.GAME_FORCE)
    def tiles(np, cmap):
        data = []
        for t in range(NT):
            x0, y0 = (t % 16) * 16, (t // 16) * 16
            for p in range(np):
                for c in range(2):
                    for r in range(16):
                        b = 0
                        for i in range(8):
                            if (cmap[px[y0+r][x0+c*8+i]] >> (np-1-p)) & 1:
                                b |= 0x80 >> i
                        data.append(b)
        per = np * 32
        for h, v in m.ROT_PAIRS:
            data[v*per:(v+1)*per] = [0]*per
        return bytes(data)
    cart = open(os.path.join(ROOT, 'build', 'data', 'tiles.bin'), 'rb').read()
    t3 = tiles(3, cm8)
    assert t3 == cart[:len(t3)], 'тайлы 3 плоскостей не совпали с build/data/tiles.bin: разошёлся лист с mkdata'
    blob = tiles(4, {c: c for c in range(16)}) + cart[len(t3):]      # + глифы картриджа
    raw = os.path.join(OUT, 'tiles16.bin')
    open(raw, 'wb').write(blob)
    import subprocess
    subprocess.run([m.SALVADOR, raw, os.path.join(OUT, 'tiles16.zx0')], check=True, stdout=subprocess.DEVNULL)
    n = os.path.getsize(os.path.join(OUT, 'tiles16.zx0'))
    print('тайлы 16 цв.: %d Б -> ZX0 %d Б' % (len(blob), n))


def build():
    os.makedirs(OUT, exist_ok=True)
    P = palettes()
    pics = {}
    # титул: SETUP 3422 — окно меню стёрто цветом 5 (QR внутри окна), палитра 3430, бордюр 5
    t = load_sc5('IRONCLAD.SC5')
    line_bf(t, 34, 150, 222, 210, 5)
    pics['title'] = (t, P['menu'])
    # итог: палитра 9042 (2508), бордюр — цвет 1 (COLOR 15,1,1), полоса подписей — цвет 5
    for nm, f in (('victory', 'VICTORY.SC5'), ('defeat', 'DEFEAT.SC5')):
        px = load_sc5(f)
        line_bf(px, 0, 162, 255, 211, 5)
        if nm == 'victory':
            for y in range(162):
                for x in range(3):
                    px[y][x] = px[y][5 - x]
                for x in range(253, 256):
                    px[y][x] = px[y][505 - x]
        pics[nm] = (px, P[nm])
    inc = ['; сгенерировано tools/mkdisk.py: палитры картинок дисковой версии (16 цветов, BBGGGRRR),',
           '; индекс = номер цвета MSX, индекс 0 = цвет бордюра MSX']
    for nm, (px, pal) in pics.items():
        v = vram16(px)
        open(os.path.join(OUT, nm + '.vram'), 'wb').write(v)
        png(nm, v, pal)
        inc.append('pal16_%s: db %s' % (nm, ','.join('%d' % c for c in pal)))
        # совпавшие на Векторе цвета (синий у Вектора 2-битный)
        same = [(i, j) for i in range(1, 16) for j in range(i + 1, 16) if pal[i] == pal[j]]
        print('%-8s 32768 Б, палитра %s%s' % (nm, ' '.join('%02X' % c for c in pal),
              ('; совпали цвета ' + ', '.join('%d=%d' % s for s in same)) if same else ''))
    open(os.path.join(OUT, 'pics.inc'), 'w').write('\n'.join(inc) + '\n')
    # палитры игры (-DDISK): 16 байт на экран; cmap_* — одна тождественная таблица цвет<<4
    # (col2bits берёт биты 7..4 — плоскости $8000..$E000)
    g = ['; сгенерировано tools/mkdisk.py: палитры дисковой версии (16 цветов, BBGGGRRR), cmap тождественный']
    for nm in ('game', 'menu', 'victory', 'defeat'):
        g.append('pal_%s: db %s' % (nm, ','.join('%d' % c for c in P[nm])))
    g.append('cmap_game:')
    g.append('cmap_menu:')
    g.append('cmap_victory:')
    g.append('cmap_defeat: db ' + ','.join('%d' % (c << 4) for c in range(16)))
    open(os.path.join(OUT, 'pal16.inc'), 'w').write('\n'.join(g) + '\n')
    build_tiles16()


if __name__ == '__main__':
    build()

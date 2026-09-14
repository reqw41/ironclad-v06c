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


def build():
    os.makedirs(OUT, exist_ok=True)
    pics = {}
    # титул: SETUP 3422 — окно меню стёрто цветом 5 (QR внутри окна), палитра 3430, бордюр 5
    t = load_sc5('IRONCLAD.SC5')
    line_bf(t, 34, 150, 222, 210, 5)
    pics['title'] = (t, pal16(PAL_MENU, 5))
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
        pics[nm] = (px, pal16(PAL_END, 1))
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


if __name__ == '__main__':
    build()

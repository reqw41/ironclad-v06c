#!/usr/bin/env python3
"""Данные порта из ресурсов MSX: палитры, тайлы, глифы цифр, шрифт, картинки.

    python3 tools/mkdata.py            # -> build/data/*.inc, *.zx0, *.png (для глаз)

Экран Вектора: байт = 0x8000 + плоскость*0x2000 + столбец*256 + строка_памяти;
строка памяти 255 = верх кадра. Индекс цвета = p8000<<3 | pA000<<2 | pC000<<1 | pE000,
то есть номер цвета MSX кладётся в плоскости как есть (бит 3 -> $8000 ... бит 0 -> $E000).
Экран MSX 256x212 стоит со сдвигом TOP=22 строки: строка MSX y -> строка памяти 233-y.
"""
import os, subprocess, sys
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REF = os.path.join(ROOT, 'ref', 'ironclad-msx')
OUT = os.path.join(ROOT, 'build', 'data')
SALVADOR = os.path.join(ROOT, 'tools', 'salvador')
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import font5x7

TOP = 22                     # строк сверху до экрана MSX
def memrow(y): return 255 - TOP - y

# --------------------------------------------------------------------------- палитры
def msxpal(vals):
    """DATA из BASIC: 15 троек r,g,b (цвета 1..15). Цвет 0 = цвет фона (TP=0 у MSX-BASIC
    показывает на месте цвета 0 бордюр), кладём его отдельно."""
    return [tuple(vals[i*3:i*3+3]) for i in range(15)]

def vecbyte(rgb):
    r, g, b = rgb
    return ((b >> 1) << 6) | (g << 3) | r

PAL_GAME = msxpal([0,1,3,0,2,5,2,5,7,2,2,3,5,5,6,7,4,0,7,7,2,7,1,1,1,6,2,1,1,1,7,7,7,4,4,5,0,0,0,5,3,1,7,7,7])   # 9040
PAL_END  = msxpal([7,7,7,6,6,6,5,5,5,4,4,4,0,0,1,7,5,1,4,4,5,3,3,3,2,3,7,2,2,2,6,2,0,0,2,6,0,1,6,0,1,5,1,1,1])   # 9042
PAL_MENU = msxpal([7,7,7,6,6,6,5,5,5,4,4,4,0,0,1,7,5,1,4,4,5,3,3,3,2,3,7,2,2,2,6,2,0,0,2,6,0,1,6,0,1,5,1,1,1])   # SETUP 3430

def pal16(p, backdrop):
    """16 байт палитры Вектора: [0] = цвет бордюра (номер backdrop), [1..15] = COLOR=(i,...)."""
    return [vecbyte(p[backdrop-1])] + [vecbyte(c) for c in p]

def rgb_of(p, backdrop):
    return [tuple(v*255//7 for v in p[backdrop-1])] + [tuple(v*255//7 for v in c) for c in p]

# --------------------------------------------------------------------------- SC5
def load_sc5(name):
    v = open(os.path.join(REF, name), 'rb').read()[7:]
    return [[(v[y*128+x//2] >> 4) if x % 2 == 0 else v[y*128+x//2] & 15 for x in range(256)] for y in range(212)]

def line_bf(px, x1, y1, x2, y2, c):
    for y in range(min(y1,y2), max(y1,y2)+1):
        for x in range(min(x1,x2), max(x1,x2)+1):
            px[y][x] = c

def line_b(px, x1, y1, x2, y2, c):
    for x in range(min(x1,x2), max(x1,x2)+1):
        px[y1][x] = c; px[y2][x] = c
    for y in range(min(y1,y2), max(y1,y2)+1):
        px[y][x1] = c; px[y][x2] = c

def line(px, x1, y1, x2, y2, c):
    assert x1 == x2 or y1 == y2
    line_bf(px, x1, y1, x2, y2, c)

# --------------------------------------------------------------------------- вывод
def db_lines(data, per=16):
    out = []
    for i in range(0, len(data), per):
        out.append('        db ' + ','.join('%d' % b for b in data[i:i+per]))
    return '\n'.join(out)

def write(name, text):
    with open(os.path.join(OUT, name), 'w') as f:
        f.write(text)

def zx0(name, data):
    raw = os.path.join(OUT, name + '.bin')
    comp = os.path.join(OUT, name + '.zx0')
    open(raw, 'wb').write(bytes(data))
    subprocess.run([SALVADOR, raw, comp], check=True, stdout=subprocess.DEVNULL)
    return os.path.getsize(comp)

def png(name, px, rgb, scale=2):
    h = len(px); w = len(px[0])
    im = Image.new('RGB', (w, h))
    for y in range(h):
        for x in range(w):
            im.putpixel((x, y), rgb[px[y][x]])
    im.resize((w*scale, h*scale), Image.NEAREST).save(os.path.join(OUT, name + '.png'))

# --------------------------------------------------------------------------- тайлы
def build_tiles():
    px = load_sc5('TILES.SC5')
    # SETUP 3008-3009: буи рисуются командами LINE в странице 3 поверх листа
    line_bf(px,160,0,175,15,0); line_bf(px,165,10,171,14,5); line_bf(px,166,7,170,9,5)
    line_b(px,165,10,171,14,4); line(px,168,2,168,6,15); line_bf(px,169,2,171,3,8)
    line_bf(px,176,0,191,15,0); line_bf(px,181,10,187,14,7); line_bf(px,182,7,186,9,7)
    line_b(px,181,10,187,14,6); line(px,184,2,184,6,15); line_bf(px,185,2,187,3,8)
    # фон сетки (96,32)-(255,191) должен совпадать с тайлом воды — тогда 1154 = 100 тайлов 0
    water = [px[y][0:16] for y in range(16)]
    for j in range(10):
        for i in range(10):
            assert [px[32+16*j+y][96+16*i:112+16*i] for y in range(16)] == water, 'фон сетки'
    NT = 23                                   # используются тайлы 0..22
    data = []
    for t in range(NT):
        x0, y0 = (t % 16) * 16, (t // 16) * 16
        # формат: плоскость p (0 = бит 3 -> $8000), столбец-байт c (0..1), строка r сверху вниз
        for p in range(4):
            for c in range(2):
                for r in range(16):
                    b = 0
                    for i in range(8):
                        if (px[y0+r][x0+c*8+i] >> (3-p)) & 1:
                            b |= 0x80 >> i
                    data.append(b)
    # глифы 8x10: одна форма на 32 символа (белые/жёлтые/красные отличаются только заливкой)
    def g(x, y): return [px[yy][x:x+8] for yy in range(y, y+10)]
    white = [g(32+(m % 8)*8, 48+(m//8)*10) for m in range(32)]
    yellow = [g((m % 12)*8, 144+(m//12)*10) for m in range(32)]
    red = [g(m*8, 196) for m in range(32)]
    fills = {'white': 15, 'yellow': 7, 'red': 8}
    for nm, s in (('white', white), ('yellow', yellow), ('red', red)):
        for k in range(32):
            for yy in range(10):
                for xx in range(8):
                    c = s[k][yy][xx]
                    w = white[k][yy][xx]
                    assert c in (0, 10, fills[nm]) and (c == 0) == (w == 0) and (c == 10) == (w == 10), (nm, k)
    gl = []
    for k in range(32):
        for yy in range(10):
            f = o = 0
            for xx in range(8):
                c = white[k][yy][xx]
                if c == 15: f |= 0x80 >> xx
                if c == 10: o |= 0x80 >> xx
            gl += [f, o]
    txt = ['; сгенерировано tools/mkdata.py — не править',
           '; тайлы 16x16: 128 байт = 4 плоскости ($8000..$E000) x 2 столбца x 16 строк сверху вниз',
           'tiles_data:', db_lines(data),
           '; глифы 8x10: 10 строк x (заливка, обводка цветом 10); бит 7 = левый столбец',
           'glyph_data:', db_lines(gl)]
    write('tiles.inc', '\n'.join(txt) + '\n')
    # контрольная картинка
    sheet = [[0]*256 for _ in range(32)]
    for y in range(32):
        sheet[y] = px[y][:]
    png('tiles_check', sheet, rgb_of(PAL_GAME, 1), 3)
    return len(data), len(gl)

# --------------------------------------------------------------------------- шрифт
def build_font():
    data = []
    for code in range(32, 128):
        data += font5x7.rows(chr(code))
    write('font.inc', '; сгенерировано tools/mkdata.py: шрифт 5x7 (tools/font5x7.py), коды 32..127, 8 байт на знак\nfont_data:\n' + db_lines(data) + '\n')
    return len(data)

# --------------------------------------------------------------------------- картинки
def vram_image(px, backdrop):
    """Полный образ экрана Вектора 32 КБ ($8000..$FFFF) под картинку MSX; поля = backdrop."""
    v = bytearray(0x8000)
    for p in range(4):
        for col in range(32):
            for row in range(256):
                y = 255 - TOP - row
                b = 0
                for i in range(8):
                    c = px[y][col*8+i] if 0 <= y < 212 else backdrop
                    if (c >> (3-p)) & 1:
                        b |= 0x80 >> i
                v[p*0x2000 + col*256 + row] = b
    return v

def build_images():
    res = {}
    # титул: SETUP 3422 сразу стирает окно меню LINE(34,150)-(222,210),5,BF, предварительно
    # сняв с этого места QR (36,152)-(93,209). QR хранится отдельно, 1 бит на точку.
    t = load_sc5('IRONCLAD.SC5')
    qr = [row[36:94] for row in t[152:210]]
    qcols = sorted(set(c for r in qr for c in r))
    line_bf(t, 34, 150, 222, 210, 5)
    res['title'] = zx0('title', vram_image(t, 5))
    png('title_check', t, rgb_of(PAL_MENU, 5))
    assert len(qcols) == 2, qcols
    qbits = []
    for r in qr:
        for x0 in range(0, 64, 8):
            b = 0
            for i in range(8):
                x = x0 + i
                if x < 58 and r[x] == qcols[1]:
                    b |= 0x80 >> i
            qbits.append(b)
    write('qr.inc', '; QR 58x58 из IRONCLAD.SC5 (36,152): 58 строк x 8 байт, 1 = цвет %d, 0 = цвет %d\nQR_C0 equ %d\nQR_C1 equ %d\nqr_data:\n' % (qcols[1], qcols[0], qcols[0], qcols[1]) + db_lines(qbits, 8) + '\n')
    res['qr'] = len(qbits)
    for nm, f in (('victory', 'VICTORY.SC5'), ('defeat', 'DEFEAT.SC5')):
        px = load_sc5(f)
        res[nm] = zx0(nm, vram_image(px, 1))
    return res

def build_palettes():
    txt = ['; сгенерировано tools/mkdata.py: палитры Вектора (BBGGGRRR), [0] = цвет бордюра',
           'pal_game:', db_lines(pal16(PAL_GAME, 1)),
           'pal_end:', db_lines(pal16(PAL_END, 1)),
           'pal_menu:', db_lines(pal16(PAL_MENU, 5))]
    write('palettes.inc', '\n'.join(txt) + '\n')

if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    nt, ng = build_tiles()
    nf = build_font()
    build_palettes()
    im = build_images()
    ver = open(os.path.join(REF, 'VERSION')).read().strip()
    write('version.inc', '        db "V%s"\n' % ver)
    print('тайлы %d Б, глифы %d Б, шрифт %d Б' % (nt, ng, nf))
    for k, v in im.items():
        print('%-8s %6d Б' % (k, v))
    print('картинки всего %d Б' % sum(im.values()))

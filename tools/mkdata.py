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

# ---------------------------------------------------------------- 8-цветный режим
# Экран — 3 плоскости ($8000 = бит 2 слота, $A000 = бит 1, $C000 = бит 0), плоскость $E000 —
# память программы. Индекс Вектора i (4 бита) -> слот i>>1, пары индексов одного цвета.
# Слот 0 — цвет фона (бордюр, поля экрана, нули видеопамяти); в игре он же — прозрачность тайлов.
import itertools, collections
def cdist(a, b): return (a[0]-b[0])**2*3 + (a[1]-b[1])**2*4 + (a[2]-b[2])**2*2
def pick_slots(cnt, pal, n, forced):
    """forced[0] -> слот 0; остальные слоты — перебором подмножеств цветов MSX (новых цветов нет)."""
    free = [c for c in cnt if c not in forced and cnt[c] > 0]
    best = None
    for sub in itertools.combinations(free, max(0, min(n - len(forced), len(free)))):
        S = list(forced) + list(sub)
        e = sum(w * min(cdist(pal[k], pal[c]) for k in S) for c, w in cnt.items())
        if best is None or e < best[0]: best = (e, S)
    return best[1]
def cmap_of(slots, pal, avoid0=()):
    m = {}
    for c in range(1, 16):
        order = sorted(range(len(slots)), key=lambda i: cdist(pal[slots[i]], pal[c]))
        if c in avoid0 and order[0] == 0: order = order[1:]
        m[c] = order[0]
    m[0] = 0
    return m
def pal8(slots, pal):
    out = []
    for i in range(16):
        k = i >> 1
        out.append(vecbyte(pal[slots[k]]) if k < len(slots) else 0)
    return out
def mpal(p): return {i+1: c for i, c in enumerate(p)}
ROT_PAIRS = [(4,7),(5,8),(6,9),(12,13),(14,15),(16,17),(18,19),(20,21)]
GAME_SLOTS = [1, 2, 12, 10, 15, 8, 7, 9]    # фон, вода, серый, чёрный, белый, красный, жёлтый, зелёный

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
    gp = mpal(PAL_GAME)
    # в тайлах, что кладутся с TPSET (2..22), слот 0 = прозрачность: их цвета не должны в него попадать
    tp_cols = set(px[y][x] for t in range(2, NT) for y in range((t//16)*16, (t//16)*16+16)
                  for x in range((t%16)*16, (t%16)*16+16)) - {0}
    cm = cmap_of(GAME_SLOTS, gp, avoid0=tp_cols)
    assert all(cm[c] != 0 for c in tp_cols), tp_cols
    data = []
    for t in range(NT):
        x0, y0 = (t % 16) * 16, (t // 16) * 16
        # формат: плоскость p (0 = бит 2 слота -> $8000), столбец-байт c (0..1), строка r сверху вниз
        for p in range(3):
            for c in range(2):
                for r in range(16):
                    b = 0
                    for i in range(8):
                        if (cm[px[y0+r][x0+c*8+i]] >> (2-p)) & 1:
                            b |= 0x80 >> i
                    data.append(b)
    global CMAP_GAME
    CMAP_GAME = cm
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
    # вертикальные части кораблей = горизонтальные, повёрнутые на 90° по часовой: их строит
    # программа при старте (rot_tiles), в блоке они нули. Блок = 23 тайла + глифы, сжат ZX0,
    # распаковывается в плоскость $E000.
    def rot(t):
        return [[t[15-c][r] for c in range(16)] for r in range(16)]
    for h, v in ROT_PAIRS:
        th = [px[(h//16)*16+r][(h%16)*16:(h%16)*16+16] for r in range(16)]
        tv = [px[(v//16)*16+r][(v%16)*16:(v%16)*16+16] for r in range(16)]
        assert rot(th) == tv, (h, v)
        data[v*96:(v+1)*96] = [0]*96
    blob = bytes(data) + bytes(gl)
    n = zx0('tiles', blob)
    write('tiles.inc', '; сгенерировано tools/mkdata.py: пары (горизонтальный, вертикальный) тайлов для rot_tiles\n'
          'rot_pairs: db ' + ','.join('%d,%d' % p for p in ROT_PAIRS) + ',255\n'
          'TILES_BLOB equ %d\n' % len(blob))
    print('тайлы+глифы: %d Б -> ZX0 %d Б' % (len(blob), n))
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
def vram_image(px, slotmap, planes):
    """Образ плоскостей $8000.. (planes x 8 КБ) под картинку MSX; поля = слот 0 (фон)."""
    v = bytearray(0x2000 * planes)
    for p in range(planes):
        for col in range(32):
            for row in range(256):
                y = 255 - TOP - row
                b = 0
                for i in range(8):
                    c = slotmap[px[y][col*8+i]] if 0 <= y < 212 else 0
                    if (c >> (planes-1-p)) & 1:
                        b |= 0x80 >> i
                v[p*0x2000 + col*256 + row] = b
    return v

IMG_COLORS = {'title': 8, 'victory': int(os.environ.get('VICTORY_COLORS', '4')), 'defeat': 4}

def vram_planes(px, slotmap, planes):
    """Плоскости картинки без полей: planes x 8 КБ, старший бит слота — в первой."""
    v = bytearray(0x2000 * planes)
    for p in range(planes):
        for col in range(32):
            for row in range(256):
                y = 255 - TOP - row
                b = 0
                if 0 <= y < 212:
                    for i in range(8):
                        if (slotmap[px[y][col*8+i]] >> (planes-1-p)) & 1:
                            b |= 0x80 >> i
                v[p*0x2000 + col*256 + row] = b
    return v

def build_images():
    res = {}
    pals = {}
    # титул (8 цв., плоскости $8000..$C000): SETUP 3422 сразу стирает окно меню LINE(34,150)-(222,210),5,BF.
    # Слот 0 = цвет 5 (фон меню и бордюр), обязательны цвета интерфейса меню 1, 2, 3 и 10 (подпись автора)
    t = load_sc5('IRONCLAD.SC5')
    line_bf(t, 34, 150, 222, 210, 5)
    mp = mpal(PAL_MENU)
    cnt = collections.Counter(c for r in t for c in r)
    sl = pick_slots(cnt, mp, 8, (5, 1, 2, 3, 10))
    cm = cmap_of(sl, mp)
    res['title'] = zx0('title', vram_planes(t, cm, 3))
    pals['menu'] = (sl, cm)
    # итог матча (4 цв.): данные — 2 плоскости $A000/$C000 (слоты 0..3, самый частый цвет = слот 0);
    # слот 4 = цвет 1 палитры 9042 (белый бордюр MSX): плоскость $8000 код заливает в полях экрана
    ep = mpal(PAL_END)
    for nm, f in (('victory', 'VICTORY.SC5'), ('defeat', 'DEFEAT.SC5')):
        px = load_sc5(f)
        # подписи (строки 168..203) нарисованы в картинке; полоса 162..211 — ровный фон 5,
        # подписи печатает программа (end_captions)
        line_bf(px, 0, 162, 255, 211, 5)
        n = IMG_COLORS[nm]
        cnt = collections.Counter(c for r in px for c in r)
        top = cnt.most_common(1)[0][0]
        sl = pick_slots(cnt, ep, n, (top, 2))     # 2 — цвет «TAB:»/«SPACE:» в подписях
        cm = cmap_of(sl, ep)
        if n == 4:
            res[nm] = zx0(nm, vram_planes(px, cm, 2))
            sl = sl + [1]                         # слот 4 — бордюр
            cm = dict(cm); cm[1] = 4              # белый (бордюр, заголовок подписи) — слот 4
        else:
            res[nm] = zx0(nm, vram_planes(px, cm, 3))
        pals[nm] = (sl, cm)
    return res, pals

def build_palettes(pals):
    gp, mp = mpal(PAL_GAME), mpal(PAL_MENU)
    txt = ['; сгенерировано tools/mkdata.py: палитры Вектора (BBGGGRRR) 8-цветного режима:',
           '; индекс i -> слот i>>1; слот 0 = фон/бордюр. cmap_* — номер цвета MSX -> слот (для рисования)',
           'pal_game:', db_lines(pal8(GAME_SLOTS, gp)),
           'pal_menu:', db_lines(pal8(pals['menu'][0], mp)),
           'pal_victory:', db_lines(pal8(pals['victory'][0], mpal(PAL_END))),
           'pal_defeat:', db_lines(pal8(pals['defeat'][0], mpal(PAL_END))),
           'cmap_game:', db_lines([CMAP_GAME[c] for c in range(16)]),
           'cmap_menu:', db_lines([pals['menu'][1][c] for c in range(16)]),
           'cmap_victory:', db_lines([pals['victory'][1][c] for c in range(16)]),
           'cmap_defeat:', db_lines([pals['defeat'][1][c] for c in range(16)]),
           'VICTORY_PLANES equ %d' % (3 if IMG_COLORS['victory'] == 8 else 2),
           'DEFEAT_PLANES equ %d' % (3 if IMG_COLORS['defeat'] == 8 else 2),
           '; 4-цветные: данные в $A000/$C000, бордюр — слот 4 (индекс 8), поля — плоскость $8000',
           'BORDER_4C equ 8']
    write('palettes.inc', '\n'.join(txt) + '\n')
    print('слоты: игра', GAME_SLOTS, 'меню', pals['menu'][0], 'победа', pals['victory'][0], 'поражение', pals['defeat'][0])

if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    nt, ng = build_tiles()
    nf = build_font()
    im, pals = build_images()
    build_palettes(pals)
    ver = open(os.path.join(REF, 'VERSION')).read().strip()
    write('version.inc', '        db "V%s"\n' % ver)
    print('тайлы %d Б, глифы %d Б, шрифт %d Б' % (nt, ng, nf))
    for k, v in im.items():
        print('%-8s %6d Б' % (k, v))
    print('картинки всего %d Б' % sum(im.values()))

#!/usr/bin/env python3
"""Страница-галерея картинок порта для просмотра в браузере (локально):
оригиналы MSX, варианты для Вектора (8/4 цвета, цвета Вектора 3-3-2, размер после ZX0), кадры стенда.
    python3 tools/gallery.py [каталог]   # по умолчанию ~/projects/vector06js/ironclad_pics
"""
import sys, os, collections, subprocess, shutil
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mkdata as M
from PIL import Image
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser('~/projects/vector06js/ironclad_pics')
os.makedirs(OUT, exist_ok=True)
TMP = os.path.join(M.ROOT, 'build', 'gallery'); os.makedirs(TMP, exist_ok=True)
def vrgb(w): return ((w & 7) * 255 // 7, ((w >> 3) & 7) * 255 // 7, ((w >> 6) & 3) * 255 // 3)
def msxrgb(c): return tuple(v * 255 // 7 for v in c)
def save(px, colfn, name, h=212):
    im = Image.new('RGB', (256, h))
    for y in range(h):
        for x in range(256): im.putpixel((x, y), colfn(px[y][x]))
    im.resize((512, h * 2), Image.NEAREST).save(os.path.join(OUT, name))
def zsize(v):
    a = os.path.join(TMP, 'x.bin'); b = os.path.join(TMP, 'x.zx0')
    open(a, 'wb').write(v); subprocess.run([M.SALVADOR, a, b], stdout=subprocess.DEVNULL)
    return os.path.getsize(b)
cards = []
def card(group, name, title, note):
    cards.append((group, name, title, note))
# оригиналы
for f, p, bd, t in (('IRONCLAD.SC5', M.PAL_MENU, 5, 'Титул'), ('VICTORY.SC5', M.PAL_END, 1, 'Победа'), ('DEFEAT.SC5', M.PAL_END, 1, 'Поражение')):
    px = M.load_sc5(f); pal = M.mpal(p); pal[0] = p[bd - 1]
    save(px, lambda c: msxrgb(pal[c]), 'msx_' + f.lower() + '.png')
    card('Оригинал MSX2 (16 цветов из 512)', 'msx_' + f.lower() + '.png', t, f + ', 256×212')
# варианты для Вектора
def variant(f, pal, n, forced, planes, blank_caps, title, tag):
    px = M.load_sc5(f)
    if f == 'IRONCLAD.SC5': M.line_bf(px, 34, 150, 222, 210, 5)
    if blank_caps: M.line_bf(px, 0, 162, 255, 211, 5)
    mp = M.mpal(pal); cnt = collections.Counter(c for r in px for c in r)
    top = cnt.most_common(1)[0][0]
    sl = M.pick_slots(cnt, mp, n, forced if forced else (top, 2))
    cm = M.cmap_of(sl, mp)
    size = zsize(M.vram_planes(px, cm, planes))
    save(px, lambda c: vrgb(M.vecbyte(mp[sl[cm[c]]])), tag + '.png')
    card('На Векторе: картинка в памяти (цвета Вектора)', tag + '.png', '%s — %d цв.' % (title, n), '%.1f КБ после ZX0' % (size / 1024))
variant('IRONCLAD.SC5', M.PAL_MENU, 8, (5, 1, 2, 3, 10), 3, False, 'Титул (окно меню рисует программа)', 'vec_title8')
variant('VICTORY.SC5', M.PAL_END, 4, None, 2, True, 'Победа (подписи печатает программа)', 'vec_victory4')
variant('VICTORY.SC5', M.PAL_END, 8, None, 3, True, 'Победа', 'vec_victory8')
variant('DEFEAT.SC5', M.PAL_END, 4, None, 2, True, 'Поражение (подписи печатает программа)', 'vec_defeat4')
variant('DEFEAT.SC5', M.PAL_END, 8, None, 3, True, 'Поражение', 'vec_defeat8')
# кадры стенда, если есть
for fn, t, n in (('build/sp_splash.png', 'Загрузочная заставка (заглушка, 16 цв.)', 'кадр стенда, образ 64 КБ'),
                 ('build/end_cap1.png', 'Экран победы в игре', 'кадр стенда: картинка 4 цв. + подписи'),
                 ('build/end_cap2.png', 'Экран поражения в игре', 'кадр стенда: картинка 4 цв. + подписи'),
                 ('build/c8_p1.png', 'Партия в 8 цветах', 'кадр стенда')):
    src = os.path.join(M.ROOT, fn)
    if os.path.exists(src):
        shutil.copy(src, os.path.join(OUT, os.path.basename(fn)))
        card('Кадры со стенда (vector06js)', os.path.basename(fn), t, n)
groups = []
for g, *_ in cards:
    if g not in groups: groups.append(g)
html = ['<!doctype html><meta charset="utf-8"><title>Картинки IRONCLAD</title>',
        '<style>body{background:#10151d;color:#dde4ee;font:15px/1.5 system-ui,sans-serif;margin:0;padding:24px}'
        'h1{font-size:22px;margin:0 0 6px}h2{font-size:16px;margin:28px 0 10px;color:#9fb0c6}'
        '.row{display:flex;flex-wrap:wrap;gap:18px}.c{background:#18202b;border:1px solid #2a3545;padding:10px;border-radius:6px}'
        '.c img{display:block;image-rendering:pixelated;max-width:100%}.t{margin-top:6px;font-weight:600}.n{color:#8ea0b5;font-size:13px}</style>',
        '<h1>Картинки порта IRONCLAD на Вектор-06Ц</h1><div class="n">Увеличено ×2. Локальная страница, только для просмотра.</div>']
for g in groups:
    html.append('<h2>%s</h2><div class="row">' % g)
    for gg, name, t, n in cards:
        if gg == g: html.append('<div class="c"><img src="%s" width="512"><div class="t">%s</div><div class="n">%s</div></div>' % (name, t, n))
    html.append('</div>')
open(os.path.join(OUT, 'index.html'), 'w').write('\n'.join(html))
print('готово:', OUT)

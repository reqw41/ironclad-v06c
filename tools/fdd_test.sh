#!/bin/sh
# Проверка дисковой версии headless (vector06js + штатное ПЗУ boots.bin): загрузка с дискеты,
# сверка загруженного с файлами байт в байт, время загрузки в кадрах, снимки build/disk/*.png.
#   ./build.sh && python3 tools/build_fdd.py && tools/fdd_test.sh
set -e
cd "$(dirname "$0")/.."
IE=$(grep -m1 '|L|,image_end,' build/ironclad.sld | cut -d'|' -f6)
echo "== build/ironclad.fdd: заставка, игра, меню"
node tools/vfdd.js build/ironclad.fdd "boot;t bt_sld;t bt_splash;cmp build/ironclad.rom 0x8000 0x7F00 32768;\
t res.res_game;s build/disk/splash.png;t 256;cmp build/ironclad.rom 256 0 $((IE-256));t setup_main;w 400;s build/disk/menu.png"
echo "== build/disk/pictest.fdd: титул, победа, поражение в 16 цветах"
S="boot;t bt_splash"
for p in title victory defeat; do
  S="$S;t pt_load;t pt_loaded;cmp build/disk/$p.vram 0x8000;t pt_shown;s build/disk/$p.png"
done
node tools/vfdd.js build/disk/pictest.fdd "$S"

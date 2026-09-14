#!/bin/sh
# Дисковая версия (16 цветов, картинки с дискеты): build/disk/game.rom -> build/ironclad.fdd
#   tools/build_disk.sh            (DEFS=... — доп. флаги, как у build.sh)
# Картридж (./build.sh) от этого не меняется: весь код дисковой версии — под IFDEF DISK,
# выход — в build/disk/.
set -e
cd "$(dirname "$0")/.."
mkdir -p build/disk
python3 tools/mkdata.py >/dev/null          # общие данные (шрифт, словарь, тайлы картриджа, заставка)
python3 tools/mkdisk.py >/dev/null          # картинки, палитры, тайлы 16 цветов
python3 tools/build_fdd.py --layout         # позиции на дискете -> build/disk/layout.inc
DEF="-DDISK ${DEFS:-}"
# проход 1: оверлеи -> build/disk/ovl_*.bin -> salvador -> .zx0 (как в build.sh)
./tools/sjasmplus --i8080 $DEF -DOVL_PASS1 --fullpath src/main.asm >/dev/null 2>&1 || true
for o in ovl_menu ovl_end; do
  cp build/disk/$o.bin build/disk/$o.pass1
  ./tools/salvador build/disk/$o.bin build/disk/$o.zx0 >/dev/null
done
./tools/sjasmplus --i8080 $DEF --fullpath --sld=build/disk/game.sld --lst=build/disk/game.lst src/main.asm 2>&1 \
  | grep -v "^include data" | grep -v "^SjASMPlus" | grep -v "^Pass"
for o in ovl_menu ovl_end; do
  cmp -s build/disk/$o.bin build/disk/$o.pass1 || { echo "ОШИБКА: оверлей $o разный в проходах 1 и 2"; exit 1; }
done
python3 tools/build_fdd.py | grep -v "^title \|^victory \|^defeat \|^тайлы"

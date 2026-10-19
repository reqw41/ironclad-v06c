#!/bin/sh
# Дисковая версия (16 цветов, картинки с дискеты): build/disk/game.rom -> build/ironclad.fdd
#   tools/build_disk.sh                  — русская
#   DEFS=-DLANG_EN tools/build_disk.sh   — английская: build/disk_en/game.rom -> build/ironclad_en.fdd
# Картридж (./build.sh) от этого не меняется: весь код дисковой версии — под IFDEF DISK,
# выход — в build/disk/ (build/disk_en/). Все четыре образа — tools/build_all.sh.
set -e
cd "$(dirname "$0")/.."
DEF="-DDISK ${DEFS:-}"
DD=build/disk; EN=""
case " $DEF " in *" -DLANG_EN "*) DD=build/disk_en; EN=--en;; esac
mkdir -p build/disk $DD
[ -f ref/ironclad-msx/IRONCLAD.SC5 ] || tools/fetch_ref.sh   # исходники MSX: картинки .SC5
python3 tools/mkdata.py >/dev/null          # общие данные (шрифт, словарь, тайлы картриджа, заставка)
python3 tools/mkdisk.py >/dev/null          # картинки, палитры, тайлы 16 цветов
python3 tools/build_fdd.py --layout $EN     # позиции на дискете -> $DD/layout.inc
# проход 1: оверлеи -> $DD/ovl_*.bin -> salvador -> .zx0 (как в build.sh)
./tools/sjasmplus --i8080 $DEF -DOVL_PASS1 --fullpath src/main.asm >/dev/null 2>&1 || true
for o in ovl_menu ovl_end; do
  cp $DD/$o.bin $DD/$o.pass1
  ./tools/salvador $DD/$o.bin $DD/$o.zx0 >/dev/null
done
./tools/sjasmplus --i8080 $DEF --fullpath --sld=$DD/game.sld --lst=$DD/game.lst src/main.asm 2>&1 \
  | grep -v "^include data" | grep -v "^SjASMPlus" | grep -v "^Pass"
for o in ovl_menu ovl_end; do
  cmp -s $DD/$o.bin $DD/$o.pass1 || { echo "ОШИБКА: оверлей $o разный в проходах 1 и 2"; exit 1; }
done
python3 tools/build_fdd.py $EN | grep -v "^title \|^victory \|^defeat \|^тайлы"

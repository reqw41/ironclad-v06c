#!/bin/sh
# Сборка IRONCLAD для Вектора-06Ц: build/ironclad.rom (+ .sld/.lst для стенда)
#   ./build.sh                  — игра, русская
#   DEFS=-DLANG_EN ./build.sh   — английская: build/ironclad_en.rom (оверлеи — в build/en/)
#   ./build.sh libtest          — проверка библиотеки
# Все четыре образа (картридж и дискета, русские и английские) — tools/build_all.sh.
set -e
cd "$(dirname "$0")"
mkdir -p build
[ -f ref/ironclad-msx/IRONCLAD.SC5 ] || tools/fetch_ref.sh   # исходники MSX: картинки .SC5
python3 tools/mkdata.py >/dev/null
DEF="${DEFS:-}"
[ "$1" = "libtest" ] && DEF="-DLIBTEST"
OD=build; ROM=build/ironclad
case " $DEF " in *" -DLANG_EN "*) OD=build/en; ROM=build/ironclad_en; mkdir -p $OD;; esac
if [ "$1" != "libtest" ]; then
  # проход 1: код оверлея меню -> $OD/ovl_menu.bin -> salvador -> $OD/ovl_menu.zx0
  ./tools/sjasmplus --i8080 $DEF -DOVL_PASS1 --fullpath src/main.asm >/dev/null 2>&1 || true
  for o in ovl_menu ovl_end; do
    cp $OD/$o.bin $OD/$o.pass1
    ./tools/salvador $OD/$o.bin $OD/$o.zx0 >/dev/null
  done
fi
./tools/sjasmplus --i8080 $DEF --fullpath --sld=$ROM.sld --lst=$ROM.lst src/main.asm 2>&1 | grep -v "^include data" | grep -v "^SjASMPlus"
if [ "$1" != "libtest" ]; then
  for o in ovl_menu ovl_end; do
    cmp -s $OD/$o.bin $OD/$o.pass1 || { echo "ОШИБКА: оверлей $o разный в проходах 1 и 2"; exit 1; }
  done
  ls -l $OD/ovl_*.bin $OD/ovl_*.zx0 | awk '{print $9":", $5, "Б"}'
fi
ls -l $ROM.rom | awk '{print $9":", $5, "Б"}'

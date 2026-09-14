#!/bin/sh
# Сборка IRONCLAD для Вектора-06Ц: build/ironclad.rom (+ .sld/.lst для стенда)
#   ./build.sh          — игра
#   ./build.sh libtest  — проверка библиотеки
set -e
cd "$(dirname "$0")"
mkdir -p build
python3 tools/mkdata.py >/dev/null
DEF="${DEFS:-}"
[ "$1" = "libtest" ] && DEF="-DLIBTEST"
if [ "$1" != "libtest" ]; then
  # проход 1: код оверлея меню -> build/ovl_menu.bin -> salvador -> build/ovl_menu.zx0
  ./tools/sjasmplus --i8080 $DEF -DOVL_PASS1 --fullpath src/main.asm >/dev/null 2>&1 || true
  for o in ovl_menu ovl_end; do
    cp build/$o.bin build/$o.pass1
    ./tools/salvador build/$o.bin build/$o.zx0 >/dev/null
  done
fi
./tools/sjasmplus --i8080 $DEF --fullpath --sld=build/ironclad.sld --lst=build/ironclad.lst src/main.asm 2>&1 | grep -v "^include data" | grep -v "^SjASMPlus"
if [ "$1" != "libtest" ]; then
  for o in ovl_menu ovl_end; do
    cmp -s build/$o.bin build/$o.pass1 || { echo "ОШИБКА: оверлей $o разный в проходах 1 и 2"; exit 1; }
  done
  ls -l build/ovl_*.bin build/ovl_*.zx0 | awk '{print $9":", $5, "Б"}'
fi
ls -l build/ironclad.rom | awk '{print "build/ironclad.rom:", $5, "Б"}'

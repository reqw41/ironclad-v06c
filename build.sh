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
./tools/sjasmplus --i8080 $DEF --fullpath --sld=build/ironclad.sld --lst=build/ironclad.lst src/main.asm 2>&1 | grep -v "^include data" | grep -v "^SjASMPlus"
ls -l build/ironclad.rom | awk '{print "build/ironclad.rom:", $5, "Б"}'

#!/bin/sh
# ГОТОВЫЕ ОБРАЗЫ В rom/ одной командой:
#   rom/ironclad.rom              — картридж, русский, с заставкой (65280 Б: вторая половина файла —
#                                   картинка прямо в видеопамять, видна во время загрузки)
#   rom/ironclad-nosplash.rom     — то же без заставки (< 32 КБ): для загрузчиков, которым 64 КБ не по
#                                   силам, например Вектор Турбо+ из CP/M (ИМЯ.COM -V T3)
#   rom/ironclad.fdd              — дискета, русская (16 цветов, картинки с дискеты)
#   rom/ironclad-en*.rom, rom/ironclad-en.fdd — то же на английском, языке оригинала
set -e
cd "$(dirname "$0")/.."
mkdir -p rom
Q() { grep -E "error|ОШИБКА|Errors: [1-9]" || true; }
# без заставки — первыми: build.sh пишет в те же build/ironclad*.rom
DEFS=-DNOSPLASH ./build.sh 2>&1 | Q
cp build/ironclad.rom rom/ironclad-nosplash.rom
DEFS="-DNOSPLASH -DLANG_EN" ./build.sh 2>&1 | Q
cp build/ironclad_en.rom rom/ironclad-en-nosplash.rom
tools/build_all.sh
cp build/ironclad.rom rom/ironclad.rom
cp build/ironclad_en.rom rom/ironclad-en.rom
cp build/ironclad.fdd rom/ironclad.fdd
cp build/ironclad_en.fdd rom/ironclad-en.fdd
ls -l rom

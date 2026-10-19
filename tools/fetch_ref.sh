#!/bin/sh
# Исходники MSX-оригинала (mbelgin/ironclad) — в ref/ironclad-msx. Сборка берёт из них картинки
# (*.SC5) и сверяется с текстами BASIC. В репозиторий порта они не входят: у оригинала нет
# лицензии. Скрипт клонирует публичный репозиторий автора и ставит проверенный коммит.
# Вызывается из build.sh и tools/build_disk.sh, если ref/ironclad-msx ещё нет.
set -e
cd "$(dirname "$0")/.."
REV=8dc2a2c0ef789b8da67ad7a8b85275a7a1c91aa5
[ -f ref/ironclad-msx/IRONCLAD.SC5 ] && exit 0
mkdir -p ref
git clone -q https://github.com/mbelgin/ironclad.git ref/ironclad-msx
git -C ref/ironclad-msx checkout -q $REV
echo "ref/ironclad-msx: mbelgin/ironclad @ $(git -C ref/ironclad-msx rev-parse --short HEAD)"

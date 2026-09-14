#!/bin/sh
# Гейт дисковой версии: картридж не изменился (cmp с эталоном, если задан CART_REF=файл),
# трассы 7 правил дисковой сборки = трассы картриджа по всем переменным (экран не сверяется:
# 16 цветов против 8), автоигра 7 правил доходит до меню, замер загрузки картинок в партии.
#   ./build.sh && tools/build_disk.sh && tools/gate_disk.sh
set -e
cd "$(dirname "$0")/.."
[ -n "$CART_REF" ] && { cmp build/ironclad.rom "$CART_REF" && echo "картридж: байт в байт как эталон"; }
T=build/disk/trace; mkdir -p $T
cp build/ironclad.rom $T/cart.rom; cp build/ironclad.sld $T/cart.sld
for r in 0 1 2 3 4 5 6; do
  node tools/trace.js $T/cart.rom $r $T/c$r.json >/dev/null &
  VFDD=build/ironclad.fdd node tools/trace.js build/disk/game.rom $r $T/d$r.json >/dev/null &
done; wait
ok=0
for r in 0 1 2 3 4 5 6; do python3 tools/trace_cmp.py $T/c$r.json $T/d$r.json --noscreen || ok=1; done
for r in 0 1 2 3 4 5 6; do
  VMARK=S3406,show_end_image,dk_rd,dk_done VFDD=build/ironclad.fdd node tools/autoplay.js build/disk/game.rom $r 200000 build/disk/auto/r$r \
    | grep -v снимок > build/disk/auto_r$r.log &
done; wait
for r in 0 1 2 3 4 5 6; do tail -1 build/disk/auto_r$r.log; grep -q "в меню: true" build/disk/auto_r$r.log || ok=1; done
echo "загрузка картинок в партии (правило 6, кадры):"; grep -v правило build/disk/auto_r6.log
[ $ok = 0 ] && echo "ГЕЙТ ДИСКОВОЙ ВЕРСИИ: 7/7 трасс, 7/7 автоигр" || { echo "ГЕЙТ ДИСКОВОЙ ВЕРСИИ: РАСХОЖДЕНИЕ"; exit 1; }

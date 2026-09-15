#!/bin/sh
# Гейт дисковой версии: картридж не изменился (cmp с эталоном, если задан CART_REF=файл),
# трассы 7 правил дисковой сборки = трассы картриджа того же языка по всем переменным (экран не
# сверяется: 16 цветов против 8), автоигра 7 правил доходит до меню, замер загрузки картинок в партии.
#   ./build.sh && tools/build_disk.sh && tools/gate_disk.sh          — русская
#   tools/build_all.sh && tools/gate_disk.sh en                      — английская
#     (build/ironclad_en.rom против build/disk_en/game.rom с дискетой build/ironclad_en.fdd)
set -e
cd "$(dirname "$0")/.."
CART=build/ironclad; DD=build/disk; FDD=build/ironclad.fdd; SFX=""
[ "$1" = "en" ] && { CART=build/ironclad_en; DD=build/disk_en; FDD=build/ironclad_en.fdd; SFX=_en; }
[ -n "$CART_REF" ] && { cmp $CART.rom "$CART_REF" && echo "картридж: байт в байт как эталон"; }
T=$DD/trace; mkdir -p $T
cp $CART.rom $T/cart.rom; cp $CART.sld $T/cart.sld
for r in 0 1 2 3 4 5 6; do
  node tools/trace.js $T/cart.rom $r $T/c$r.json >/dev/null &
  VFDD=$FDD node tools/trace.js $DD/game.rom $r $T/d$r.json >/dev/null &
done; wait
ok=0
for r in 0 1 2 3 4 5 6; do python3 tools/trace_cmp.py $T/c$r.json $T/d$r.json --noscreen || ok=1; done
for r in 0 1 2 3 4 5 6; do
  VMARK=S3406,show_end_image,dk_rd,dk_done VFDD=$FDD node tools/autoplay.js $DD/game.rom $r 200000 $DD/auto/r$r \
    | grep -v снимок > $DD/auto_r$r.log &
done; wait
for r in 0 1 2 3 4 5 6; do tail -1 $DD/auto_r$r.log; grep -q "в меню: true" $DD/auto_r$r.log || ok=1; done
echo "загрузка картинок в партии (правило 6, кадры):"; grep -v правило $DD/auto_r6.log
[ $ok = 0 ] && echo "ГЕЙТ ДИСКОВОЙ ВЕРСИИ$SFX: 7/7 трасс, 7/7 автоигр" || { echo "ГЕЙТ ДИСКОВОЙ ВЕРСИИ$SFX: РАСХОЖДЕНИЕ"; exit 1; }

#!/bin/sh
# Снимки основных экранов (headless, vector06js) -> build/lang/<издание>_<язык>_<экран>.png:
# меню, правила, расстановка, помощь, бой (поле противника и свой флот), итог — победа и поражение.
#   tools/build_all.sh && tools/lang_shots.sh          — английские картридж и дискета
#   tools/lang_shots.sh en ru                          — оба языка
# Итог — из автоигры (tools/autoplay.js): правило 0 кончается поражением, правило 6 (АНКА) —
# победой (прогон детерминирован; если сборка изменится — проверить глазами).
set -e
cd "$(dirname "$0")/.."
O=build/lang; mkdir -p $O
# бой: три выстрела по диагонали, результат залпа, затем другое поле (TAB)
FIRE="k space;w 200;k space;w 100;k space;w 30;k right;k down;k space;w 30;k right;k down;k space;w 30;k right;k down;k space;w 400"
for L in ${@:-en}; do
  S=""; [ $L = en ] && S=_en
  for ED in cart disk; do
    if [ $ED = cart ]; then ROM=build/ironclad$S.rom; V=""; else ROM=build/disk$S/game.rom; V=build/ironclad$S.fdd; fi
    [ $ED = disk ] && [ $L = ru ] && ROM=build/disk/game.rom
    P=$O/${ED}_${L}
    K=z; [ $L = ru ] && K=a
    VFDD=$V node tools/vshot.js $ROM "until S3540 3000;w 10;s ${P}_menu.png;k slash;until S3722 3000;w 5;s ${P}_rules.png;\
k space;until S3540 3000;w 5;k space;until L1416 3000;w 10;s ${P}_place.png;k slash;until L3920 3000;w 5;s ${P}_help.png;\
k space;until L1416 3000;k $K;w 400;$FIRE;s ${P}_battle1.png;k tab;w 60;s ${P}_battle2.png" | grep -c снимок | sed "s|^|$P: снимков |"
    for r in 0 6; do VFDD=$V node tools/autoplay.js $ROM $r 200000 build/lang/auto_${ED}_$L$r >/dev/null & done; wait
    cp build/lang/auto_${ED}_${L}0/end1.png ${P}_defeat.png
    cp build/lang/auto_${ED}_${L}6/end1.png ${P}_victory.png
  done
done
ls $O/*.png | wc -l | sed 's/^/снимков в build\/lang: /'

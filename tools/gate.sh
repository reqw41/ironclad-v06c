#!/bin/sh
# Гейт сверки логики картриджа: сборка -DNOTITLE, трассы 7 правил, сверка с эталонами.
#   tools/gate.sh            — русская сборка против squeeze_base/base<r>.json (выход 1 при расхождении)
#   tools/gate.sh en         — английская (-DLANG_EN) против squeeze_base/en/base<r>.json: все
#                              переменные BASIC, включая строки, точки ожидания, клавиши и экран
#   tools/gate.sh base       — снять русские эталоны (до изменений)
#   tools/gate.sh base_en    — снять английские эталоны со сборки до перевода (коммит 30e4f32^,
#                              временное дерево build/en0wt) — трассы английской сборки должны
#                              совпасть с ними полностью
#   tools/gate.sh ru         — сверка русской сборки с английскими эталонами (trace_cmp.py --ru:
#                              без экрана и текстовых переменных, клавиши Z/X/Q -> A/B/M)
# Внимание: собирает build/ironclad[_en].rom с -DNOTITLE (tools/build_all.sh — собрать заново).
set -e
cd "$(dirname "$0")/.."
ROM=build/ironclad.rom; BASE=squeeze_base; LD=""
case "$1" in
  en) ROM=build/ironclad_en.rom; BASE=squeeze_base/en; LD=-DLANG_EN;;
  ru) BASE=squeeze_base/en;;
esac
if [ "$1" = "base_en" ]; then
  W=build/en0wt; REV=30e4f32^
  [ -d $W ] || git worktree add --detach $W $REV >/dev/null
  ln -sfn "$(cd ref && pwd -P)" $W/ref; mkdir -p $W/build/data
  cp build/data/slotcache.json $W/build/data/ 2>/dev/null || true
  (cd $W && DEFS=-DNOTITLE ./build.sh | grep -E "ironclad.rom|rror")
  mkdir -p squeeze_base/en
  for r in 0 1 2 3 4 5 6; do node tools/trace.js $W/build/ironclad.rom $r squeeze_base/en/base$r.json & done; wait
  exit 0
fi
DEFS="-DNOTITLE $LD" ./build.sh | grep -E "образ|rror" || true
mkdir -p $BASE build/trace
if [ "$1" = "base" ]; then
  for r in 0 1 2 3 4 5 6; do node tools/trace.js $ROM $r $BASE/base$r.json & done; wait
  exit 0
fi
for r in 0 1 2 3 4 5 6; do node tools/trace.js $ROM $r build/trace/t$r.json >/dev/null & done; wait
ok=0
CMP=""; [ "$1" = "ru" ] && CMP="--ru"
for r in 0 1 2 3 4 5 6; do python3 tools/trace_cmp.py $BASE/base$r.json build/trace/t$r.json $CMP || ok=1; done
[ $ok = 0 ] && echo "ГЕЙТ${1:+ ($1)}: все 7 совпали" || { echo "ГЕЙТ${1:+ ($1)}: РАСХОЖДЕНИЕ"; exit 1; }

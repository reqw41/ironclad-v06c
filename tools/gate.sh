#!/bin/sh
# Гейт сверки логики: сборка -DNOTITLE, трассы 7 правил, сверка с эталонами squeeze_base/base<r>.json.
#   tools/gate.sh            — сверка (выход 1 при расхождении)
#   tools/gate.sh base       — снять эталоны (до изменений)
set -e
cd "$(dirname "$0")/.."
DEFS=-DNOTITLE ./build.sh | grep -E "образ|rror" || true
mkdir -p squeeze_base build/trace
if [ "$1" = "base" ]; then
  for r in 0 1 2 3 4 5 6; do node tools/trace.js build/ironclad.rom $r squeeze_base/base$r.json & done; wait
  exit 0
fi
for r in 0 1 2 3 4 5 6; do node tools/trace.js build/ironclad.rom $r build/trace/t$r.json >/dev/null & done; wait
ok=0
for r in 0 1 2 3 4 5 6; do python3 tools/trace_cmp.py squeeze_base/base$r.json build/trace/t$r.json || ok=1; done
[ $ok = 0 ] && echo "ГЕЙТ: все 7 совпали" || { echo "ГЕЙТ: РАСХОЖДЕНИЕ"; exit 1; }

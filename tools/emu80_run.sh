#!/bin/sh
# Emu80 без окна (GUI владельца не трогаем): tools/emu80_run.sh <образ.rom> [порт]
# Запускать в фоне; готовность — порт MCP слушается (lsof -nP -iTCP:<порт>).
# Погасить: kill $(lsof -nP -t -iTCP:<порт> -sTCP:LISTEN)
ROM=$(cd "$(dirname "$1")" && pwd)/$(basename "$1"); PORT=${2:-19798}
cd ~/projects/emu80v4/Emu80qt-mcp.app/Contents/MacOS && \
QT_QPA_PLATFORM=offscreen QT_PLUGIN_PATH=/opt/homebrew/share/qt/plugins EMU80_MCP_PORT=$PORT exec ./Emu80qt-mcp --platform vector --run "$ROM"

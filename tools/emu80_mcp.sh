#!/bin/sh
# curl-помощник MCP Emu80 (без окна: см. tools/emu80_run.sh): tools/emu80_mcp.sh <инструмент> '<json>' [порт]
#   screen '{}' | kbd_send '{"keys":["space"],"action":"tap","duration_ms":200}' | mem_read '{"addr":"0xF100","len":64}'
#   emu_load '{"file":"...rom","run":true}' (после него — switch_platform '{"platform":"vector"}')
# Снимок в PNG: tools/emu80_mcp.sh screen '{}' | python3 tools/emu80_png.py out.png
TOOL=$1; ARGS=${2:-'{}'}; PORT=${3:-19798}
H='-H Content-Type:application/json -H Accept:application/json,text/event-stream'
curl -s $H -X POST http://127.0.0.1:$PORT/mcp -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"ironclad","version":"0"}}}' >/dev/null
curl -s $H -X POST http://127.0.0.1:$PORT/mcp -d "{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"tools/call\",\"params\":{\"name\":\"$TOOL\",\"arguments\":$ARGS}}"

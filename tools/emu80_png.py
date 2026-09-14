#!/usr/bin/env python3
"""Ответ MCP-инструмента screen (stdin: JSON или SSE 'data: {...}') -> PNG-файл argv[1]."""
import sys, json, base64
t = sys.stdin.read()
for line in t.splitlines():
    if line.startswith('data:'):
        t = line[5:]
        break
r = json.loads(t)
for c in r['result']['content']:
    if c.get('type') == 'image':
        open(sys.argv[1], 'wb').write(base64.b64decode(c['data']))
        print(sys.argv[1])
        break
else:
    print('нет картинки:', t[:300]); sys.exit(1)

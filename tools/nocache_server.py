#!/usr/bin/env python3
"""Статический сервер без кэша для vector06js: python3 tools/nocache_server.py [порт] [каталог]"""
import http.server, os, sys
port = int(sys.argv[1]) if len(sys.argv) > 1 else 8000
os.chdir(sys.argv[2] if len(sys.argv) > 2 else os.path.expanduser('~/projects/vector06js'))
class H(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Cache-Control', 'no-store')
        super().end_headers()
    def log_message(self, *a): pass
http.server.ThreadingHTTPServer(('127.0.0.1', port), H).serve_forever()

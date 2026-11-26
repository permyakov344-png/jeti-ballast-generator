#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Приёмник файлов из браузера: POST /save/<name> с телом → папка out/.

Нужен только для сверки: генератор в браузере скачивает .lua через <a download>,
а здесь мы забираем тот же текст по HTTP, чтобы прогнать тесты.

    python tools/collect.py 8766 reference
"""

import os
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


class Handler(BaseHTTPRequestHandler):
    outdir = "."

    def _cors(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "*")

    def do_OPTIONS(self):
        self.send_response(204)
        self._cors()
        self.end_headers()

    def do_POST(self):
        name = os.path.basename(self.path.rstrip("/").split("/")[-1]) or "out.lua"
        length = int(self.headers.get("Content-Length") or 0)
        body = self.rfile.read(length)
        path = os.path.join(self.outdir, name)
        with open(path, "wb") as f:
            f.write(body)
        print("saved %s (%d bytes)" % (path, len(body)), flush=True)
        self.send_response(200)
        self._cors()
        self.send_header("Content-Type", "text/plain")
        self.end_headers()
        self.wfile.write(b"ok")

    def log_message(self, *args):
        pass


def main(argv):
    port = int(argv[1]) if len(argv) > 1 else 8766
    Handler.outdir = argv[2] if len(argv) > 2 else "."
    os.makedirs(Handler.outdir, exist_ok=True)
    print("listening on %d -> %s" % (port, Handler.outdir), flush=True)
    ThreadingHTTPServer(("127.0.0.1", port), Handler).serve_forever()


if __name__ == "__main__":
    main(sys.argv)

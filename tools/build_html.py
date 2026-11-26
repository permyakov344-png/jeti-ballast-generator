#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Собирает generator/jeti_lua_generator.html из generator.js + текущей «шапки».

Шапка (HTML + CSS) уже лежит в самом HTML-файле, меняется только <script>.

    python tools/build_html.py
"""

import io
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HTML = os.path.join(ROOT, "generator", "jeti_lua_generator.html")
JS = os.path.join(ROOT, "tools", "generator.js")


def main():
    with io.open(HTML, encoding="utf-8") as f:
        src = f.read()

    # основной скрипт — последний блок <script> в файле
    head = src.rsplit("<script>", 1)[0]
    with io.open(JS, encoding="utf-8") as f:
        js = f.read()

    out = head + "<script>\n" + js + "</script>\n</body>\n</html>\n"
    with io.open(HTML, "w", encoding="utf-8", newline="\n") as f:
        f.write(out)
    print("built %s (%d байт)" % (HTML, len(out.encode("utf-8"))))
    return 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Проверяет, что все ссылки и картинки в README и index.html ведут на
существующие файлы (или на внешний сайт).

    python tools/check_links.py
"""

import io
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def collect(text, base_url_ok=True):
    out = []
    for m in re.finditer(r'!?\[[^\]]*\]\(([^)\s]+)\)', text):
        out.append(m.group(1))
    for m in re.finditer(r'(?:src|href)="([^"]+)"', text):
        out.append(m.group(1))
    return out


def local_target(url):
    if url.startswith(("http://", "https://", "#", "mailto:")):
        return None
    return url.split("#")[0].split("?")[0]


def main():
    bad = 0
    for name in ("README.md", "index.html"):
        path = os.path.join(ROOT, name)
        if not os.path.exists(path):
            continue
        text = io.open(path, encoding="utf-8").read()
        for url in sorted(set(collect(text))):
            target = local_target(url)
            if target is None:
                continue
            full = os.path.join(ROOT, target.replace("/", os.sep))
            if not os.path.exists(full):
                print("MISSING  %-14s %s" % (name, url))
                bad += 1
    if bad:
        print("\n%d битых ссылок" % bad)
        return 1
    print("все ссылки в README.md и index.html на месте")
    return 0


if __name__ == "__main__":
    sys.exit(main())

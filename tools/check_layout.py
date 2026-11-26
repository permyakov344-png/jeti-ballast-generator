#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Проверка раскладки: ничего не вылезает за экран и тексты не наезжают друг на друга.

    python tools/check_layout.py output
"""

import glob
import os
import sys

from lupa import LuaRuntime

from preview import STUB, FONT_BIG_PX

W, H = 320, 240
CHAR_W = {0: 7, 1: 7, 2: 6, 3: 11, 4: 15}
CHAR_H = {0: 14, 1: 14, 2: 11, 3: 20, 4: 26}


def boxes(gi):
    out = []
    for row in [list(r.values()) for r in gi.calls["texts"].values()]:
        x, y, s, f = int(row[0]), int(row[1]), str(row[2]), int(row[3])
        w = len(s) * CHAR_W.get(f, 7)
        h = CHAR_H.get(f, 14)
        out.append((x, y, w, h, s))
    return out


def check(path):
    rt = LuaRuntime(unpack_returned_tuples=True)
    rt.execute(STUB)
    mod = rt.execute(open(path, encoding="utf-8").read())
    gi = rt.globals()
    mod["init"]()
    form = gi.calls["form"]
    problems = []

    pages = 0
    total = 1
    for _ in range(30):
        rt.execute("calls.rects = {}; calls.texts = {}; calls.lines = {}")
        form["print"]()
        pages += 1
        for row in [list(r.values()) for r in gi.calls["texts"].values()]:
            if str(row[2]).startswith("p."):
                total = int(str(row[2]).split("/")[-1])
        bs = boxes(gi)
        for x, y, w, h, s in bs:
            if x < 0 or y < 0 or x + w > W or y + h > H:
                problems.append("стр.%d: '%s' вылезает (%d,%d %dx%d)" % (pages, s, x, y, w, h))
        for i in range(len(bs)):
            for j in range(i + 1, len(bs)):
                x1, y1, w1, _, s1 = bs[i]
                x2, y2, w2, _, s2 = bs[j]
                h1, h2 = bs[i][3], bs[j][3]
                if y1 < y2 + h2 - 1 and y2 < y1 + h1 - 1 and x1 < x2 + w2 and x2 < x1 + w1:
                    problems.append("стр.%d: '%s' и '%s' наезжают" % (pages, s1, s2))
        form["key"](gi.KEY_DOWN)
        if pages >= total:
            break

    return pages, problems


def main(argv):
    src = argv[1] if len(argv) > 1 else "output"
    files = ([src] if src.endswith(".lua")
             else [p for p in sorted(glob.glob(os.path.join(src, "*.lua")))])
    if not files:
        print("нет .lua")
        return 1
    bad = 0
    for path in files:
        pages, problems = check(path)
        name = os.path.basename(path)
        if problems:
            bad += 1
            print("FAIL %-24s %d стр., %d проблем" % (name, pages, len(problems)))
            for p in problems[:6]:
                print("     " + p)
        else:
            print("ok   %-24s %d стр., раскладка чистая" % (name, pages))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))

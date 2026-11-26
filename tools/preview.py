#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Отрисовка превью экрана Jeti (320x240) из .lua без передатчика.

Перехватывает вызовы lcd.* и рисует их PIL'ом — чтобы проверить раскладку
до загрузки скрипта в DC-24.

    python tools/preview.py output/PIKEF3F.lua preview
"""

import os
import sys

from lupa import LuaRuntime
from PIL import Image, ImageDraw, ImageFont

W, H = 320, 240

STUB = r"""
FONT_NORMAL, FONT_BOLD, FONT_MINI, FONT_BIG, FONT_MAXI = 0, 1, 2, 3, 4
MENU_MAIN, MENU_APPS = 1, 2
KEY_UP, KEY_DOWN, KEY_ESC = 1, 2, 3

calls = {rects = {}, lines = {}, texts = {}, colors = {}}
fg = {255, 255, 255}

local function push(tbl, ...) tbl[#tbl + 1] = {...} end

lcd = {
  width = 320, height = 240,
  setColor = function(r, g, b) fg = {r, g, b}; push(calls.colors, r, g, b) end,
  drawFilledRectangle = function(x, y, w, h)
    push(calls.rects, x, y, w, h, fg[1], fg[2], fg[3])
  end,
  drawRectangle = function(x, y, w, h)
    push(calls.lines, x, y, x + w, y, fg[1], fg[2], fg[3])
    push(calls.lines, x, y + h, x + w, y + h, fg[1], fg[2], fg[3])
    push(calls.lines, x, y, x, y + h, fg[1], fg[2], fg[3])
    push(calls.lines, x + w, y, x + w, y + h, fg[1], fg[2], fg[3])
  end,
  drawLine = function(x1, y1, x2, y2)
    push(calls.lines, x1, y1, x2, y2, fg[1], fg[2], fg[3])
  end,
  drawText = function(x, y, s, f)
    push(calls.texts, x, y, tostring(s), f or 0, fg[1], fg[2], fg[3])
  end,
  getTextWidth = function(f, s)
    local k = (f == FONT_BIG and 11) or (f == FONT_MAXI and 15) or 7
    return #tostring(s) * k, 18
  end,
  drawNumber = function() end,
  clear = function() end,
}

system = {
  exitScript = function() calls.exited = true end,
  registerForm = function(id, menu, label, initFn, keyFn, printFn)
    calls.form = {label = label, key = keyFn, print = printFn}
    return id
  end,
}
"""

FONT_BIG_PX = {0: 12, 1: 12, 2: 8, 3: 16, 4: 22}


def font_for(spec):
    size = FONT_BIG_PX.get(int(spec), 10)
    for name in ("consola.ttf", "arial.ttf", "DejaVuSansMono.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            continue
    return ImageFont.load_default()


def render(lua_path, page=1):
    rt = LuaRuntime(unpack_returned_tuples=True)
    rt.execute(STUB)
    mod = rt.execute(open(lua_path, encoding="utf-8").read())
    gi = rt.globals()
    mod["init"]()
    form = gi.calls["form"]

    for _ in range(page - 1):
        form["key"](gi.KEY_DOWN)

    rt.execute("calls.rects = {}; calls.texts = {}; calls.lines = {}; calls.colors = {}")
    form["print"]()

    img = Image.new("RGB", (W, H), (0, 0, 0))
    dr = ImageDraw.Draw(img)

    for row in [list(r.values()) for r in gi.calls["rects"].values()]:
        x, y, w, h, r, g, b = row
        x, y, w, h = float(x), float(y), float(w), float(h)
        dr.rectangle([x, y, x + max(w, 1) - 1, y + max(h, 1) - 1],
                     fill=(int(r), int(g), int(b)))

    for row in [list(r.values()) for r in gi.calls["lines"].values()]:
        x1, y1, x2, y2, r, g, b = row
        dr.line([float(x1), float(y1), float(x2), float(y2)],
                fill=(int(r), int(g), int(b)), width=1)

    for row in [list(r.values()) for r in gi.calls["texts"].values()]:
        x, y, s, f, r, g, b = row
        dr.text((float(x), float(y)), str(s), font=font_for(f),
                fill=(int(r), int(g), int(b)))

    return img


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 1
    src = argv[1]
    outdir = argv[2] if len(argv) > 2 else "preview"
    os.makedirs(outdir, exist_ok=True)

    files = ([src] if src.endswith(".lua")
             else [os.path.join(src, f) for f in sorted(os.listdir(src))
                   if f.endswith(".lua")])
    for path in files:
        base = os.path.splitext(os.path.basename(path))[0]
        img = render(path, 1)
        out = os.path.join(outdir, base + ".png")
        img.save(out)
        print("%-24s -> %s" % (base, out))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))

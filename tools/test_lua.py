#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Проверка сгенерированных .lua без передатчика.

Подставляет заглушки Jeti Lua API (lcd, system, FONT_*, KEY_*, MENU_APPS),
выполняет init() + draw() + перелистывание страниц и падает, если скрипт
вызывает несуществующие функции (setFont, drawFilledRect, color, RGB) или
уходит в ошибку.

    python tools/test_lua.py output/*.lua
"""

import glob
import os
import sys

from lupa import LuaRuntime

STUB = r"""
-- ── заглушки Jeti Lua API ────────────────────────────────────
FONT_NORMAL, FONT_BOLD, FONT_MINI, FONT_BIG, FONT_MAXI = 0, 1, 2, 3, 4
MENU_MAIN, MENU_APPS = 1, 2
KEY_UP, KEY_DOWN, KEY_ESC = 1, 2, 3

calls = {texts = {}, rects = {}, lines = {}, colors = {}, errors = {}}

local function rec(bucket, ...)
  calls[bucket][#calls[bucket] + 1] = {...}
end

lcd = {
  width = 320, height = 240,
  setColor  = function(r, g, b, a) rec('colors', r, g, b) end,
  drawFilledRectangle = function(x, y, w, h) rec('rects', x, y, w, h) end,
  drawRectangle = function(x, y, w, h) rec('rects', x, y, w, h) end,
  drawLine   = function(x1, y1, x2, y2) rec('lines', x1, y1, x2, y2) end,
  drawText   = function(x, y, s, f) rec('texts', x, y, tostring(s), f or 0) end,
  getTextWidth = function(f, s) return #tostring(s) * 8, 18 end,
  drawNumber = function() end,
  clear = function() end,
}

system = {
  exitScript = function() calls.exited = true end,
  registerForm = function(id, menu, label, initFn, keyFn, printFn)
    calls.form = {id = id, menu = menu, label = label, key = keyFn, print = printFn}
    return id
  end,
}

-- запрещаем несуществующие вызовы
local api = lcd
lcd.setFont = function() error('lcd.setFont не существует в Jeti API') end
lcd.color   = function() error('lcd.color не существует в Jeti API') end
lcd.drawFilledRect = function() error('lcd.drawFilledRect: нужно drawFilledRectangle') end
"""


def run(path):
    runtime = LuaRuntime(unpack_returned_tuples=True)
    runtime.execute(STUB)
    with open(path, encoding="utf-8") as f:
        chunk = f.read()

    mod = runtime.execute(chunk)
    assert mod is not None, "скрипт не вернул таблицу"
    for field in ("init", "loop", "name", "version"):
        assert mod[field] is not None, "нет поля " + field

    mod["init"]()
    form = runtime.globals().calls["form"]
    assert form is not None, "init() не вызвал system.registerForm"
    assert form["label"], "пустой заголовок формы"

    form["print"]()
    texts = runtime.globals().calls["texts"]
    assert len(texts) > 0, "draw() ничего не нарисовал"

    # пролистать все страницы вперёд и назад
    key = form["key"]
    for _ in range(20):
        key(runtime.globals().KEY_DOWN)
        form["print"]()
    for _ in range(20):
        key(runtime.globals().KEY_UP)
        form["print"]()
    key(runtime.globals().KEY_ESC)
    assert runtime.globals().calls["exited"] is True, "ESC не вызывает system.exitScript"

    return len(texts), len(runtime.globals().calls["rects"])


BAD = ("setFont", "lcd.color(", "drawFilledRect(", "lcd.RGB(")


def main(argv):
    args = argv[1:]
    files = []
    for a in args:
        if os.path.isdir(a):
            files.extend(sorted(glob.glob(os.path.join(a, "*.lua"))))
        else:
            files.append(a)
    if not args:
        files = sorted(glob.glob(os.path.join("output", "*.lua")))
    if not files:
        print("нет файлов для проверки")
        return 1

    failed = 0
    for path in files:
        src = open(path, encoding="utf-8").read()
        bad = [b for b in BAD if b in src]
        if bad:
            print("FAIL %-24s запрещённые вызовы: %s" % (path, ", ".join(bad)))
            failed += 1
            continue
        try:
            texts, rects = run(path)
        except Exception as exc:  # noqa: BLE001
            print("FAIL %-24s %s" % (path, exc))
            failed += 1
            continue
        print("ok   %-24s %d строк текста, %d прямоугольников" % (path, texts, rects))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))

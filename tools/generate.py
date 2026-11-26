#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Jeti Lua Generator (offline CLI).

Читает Excel (.xls / .xlsx) с таблицами балласта и собирает .lua приложения
для Jeti DC-24 / DS-24. Тот же алгоритм, что и в generator/jeti_lua_generator.html.

    python tools/generate.py data/zagluzka_2026_v2.xls output
"""

import json
import os
import re
import sys

# ─────────────────────────── чтение Excel ───────────────────────────


def read_sheets(path):
    if os.path.splitext(path)[1].lower() == ".xls":
        import xlrd
        wb = xlrd.open_workbook(path)
        return [
            (sh.name, [
                [sh.cell_value(r, c) if sh.cell_type(r, c) else None
                 for c in range(sh.ncols)]
                for r in range(sh.nrows)
            ])
            for sh in wb.sheets()
        ]

    import openpyxl
    wb = openpyxl.load_workbook(path, data_only=True)
    return [
        (ws.title, [list(row) for row in ws.iter_rows(values_only=True)])
        for ws in wb.worksheets
    ]


# ─────────────────────────── нормализация ───────────────────────────


def as_text(v):
    if v is None:
        return "--"
    if isinstance(v, bool):
        return "1" if v else "0"
    if isinstance(v, float):
        if v == int(v):
            return str(int(v))
        return ("%.3f" % v).rstrip("0").rstrip(".")
    if isinstance(v, int):
        return str(v)
    s = str(v).replace("\u00a0", " ").strip()
    return s if s else "--"


def as_int(v):

    if v is None or isinstance(v, bool):
        return None
    if isinstance(v, (int, float)):
        return int(v) if v == int(v) else None
    s = str(v).strip()
    if re.fullmatch(r"\d+(\.0+)?", s):
        return int(float(s))
    return None


def cell(row, idx):
    return row[idx] if idx < len(row) else None


# ─────────────────────────── разбор листа ───────────────────────────


def parse_sheet(name, rows):
    """Имя листа → заголовок; row0 → слоги; пары строк → варианты."""
    head = rows[0] if rows else []

    # заголовок: строка с максимумом латинских букв
    title, best = "", -1
    for v in head:
        t = as_text(v)
        if t == "--" or re.fullmatch(r"[\d.,]+", t):
            continue
        score = len(re.findall(r"[A-Za-z]", t))
        if score > best:
            best, title = score, t
    if not title:
        title = name.strip()

    slugs = []
    for v in head:
        t = as_text(v)
        if t == "--" or re.fullmatch(r"[\d.,]+", t):
            continue
        slugs.append(t)
    slugs = [clean_slug(s) for s in slugs
             if s != title and re.search(r"[\d/]", s)]

    # сдвиг правого блока: ищем во 2-й строке вторую колонку "№"
    hdr = rows[1] if len(rows) > 1 else []
    off = 5
    seen = 0
    for c, v in enumerate(hdr):
        if as_text(v).startswith("№"):
            seen += 1
            if seen == 2:
                off = c
                break

    found = {}
    i = 2
    while i < len(rows):
        r1, r2 = rows[i], (rows[i + 1] if i + 1 < len(rows) else [])
        for col in (0, off):
            num = as_int(cell(r1, col))
            if num is None or num <= 0:
                continue
            vals = [
                as_text(cell(r1, col + 1)), as_text(cell(r2, col + 1)),
                as_text(cell(r1, col + 2)),
                as_text(cell(r1, col + 3)), as_text(cell(r2, col + 3)),
                as_text(cell(r1, col + 4)),
            ]
            found[num] = vals
        i += 2

    variants = [[clean_cell(v) for v in found[k]] for k in sorted(found)]
    return {"name": name, "title": title, "slugs": slugs,
            "rows": variants}


def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


TRANSLIT = {
    "а": "a", "б": "b", "в": "v", "г": "g", "д": "d", "е": "e", "ё": "e",
    "ж": "zh", "з": "z", "и": "i", "й": "j", "к": "k", "л": "l", "м": "m",
    "н": "n", "о": "o", "п": "p", "р": "r", "с": "s", "т": "t", "у": "u",
    "ф": "f", "х": "h", "ц": "c", "ч": "ch", "ш": "sh", "щ": "sch", "ъ": "",
    "ы": "y", "ь": "", "э": "e", "ю": "ju", "я": "ja",
}


def translit(s):
    """Кириллица → латиница: DC/DS не умеет выводить кириллицу."""
    out = []
    for ch in s:
        low = ch.lower()
        if low in TRANSLIT:
            rep = TRANSLIT[low]
            out.append(rep[:1].upper() + rep[1:] if ch.isupper() else rep)
        else:
            out.append(ch)
    return "".join(out)


# цвета балласта пишем коротко — иначе не влезает в ячейку
COLOR_WORDS = {
    "черный": "CHERN", "чёрный": "CHERN", "красный": "KRASN",
    "белый": "BELYJ", "синий": "SINIJ", "зеленый": "ZELEN",
    "зелёный": "ZELEN", "желтый": "ZHELT", "жёлтый": "ZHELT",
    "латунь": "LATUN", "сталь": "STAL",
}


def clean_slug(s):
    """'45г/98' → '45/98': на экране передатчика 'г' лишняя."""
    return translit(s.replace("г", "").replace("Г", "").strip())


def clean_cell(s):
    if s in ("--", ""):
        return s
    key = s.strip().lower()
    if key in COLOR_WORDS:
        return COLOR_WORDS[key]
    return translit(s)


# ─────────────────────────── шаблон Lua ───────────────────────────

LUA_TEMPLATE = r"""-- {fname}.lua
-- {title} - Ballast Table
-- Jeti DC-24 / DS-24, Lua API (setColor / drawFilledRectangle / FONT_*)
-- UP/DOWN - page, ESC - exit
-- Generated by Jeti Lua Generator

local TITLE = {title_lit}
local SLUGS = {{{slugs}}}
local RTAG  = {rtag_lit}

local data = {{
{data}
}}

local PER_PAGE = 2
local pages = {{}}
for i = 1, #data, PER_PAGE do pages[#pages + 1] = {{i, data[i + 1] and i + 1 or nil}} end
local page  = 1
local PAGES = #pages

local W, H = 320, 240
local HDR_H, COLH_H = 18, 16
local ROW_H = 97
local SUB_H = 48
local Cn  = {{x = 0,   w = 36}}
local Cno = {{x = 36,  w = 72}}
local Cw  = {{x = 108, w = 70}}
local Ccg = {{x = 178, w = 72}}
local Cv  = {{x = 250, w = 70}}

local function ct(col, y, h, s, font)
  local tw = lcd.getTextWidth(font, s)
  if tw > col.w - 4 then font = FONT_MINI; tw = lcd.getTextWidth(font, s) end
  lcd.drawText(col.x + (col.w - tw) // 2, y + (h - 14) // 2, s, font)
end

local function dv(y0, idx)
  local v  = data[idx]
  local y1 = y0 + SUB_H
  lcd.setColor(200, 200, 200); lcd.drawFilledRectangle(Cn.x,  y0, Cn.w,  ROW_H)
  lcd.setColor(205, 205, 205); lcd.drawFilledRectangle(Cno.x, y0, Cno.w, ROW_H)
  lcd.setColor(200, 100, 0);   lcd.drawFilledRectangle(Cw.x,  y0, Cw.w,  ROW_H)
  lcd.setColor(205, 205, 205); lcd.drawFilledRectangle(Ccg.x, y0, Ccg.w, ROW_H)
  lcd.setColor(80, 170, 0);    lcd.drawFilledRectangle(Cv.x,  y0, Cv.w,  ROW_H)
  lcd.setColor(150, 150, 150)
  lcd.drawLine(Cno.x, y1 - 1, Cno.x + Cno.w, y1 - 1)
  lcd.drawLine(Ccg.x, y1 - 1, Ccg.x + Ccg.w, y1 - 1)
  lcd.setColor(120, 120, 120)
  lcd.drawLine(Cno.x - 1, y0, Cno.x - 1, y0 + ROW_H)
  lcd.drawLine(Cw.x - 1,  y0, Cw.x - 1,  y0 + ROW_H)
  lcd.drawLine(Ccg.x - 1, y0, Ccg.x - 1, y0 + ROW_H)
  lcd.drawLine(Cv.x - 1,  y0, Cv.x - 1,  y0 + ROW_H)
  lcd.setColor(100, 100, 100)
  lcd.drawLine(0, y0 + ROW_H - 1, W, y0 + ROW_H - 1)
  lcd.setColor(10, 10, 10)
  ct(Cn,  y0, ROW_H, tostring(idx), FONT_BIG)
  ct(Cno, y0, SUB_H, v[1], FONT_BIG)
  ct(Cno, y1, SUB_H, v[2], FONT_BIG)
  ct(Cw,  y0, ROW_H, v[3], FONT_BIG)
  ct(Ccg, y0, SUB_H, v[4], FONT_BIG)
  ct(Ccg, y1, SUB_H, v[5], FONT_BIG)
  ct(Cv,  y0, ROW_H, v[6], FONT_BIG)
end

local function chdr(col, s, r, g, b)
  lcd.setColor(r, g, b)
  local tw = lcd.getTextWidth(FONT_MINI, s)
  lcd.drawText(col.x + (col.w - tw) // 2, HDR_H + 3, s, FONT_MINI)
end

local function draw()
  lcd.setColor(30, 30, 30);  lcd.drawFilledRectangle(0, 0, W, H)
  lcd.setColor(90, 90, 90);  lcd.drawFilledRectangle(0, 0, W, HDR_H)
  local x = 3
  lcd.setColor(0, 220, 255)
  local t = TITLE
  while lcd.getTextWidth(FONT_MINI, t) > 150 and #t > 4 do
    t = string.sub(t, 1, #t - 1)
  end
  lcd.drawText(x, 3, t, FONT_MINI)
  x = x + lcd.getTextWidth(FONT_MINI, t) + 4
  lcd.setColor(255, 238, 136)
  local xlim = W - lcd.getTextWidth(FONT_MINI, RTAG) - 6
  for _, s in ipairs(SLUGS) do
    local sw = lcd.getTextWidth(FONT_MINI, s)
    if x + sw > xlim then break end
    lcd.drawText(x, 3, s, FONT_MINI)
    x = x + sw + 4
  end
  lcd.setColor(255, 100, 30)
  lcd.drawText(W - lcd.getTextWidth(FONT_MINI, RTAG) - 3, 3, RTAG, FONT_MINI)

  lcd.setColor(210, 210, 210); lcd.drawFilledRectangle(0, HDR_H, W, COLH_H)
  chdr(Cn,  "No",    20, 20, 20)
  chdr(Cno, "NOS",   20, 20, 20)
  chdr(Cw,  "KRYLO", 20, 20, 20)
  chdr(Ccg, "CG",    200, 0, 0)
  chdr(Cv,  "VES",   20, 20, 20)
  lcd.setColor(120, 120, 120)
  lcd.drawLine(0, HDR_H + COLH_H - 1, W, HDR_H + COLH_H - 1)

  local p  = pages[page]
  local yd = HDR_H + COLH_H
  dv(yd, p[1])
  if p[2] then dv(yd + ROW_H, p[2]) end

  local foot = "p." .. page .. "/" .. PAGES
  lcd.setColor(100, 100, 100)
  lcd.drawText(W - lcd.getTextWidth(FONT_MINI, foot) - 3, H - 12, foot, FONT_MINI)
end

local function key(k)
  if k == KEY_UP then
    page = page - 1
    if page < 1 then page = PAGES end
  elseif k == KEY_DOWN then
    page = page + 1
    if page > PAGES then page = 1 end
  elseif k == KEY_ESC then
    system.exitScript()
  end
end

local function init()
  system.registerForm(1, MENU_APPS, TITLE, nil, key, draw)
end

return {{init = init, loop = function() end, author = "Ballast", version = "1.0", name = TITLE}}
"""


def make_filename(title, override=None):
    if override:
        return override
    s = re.sub(r"\s*20\d\d\s*$", "", title)
    s = re.sub(r"[^A-Za-z0-9]", "", s).upper()
    return (s or "BALLAST")[:8]


def build_lua(sheet, fname):
    data = ",\n".join(
        "  {" + ", ".join(lua_str(v) for v in row) + "}" for row in sheet["rows"]
    )
    return LUA_TEMPLATE.format(
        fname=fname,
        title=translit(sheet["title"]),
        title_lit=lua_str(translit(sheet["title"])),
        slugs=", ".join(lua_str(s) for s in sheet["slugs"]),
        rtag_lit=lua_str("MED'"),
        data=data,
    )


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 1
    src = argv[1]
    outdir = argv[2] if len(argv) > 2 else "output"
    names = {}
    if len(argv) > 3 and os.path.isfile(argv[3]):
        with open(argv[3], encoding="utf-8") as f:
            names = json.load(f)
    os.makedirs(outdir, exist_ok=True)

    for name, rows in read_sheets(src):
        sheet = parse_sheet(name, rows)
        if not sheet["rows"]:
            print("skip %-16s (нет вариантов)" % name)
            continue
        fname = make_filename(sheet["title"], names.get(name))
        path = os.path.join(outdir, fname + ".lua")
        with open(path, "w", encoding="utf-8", newline="\n") as f:
            f.write(build_lua(sheet, fname))
        print("%-16s -> %s (%d вариантов, %d строк)" % (
            name, path, len(sheet["rows"]),
            sum(1 for _ in open(path, encoding="utf-8"))))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))

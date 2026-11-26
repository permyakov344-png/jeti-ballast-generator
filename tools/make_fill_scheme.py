#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Рисует наглядную схему заполнения таблицы: docs/img/03-fill-scheme.png

Не зависит от Excel/LibreOffice — рисуется напрямую PIL'ом, поэтому одинакова
на любой машине.

    python tools/make_fill_scheme.py
"""

import os
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "docs", "img", "03-fill-scheme.png")

BG = (255, 255, 255)
GRID = (190, 198, 208)
HEAD_FILL = (232, 236, 242)
EDIT_FILL = (255, 244, 200)
TITLE_FILL = (214, 228, 243)
TEXT = (28, 34, 42)
DIM = (110, 122, 136)
NOTE = (0, 110, 170)

CELL_W = 78
CELL_H = 40
COL0 = 86
ROW0 = 96

HEAD = ["№", "НОС", "КРЫЛО", "CG", "ВЕС"]

# строки листа: (значения левого блока, значения правого блока)
ROWS = [
    ["1", "0", "0", "103", "2300"],
    ["", "45", "", "98", ""],
    ["2", "15", "0.5", "102", "2500"],
    ["", "45", "", "98", ""],
    ["3", "15", "1", "102", "2700"],
    ["", "45", "", "98", ""],
    ["4", "15", "1.5", "102", "2850"],
    ["", "45", "", "98", ""],
]


def font(size, bold=False):
    names = (("seguisb.ttf", "segoeuib.ttf", "arialbd.ttf") if bold
             else ("segoeui.ttf", "arial.ttf", "DejaVuSans.ttf"))
    for name in names:
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            continue
    return ImageFont.load_default()


def cell_box(col, row, block=0):
    x = COL0 + (col + block * 5) * CELL_W
    y = ROW0 + row * CELL_H
    return x, y, x + CELL_W, y + CELL_H


def draw_cell(dr, col, row, value, block=0, fill=None, bold=False):
    x0, y0, x1, y1 = cell_box(col, row, block)
    if fill:
        dr.rectangle([x0, y0, x1, y1], fill=fill)
    dr.rectangle([x0, y0, x1 - 1, y1 - 1], outline=GRID)
    f = font(17, bold)
    tw = dr.textlength(str(value), font=f)
    dr.text((x0 + (CELL_W - tw) / 2, y0 + 10), str(value), font=f, fill=TEXT)


def arrow(dr, x0, y0, x1, y1, color=NOTE):
    dr.line([x0, y0, x1, y1], fill=color, width=2)
    # наконечник
    dx, dy = x1 - x0, y1 - y0
    length = max((dx * dx + dy * dy) ** 0.5, 1)
    ux, uy = dx / length, dy / length
    px, py = -uy, ux
    dr.polygon([(x1, y1),
                (x1 - ux * 9 + px * 4, y1 - uy * 9 + py * 4),
                (x1 - ux * 9 - px * 4, y1 - uy * 9 - py * 4)], fill=color)


def note(dr, xy, text, anchor="lm", size=16):
    dr.text(xy, text, font=font(size, True), fill=NOTE, anchor=anchor)


def main():
    width = 1040
    height = 640
    img = Image.new("RGB", (width, height), BG)
    dr = ImageDraw.Draw(img)

    dr.text((COL0, 30), "Лист Excel: как заполнять", font=font(28, True), fill=TEXT)
    dr.text((COL0, 66),
            "Белые ячейки — из шапки, не трогать. Жёлтые — вписывать свои числа.",
            font=font(16), fill=DIM)

    # подпись модели над таблицей
    bx = COL0 + CELL_W
    dr.rectangle([bx, ROW0 - 46, bx + 3 * CELL_W, ROW0 - 8], fill=TITLE_FILL, outline=GRID)
    dr.text((bx + 8, ROW0 - 38), "PIKE F3F 2026", font=font(17, True), fill=TEXT)
    note(dr, (bx + 3 * CELL_W + 14, ROW0 - 26), "1. название модели (B1)")
    arrow(dr, bx + 3 * CELL_W + 10, ROW0 - 26, bx + 3 * CELL_W + 2, ROW0 - 26)

    # подписи снарядов
    for i, s in enumerate(["45/98", "30/100", "15/102"]):
        x0 = COL0 + (5 + i) * CELL_W
        dr.rectangle([x0, ROW0 - 46, x0 + CELL_W, ROW0 - 8], fill=TITLE_FILL, outline=GRID)
        tw = dr.textlength(s, font=font(16, True))
        dr.text((x0 + (CELL_W - tw) / 2, ROW0 - 38), s, font=font(16, True), fill=TEXT)

    note(dr, (COL0 + 5 * CELL_W + 10 * 0 + 20, ROW0 - 66),
         "2. подписи снарядов (F1 и правее)", anchor="lm", size=15)

    # шапка
    for block in (0, 1):
        for i, h in enumerate(HEAD):
            draw_cell(dr, i, 0, h, block, HEAD_FILL, bold=True)

    note(dr, (COL0 + 10 * CELL_W + 16, ROW0 + CELL_H / 2),
         "3. шапку не менять", size=15)

    # данные: вариант = 2 строки
    for r, row in enumerate(ROWS):
        for i, v in enumerate(row):
            draw_cell(dr, i, r + 1, v, 0, EDIT_FILL if i != 0 or r % 2 == 0 else None)
        for i in range(5):
            draw_cell(dr, i, r + 1, "", 1, EDIT_FILL if r % 2 == 0 else None)

    # границы пар
    for pair in range(4):
        y0 = ROW0 + (1 + pair * 2) * CELL_H
        dr.rectangle([COL0, y0, COL0 + 10 * CELL_W, y0 + 2 * CELL_H], outline=NOTE)

    note(dr, (COL0, ROW0 + 9 * CELL_H + 34),
         "4. один вариант — ДВЕ строки: сверху НОС, снизу НОС низ (и CG)")
    dr.text((COL0, ROW0 + 9 * CELL_H + 62),
            "5. правый блок (F..J) — второй вариант на том же листе; так же по две строки",
            font=font(16), fill=DIM)
    dr.text((COL0, ROW0 + 9 * CELL_H + 88),
            "6. колонку № заполнять обязательно: по ней строка попадает в таблицу",
            font=font(16), fill=DIM)
    dr.text((COL0, ROW0 + 9 * CELL_H + 114),
            "7. кириллицу в значения не писать — экран передатчика её не покажет",
            font=font(16), fill=DIM)

    # стрелки-пометки
    arrow(dr, COL0 + 10 * CELL_W + 22, ROW0 + 1 * CELL_H + 20,
          COL0 + 5 * CELL_W + 4, ROW0 + 2 * CELL_H - 2)
    note(dr, (COL0 + 10 * CELL_W + 26, ROW0 + 1 * CELL_H + 20),
         "верхняя строка", size=14)
    arrow(dr, COL0 + 10 * CELL_W + 22, ROW0 + 3 * CELL_H + 40,
          COL0 + 5 * CELL_W + 4, ROW0 + 3 * CELL_H + 22)
    note(dr, (COL0 + 10 * CELL_W + 26, ROW0 + 3 * CELL_H + 42),
         "нижняя строка", size=14)

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    img.save(OUT)
    print("saved %s (%dx%d)" % (OUT, img.size[0], img.size[1]))
    return 0


if __name__ == "__main__":
    sys.exit(main())

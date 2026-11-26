#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Собирает шаблон для заполнения: templates/ballast_template.xlsx

Структура листа (как ждёт generator):
    строка 1  B1 = название модели, F1.. = подписи (45г/98 ...)
    строка 2  A2..E2 = № | НОС | КРЫЛО | CG | ВЕС, то же с F2 (правый блок)
    строка 3+ пара строк на вариант: верхняя — НОС верх / КРЫЛО / CG верх / ВЕС,
               нижняя — НОС низ / CG низ

Колонки F..J повторяют A..E: за один лист парсится два варианта на строку.

    python tools/make_template.py
"""

import os
import sys

from openpyxl import Workbook
from openpyxl.styles import Alignment, Border, Font, PatternFill, Side

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "templates", "ballast_template.xlsx")

HEAD = ["№", "НОС", "КРЫЛО", "CG", "ВЕС"]

SAMPLE = {
    "PIKE F3F 2026": {
        "title": "PIKE F3F 2026",
        "slugs": ["45г/98", "30г/100", "15г/102"],
        "rows": [
            ("1", "0", "0", "103", "2300", "45", "98"),
            ("2", "15", "0.5", "102", "2500", "45", "98"),
            ("3", "15", "1", "102", "2700", "45", "98"),
            ("4", "15", "1.5", "102", "2850", "45", "98"),
        ],
    },
    "DEVICE 2026": {
        "title": "Device 2026",
        "slugs": ["45г/97", "30г/99", "20г/100"],
        "rows": [
            ("1", "45", "0", "97", "2140", "20", "100"),
            ("2", "45", "0.5", "97", "2350", "20", "100"),
        ],
    },
}

THIN = Side(style="thin", color="FF999999")
BORDER = Border(left=THIN, right=THIN, top=THIN, bottom=THIN)
CENTER = Alignment(horizontal="center", vertical="center")

TITLE_FILL = PatternFill("solid", fgColor="FFDCE6F1")
HEAD_FILL = PatternFill("solid", fgColor="FFEFEFEF")
EDIT_FILL = PatternFill("solid", fgColor="FFFFF9E6")


def style_sheet(ws, nrows):
    for row in ws.iter_rows(min_row=1, max_row=nrows, min_col=1, max_col=10):
        for c in row:
            c.border = BORDER
            c.alignment = CENTER


def build_sheet(wb, name, spec):
    ws = wb.create_sheet(name)

    ws["B1"] = spec["title"]
    ws["B1"].font = Font(bold=True, size=12)
    ws["B1"].fill = TITLE_FILL
    ws["B1"].alignment = CENTER

    # подписи идут с колонки F, как в исходной таблице
    for i, s in enumerate(spec["slugs"]):
        c = ws.cell(row=1, column=6 + i, value=s)
        c.fill = TITLE_FILL
        c.alignment = CENTER

    for block in (1, 6):
        for i, h in enumerate(HEAD):
            c = ws.cell(row=2, column=block + i, value=h)
            c.font = Font(bold=True)
            c.fill = HEAD_FILL

    r = 3
    for num, nos1, wing, cg1, ves, nos2, cg2 in spec["rows"]:
        ws.cell(row=r, column=1, value=num).fill = EDIT_FILL
        ws.cell(row=r, column=2, value=nos1).fill = EDIT_FILL
        ws.cell(row=r, column=3, value=wing).fill = EDIT_FILL
        ws.cell(row=r, column=4, value=cg1).fill = EDIT_FILL
        ws.cell(row=r, column=5, value=ves).fill = EDIT_FILL
        ws.cell(row=r + 1, column=2, value=nos2).fill = EDIT_FILL
        ws.cell(row=r + 1, column=4, value=cg2).fill = EDIT_FILL
        r += 2

    # пустые строки «под заполнение» ещё на 10 вариантов
    for _ in range(10):
        for block in (0, 5):
            ws.cell(row=r, column=block + 1).fill = EDIT_FILL
            ws.cell(row=r + 1, column=block + 2).fill = EDIT_FILL
            ws.cell(row=r + 1, column=block + 4).fill = EDIT_FILL
        r += 2

    widths = [5, 8, 7, 8, 8, 8, 8, 7, 8, 8]
    for i, w in enumerate(widths, start=1):
        ws.column_dimensions[ws.cell(row=1, column=i).column_letter].width = w

    style_sheet(ws, r - 1)
    return ws


def build_instructions(wb):
    ws = wb.create_sheet("Инструкция", 0)
    ws.column_dimensions["A"].width = 110

    lines = [
        ("ШАБЛОН ТАБЛИЦЫ БАЛЛАСТА ДЛЯ JETI (DC-24 / DS-24)", True),
        ("", False),
        ("Этот лист не читается генератором, он только для подсказки.", False),
        ("", False),
        ("Как заполнять остальные листы:", True),
        ("1. Строка 1: в B1 — название модели (латиницей, попадёт в заголовок и имя файла).", False),
        ("   В F1 и правее — подписи снарядов, например 45г/98, 30г/100.", False),
        ("2. Строка 2: шапка № | НОС | КРЫЛО | CG | ВЕС в A2..E2 и повтор в F2..J2.", False),
        ("3. Строка 3 и далее — ПАРА строк на один вариант:", False),
        ("     верхняя: № | НОС верх | КРЫЛО | CG верх | ВЕС", False),
        ("     нижняя:  пусто | НОС низ | пусто  | CG низ  | пусто", False),
        ("4. В ширину листа помещаются два варианта: левый (A..E) и правый (F..J).", False),
        ("5. Номер варианта (№) обязателен: по нему строка попадает в таблицу.", False),
        ("", False),
        ("Чего делать НЕ надо:", True),
        ("- Не менять порядок колонок и шапку — генератор ищет «№» во 2-й строке.", False),
        ("- Не писать кириллицу в значения: на экране передатчика её нет.", False),
        ("  Знакомые цвета сокращаются автоматически (красный → KRASN, черный → CHERN).", False),
        ("- Не оставлять пустых значений там, где нет данных: генератор подставит --.", False),
        ("", False),
        ("Как получить .lua:", True),
        ("- Браузер: открыть generator/jeti_lua_generator.html, перетащить этот .xlsx.",
         False),
        ("- Командная строка: python tools/generate.py этот_файл.xlsx output", False),
        ("", False),
        ("Имя файла: до 8 символов, только латиница и цифры (PIKEF3F, PIKEX, DEVICE26).", False),
    ]
    for i, (text, bold) in enumerate(lines, start=1):
        c = ws.cell(row=i, column=1, value=text)
        if bold:
            c.font = Font(bold=True, size=12 if i == 1 else 11)
    return ws


def main():
    wb = Workbook()
    wb.remove(wb.active)
    build_instructions(wb)
    for name, spec in SAMPLE.items():
        build_sheet(wb, name, spec)

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    wb.save(OUT)
    print("saved %s" % OUT)
    return 0


if __name__ == "__main__":
    sys.exit(main())

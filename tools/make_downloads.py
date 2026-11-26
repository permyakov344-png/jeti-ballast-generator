#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Собирает папку downloads/ — то, что человек скачивает и запускает.

    python tools/make_downloads.py

Кладёт:
    downloads/jeti-ballast-generator.zip   всё нужное одним архивом
    downloads/jeti_lua_generator.html      генератор одним файлом
    downloads/ballast_template.xlsx        пустой шаблон

Архив устроен так, что его можно просто распаковать и открыть HTML.
"""

import os
import shutil
import sys
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "downloads")

# что попадает в архив: (путь в проекте, имя внутри архива)
FILES = [
    ("generator/jeti_lua_generator.html", "jeti_lua_generator.html"),
    ("generator/xlsx.full.min.js", "xlsx.full.min.js"),
    ("templates/ballast_template.xlsx", "ballast_template.xlsx"),
    ("output/PIKEF3F.lua", "PIKEF3F.lua"),
    ("output/PIKEX.lua", "PIKEX.lua"),
    ("output/DEVICE26.lua", "DEVICE26.lua"),
    ("docs/КАК-ПОЛЬЗОВАТЬСЯ.txt", "КАК-ПОЛЬЗОВАТЬСЯ.txt"),
]

ZIP_NAME = "jeti-ballast-generator.zip"


def main():
    os.makedirs(OUT, exist_ok=True)

    zip_path = os.path.join(OUT, ZIP_NAME)
    missing = []
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as z:
        for src, name in FILES:
            path = os.path.join(ROOT, src)
            if not os.path.exists(path):
                missing.append(src)
                continue
            z.write(path, name)

    print("%-42s %d КБ" % (os.path.relpath(zip_path, ROOT),
                           os.path.getsize(zip_path) // 1024))

    for src, name in (("generator/jeti_lua_generator.html", "jeti_lua_generator.html"),
                      ("templates/ballast_template.xlsx", "ballast_template.xlsx")):
        path = os.path.join(ROOT, src)
        if os.path.exists(path):
            dst = os.path.join(OUT, name)
            shutil.copy2(path, dst)
            print("%-42s %d КБ" % (os.path.relpath(dst, ROOT),
                                   os.path.getsize(dst) // 1024))

    if missing:
        print("не найдено: " + ", ".join(missing))
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())

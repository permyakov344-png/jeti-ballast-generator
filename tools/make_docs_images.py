#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Все картинки для README и страницы на GitHub.

    python tools/make_docs_images.py

Что делает:
  1. docs/img/01-generator.png  — генератор с загруженной таблицей (Edge headless)
  2. docs/img/02-result.png     — он же с готовым кодом и кнопкой скачивания
  3. docs/img/screen-*.png      — экран передатчика из preview/*.png (x3)
  4. docs/img/04-template.png   — лист шаблона Excel (нужен LibreOffice)

Скриншоты браузера делаются через Edge/Chrome в headless-режиме, поэтому
рядом должен работать локальный сервер:

    python -m http.server 8765 --bind 127.0.0.1
"""

import io
import os
import shutil
import subprocess
import sys
import tempfile
import time
import urllib.request

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
IMG = os.path.join(ROOT, "docs", "img")

BROWSERS = [
    r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
    r"C:\Program Files\Microsoft\Edge\Application\msedge.exe",
    r"C:\Program Files\Google\Chrome\Application\chrome.exe",
    r"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
    "/usr/bin/google-chrome",
    "/usr/bin/chromium",
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
]

SHOT_WRAPPER = """
<script>
async function __demo() {
  const r = await fetch('%FILE%');
  const buf = await r.arrayBuffer();
  loadFile(new File([buf], '%FILE%'.split('/').pop()));
  await new Promise(res => setTimeout(res, 700));
  if (%GEN%) {
    generateOne(0);
    await new Promise(res => setTimeout(res, 400));
  }
}
window.addEventListener('load', __demo);
</script>
</body>
</html>
"""

PANEL = (18, 22, 28)
EDGE = (60, 70, 84)
TEXT = (200, 212, 224)

SCALE = 3
PAD = 18
CAPTION_H = 34


def font(size, bold=False):
    names = (("seguisb.ttf", "segoeuib.ttf", "arialbd.ttf") if bold
             else ("segoeui.ttf", "arial.ttf", "DejaVuSans.ttf"))
    for name in names:
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            continue
    return ImageFont.load_default()


def find_browser():
    for path in BROWSERS:
        if os.path.exists(path):
            return path
    return None


def server_alive(url):
    try:
        urllib.request.urlopen(url, timeout=3).read(1)
        return True
    except Exception:  # noqa: BLE001
        return False


def browser_shot(page, dst, size, selector_html=None):
    """Снимок страницы headless-браузером."""
    exe = find_browser()
    if not exe:
        print("браузер не найден — %s пропускаю" % dst)
        return False

    tmp = tempfile.mkdtemp(prefix="jetishot_")
    raw = os.path.join(tmp, "shot.png")
    profile = os.path.join(tmp, "profile")
    args = [
        exe, "--headless=new", "--disable-gpu", "--no-sandbox",
        "--hide-scrollbars", "--force-device-scale-factor=1",
        "--user-data-dir=" + profile,
        "--window-size=%d,%d" % size,
        "--virtual-time-budget=8000",
        "--screenshot=" + raw, page,
    ]
    try:
        subprocess.run(args, timeout=90, stdout=subprocess.DEVNULL,
                       stderr=subprocess.DEVNULL, check=False)
    except subprocess.TimeoutExpired:
        pass

    if not os.path.exists(raw):
        print("снимок не получился — %s" % dst)
        shutil.rmtree(tmp, ignore_errors=True)
        return False

    im = Image.open(raw).convert("RGB")
    im = crop_dark(im)
    im.save(dst)
    print("%-46s %s" % (os.path.relpath(dst, ROOT), im.size))
    shutil.rmtree(tmp, ignore_errors=True)
    return True


def crop_dark(im, pad=6):
    """Обрезает тёмные поля вокруг светлого содержимого."""
    from PIL import ImageChops

    bg = Image.new("RGB", im.size, im.getpixel((2, im.size[1] - 3)))
    box = ImageChops.difference(im, bg).getbbox()
    if not box:
        return im
    x0, y0, x1, y1 = box
    return im.crop((max(0, x0 - pad), max(0, y0 - pad),
                    min(im.width, x1 + pad), min(im.height, y1 + pad)))


def screen_mockup(src, dst, caption):
    shot = Image.open(src).convert("RGB")
    shot = shot.resize((shot.width * SCALE, shot.height * SCALE), Image.NEAREST)

    w = shot.width + PAD * 2
    h = shot.height + PAD * 2 + CAPTION_H
    img = Image.new("RGB", (w, h), PANEL)
    dr = ImageDraw.Draw(img)

    dr.rounded_rectangle([PAD - 3, PAD - 3, shot.width + PAD + 2, shot.height + PAD + 2],
                         radius=6, outline=EDGE, width=2)
    img.paste(shot, (PAD, PAD))
    dr.text((PAD, shot.height + PAD + 10), caption, font=font(18), fill=TEXT)
    img.save(dst)
    print("%-46s %s" % (os.path.relpath(dst, ROOT), img.size))


def excel_mockup(src, dst, page=0):
    """xlsx -> pdf -> png. Нужен LibreOffice."""
    soffice = None
    for path in (r"C:\Program Files\LibreOffice\program\soffice.exe",
                 "/usr/bin/soffice", "/usr/bin/libreoffice",
                 "/Applications/LibreOffice.app/Contents/MacOS/soffice"):
        if os.path.exists(path):
            soffice = path
            break
    if not soffice:
        print("LibreOffice не найден — %s пропускаю" % dst)
        return False

    tmp = tempfile.mkdtemp(prefix="jetixls_")
    subprocess.run([soffice, "--headless", "--convert-to", "pdf", "--outdir", tmp, src],
                   check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    pdf = os.path.join(tmp, os.path.splitext(os.path.basename(src))[0] + ".pdf")
    if not os.path.exists(pdf):
        print("PDF не собрался — %s пропускаю" % dst)
        shutil.rmtree(tmp, ignore_errors=True)
        return False

    import pymupdf

    doc = pymupdf.open(pdf)
    pix = doc[page].get_pixmap(dpi=150)
    png = os.path.join(tmp, "page.png")
    pix.save(png)
    doc.close()

    im = Image.open(png).convert("RGB")
    gray = im.convert("L").point(lambda v: 255 if v < 250 else 0)
    box = gray.getbbox()
    if box:
        im = im.crop(box)

    pad = 14
    framed = Image.new("RGB", (im.width + pad * 2, im.height + pad * 2), (255, 255, 255))
    framed.paste(im, (pad, pad))
    framed.save(dst)
    print("%-46s %s" % (os.path.relpath(dst, ROOT), framed.size))
    shutil.rmtree(tmp, ignore_errors=True)
    return True


def main():
    os.makedirs(IMG, exist_ok=True)
    base = "http://127.0.0.1:8765"

    # --- скриншоты генератора -------------------------------------------
    html_path = os.path.join(ROOT, "generator", "jeti_lua_generator.html")
    src = io.open(html_path, encoding="utf-8").read()

    shots = [
        ("__shot-data.html", "/data/zagluzka_2026_v2.xls", "false",
         os.path.join(IMG, "01-generator.png"), (1160, 1080)),
        ("__shot-gen.html", "/data/zagluzka_2026_v2.xls", "true",
         os.path.join(IMG, "02-result.png"), (1160, 1500)),
    ]
    for name, file_url, gen, dst, size in shots:
        body = SHOT_WRAPPER.replace("%FILE%", file_url).replace("%GEN%", gen)
        out = src.replace("</body>\n</html>\n", body)
        path = os.path.join(ROOT, "generator", name)
        io.open(path, "w", encoding="utf-8", newline="\n").write(out)
        try:
            if not server_alive(base + "/generator/" + name):
                print("сервер на %s не отвечает — скриншоты пропускаю" % base)
            else:
                browser_shot(base + "/generator/" + name, dst, size)
        finally:
            os.remove(path)

    # --- экраны передатчика ---------------------------------------------
    pairs = [
        ("PIKEF3F", "PIKE F3F 2026 — вариант 3 из 14, страница 2 из 7"),
        ("PIKEX", "PIKE X 2025 — цвета сведены к латинице: KRASN / CHERN"),
    ]
    for base_name, caption in pairs:
        src_png = os.path.join(ROOT, "preview", base_name + ".png")
        if os.path.exists(src_png):
            screen_mockup(src_png, os.path.join(IMG, "screen-%s.png" % base_name.lower()),
                          caption)

    # --- шаблон Excel ----------------------------------------------------
    tpl = os.path.join(ROOT, "templates", "ballast_template.xlsx")
    if os.path.exists(tpl):
        excel_mockup(tpl, os.path.join(IMG, "05-template.png"), page=1)
    return 0


if __name__ == "__main__":
    sys.exit(main())

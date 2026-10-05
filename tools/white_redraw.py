# -*- coding: utf-8 -*-
"""重绘 中指/肘/悲伤，颜色改成纯白（白填充 + 粗黑描边），输出 96x96 成品图标。"""
import os, sys, time, json, base64, mimetypes
from concurrent.futures import ThreadPoolExecutor

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from seedream import call, save_image, DEFAULT_MODEL  # noqa: E402
from to_brotato_icon import flood_alpha, dewhite_edge, fit_icon  # noqa: E402
from PIL import Image  # noqa: E402

SRC = r"D:\DSH\Bromeme\aiart_src"
REF = os.path.join(SRC, "ref")
EDITED = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\resources\edited"

TARGETS = [
    ("1763088849", "中指"),
    ("1760709365", "肘"),
    ("1763096950", "悲伤"),
]
TOL = 40


def one(stem, name):
    key = os.environ.get("ARK_API_KEY", "")
    ref = os.path.join(REF, stem + ".png")
    prompt = open(os.path.join(SRC, stem + ".white.prompt.txt"), encoding="utf-8").read().strip()
    mime = mimetypes.guess_type(ref)[0] or "image/png"
    with open(ref, "rb") as f:
        data_url = "data:%s;base64,%s" % (mime, base64.b64encode(f.read()).decode("ascii"))
    payload = {
        "model": DEFAULT_MODEL,
        "prompt": prompt,
        "size": "1024x1024",
        "response_format": "url",
        "watermark": False,
        "image": data_url,
    }
    out = os.path.join(SRC, stem + "_white.png")
    t0 = time.time()
    resp = call(payload, key)
    items = resp.get("data") or []
    if not items:
        print("FAIL %s: %s" % (name, json.dumps(resp, ensure_ascii=False)[:300]), flush=True)
        return False
    save_image(items[0], out)
    img = Image.open(out)
    icon = fit_icon(dewhite_edge(flood_alpha(img, TOL), TOL), 96, 2)
    icon.save(os.path.join(EDITED, stem + ".png"))
    print("OK   %-4s %-10s %5.1fs raw=%d bytes icon=%d bytes" %
          (name, stem, time.time() - t0, os.path.getsize(out),
           os.path.getsize(os.path.join(EDITED, stem + ".png"))), flush=True)
    return True


if __name__ == "__main__":
    with ThreadPoolExecutor(max_workers=3) as ex:
        res = list(ex.map(lambda t: one(*t), TARGETS))
    print("done", sum(1 for r in res if r), "/", len(res))

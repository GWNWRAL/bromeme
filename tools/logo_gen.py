# -*- coding: utf-8 -*-
"""画 Bromeme 的 logo（横长构图）+ 抠白底，输出 mod 用的 png。"""
import os, sys, time, base64, mimetypes
from concurrent.futures import ThreadPoolExecutor

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from seedream import call, save_image, DEFAULT_MODEL  # noqa: E402
from to_brotato_icon import flood_alpha, dewhite_edge  # noqa: E402
from PIL import Image  # noqa: E402

SRC = r"D:\DSH\Bromeme\aiart_src"
REF = r"D:\DSH\Bromeme\aiart_src\bromeme_logo_ref.png"   # 可选参考图（不存在就不传）
PROMPT = os.path.join(SRC, "bromeme_logo.prompt.txt")
SEEDS = [7, 77, 777]
KEY = os.environ.get("ARK_API_KEY", "")
SIZE = "1280x768"      # 横长，面积也满足接口要求


def one(seed):
    prompt = io_read(PROMPT)
    payload = {
        "model": DEFAULT_MODEL,
        "prompt": prompt,
        "size": SIZE,
        "response_format": "url",
        "watermark": False,
        "seed": seed,
    }
    if os.path.isfile(REF):
        mime = mimetypes.guess_type(REF)[0] or "image/png"
        with open(REF, "rb") as f:
            payload["image"] = "data:%s;base64,%s" % (mime, base64.b64encode(f.read()).decode("ascii"))
    out = os.path.join(SRC, "bromeme_logo_%d.png" % seed)
    t0 = time.time()
    try:
        resp = call(payload, KEY)
    except Exception as e:
        print("FAIL seed=%d %s" % (seed, str(e)[:200]), flush=True)
        return False
    data = resp.get("data") or []
    if not data:
        print("FAIL seed=%d no image" % seed, flush=True)
        return False
    save_image(data[0], out)
    print("OK  seed=%d %5.1fs %s" % (seed, time.time() - t0, os.path.basename(out)), flush=True)
    return True


def io_read(path):
    with open(path, encoding="utf-8") as f:
        return f.read().strip()


if __name__ == "__main__":
    with ThreadPoolExecutor(max_workers=3) as ex:
        res = list(ex.map(one, SEEDS))
    print("done", sum(1 for r in res if r), "/", len(res))

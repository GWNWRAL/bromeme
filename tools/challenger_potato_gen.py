# -*- coding: utf-8 -*-
"""挑战者：把 icon（黑白漫画角色）的脸转移到土豆身上，画风保持黑白漫画。四个种子候选。"""
import os, sys, time, json, base64, mimetypes
from concurrent.futures import ThreadPoolExecutor

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from seedream import call, save_image, DEFAULT_MODEL  # noqa: E402

SRC = r"D:\DSH\Bromeme\aiart_src"
REFS = [
    r"D:\DSH\Bromeme\image\挑战者.png",
    r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\resources\icons\1790000001.png",
]
PROMPT = os.path.join(SRC, "1790000001.potato.prompt.txt")
SEEDS = [11, 22, 33, 44]
KEY = os.environ.get("ARK_API_KEY", "")


def one(seed):
    prompt = open(PROMPT, encoding="utf-8").read().strip()
    imgs = []
    for p in REFS:
        mime = mimetypes.guess_type(p)[0] or "image/png"
        with open(p, "rb") as f:
            imgs.append("data:%s;base64,%s" % (mime, base64.b64encode(f.read()).decode("ascii")))
    payload = {
        "model": DEFAULT_MODEL,
        "prompt": prompt,
        "size": "1024x1024",
        "response_format": "url",
        "watermark": False,
        "seed": seed,
        "image": imgs if len(imgs) > 1 else imgs[0],
    }
    out = os.path.join(SRC, "challenger_potato_%d.png" % seed)
    t0 = time.time()
    try:
        resp = call(payload, KEY)
    except Exception as e:
        print("FAIL seed=%d %s" % (seed, str(e)[:200]), flush=True)
        return False
    data = resp.get("data") or []
    if not data:
        print("FAIL seed=%d no image: %s" % (seed, json.dumps(resp, ensure_ascii=False)[:200]), flush=True)
        return False
    save_image(data[0], out)
    print("OK   seed=%d %5.1fs %s %d bytes" % (seed, time.time() - t0, os.path.basename(out), os.path.getsize(out)), flush=True)
    return True


if __name__ == "__main__":
    with ThreadPoolExecutor(max_workers=4) as ex:
        res = list(ex.map(one, SEEDS))
    print("done", sum(1 for r in res if r), "/", len(res))

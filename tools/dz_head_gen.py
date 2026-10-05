# -*- coding: utf-8 -*-
"""丁真：只保留头部的重绘候选（保持原图画风）。生成 4 个不同种子的候选。"""
import os, sys, time, json, base64, mimetypes
from concurrent.futures import ThreadPoolExecutor

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from seedream import call, save_image, DEFAULT_MODEL  # noqa: E402

SRC = r"D:\DSH\Bromeme\aiart_src"
REF = os.path.join(SRC, "ref", "1762955139.png")
PROMPT = os.path.join(SRC, "1762955139.headonly.prompt.txt")
SEEDS = [101, 202, 303, 404]
KEY = os.environ.get("ARK_API_KEY", "")


def one(seed):
    prompt = open(PROMPT, encoding="utf-8").read().strip()
    mime = mimetypes.guess_type(REF)[0] or "image/png"
    with open(REF, "rb") as f:
        data_url = "data:%s;base64,%s" % (mime, base64.b64encode(f.read()).decode("ascii"))
    payload = {
        "model": DEFAULT_MODEL,
        "prompt": prompt,
        "size": "1024x1024",
        "response_format": "url",
        "watermark": False,
        "seed": seed,
        "image": data_url,
    }
    out = os.path.join(SRC, "dz_head_%d.png" % seed)
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

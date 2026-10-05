# -*- coding: utf-8 -*-
"""
Seedream（火山方舟 Ark）图像生成 / 图生图 调用工具。

用法:
    set ARK_API_KEY=ark-xxxx
    python seedream.py --prompt-file prompt.txt --out out.png [--ref a.png b.png] [--size 1024x1024]

    # 只打印将要发送的请求体（不消耗额度）
    python seedream.py --prompt "..." --out out.png --dry

说明:
    - 文本生图: 不传 --ref
    - 图生图/参考图: --ref 可给 1~10 张本地图片，脚本会转成 data URL 传给 image 字段
    - 成功后在 out 旁边写 out.json（原始响应，便于排查）
"""
import argparse, base64, json, mimetypes, os, sys, time, urllib.request, urllib.error

API_URL = "https://ark.cn-beijing.volces.com/api/v3/images/generations"
DEFAULT_MODEL = "doubao-seedream-5-0-pro-260628"


def data_url(path: str) -> str:
    mime = mimetypes.guess_type(path)[0] or "image/png"
    with open(path, "rb") as f:
        return "data:%s;base64,%s" % (mime, base64.b64encode(f.read()).decode("ascii"))


def call(payload: dict, key: str, timeout: int = 180) -> dict:
    req = urllib.request.Request(
        API_URL,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json", "Authorization": "Bearer " + key},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return json.loads(r.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", "replace")
        raise RuntimeError("HTTP %s: %s" % (e.code, body))


def save_image(item: dict, out_path: str):
    os.makedirs(os.path.dirname(os.path.abspath(out_path)), exist_ok=True)
    if item.get("b64_json"):
        raw = base64.b64decode(item["b64_json"])
        src = "b64"
    else:
        url = item.get("url") or ""
        if not url:
            raise RuntimeError("响应里既没有 b64_json 也没有 url: %s" % json.dumps(item, ensure_ascii=False)[:400])
        with urllib.request.urlopen(url, timeout=180) as r:
            raw = r.read()
        src = url
    # Ark 实际返回的可能是 jpeg，这里统一转成 PNG，方便后续处理
    if out_path.lower().endswith(".png"):
        import io
        from PIL import Image
        img = Image.open(io.BytesIO(raw))
        img.convert("RGB").save(out_path, "PNG")
    else:
        with open(out_path, "wb") as f:
            f.write(raw)
    return src


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--prompt", default="")
    ap.add_argument("--prompt-file", default="")
    ap.add_argument("--out", required=True)
    ap.add_argument("--ref", nargs="*", default=[])
    ap.add_argument("--size", default="1024x1024")
    ap.add_argument("--model", default=DEFAULT_MODEL)
    ap.add_argument("--seed", type=int, default=-1)
    ap.add_argument("--n", type=int, default=1)
    ap.add_argument("--sequential", default="")  # 留空表示不发送该字段（部分模型不支持）
    ap.add_argument("--format", default="url")           # url | b64_json
    ap.add_argument("--dry", action="store_true")
    args = ap.parse_args()

    prompt = args.prompt
    if args.prompt_file:
        prompt = open(args.prompt_file, encoding="utf-8").read().strip()
    if not prompt:
        print("缺少 prompt", file=sys.stderr)
        return 2

    payload = {
        "model": args.model,
        "prompt": prompt,
        "size": args.size,
        "response_format": args.format,
        "watermark": False,
    }
    if args.sequential:
        payload["sequential_image_generation"] = args.sequential
    if args.n > 1:
        payload["sequential_image_generation_options"] = {"max_images": args.n}
    if args.ref:
        imgs = [data_url(p) for p in args.ref]
        payload["image"] = imgs[0] if len(imgs) == 1 else imgs
    if args.seed >= 0:
        payload["seed"] = args.seed

    if args.dry:
        shown = dict(payload)
        if "image" in shown:
            shown["image"] = "<data url x%d, %d KB>" % (
                len(args.ref),
                sum(os.path.getsize(p) for p in args.ref) // 1024,
            )
        print(json.dumps(shown, ensure_ascii=False, indent=2))
        return 0

    key = os.environ.get("ARK_API_KEY", "")
    if not key:
        print("请先设置环境变量 ARK_API_KEY", file=sys.stderr)
        return 2

    t0 = time.time()
    resp = call(payload, key)
    print("[%.1fs] usage=%s" % (time.time() - t0, json.dumps(resp.get("usage", {}), ensure_ascii=False)))
    data = resp.get("data") or []
    if not data:
        print("响应无图:", json.dumps(resp, ensure_ascii=False)[:800], file=sys.stderr)
        return 1

    outs = []
    for i, item in enumerate(data):
        p = args.out if i == 0 else args.out.replace(".png", "_%d.png" % i)
        src = save_image(item, p)
        outs.append(p)
        print("已保存:", p, "(%d bytes) 来源=%s" % (os.path.getsize(p), src))
    with open(args.out.rsplit(".", 1)[0] + ".json", "w", encoding="utf-8") as f:
        json.dump(resp, f, ensure_ascii=False, indent=2)
    return 0


if __name__ == "__main__":
    sys.exit(main())

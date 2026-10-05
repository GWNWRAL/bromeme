# -*- coding: utf-8 -*-
"""meme值属性图标：让 AI 画一个「me」字母图标，抠底后按现有 meme 图标尺寸覆盖。"""
import os, sys, time, base64, mimetypes
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from seedream import call, save_image, DEFAULT_MODEL  # noqa: E402
from to_brotato_icon import flood_alpha, dewhite_edge  # noqa: E402

MOD = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme"
SRC = r"D:\DSH\Bromeme\aiart_src"
DST = os.path.join(MOD, "meme", "stat_meme_icon.png")
KEY = os.environ.get("ARK_API_KEY", "")

PROMPT = """画一个《土豆兄弟》(Brotato) 风格的属性小图标：
- 主体：小写字母「me」两个字母组成的连写字母标志（m 和 e 紧挨着，像一个小徽标）
- 粗黑描边（约4像素）、扁平大色块、矢量插画风格，饱和明快的奶油黄/橘色系
- 只保留大块高光与暗部，不要渐变、不要写实光影、不要3D、不要照片质感
- 不要任何其他文字、不要水印、不要相框、不要投影
- 纯白背景（干干净净），正方形构图，字母居中占画面约 80%
"""

if os.path.isfile(DST):
    print("现有图标尺寸:", Image.open(DST).size)

payload = {"model": DEFAULT_MODEL, "prompt": PROMPT, "size": "1024x1024",
           "response_format": "url", "watermark": False}
ref = os.path.join(SRC, "ref", "1760708558.png")
if os.path.isfile(ref):
    mime = mimetypes.guess_type(ref)[0] or "image/png"
    with open(ref, "rb") as f:
        payload["image"] = "data:%s;base64,%s" % (mime, base64.b64encode(f.read()).decode("ascii"))

t0 = time.time()
resp = call(payload, KEY)
data = resp.get("data") or []
if not data:
    print("FAIL 没拿到图")
    raise SystemExit(1)

raw = os.path.join(SRC, "meme_icon_ai.png")
save_image(data[0], raw)
cut = dewhite_edge(flood_alpha(Image.open(raw).convert("RGBA"), 40), 40)

# 尺寸对齐现有 meme 图标（原版属性图标都是这个规格）
if os.path.isfile(DST):
    w, h = Image.open(DST).size
else:
    w, h = 64, 64
scale = min(w / float(cut.size[0]), h / float(cut.size[1]))
small = cut.resize((max(1, int(cut.size[0] * scale)), max(1, int(cut.size[1] * scale))), Image.LANCZOS)
canvas = Image.new("RGBA", (w, h), (0, 0, 0, 0))
canvas.alpha_composite(small, ((w - small.size[0]) // 2, (h - small.size[1]) // 2))
canvas.save(DST)
cut.save(os.path.join(SRC, "meme_icon_ai_cut.png"))
print("OK %.1fs -> %s（%s）" % (time.time() - t0, DST, canvas.size))

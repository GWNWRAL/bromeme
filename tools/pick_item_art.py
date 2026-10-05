# -*- coding: utf-8 -*-
"""生成 4 个「选项专属道具」的图标（Brotato 风格、红色系、白底），再抠底成 96x96。"""
import os, sys, time, json, base64, mimetypes
from concurrent.futures import ThreadPoolExecutor

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from seedream import call, save_image, DEFAULT_MODEL  # noqa: E402
from to_brotato_icon import flood_alpha, dewhite_edge, fit_icon  # noqa: E402
from PIL import Image  # noqa: E402

MOD = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme"
SRC = r"D:\DSH\Bromeme\aiart_src"
OUT_DIR = os.path.join(MOD, "resources", "icons")
REF = os.path.join(SRC, "ref", "1760708558.png")   # 任意一张本 mod 的道具图当画风参考
KEY = os.environ.get("ARK_API_KEY", "")

BASE = """请画一个游戏《土豆兄弟》(Brotato) 的道具图标（正方形、主体居中占画面约 85%）：
- 主体：{subject}
- 粗黑描边（约4像素宽）、扁平大色块、赛璐璐/矢量插画风格，颜色饱和明快
- 主色调：{color}
- 只保留大块高光与暗部，不要写实光影、不要渐变、不要照片质感、不要3D渲染感
- 去掉所有文字、水印、商标
- 纯白背景（背景必须干干净净，不要卡片、不要浅灰底、不要相框、不要投影）
- 可爱卡通风格的游戏道具图标
"""

TARGETS = [
    ("1791000101", "meme核心",
     "一颗发着红光的正方体核心（里面像有一张笑脸的小表情），四周有短小的红色尖刺/凸起",
     "深红 + 亮红的发光核心，黑色描边"),
    ("1791000102", "混沌meme",
     "一个红紫相间的混乱漩涡/螺旋，漩涡中心是一张歪嘴笑著的小脸，旁边飘着几个小星星",
     "红色为主 + 一点紫色，黑色描边"),
    ("1791000103", "随机meme",
     "两颗红色的骰子叠在一起，骰子正面是一张吐舌头的小脸，点数用白色圆点表示",
     "红色骰子 + 白色点数，黑色描边"),
    ("1791000104", "出售meme",
     "一个红色的价格标签（tag）和几枚金币，标签上画着一张笑眯眯的小脸",
     "红色标签 + 金黄色金币，黑色描边"),
]


def one(target):
    stem, name, subject, color = target
    prompt = BASE.format(subject=subject, color=color)
    payload = {
        "model": DEFAULT_MODEL,
        "prompt": prompt,
        "size": "1024x1024",
        "response_format": "url",
        "watermark": False,
    }
    if os.path.isfile(REF):
        mime = mimetypes.guess_type(REF)[0] or "image/png"
        with open(REF, "rb") as f:
            payload["image"] = "data:%s;base64,%s" % (mime, base64.b64encode(f.read()).decode("ascii"))
    raw = os.path.join(SRC, "pick_item_%s.png" % stem)
    t0 = time.time()
    try:
        resp = call(payload, KEY)
    except Exception as e:
        print("FAIL %s %s" % (name, str(e)[:160]), flush=True)
        return False
    data = resp.get("data") or []
    if not data:
        print("FAIL %s no image" % name, flush=True)
        return False
    save_image(data[0], raw)
    icon = fit_icon(dewhite_edge(flood_alpha(Image.open(raw).convert("RGBA"), 40), 40), 96, 2)
    os.makedirs(OUT_DIR, exist_ok=True)
    icon.save(os.path.join(OUT_DIR, stem + ".png"))
    print("OK  %-8s %5.1fs -> icons/%s.png" % (name, time.time() - t0, stem), flush=True)
    return True


if __name__ == "__main__":
    with ThreadPoolExecutor(max_workers=4) as ex:
        res = list(ex.map(one, TARGETS))
    print("done", sum(1 for r in res if r), "/", len(res))

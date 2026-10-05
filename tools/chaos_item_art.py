# -*- coding: utf-8 -*-
"""生成「更混沌」专属道具的图标（Brotato 风格、红紫混乱色系、白底），抠底成 96x96。"""
import os, sys, time, base64, mimetypes
from concurrent.futures import ThreadPoolExecutor

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from seedream import call, save_image, DEFAULT_MODEL  # noqa: E402
from to_brotato_icon import flood_alpha, dewhite_edge, fit_icon  # noqa: E402
from PIL import Image  # noqa: E402

MOD = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme"
SRC = r"D:\DSH\Bromeme\aiart_src"
OUT_DIR = os.path.join(MOD, "resources", "icons")
REF = os.path.join(SRC, "ref", "1760708558.png")
KEY = os.environ.get("ARK_API_KEY", "")

BASE = """请画一个游戏《土豆兄弟》(Brotato) 的道具图标（正方形、主体居中占画面约 85%）：
- 主体：{subject}
- 粗黑描边（约4像素宽）、扁平大色块、赛璐璐/矢量插画风格，颜色饱和明快
- 主色调：{color}
- 只保留大块高光与暗部，不要写实光影、不要渐变、不要照片质感、不要3D渲染感
- 去掉所有文字、水印、商标
- 纯白背景（背景必须干干净净，不要卡片、不要浅灰底、不要相框、不要投影）
- 可爱卡通风格的游戏道具图标，带一点混乱/疯狂的感觉
"""

TARGETS = [
    ("1791000201", "熵增meme",
     "一团乱糟糟的红色能量漩涡，里面混着向上向下的箭头和问号，漩涡中心是一张歪嘴狂笑的小脸",
     "深红 + 亮红 + 一点紫色，黑色描边"),
    ("1791000202", "赌徒meme",
     "两枚叠起来的红色筹码和一粒红色骰子，筹码上画着一张坏笑的小脸",
     "红色筹码 + 白色骰点 + 一点金色，黑色描边"),
    ("1791000203", "量子meme",
     "一个红紫色的发光球体，同时呈现出「实心」和「半透明虚影」两种重叠状态，球上有一张呆滞的小脸",
     "紫红 + 亮紫，黑色描边"),
    ("1791000204", "献祭meme",
     "一座小红色祭坛，上面飘着几个红色的小火苗和一颗小骷髅头，旁边有一张虔诚傻笑的小土豆脸",
     "深红 + 暗红，黑色描边"),
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
    raw = os.path.join(SRC, "chaos_item_%s.png" % stem)
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

# -*- coding: utf-8 -*-
"""Bromeme 贴图批量“土豆兄弟化”。

- 参考图固定用 aiart_src/ref/<stem>.png（首次运行会把当前贴图复制过去），
  这样反复重绘时参考图不会漂移。
- 输出：aiart_src/<stem>.png（AI 原画，1024）、resources/edited/<stem>.png（96x96 成品）
- 日志：aiart/batch_log.txt

用法:
    python bromeme_aiart.py [--only stem1,stem2] [--conc 3] [--model xxx]
"""
import os, sys, time, shutil, argparse, traceback
from concurrent.futures import ThreadPoolExecutor

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from seedream import call, save_image, DEFAULT_MODEL  # noqa: E402
from to_brotato_icon import flood_alpha, dewhite_edge, fit_icon  # noqa: E402
from PIL import Image  # noqa: E402

MOD = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme"
RES = os.path.join(MOD, "resources")
ICONS = os.path.join(RES, "icons")
EDITED = os.path.join(RES, "edited")
SRC = r"D:\DSH\Bromeme\aiart_src"
REF = os.path.join(SRC, "ref")
LOG = r"D:\DSH\_aitato_work\aiart\batch_log.txt"

# kind: char/item;  mode: normal/head
TARGETS = [
    # ---- 角色（真人照片 -> 只保留头部放大）----
    ("1760785273", "char", "head", "嘉豪"),
    ("1761493042", "char", "head", "大卫戴"),
    ("1762266899", "char", "head", "牢大"),
    ("1762608632", "char", "head", "雨姐"),
    ("1762944079", "char", "head", "霍金"),
    ("1762955139", "char", "head", "丁真"),
    ("1765211966", "char", "head", "王源"),
    ("1765220738", "char", "head", "李文亚"),
    ("1783444690", "char", "head", "张雪峰"),
    ("1784882689", "char", "head", "不死老表"),
    # ---- 角色（卡通 / 3D 渲染 / 机甲）----
    ("1760804436", "char", "normal", "鸡哥"),
    ("1760863546", "char", "normal", "龙卷风"),
    ("1761042954", "char", "normal", "猪猪侠"),
    ("1761130691", "char", "normal", "风火轮"),
    ("1762348216", "char", "normal", "狂战士"),
    ("1762427110", "char", "normal", "达芬奇机器人"),
    ("1762531564", "char", "normal", "哪吒"),
    ("1763660892", "char", "normal", "狙击手"),
    ("1784211450", "char", "normal", "炮塔"),
    # ---- 道具 ----
    ("1761558013", "item", "normal", "水果店"),
    ("1763032527", "item", "normal", "投资"),
    ("1761055351", "item", "normal", "烟"),
    ("1761055389", "item", "normal", "烟"),
    ("1760709365", "item", "normal", "肘"),
    ("1760712568", "item", "normal", "篮球"),
    ("1760708558", "item", "normal", "直升机"),
    ("1761539722", "item", "normal", "炮塔生产线"),
    ("1762608577", "item", "normal", "大脚"),
    ("1762943994", "item", "normal", "和平主义"),
    ("1763025652", "item", "normal", "纯正的冰"),
    ("1762960272", "item", "normal", "能量护盾"),
    ("1763059780", "item", "normal", "能量护盾air"),
    ("1763096160", "item", "normal", "愤怒"),
    ("1763096950", "item", "normal", "悲伤"),
]

HEAD_PROMPT = """参考图1是一张真人照片（角色名：{name}）。请只取这个人的头部，把它重画成游戏《土豆兄弟》(Brotato) 的角色图标：

- 只画头部特写（头肩或纯头部），放大占满画面，不要身体、不要背景、不要手
- 不要画成写实真人：画成卡通土豆角色的脸，保留参考图中人物的发型、发色、胡须、眼镜、帽子、眼罩、配饰等标志性特征和主色调
- 粗黑描边（约4像素宽）、扁平大色块、赛璐璐上色，颜色饱和明快
- 不要写实光影、不要渐变、不要照片质感、不要3D渲染感、不要景深虚化
- 去掉所有文字、水印、背景和投影
- 头部居中，占画面约 90%，纯白背景，正方形构图，可爱卡通游戏头像
"""

NORMAL_PROMPT = """参考图1（{kind_cn}：{name}）。请把它重新绘制成游戏《土豆兄弟》(Brotato) 的{kind_cn}图标风格：

- 粗黑描边（约4像素宽）、扁平大色块、赛璐璐/矢量插画风格，颜色饱和明快
- 只保留大块高光与暗部，不要写实光影、不要渐变、不要照片质感、不要3D渲染感、不要景深
- 保持参考图主体的轮廓、比例、配色和标志性特征，适当简化细节
- 去掉所有文字、水印、商标、背景和投影
- 主体居中，占画面约 85%，纯白背景，正方形构图，可爱卡通风格的游戏图标
"""


def log(msg):
    line = "[%s] %s" % (time.strftime("%H:%M:%S"), msg)
    print(line, flush=True)
    os.makedirs(os.path.dirname(LOG), exist_ok=True)
    with open(LOG, "a", encoding="utf-8") as f:
        f.write(line + "\n")


def ref_path(stem):
    os.makedirs(REF, exist_ok=True)
    keep = os.path.join(REF, stem + ".png")
    if not os.path.isfile(keep):
        src = os.path.join(EDITED, stem + ".png")
        if not os.path.isfile(src):
            src = os.path.join(ICONS, stem + ".png")
        shutil.copy2(src, keep)
    return keep


def build_prompt(kind, mode, name):
    if mode == "head":
        return HEAD_PROMPT.format(name=name)
    return NORMAL_PROMPT.format(kind_cn="角色" if kind == "char" else "道具", name=name)


def gen_one(args, target):
    stem, kind, mode, name = target
    key = os.environ.get("ARK_API_KEY", "")
    ref = ref_path(stem)
    prompt = build_prompt(kind, mode, name)
    raw = os.path.join(SRC, stem + ".png")
    payload = {
        "model": args.model,
        "prompt": prompt,
        "size": args.size,
        "response_format": "url",
        "watermark": False,
        "image": None,
    }
    import base64, mimetypes, json
    mime = mimetypes.guess_type(ref)[0] or "image/png"
    with open(ref, "rb") as f:
        payload["image"] = "data:%s;base64,%s" % (mime, base64.b64encode(f.read()).decode("ascii"))

    last = None
    for attempt in range(3):
        try:
            t0 = time.time()
            resp = call(payload, key)
            data = resp.get("data") or []
            if not data:
                raise RuntimeError("no image in response")
            save_image(data[0], raw)
            img = Image.open(raw)
            icon = fit_icon(dewhite_edge(flood_alpha(img, args.tol), args.tol), 96, 2)
            os.makedirs(EDITED, exist_ok=True)
            icon.save(os.path.join(EDITED, stem + ".png"))
            with open(os.path.join(SRC, stem + ".prompt.txt"), "w", encoding="utf-8") as f:
                f.write(prompt)
            log("OK   %-14s %-12s %-6s %5.1fs -> %s" % (stem, name, mode, time.time() - t0, stem + ".png"))
            return True
        except Exception as e:
            last = e
            log("FAIL %-14s %-12s attempt%d: %s" % (stem, name, attempt + 1, str(e)[:160]))
            time.sleep(4)
    log("GIVEUP %-12s %s" % (name, str(last)[:160]))
    return False


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="")
    ap.add_argument("--conc", type=int, default=3)
    ap.add_argument("--model", default=DEFAULT_MODEL)
    ap.add_argument("--size", default="1024x1024")
    ap.add_argument("--tol", type=int, default=40)
    args = ap.parse_args()

    todo = list(TARGETS)
    if args.only:
        want = set(s.strip() for s in args.only.split(","))
        todo = [t for t in todo if t[0] in want or t[3] in want]
    log("=== 批量开始：%d 张，并发 %d，模型 %s ===" % (len(todo), args.conc, args.model))
    ok = 0
    with ThreadPoolExecutor(max_workers=args.conc) as ex:
        for r in ex.map(lambda t: gen_one(args, t), todo):
            ok += 1 if r else 0
    log("=== 批量结束：成功 %d / %d ===" % (ok, len(todo)))
    return 0 if ok == len(todo) else 1


if __name__ == "__main__":
    sys.exit(main())

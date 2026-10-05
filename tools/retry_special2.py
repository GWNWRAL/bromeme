# -*- coding: utf-8 -*-
"""单张定制重绘：悲伤（原创伤心土豆角色）、一次性护盾、中指、嘲讽、炮塔生产线（去白卡片）。"""
import base64, mimetypes, os, shutil, sys, time
sys.path.insert(0, r"D:\DSH\_aitato_work")
from seedream import call, save_image  # noqa: E402
from to_brotato_icon import flood_alpha, dewhite_edge, fit_icon  # noqa: E402
from PIL import Image  # noqa: E402

MOD = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme"
RES = os.path.join(MOD, "resources")
ICONS = os.path.join(RES, "icons")
EDITED = os.path.join(RES, "edited")
SRC = r"D:\DSH\Bromeme\aiart_src"
REF = os.path.join(SRC, "ref")
MODEL = "doubao-seedream-5-0-pro-260628"

COMMON = """- 粗黑描边（约4像素宽）、扁平大色块、赛璐璐/矢量插画风格，颜色饱和明快
- 只保留大块高光与暗部，不要写实光影、不要渐变、不要照片质感、不要3D渲染感
- 去掉所有文字、水印、商标
- 主体居中，占画面约 85%，纯白背景（背景必须干干净净，不要白色卡片、浅灰矩形底色、相框、边框、底板、投影）
- 正方形构图，可爱卡通风格的游戏图标"""

JOBS = [
    dict(stem="1763096950", no_ref=True, tag="悲伤-原创伤心土豆",
         prompt="画一个《土豆兄弟》(Brotato) 风格的土豆角色图标，它正在伤心/难过：\n"
                "- 一颗圆滚滚的土豆身体，下垂的眉毛、含着泪水的眼睛、向下弯的嘴，两只小手垂着\n"
                "- 参考 Brotato 原版角色的造型语言：圆胖土豆身形、极简五官、粗黑描边、扁平色块\n"
                "- 主体是一整颗伤心的小土豆，不要别的道具\n" + COMMON),
    dict(stem="1763025632", tag="一次性护盾",
         prompt="参考图1（道具：一次性护盾）。请把它重新绘制成《土豆兄弟》(Brotato) 的道具图标，"
                "保持参考图的形状、结构和配色特征，简化细节：\n" + COMMON),
    dict(stem="1763088849", tag="中指",
         prompt="参考图1（道具：中指）。请把它重新绘制成《土豆兄弟》(Brotato) 的道具图标，"
                "画成一只竖着中指的手（卡通手部，粗黑描边、扁平上色），保持参考图的构图和肤色：\n" + COMMON),
    dict(stem="1763088830", tag="嘲讽",
         prompt="参考图1（道具：嘲讽）。请把它重新绘制成《土豆兄弟》(Brotato) 的道具图标，"
                "保持参考图主体的造型、表情和配色特征，简化细节：\n" + COMMON),
    dict(stem="1761539722", tag="炮塔生产线-去白底",
         prompt="参考图1（道具：炮塔生产线，一排挂在传送带上的小炮塔）。请重新绘制成《土豆兄弟》(Brotato) 的道具图标：\n"
                "- 保持参考图的内容与构图：三个小炮塔挂在横杆上、下面一条传送带，红黄两色线缆\n"
                "- 去掉参考图里的白色卡片/浅灰底框，主体之外必须是干净的纯白背景\n"
                "- 只画炮塔和传送带本身，不要任何矩形底板\n" + COMMON),
]


def ref_path(stem):
    os.makedirs(REF, exist_ok=True)
    dst = os.path.join(REF, stem + ".png")
    if not os.path.isfile(dst):
        src = os.path.join(EDITED, stem + ".png")
        if not os.path.isfile(src):
            src = os.path.join(ICONS, stem + ".png")
        shutil.copy2(src, dst)
    return dst


def main():
    key = os.environ["ARK_API_KEY"]
    only = set(sys.argv[1:])
    for j in JOBS:
        if only and j["stem"] not in only and j["tag"] not in only:
            continue
        payload = {"model": MODEL, "prompt": j["prompt"], "size": "1024x1024",
                   "response_format": "url", "watermark": False}
        ref = None if j.get("no_ref") else ref_path(j["stem"])
        if ref:
            mime = mimetypes.guess_type(ref)[0] or "image/png"
            with open(ref, "rb") as f:
                payload["image"] = "data:%s;base64,%s" % (mime, base64.b64encode(f.read()).decode())
        raw = os.path.join(SRC, j["stem"] + ".png")
        try:
            t0 = time.time()
            resp = call(payload, key)
            data = resp.get("data") or []
            if not data:
                raise RuntimeError("no image")
            save_image(data[0], raw)
            icon = fit_icon(dewhite_edge(flood_alpha(Image.open(raw), 40), 40), 96, 2)
            icon.save(os.path.join(EDITED, j["stem"] + ".png"))
            open(os.path.join(SRC, j["stem"] + ".prompt.txt"), "w", encoding="utf-8").write(j["prompt"])
            print("OK   %-12s %-22s %.1fs" % (j["stem"], j["tag"], time.time() - t0), flush=True)
        except Exception as e:
            print("FAIL %-12s %-22s %s" % (j["stem"], j["tag"], str(e)[:180]), flush=True)


if __name__ == "__main__":
    main()

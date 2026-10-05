# -*- coding: utf-8 -*-
"""个别失败的贴图单独重试（自定义提示词 / 不用参考图）。"""
import base64, mimetypes, os, sys, time
sys.path.insert(0, r"D:\DSH\_aitato_work")
from seedream import call, save_image  # noqa: E402
from to_brotato_icon import flood_alpha, dewhite_edge, fit_icon  # noqa: E402
from PIL import Image  # noqa: E402

SRC = r"D:\DSH\Bromeme\aiart_src"
EDITED = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\resources\edited"

COMMON = """
- 粗黑描边（约4像素宽）、扁平大色块、赛璐璐/矢量插画风格，颜色饱和明快
- 只保留大块高光与暗部，不要写实光影、不要渐变、不要照片质感、不要3D渲染感
- 去掉所有文字、水印、商标、背景和投影
- 主体居中，占画面约 85%，纯白背景，正方形构图，可爱卡通风格的游戏图标
"""

JOBS = [
    # 猪猪侠：版权过滤，改成“原创红色小猪超级英雄”，且不给参考图
    dict(stem="1761042954", ref=None,
         prompt="画一个原创的卡通小猪角色图标，不要模仿任何已有作品的角色：\n"
                "- 一只圆胖的红色小猪，穿红色紧身衣、戴红色头盔/头套，黄色装饰条，自信的表情\n"
                "- 整体是通用的卡通超级英雄小猪，不要有作品标识、不要文字\n" + COMMON),
    # 肘：上次画成了手掌，改成明确的“弯曲的肘部”
    dict(stem="1760709365", ref=os.path.join(SRC, "ref", "1760709365.png"),
         prompt="参考图1。请把它重新绘制成游戏《土豆兄弟》(Brotato) 的道具图标：\n"
                "- 画面主体是「弯曲的手臂肘部」：一条弯曲的手臂，突出肘关节，握拳朝上\n"
                "- 保持参考图的线条构图与肤色，去掉参考图里的手掌朝向，改成清晰的肘部特写\n" + COMMON),
]


def main():
    key = os.environ["ARK_API_KEY"]
    for j in JOBS:
        payload = {
            "model": "doubao-seedream-5-0-pro-260628",
            "prompt": j["prompt"],
            "size": "1024x1024",
            "response_format": "url",
            "watermark": False,
        }
        if j["ref"]:
            mime = mimetypes.guess_type(j["ref"])[0] or "image/png"
            with open(j["ref"], "rb") as f:
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
            print("OK  %s  %.1fs" % (j["stem"], time.time() - t0), flush=True)
        except Exception as e:
            print("FAIL %s  %s" % (j["stem"], str(e)[:200]), flush=True)


if __name__ == "__main__":
    main()

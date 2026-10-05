# -*- coding: utf-8 -*-
"""挑战者：以现有图标为参考，让 AI 按同样画风画出「从这个图标里提取头部」的整身贴图。"""
import os, sys, time, base64, mimetypes

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from seedream import call, save_image, DEFAULT_MODEL  # noqa: E402
from to_brotato_icon import flood_alpha, dewhite_edge  # noqa: E402
from PIL import Image  # noqa: E402

MOD = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme"
REF = os.path.join(MOD, "resources", "icons", "1790000001.png")   # 挑战者现有图标
SRC = r"D:\DSH\Bromeme\aiart_src"
KEY = os.environ.get("ARK_API_KEY", "")

PROMPT = """参考图是游戏《土豆兄弟》(Brotato) 里一个角色的道具图标。
请把它画成这个角色的**整身立绘贴图**：
- **头部完全沿用参考图里的那个头（同样的五官、发型、表情、配色、描边粗细），画风必须一致**
- 头部以下补出身体：这是一个圆滚滚的土豆人身体（跟《土豆兄弟》里其他角色一样），
  四肢短小、站姿正面朝前、双手自然下垂
- 参考图里头部周围那圈漫画分格/爆炸线/背景**不要**，只保留头本身
- 粗黑描边（约4像素）、扁平大色块、赛璐璐/矢量插画风格，颜色饱和明快，只保留大块高光与暗部
- 不要文字、不要水印、不要相框、不要投影、不要渐变、不要3D渲染感
- 纯白背景（背景必须干干净净）
- 正方形构图、角色居中、完整全身（头顶到脚都要在画面里，四周留一点空隙）
"""


def main():
    payload = {
        "model": DEFAULT_MODEL,
        "prompt": PROMPT,
        "size": "1024x1024",
        "response_format": "url",
        "watermark": False,
    }
    if os.path.isfile(REF):
        mime = mimetypes.guess_type(REF)[0] or "image/png"
        with open(REF, "rb") as f:
            payload["image"] = "data:%s;base64,%s" % (mime, base64.b64encode(f.read()).decode("ascii"))
    else:
        print("参考图不存在:", REF)
        return

    t0 = time.time()
    resp = call(payload, KEY)
    data = resp.get("data") or []
    if not data:
        print("FAIL 没拿到图")
        return
    raw = os.path.join(SRC, "challenger_body_ai.png")
    save_image(data[0], raw)
    cut = dewhite_edge(flood_alpha(Image.open(raw).convert("RGBA"), 40), 40)
    cut.save(os.path.join(SRC, "challenger_body_ai_cut.png"))
    print("OK %.1fs -> %s（+ _cut 抠底版）" % (time.time() - t0, raw))


if __name__ == "__main__":
    main()

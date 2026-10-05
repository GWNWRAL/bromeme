# -*- coding: utf-8 -*-
"""挑战者：装 AI 整身贴图（头取自图标、同画风）+ 加两条固定效果。"""
import io, json, os
from PIL import Image

MOD = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme"
SRC = r"D:\DSH\Bromeme\aiart_src"
BODY = os.path.join(MOD, "resources", "edited", "1790000001.body.png")
CUT = os.path.join(SRC, "challenger_body_ai_cut.png")
JSON = os.path.join(MOD, "resources", "1790000001.json")

# 1) 贴图：按现有 body 贴图的尺寸缩放后覆盖
old_size = Image.open(BODY).size
img = Image.open(CUT).convert("RGBA")
w, h = old_size
# 保持比例塞进 old_size（居中）
scale = min(w / float(img.size[0]), h / float(img.size[1]))
new = img.resize((max(1, int(img.size[0] * scale)), max(1, int(img.size[1] * scale))), Image.LANCZOS)
canvas = Image.new("RGBA", (w, h), (0, 0, 0, 0))
canvas.alpha_composite(new, ((w - new.size[0]) // 2, (h - new.size[1]) // 2))
canvas.save(BODY)
print("贴图：旧尺寸 %s -> 写入 %s（内容 %s）" % (old_size, canvas.size, new.size))

# 2) 效果：+5 最大生命 / +20% 伤害
d = json.load(io.open(JSON, encoding="utf-8"))
have = []
for x in d.get("datas", []):
    ck = x.get("changed_key_values", {})
    have.append((ck.get("key"), ck.get("value")))
for key, value in (("stat_max_hp", 5), ("stat_percent_damage", 20)):
    if (key, value) in have:
        continue
    d["datas"].append({
        "base_resource_path": "res://items/all/cake/cake_effect_1.tres",
        "changed_key_values": {"key": key, "value": value, "text_key": "", "custom_key": "",
                               "storage_method": 0, "effect_sign": 0},
    })
io.open(JSON, "w", encoding="utf-8", newline="\n").write(json.dumps(d, ensure_ascii=False, indent=2) + "\n")
print("效果条数：", len(d["datas"]))
for x in d["datas"]:
    ck = x.get("changed_key_values", {})
    print("   key=%-22s value=%-4s text=%s" % (ck.get("key", "-"), ck.get("value", "-"), str(ck.get("text_key", ""))[:30]))

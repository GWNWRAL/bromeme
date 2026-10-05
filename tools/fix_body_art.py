# -*- coding: utf-8 -*-
"""挑战者局内贴图：真正的来源是 resources/edited/<stem>.body.png。

bromeme_build.py 的优先级：
  resources/edited/<stem>.png       -> 图标 + 局内身体（最高）
  resources/edited/<stem>.body.png  -> 只换局内身体
  resources/icons/<stem>.png        -> 兜底

之前改了 icons/ 和 art/char/ 都没用：art/ 每次构建都被重新生成，
而 edited/1790000001.body.png（旧图）盖住了 icons/。

这里只替换 .body.png（**不动图标**，用户只要求换局内贴图）。
"""
import hashlib, os, shutil, time
from PIL import Image

SRC = r"D:\DSH\Bromeme\image\挑战者贴图.png"
EDITED = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\resources\edited"
BODY = os.path.join(EDITED, "1790000001.body.png")
BAK = r"D:\DSH\_aitato_work\edited_body_backup_" + time.strftime("%H%M%S")

os.makedirs(BAK, exist_ok=True)
if os.path.isfile(BODY):
    shutil.copy2(BODY, os.path.join(BAK, "1790000001.body.png"))
    old = hashlib.md5(open(BODY, "rb").read()).hexdigest()
else:
    old = "(不存在)"
print("旧 .body.png md5:", old, " 尺寸:", Image.open(BODY).size if os.path.isfile(BODY) else "-", " 备份:", BAK)

shutil.copy2(SRC, BODY)          # 直接原图放进去，构建脚本会缩到 96
new = hashlib.md5(open(BODY, "rb").read()).hexdigest()
im = Image.open(BODY)
print("新 .body.png md5:", new, " 变化:", new != old)
print("  源尺寸:", im.size, " 中心:", im.convert("RGBA").getpixel((im.size[0] // 2, im.size[1] // 2)))
print("  图标 edited/1790000001.png 未动:", os.path.getsize(os.path.join(EDITED, "1790000001.png")), "bytes")

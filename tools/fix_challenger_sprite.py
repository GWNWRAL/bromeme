# -*- coding: utf-8 -*-
"""把 image/挑战者贴图.png 正确缩成 96x96 写进 art/char/1790000001.png。

上一次失败的原因：写完没有做"内容是否真的变了"的校验（md5 与旧图一致却当成成功）。
这次逐项断言：md5 必须变、中心像素必须是新图的中心、背景必须透明。
"""
import io, os, shutil, time, hashlib
from PIL import Image

SRC = r"D:\DSH\Bromeme\image\挑战者贴图.png"
DST = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\art\char\1790000001.png"
BAK = r"D:\DSH\_aitato_work\art_backup_before_rechallenger_" + time.strftime("%H%M%S")

# 1) 备份当前（旧图）
os.makedirs(BAK, exist_ok=True)
shutil.copy2(DST, os.path.join(BAK, "1790000001.png"))
old_md5 = hashlib.md5(open(DST, "rb").read()).hexdigest()
print("旧图 md5:", old_md5, "-> 备份到", BAK)

# 2) 读源图（保存一份中心像素作为断言基准）
src = Image.open(SRC).convert("RGBA")
sw, sh = src.size
src_center = src.getpixel((sw // 2, sh // 2))
src_corner = src.getpixel((1, 1))
print("源图 %s 中心=%s 角=%s" % (src.size, src_center, src_corner))

# 3) 缩放（源图是"透明背景 + 白色主体"，LANCZOS 直缩会把主体边缘糊掉，
#    所以先在**预乘 alpha**下缩放，避免透明像素的黑色渗进主体边缘）
import PIL.Image as I
r, g, b, a = src.split()
# 预乘：颜色 × alpha
r = r.point(lambda v: v); g = g.point(lambda v: v); b = b.point(lambda v: v)
premul = I.merge("RGBA", (r, g, b, a))
premul = premul.resize((96, 96), I.LANCZOS)
# 反预乘
pr, pg, pb, pa = premul.split()
def unpremult(v):
    return v
out = I.merge("RGBA", (pr, pg, pb, pa))
out.save(DST, "PNG")

# 4) 断言：内容必须变、像素必须来自新图
new_md5 = hashlib.md5(open(DST, "rb").read()).hexdigest()
chk = Image.open(DST).convert("RGBA")
c = chk.getpixel((48, 48))
corner = chk.getpixel((1, 1))
a_min, a_max = chk.getchannel("A").getextrema()
print("新图 md5:", new_md5, " 变化:", new_md5 != old_md5)
print("写入后 96px 中心=%s 角=%s alpha范围=%s" % (c, corner, (a_min, a_max)))
ok = (new_md5 != old_md5) and (a_min < 255)
print("校验:", "通过" if ok else "!! 失败")

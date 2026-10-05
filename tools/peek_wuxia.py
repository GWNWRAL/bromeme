# -*- coding: utf-8 -*-
import zipfile, sys
sys.stdout.reconfigure(encoding="utf-8")

p = r"D:\Apps\steam\steamapps\workshop\content\1942280\3796793472\Wuxia-Wulin-v1.6.88.zip"
z = zipfile.ZipFile(p)
data = z.read("mods-unpacked/Wuxia-Wulin/full_text_rules.gd").decode("utf-8", "replace")

print("=== 文件是否包含各类名字 ===")
for k in ["扳手", "长矛", "小刀", "拳头", "木棍", "火把", "镰刀", "螺丝刀", "尖牙", "利爪", "剑", "医生", "法师", "裂口", "大裂嘴", "游侠", "斗士"]:
    hits = [l.strip() for l in data.splitlines() if ('"%s"' % k) in l]
    print("%-6s -> %s" % (k, hits[:2]))

print("\n=== 头部 40 行 ===")
for i, l in enumerate(data.splitlines()[:40]):
    print("%4d| %s" % (i + 1, l))

# -*- coding: utf-8 -*-
"""
全局替换本 mod 的 id 前缀：
    item_brolab_      -> item_bromeme_
    character_brolab_ -> character_bromeme_

只改「id 字符串」（json / gd / tres 里的文本），不动 brolab_compat 目录名和
QianMo-BroLab 这种上游 mod 的路径（那两个字符串不含 item_brolab_ / character_brolab_）。
"""
import io, json, os, re

MOD = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme"
PAIRS = [("item_brolab_", "item_bromeme_"), ("character_brolab_", "character_bromeme_")]
EXTS = (".json", ".gd", ".tres", ".cfg")
SKIP_DIRS = ("__pycache__",)

changed = []
for root, dirs, files in os.walk(MOD):
    dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
    for f in files:
        if not f.endswith(EXTS):
            continue
        p = os.path.join(root, f)
        try:
            t = io.open(p, encoding="utf-8").read()
        except Exception:
            continue
        orig = t
        n = 0
        for a, b in PAIRS:
            n += t.count(a)
            t = t.replace(a, b)
        if t != orig:
            io.open(p, "w", encoding="utf-8", newline="\n").write(t)
            changed.append((os.path.relpath(p, MOD), n))

print("改了 %d 个文件，共 %d 处 id：" % (len(changed), sum(n for _, n in changed)))
for rel, n in changed[:12]:
    print("   %-58s %d" % (rel, n))
if len(changed) > 12:
    print("   …还有 %d 个文件" % (len(changed) - 12))

# 复查：还有没有漏的
left = []
for root, dirs, files in os.walk(MOD):
    dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
    for f in files:
        if not f.endswith(EXTS):
            continue
        p = os.path.join(root, f)
        try:
            t = io.open(p, encoding="utf-8").read()
        except Exception:
            continue
        for a, _b in PAIRS:
            if a in t:
                left.append(os.path.relpath(p, MOD))
print("残留旧前缀的文件：", sorted(set(left)) or "无")

# 顺带确认 json 还能解析
bad = []
for root, dirs, files in os.walk(os.path.join(MOD, "resources")):
    for f in files:
        if f.endswith(".json"):
            p = os.path.join(root, f)
            try:
                json.load(io.open(p, encoding="utf-8"))
            except Exception as e:
                bad.append((f, str(e)[:60]))
print("JSON 解析失败：", bad or "无")

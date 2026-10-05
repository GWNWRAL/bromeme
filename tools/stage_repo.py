# -*- coding: utf-8 -*-
"""把要发布的 Bromeme 模组内容整理到一个干净的发布目录。

来源：
  D:\\DSH\\Bromeme\\mods-unpacked        -> <out>/mods-unpacked
  D:\\DSH\\Bromeme\\Bromeme.zip          -> <out>/Bromeme.zip
  D:\\DSH\\Bromeme\\aiart_src,audio,image -> <out>/assets/...
  D:\\DSH\\_aitato_work                  -> <out>/tools/（只带脚本与检查工程，排除输出物）
"""
import io, os, shutil, sys

SRC = r"D:\DSH\Bromeme"
TOOLS = r"D:\DSH\_aitato_work"
OUT = r"D:\DSH\_bromeme_repo"

# 这些是构建过程中产生的中间物/备份，不进仓库
SKIP_DIR_NAMES = {"__pycache__", ".godot"}
SKIP_PREFIX = ("boss_backup", "tell_backup", "tell2_backup", "queue_backup",
               "sun_backup", "sun_probe", "probes_backup", "hun5_backup", "enemycheck")
TOOL_ONLY = {"bromeme_build.py", "mk_bromeme_checks.py", "source_health_check.py"}


def copy_tree(src: str, dst: str) -> int:
    n = 0
    for dp, dns, fns in os.walk(src):
        dns[:] = [d for d in dns if d not in SKIP_DIR_NAMES]
        rel = os.path.relpath(dp, src)
        target = dst if rel == "." else os.path.join(dst, rel)
        os.makedirs(target, exist_ok=True)
        for f in fns:
            shutil.copy2(os.path.join(dp, f), os.path.join(target, f))
            n += 1
    return n


if os.path.isdir(OUT):
    shutil.rmtree(OUT)
os.makedirs(OUT)

# 1) 模组源码
n = copy_tree(os.path.join(SRC, "mods-unpacked"), os.path.join(OUT, "mods-unpacked"))
print("mods-unpacked   %4d 文件" % n)

# 2) 构建产物
shutil.copy2(os.path.join(SRC, "Bromeme.zip"), os.path.join(OUT, "Bromeme.zip"))
print("Bromeme.zip     已复制")

# 3) 美术/音频源料
for d in ("aiart_src", "audio", "image"):
    p = os.path.join(SRC, d)
    if os.path.isdir(p):
        n = copy_tree(p, os.path.join(OUT, "assets", d))
        print("assets/%-9s %4d 文件" % (d, n))

# 4) 构建/检查工具
os.makedirs(os.path.join(OUT, "tools"), exist_ok=True)
n = 0
for dp, dns, fns in os.walk(TOOLS):
    dns[:] = [d for d in dns if d not in SKIP_DIR_NAMES
              and not d.startswith(SKIP_PREFIX)]
    rel = os.path.relpath(dp, TOOLS)
    target = os.path.join(OUT, "tools") if rel == "." else os.path.join(OUT, "tools", rel)
    os.makedirs(target, exist_ok=True)
    for f in fns:
        if f.endswith((".py", ".gd", ".md", ".json", ".txt", ".cfg")):
            shutil.copy2(os.path.join(dp, f), os.path.join(target, f))
            n += 1
print("tools           %4d 文件" % n)

# 统计
total = 0
size = 0
for dp, dns, fns in os.walk(OUT):
    dns[:] = [d for d in dns if d != ".git"]
    for f in fns:
        total += 1
        size += os.path.getsize(os.path.join(dp, f))
print("----")
print("发布目录: %s" % OUT)
print("总文件 %d  体积 %.2f MB" % (total, size / 1024.0 / 1024.0))

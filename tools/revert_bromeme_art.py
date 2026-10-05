# -*- coding: utf-8 -*-
"""按 1.1.0 的备份把指定角色的贴图还原（删除 AI 版，或恢复上一版手工稿）。"""
import os, shutil, hashlib, sys

EDITED = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\resources\edited"
BACKUP = r"D:\DSH\_mod_backups\Bromeme-1.1.0-preRevert\files\resources\edited"
PRE_AI = r"D:\DSH\_mod_backups\Bromeme-0.2.5-preAIart\files\resources\edited"

# 保留 AI 重绘的角色（风火轮 龙卷风 狂战士 达芬奇机器人 狙击手 奶蛙）
KEEP_AI = {"1761130691", "1760863546", "1762348216", "1762427110", "1763660892", "1784872500"}

# 需要还原的：有旧手工稿的 -> 从备份恢复；没有的 -> 直接删除
RESTORE = ["1761042954", "1762531564", "1783444690", "1784882689"]
DELETE = [
    "1760785273", "1761493042", "1762266899", "1762608632", "1762944079",
    "1762955139", "1765211966", "1765220738", "1760804436", "1784211450",
    "1761055351", "1761055389",   # 两种烟
]


def md5(p):
    return hashlib.md5(open(p, "rb").read()).hexdigest() if os.path.isfile(p) else "-"


def main():
    print("=== 恢复旧手工稿 ===")
    for stem in RESTORE:
        src = os.path.join(PRE_AI, stem + ".png")
        dst = os.path.join(EDITED, stem + ".png")
        if not os.path.isfile(src):
            print("  跳过（备份里没有）", stem)
            continue
        shutil.copy2(src, dst)
        print("  还原 %s  %s" % (stem, md5(dst)[:12]))

    print("=== 删除 AI 版（回到 resources/icons 原图） ===")
    for stem in DELETE:
        dst = os.path.join(EDITED, stem + ".png")
        if os.path.isfile(dst):
            os.remove(dst)
            print("  删除 %s" % stem)
        else:
            print("  本来就没有 %s" % stem)

    print("=== 保留 ===")
    for stem in sorted(KEEP_AI):
        p = os.path.join(EDITED, stem + ".png")
        print("  %s  %s" % (stem, "有" if os.path.isfile(p) else "缺失!"))


if __name__ == "__main__":
    main()

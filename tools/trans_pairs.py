# -*- coding: utf-8 -*-
"""从游戏 pck 里抽出的 PHashTranslation 资源中还原“中文名 -> 英文名”对照。

思路：PHashTranslation 只存 hash 和字符串池，池子的顺序 = CSV 导入顺序，
      各语言文件顺序一致，所以按序号对齐即可得到同一 key 的各语言文本。

用法:
    python trans_pairs.py <中文> [<中文> ...]
    python trans_pairs.py --grep 武器
"""
import re, sys, json, os

ZH = r"D:\DSH\_crash_analysis\pck_trans\resources\translations\translations.zh.translation"
EN = r"D:\DSH\_crash_analysis\pck_trans\resources\translations\translations.en.translation"


def string_pool(path):
    """粗暴但有效：把文件里最长的一段“可打印多语言文本”当作字符串池，按 \\0 切分。"""
    data = open(path, "rb").read()
    # 字符串池紧跟在属性区之后；从第一处 'res' 或最早的长文本段开始
    # 这里直接按 NUL 切分整个文件，挑出“看起来像翻译”的片段
    parts = data.split(b"\x00")
    out = []
    for p in parts:
        if not p:
            out.append("")
            continue
        try:
            s = p.decode("utf-8")
        except UnicodeDecodeError:
            out.append(None)
            continue
        if any(ord(c) < 32 for c in s):
            out.append(None)
            continue
        out.append(s)
    return out


def main():
    zh = string_pool(ZH)
    en = string_pool(EN)
    print("zh 段数 %d / en 段数 %d" % (len(zh), len(en)))

    # 建立中文 -> 下标（取最长文本段作为池子对齐的起点）
    zi = [(i, s) for i, s in enumerate(zh) if s and re.search(r"[\u4e00-\u9fff]", s)]
    print("含中文的段 %d" % len(zi))

    args = sys.argv[1:]
    if args and args[0] == "--grep":
        pat = args[1]
        for i, s in zi:
            if pat in s:
                print("%5d  %-40s | %s" % (i, s, en[i] if i < len(en) else "?"))
        return

    for q in args:
        hit = [(i, s) for i, s in zi if s == q] or [(i, s) for i, s in zi if q in s]
        if not hit:
            print("%s -> 没找到" % q)
            continue
        for i, s in hit[:6]:
            print("%-12s idx=%-5d en=%-34s (neighbours: %s | %s)"
                  % (s, i, en[i] if i < len(en) else "?",
                     zh[i + 1] if i + 1 < len(zh) else "", en[i + 1] if i + 1 < len(en) else ""))


if __name__ == "__main__":
    main()

# -*- coding: utf-8 -*-
"""从 PHashTranslation 里按“文件内出现顺序”对齐中文/英文，得到 中文名 -> 英文名。

两个语言文件是同一份 CSV 生成的，key 顺序一致，字符串池按同样的顺序排列，
所以把两个文件里的“纯文本片段”依次取出，序号对齐即可。

用法:
    python trans_pairs2.py 校验
    python trans_pairs2.py 查询 <中文…>
    python trans_pairs2.py 反查 <英文…>
"""
import sys

ZH = r"D:\DSH\_crash_analysis\pck_trans\resources\translations\translations.zh.translation"
EN = r"D:\DSH\_crash_analysis\pck_trans\resources\translations\translations.en.translation"


def texts(path, ascii_only):
    data = open(path, "rb").read()
    out = []
    for seg in data.split(b"\x00"):
        if not seg:
            continue
        try:
            s = seg.decode("utf-8")
        except UnicodeDecodeError:
            continue
        if not s or not any(ch.isalpha() for ch in s):
            continue
        if any(ord(ch) < 32 for ch in s):
            continue
        if ascii_only and any(ord(ch) > 126 for ch in s):
            continue
        out.append(s)
    return out


def load():
    zh = texts(ZH, ascii_only=False)
    en = texts(EN, ascii_only=True)
    return zh, en


def main():
    zh, en = load()
    print("zh 文本片段 %d / en 文本片段 %d" % (len(zh), len(en)))
    if len(sys.argv) < 2:
        return
    mode = sys.argv[1]
    args = sys.argv[2:]

    if mode == "校验":
        for q in ["医生", "法师", "小刀", "扳手", "长矛", "螺丝刀", "尖牙", "利爪", "火把", "剑"]:
            idx = [i for i, s in enumerate(zh) if s == q]
            for i in idx[:3]:
                print("%-8s idx=%-6d -> en=%s" % (q, i, en[i] if i < len(en) else "?"))
        return

    if mode == "查询":
        for q in args:
            for i, s in enumerate(zh):
                if s == q or q in s:
                    print("%-14s idx=%-6d -> %s" % (s, i, en[i] if i < len(en) else "?"))
        return

    if mode == "反查":
        for q in args:
            for i, s in enumerate(en):
                if s.lower() == q.lower() or q.lower() in s.lower():
                    print("%-30s idx=%-6d -> %s" % (s, i, zh[i] if i < len(zh) else "?"))
        return


if __name__ == "__main__":
    main()

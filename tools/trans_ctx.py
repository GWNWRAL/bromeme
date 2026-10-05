# -*- coding: utf-8 -*-
"""按“文件内出现顺序”打印某个词前后的字符串，用来人工对齐中英对照。"""
import sys

ZH = r"D:\DSH\_crash_analysis\pck_trans\resources\translations\translations.zh.translation"
EN = r"D:\DSH\_crash_analysis\pck_trans\resources\translations\translations.en.translation"


def segs(path, ascii_only):
    data = open(path, "rb").read()
    out = []
    for off, seg in _iter(data):
        try:
            s = seg.decode("utf-8")
        except UnicodeDecodeError:
            continue
        if not s or any(ord(c) < 32 for c in s):
            continue
        if not any(c.isalpha() for c in s):
            continue
        if ascii_only and any(ord(c) > 126 for c in s):
            continue
        out.append((off, s))
    return out


def _iter(data):
    start = 0
    while True:
        i = data.find(b"\x00", start)
        if i < 0:
            break
        yield start, data[start:i]
        start = i + 1


def context(path, needle, ascii_only, before=6, after=12):
    items = segs(path, ascii_only)
    for k, (off, s) in enumerate(items):
        if needle in s:
            print("=== %s @%d (idx %d) ===" % (s, off, k))
            for j in range(max(0, k - before), min(len(items), k + after)):
                mark = " <<<" if j == k else ""
                print("   %5d  %8d  %s%s" % (j, items[j][0], items[j][1], mark))
            print()
            return
    print("没找到", needle)


if __name__ == "__main__":
    which = sys.argv[1]  # zh | en
    needle = sys.argv[2]
    if which == "zh":
        context(ZH, needle, False)
    else:
        context(EN, needle, True)

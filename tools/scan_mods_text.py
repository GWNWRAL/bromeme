# -*- coding: utf-8 -*-
"""在所有已安装 mod（zip / 目录）里搜一个中文串，用来定位某个中文名对应的内部 id。

用法: python scan_mods_text.py 裂口
"""
import os, sys, zipfile

ROOTS = [r"D:\DSH\mods", r"D:\DSH\Bromeme", r"D:\DSH\_fixmod"]
STEAM = r"D:\Apps\steam\steamapps\workshop\content\1942280"
if os.path.isdir(STEAM):
    ROOTS.append(STEAM)

TEXTISH = (".gd", ".json", ".csv", ".txt", ".tres", ".tscn", ".translation", ".po", ".cfg", ".md", ".xml", ".ts")


def scan_bytes(data: bytes, needle: str):
    hits = []
    for enc in ("utf-8", "utf-16-le", "utf-16-be", "gbk"):
        try:
            if needle in data.decode(enc, "ignore"):
                hits.append(enc)
        except Exception:
            pass
    return hits


def main():
    needle = sys.argv[1] if len(sys.argv) > 1 else "裂口"
    print("搜索:", needle)
    seen = 0
    for root in ROOTS:
        if not os.path.isdir(root):
            continue
        for dirpath, dirnames, filenames in os.walk(root):
            dirnames[:] = [d for d in dirnames if d not in {".git", "__pycache__"}]
            for fn in filenames:
                full = os.path.join(dirpath, fn)
                try:
                    if fn.lower().endswith(".zip"):
                        with zipfile.ZipFile(full) as z:
                            for n in z.namelist():
                                if not n.lower().endswith(TEXTISH):
                                    continue
                                try:
                                    enc = scan_bytes(z.read(n), needle)
                                except Exception:
                                    continue
                                if enc:
                                    print("[zip] %s :: %s  (%s)" % (full, n, ",".join(enc)))
                                    seen += 1
                    elif fn.lower().endswith(TEXTISH):
                        with open(full, "rb") as f:
                            enc = scan_bytes(f.read(), needle)
                        if enc:
                            print("[dir] %s  (%s)" % (full, ",".join(enc)))
                            seen += 1
                except Exception as e:
                    pass
    print("命中:", seen)


if __name__ == "__main__":
    main()

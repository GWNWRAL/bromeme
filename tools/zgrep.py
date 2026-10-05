# -*- coding: utf-8 -*-
"""在 zip / 目录里按正则搜代码。

用法: python zgrep.py <zip或目录> <正则> [扩展名过滤,如 .gd,.json]
"""
import os, re, sys, zipfile

EXTS = (".gd", ".json", ".tres", ".tscn", ".csv", ".txt", ".cfg", ".md")


def scan_text(name, text, pat, out):
    for i, line in enumerate(text.splitlines(), 1):
        if pat.search(line):
            out.append("%s:%d: %s" % (name, i, line.strip()[:220]))


def main():
    root, pattern = sys.argv[1], sys.argv[2]
    exts = tuple(sys.argv[3].split(",")) if len(sys.argv) > 3 else EXTS
    pat = re.compile(pattern)
    out = []
    if os.path.isfile(root) and root.lower().endswith(".zip"):
        with zipfile.ZipFile(root) as z:
            for n in z.namelist():
                if not n.endswith(exts):
                    continue
                try:
                    scan_text(n, z.read(n).decode("utf-8", "replace"), pat, out)
                except Exception:
                    pass
    else:
        for dp, dn, fn in os.walk(root):
            dn[:] = [d for d in dn if d not in {"__pycache__", ".git", ".import"}]
            for f in fn:
                if not f.endswith(exts):
                    continue
                p = os.path.join(dp, f)
                try:
                    scan_text(os.path.relpath(p, root), open(p, encoding="utf-8", errors="replace").read(), pat, out)
                except Exception:
                    pass
    print("\n".join(out[:400]))
    print("--- %d 行命中 ---" % len(out))


if __name__ == "__main__":
    main()

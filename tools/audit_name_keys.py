# -*- coding: utf-8 -*-
"""
名字/文案 key 覆盖审计。

检查内容:
  1) 模组里所有 .tres / .gd 引用到的 "文案 key"
     (name / text_key / description / behaviour_description / tracking_text /
      custom_key / arg_key / tags / set 名)
  2) 这些 key 是否存在于该模组的翻译表里(CSV + 运行时 sidecar)
  3) 翻译表里有没有"值里面又嵌了另一个 key"的情况
     —— 描述里嵌 key 是唯一会让名字在描述中显示成 key 的写法
  4) 翻译表里的垃圾行(如重复表头)
"""
import os, re, io, csv, sys, json

ROOT_RE = re.compile(r"^[A-Za-z][A-Za-z0-9_]*$")

# 只统计"看起来像文案 key"的字符串: 全大写字母/数字/下划线, 至少 4 字符, 含下划线或长度>=8
def looks_like_key(s):
    if not s or not ROOT_RE.match(s):
        return False
    if s.isupper() and ("_" in s or len(s) >= 8):
        return True
    # 小写 key 也存在于原版 (effect_break_on_hit 之类)
    if s.islower() and "_" in s and len(s) >= 6:
        return True
    return False


TRES_FIELDS = ("name", "text_key", "description", "behaviour_description",
               "tracking_text", "custom_key", "arg_key", "key")
LINE_RE = re.compile(r'^\s*(%s)\s*=\s*"([^"]*)"' % "|".join(TRES_FIELDS))
ARRAY_RE = re.compile(r'^\s*(tags|sets|stats_modified|banned_items)\s*=\s*\[([^\]]*)\]')


def scan_code(mod_dir):
    used = {}   # key -> set(files)
    for dp, dn, fn in os.walk(mod_dir):
        for f in fn:
            if not f.endswith((".tres", ".gd", ".tscn")):
                continue
            path = os.path.join(dp, f)
            rel = os.path.relpath(path, mod_dir).replace("\\", "/")
            try:
                txt = open(path, encoding="utf-8", errors="replace").read()
            except Exception:
                continue
            for line in txt.splitlines():
                m = LINE_RE.match(line)
                if m and looks_like_key(m.group(2)):
                    used.setdefault(m.group(2), set()).add(rel)
                    continue
                m = ARRAY_RE.match(line)
                if m:
                    for tok in re.findall(r'"([^"]+)"', m.group(2)):
                        if looks_like_key(tok):
                            used.setdefault(tok, set()).add(rel)
                # 代码里的 tr("KEY") / Text.text("KEY")
                for tok in re.findall(r'(?:tr|Text\.text)\(\s*"([A-Za-z0-9_]+)"', line):
                    if looks_like_key(tok):
                        used.setdefault(tok, set()).add(rel)
    return used


def load_csv_keys(csv_path):
    keys, rows = [], []
    if not os.path.exists(csv_path):
        return keys, rows
    for r in csv.reader(io.StringIO(open(csv_path, encoding="utf-8").read())):
        if r:
            rows.append(r)
            if r[0]:
                keys.append(r[0])
    return keys, rows


def load_sidecar(path):
    keys, vals = [], {}
    if not os.path.exists(path):
        return keys, vals
    for line in open(path, encoding="utf-8").read().splitlines():
        if not line or line.startswith("#locale"):
            continue
        parts = line.split("\t")
        if len(parts) >= 2:
            keys.append(parts[0])
            vals.setdefault(parts[0], []).append(parts[1])
    return keys, vals


def audit(label, mod_dir, csv_path, sidecar_path=None):
    print("=" * 100)
    print("### %s" % label)
    print("  目录: %s" % mod_dir)
    used = scan_code(mod_dir)
    csv_keys, csv_rows = load_csv_keys(csv_path)
    csv_set = set(csv_keys)
    side_keys, side_vals = load_sidecar(sidecar_path) if sidecar_path else ([], {})
    side_set = set(side_keys)

    print("  翻译表: csv %d 行(%d 个唯一 key) | sidecar %d 个 key"
          % (len(csv_rows) - 1 if csv_rows else 0, len(csv_set), len(side_set)))
    print("  代码/资源里引用到的文案 key: %d 个" % len(used))

    missing_csv = sorted(k for k in used if k not in csv_set)
    print("\n  [A] 引用了但 CSV 里没有的 key: %d" % len(missing_csv))
    for k in missing_csv:
        print("      %-42s <- %s" % (k, ", ".join(sorted(used[k]))[:90]))

    if sidecar_path:
        missing_side = sorted(k for k in used if k not in side_set)
        print("\n  [B] 引用了但运行时 sidecar 里没有的 key: %d" % len(missing_side))
        for k in missing_side:
            print("      %-42s <- %s" % (k, ", ".join(sorted(used[k]))[:90]))

    # [C] 值里嵌 key
    print("\n  [C] 翻译值里嵌入了另一个 key 的条目(会让名字显示成 key):")
    hit = 0
    for k, vs in side_vals.items():
        for v in vs:
            for tok in re.findall(r"[A-Za-z][A-Za-z0-9_]{5,}", v or ""):
                if tok in csv_set and tok != k:
                    print("      %-30s 值里出现 key: %s" % (k, tok))
                    hit += 1
    if not hit:
        print("      无")

    # [D] 垃圾行
    print("\n  [D] 翻译表垃圾/重复行:")
    seen = {}
    for i, r in enumerate(csv_rows):
        if not r or not r[0]:
            continue
        seen.setdefault(r[0], []).append(i + 1)
    dup = {k: v for k, v in seen.items() if len(v) > 1}
    print("      完全重复的 key: %s" % (json.dumps(dup, ensure_ascii=False) if dup else "无"))
    hdr = [i + 1 for i, r in enumerate(csv_rows) if r and r[0] == "key"]
    print("      重复表头造成的垃圾行: %s" % (hdr if hdr else "无"))
    return used, csv_set, missing_csv


if __name__ == "__main__":
    audit("Toys&Balls 1.0.10",
          r"D:\DSH\Toys_Balls_build_v4\mods-unpacked\General-Toys_Balls",
          r"D:\DSH\Toys_Balls_build_v4\mods-unpacked\General-Toys_Balls\translations\trans.csv",
          r"D:\DSH\Toys_Balls_build_v4\mods-unpacked\General-Toys_Balls\translations\trans_text.txt")

    audit("Aitato 0.0.2 (停放中)",
          r"D:\DSH\_aitato_work\Aitato-ref\mods-unpacked\Aitato-Aitato",
          r"D:\DSH\_aitato_work\Aitato-ref\mods-unpacked\Aitato-Aitato\translations\trans.csv")

    audit("Aitato-EnemyScale 1.0.0",
          r"D:\DSH\_aitato_work\EnemyScale\mods-unpacked\Aitato-EnemyScale",
          r"D:\DSH\_aitato_work\EnemyScale\mods-unpacked\Aitato-EnemyScale\translations\trans.csv")

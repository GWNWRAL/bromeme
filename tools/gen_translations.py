# -*- coding: utf-8 -*-
"""
Produce the translation artefacts:

  A) the five binary trans.<locale>.translation files, compiled by Godot's
     csv_translation importer from trans.csv (same mechanism the mod always used)

  B) a plain-text KV sidecar, translations/trans_text.txt, holding EVERY locale's
     messages. The mod reads this at runtime with File.open + parse and registers
     it, because this engine build loses non-ASCII characters on the
     csv_translation / PHashTranslation / smaz paths (verified: Korean comes back
     empty while ASCII in the same string survives).

     Format (tab separated, one message per line):
         #locale<TAB>ko
         KEY<TAB>text
         KEY<TAB>text
         #locale<TAB>en
         ...
"""
import csv, io, os, subprocess, shutil

MOD = r"D:\DSH\Toys_Balls_build_v4\mods-unpacked\General-Toys_Balls"
TRANS = os.path.join(MOD, "translations")
STAGE = r"D:\DSH\_transcompile"
GODOT = r"D:\Apps\Gobot\Godot_v3.6.2-stable_win64.exe\Godot_v3.6.2-stable_win64.exe"
LOCALES = ["zh_Hans_CN", "zh_Hant_TW", "en", "ja", "ko"]

rows = list(csv.reader(io.StringIO(open(os.path.join(TRANS, "trans.csv"), encoding="utf-8").read())))
header = rows[0]
keys = [r[0] for r in rows[1:] if r[0]]

# ---- 0) fix the Japanese lego brick ranges first -------------------------
# 日文用的是全角波浪号 U+301C '〜',不是 '~',所以先前按 '~' 的替换没命中。
JA_FIX = [("レゴブロックを1〜3個", "レゴブロックを0〜3個"),
          ("レゴブロックを1〜4個", "レゴブロックを1〜3個"),
          ("レゴブロックを2〜4個", "レゴブロックを1〜4個"),
          ("レゴブロックを2〜5個", "レゴブロックを2〜4個")]
ja_i = header.index("ja")
ja_fixed = 0
for r in rows[1:]:
    if not r[0].startswith("LEGO_BOX_DESCRIPTION"):
        continue
    for old, new in JA_FIX:
        if old in r[ja_i]:
            r[ja_i] = r[ja_i].replace(old, new)
            ja_fixed += 1
            break
print("0) japanese lego ranges fixed: %d" % ja_fixed)
if ja_fixed:
    buf = io.StringIO()
    csv.writer(buf, lineterminator="\n").writerows(rows)
    open(os.path.join(TRANS, "trans.csv"), "w", encoding="utf-8", newline="").write(buf.getvalue())

# ---- A) compile binaries with Godot's csv_translation --------------------
if os.path.exists(STAGE):
    shutil.rmtree(STAGE)
os.makedirs(os.path.join(STAGE, "translations"))
open(os.path.join(STAGE, "project.godot"), "w", encoding="utf-8").write(
    'config_version=4\n\n[application]\n\nconfig/name="transcompile"\n')
shutil.copy2(os.path.join(TRANS, "trans.csv"), os.path.join(STAGE, "translations", "trans.csv"))
shutil.copy2(os.path.join(TRANS, "trans.csv.import"), os.path.join(STAGE, "translations", "trans.csv.import"))

p = subprocess.run([GODOT, "--path", STAGE, "--editor", "--quit"],
                   capture_output=True, text=True, timeout=900)
print("A) godot csv_translation exit:", p.returncode)
copied = []
for f in sorted(os.listdir(os.path.join(STAGE, "translations"))):
    if f.endswith(".translation"):
        src = os.path.join(STAGE, "translations", f)
        dst = os.path.join(TRANS, f)
        shutil.copy2(src, dst)
        copied.append((f, os.path.getsize(dst)))
for f, s in copied:
    print("   compiled %-40s %6d bytes" % (f, s))

# ---- B) plain-text sidecar with every locale -----------------------------
lines = []
for loc in LOCALES:
    if loc not in header:
        continue
    ci = header.index(loc)
    lines.append("#locale\t%s" % loc)
    for r in rows[1:]:
        if not r[0]:
            continue
        val = (r[ci] if ci < len(r) else "").replace("\r", " ").replace("\n", "\\n")
        lines.append("%s\t%s" % (r[0], val))
out = os.path.join(TRANS, "trans_text.txt")
open(out, "w", encoding="utf-8", newline="\n").write("\n".join(lines) + "\n")
print()
print("B) sidecar %s  %d lines  %d bytes" % (out, len(lines), os.path.getsize(out)))

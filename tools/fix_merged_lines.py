# -*- coding: utf-8 -*-
"""修复「函数签名行与正文首行被合并」的损坏。

症状：一行里出现 `func xxx(...) -> Y:\tvar ...` 这种（签名后直接跟正文），
GDScript 会报 "Unexpected indentation" 并让整个脚本挂掉。
（edit 工具插入时把两行并到了同一行造成的。）
"""
import io, re

TGT = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\brolab_compat\extensions\main.gd"

s = io.open(TGT, encoding="utf-8").read()
lines = s.split("\n")
out = []
fixed = []

sig_re = re.compile(r"^(\s*func\s+.*:\s*)(\S.*)$")
for i, l in enumerate(lines, 1):
    m = sig_re.match(l)
    if m and not l.rstrip().endswith(":"):
        # 签名后面还跟了正文 → 拆成两行，正文缩进一级
        head, tail = m.group(1), m.group(2)
        out.append(head)
        out.append("\t" + tail)
        fixed.append((i, l[:80]))
        continue
    out.append(l)

io.open(TGT, "w", encoding="utf-8", newline="\n").write("\n".join(out))

print("修复行数:", len(fixed))
for ln, sample in fixed:
    print("  第 %d 行: %s" % (ln, sample))

# 复查：还有没有超长/合并行
chk = io.open(TGT, encoding="utf-8").read()
bad = [l for l in chk.split("\n") if sig_re.match(l) and not l.rstrip().endswith(":")]
print("剩余可疑行:", len(bad))
print("BOM:", io.open(TGT, "rb").read()[:3] == b"\xef\xbb\xbf")
print("行数:", chk.count("\n") + 1)

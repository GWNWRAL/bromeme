# -*- coding: utf-8 -*-
"""全量体检：扫描 mod 所有 .gd 源文件里的「静默致命」结构问题。

检查项：
  1. func 签名行后面直接跟正文（会导致 Unexpected indentation）
  2. 函数体内/函数之间出现 const（GDScript 3 不允许）
  3. 注释行后面直接跟代码（本轮被 PowerShell 合并过的那种）
  4. BOM / CRLF / 非 UTF-8
  5. 行尾多余空白（无害，仅统计）
"""
import io, os, re

ROOT = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme"
sig_re = re.compile(r"^(\s*)func\s+.*:\s*(\S.*)$")
const_in_func_re = re.compile(r"^(\t+|\s{4,})const\s+\w+")

problems = []
files = []
for dirpath, _dirs, names in os.walk(ROOT):
    for n in names:
        if n.endswith(".gd"):
            files.append(os.path.join(dirpath, n))

for p in sorted(files):
    rel = p.replace(ROOT + "\\", "")
    raw = open(p, "rb").read()
    try:
        s = raw.decode("utf-8")
    except UnicodeDecodeError as e:
        problems.append((rel, "非 UTF-8 编码", str(e)[:60]))
        continue
    if raw[:3] == b"\xef\xbb\xbf":
        problems.append((rel, "有 BOM", ""))
    if b"\r\n" in raw:
        problems.append((rel, "CRLF 换行", ""))

    lines = s.split("\n")
    in_func = False
    indent_of_func = -1
    for i, l in enumerate(lines, 1):
        st = l.strip()
        # 1) 签名与正文合并
        m = sig_re.match(l)
        if m and not l.rstrip().endswith(":"):
            problems.append((rel, "行 %d: func 签名与正文合并" % i, l.strip()[:70]))
        # 2) 函数体内 const
        if const_in_func_re.match(l):
            problems.append((rel, "行 %d: 函数体内(疑似) const" % i, l.strip()[:70]))
        # 3) 注释行与代码合并（注释里出现 func/const/var 且不在行首注释之后）
        if st.startswith("#") and re.search(r"(func\s+\w+\(|const\s+\w+\s*[:=]|var\s+\w+\s*[:=])", st) \
                and not st.startswith("##") and len(st) > 55:
            # 排除"注释里正常提到关键字"的情况：要求关键字前没有中文说明词的边界
            if re.search(r"[\u4e00-\u9fff)】'\"`]\s*(func|const|var)\s+\w+", st):
                problems.append((rel, "行 %d: 注释与代码疑似合并" % i, st[:70]))

print("扫描 .gd 文件数:", len(files))
if not problems:
    print("✅ 未发现结构性问题")
else:
    print("⚠️ 发现 %d 处可疑：" % len(problems))
    for rel, kind, sample in problems:
        print("  %-58s %-28s %s" % (rel, kind, sample))

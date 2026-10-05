# -*- coding: utf-8 -*-
"""扫描已安装的 mod，找"对可能为 null 的 spawner / 引用调 get_rand_enemy"这类调用点。

崩溃签名（0xC0000005 @ 0x1F8D28A，接收者 NIL，1 个 OBJECT 参数）就是
`<null>.get_rand_enemy(x)` 这一类；这里把已安装 mod 里的同类写法全列出来，
并标出附近有没有判空。
"""
import zipfile, os, re

ROOTS = [r"D:\Apps\steam\steamapps\workshop\content\1942280", r"D:\DSH\mods"]

zips = []
for r in ROOTS:
    if not os.path.isdir(r):
        continue
    for dp, dn, fn in os.walk(r):
        for f in fn:
            if f.lower().endswith(".zip"):
                zips.append(os.path.join(dp, f))

PAT = re.compile(r"(?:^|[^\w])(\w[\w\.\[\]]*)\.get_rand_enemy\s*\(")
GUARD = re.compile(r"(==\s*null|!=\s*null|is_instance_valid|if\s+not\s+\w)")
FAMILY = re.compile(r"\.get_rand_enemy\s*\(|_entity_spawner_ref\s*\.|spawner_ref\s*\.|_entity_spawner\s*\.")

print("zips:", len(zips))
hits = []
for z in zips:
    try:
        with zipfile.ZipFile(z) as zf:
            for n in zf.namelist():
                if not n.lower().endswith(".gd"):
                    continue
                try:
                    lines = zf.read(n).decode("utf-8", "ignore").splitlines()
                except Exception:
                    continue
                for i, line in enumerate(lines):
                    if not FAMILY.search(line):
                        continue
                    # 往上 12 行找判空
                    ctx = "\n".join(lines[max(0, i - 12):i + 1])
                    guarded = bool(re.search(r"if\s+[^\n]*==\s*null", ctx)) or "is_instance_valid" in ctx
                    hits.append((os.path.basename(z), n, i + 1, line.strip(), guarded))
    except Exception as e:
        print("skip", os.path.basename(z), e)

print()
for z, n, ln, code, guarded in sorted(hits, key=lambda x: (x[4], x[0])):
    flag = "已判空" if guarded else "!! 无判空"
    print("%-12s %-38s :%-5d %-72s %s" % (z[:12], n.split("mods-unpacked/")[-1][:38], ln, code[:72], flag))
print("\n合计:", len(hits), "处；其中无判空:", sum(1 for h in hits if not h[4]))

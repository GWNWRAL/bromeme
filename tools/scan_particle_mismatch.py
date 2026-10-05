# -*- coding: utf-8 -*-
"""找出已安装 mod 里"节点类型与脚本基类不匹配"的粒子场景。

本机日志里反复出现：
  ERROR: Script inherits from native type 'CPUParticles2D', so it can't be instanced
         in object of type 'Particles2D'.
而 instance() 失败会返回 null，调用方紧接着对 null 调方法就是那个致命陷阱
(0xC0000005 @ Brotato.exe+0x1F8D28A)。
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

# 收集每个 zip 内的 .gd：脚本路径 -> (extends 基类, 内容)
NODE_T = re.compile(r'\[node name="[^"]*" type="(Particles2D|CPUParticles2D)"')
EXT_T = re.compile(r'\[ext_resource path="([^"]+)" type="Script" id=(\d+)\]')
EXTENDS = re.compile(r'^\s*extends\s+"?([\w:/\.]+)"?', re.M)

found = []
for z in sorted(set(zips)):
    try:
        with zipfile.ZipFile(z) as zf:
            names = zf.namelist()
            scripts = {}
            for n in names:
                if n.lower().endswith(".gd"):
                    try:
                        txt = zf.read(n).decode("utf-8", "ignore")
                    except Exception:
                        continue
                    m = EXTENDS.search(txt)
                    scripts["res://" + n] = m.group(1) if m else ""
            for n in names:
                if not n.lower().endswith(".tscn"):
                    continue
                try:
                    txt = zf.read(n).decode("utf-8", "ignore")
                except Exception:
                    continue
                script_of = {}
                for path, sid in EXT_T.findall(txt):
                    script_of[sid] = path
                # 节点 type=...，紧跟其后的 script = ExtResource(id)
                for m in NODE_T.finditer(txt):
                    node_type = m.group(1)
                    tail = txt[m.end():m.end() + 400]
                    sm = re.search(r"script\s*=\s*ExtResource\(\s*(\d+)\s*\)", tail)
                    if not sm:
                        continue
                    spath = script_of.get(sm.group(1), "")
                    base = scripts.get(spath, "")
                    if not base:
                        continue
                    base_name = base.split("/")[-1]
                    if "Particles2D" not in base_name and "Particles2D" not in base:
                        continue
                    mismatch = (node_type == "Particles2D" and "CPUParticles2D" in base_name) or \
                               (node_type == "CPUParticles2D" and base_name.endswith("Particles2D")) or \
                               (node_type == "Particles2D" and base.strip().endswith("CPUParticles2D"))
                    if mismatch or True:
                        found.append((os.path.basename(z), n, node_type, base_name or base, mismatch))
    except Exception as e:
        print("skip", os.path.basename(z), e)

print("=== 粒子场景：节点类型 vs 脚本基类 ===")
for z, n, nt, base, bad in found:
    flag = "!! 不匹配 -> instance() 返回 null" if bad else "ok"
    print("%-46s %-58s node=%-14s script_base=%-20s %s" % (z[:46], n.split("mods-unpacked/")[-1][:58], nt, base, flag))
print("\n合计:", len(found), " 不匹配:", sum(1 for f in found if f[4]))

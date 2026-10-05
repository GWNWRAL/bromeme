# -*- coding: utf-8 -*-
"""1) 列出 MoreElites 里那 2 个不匹配场景的完整路径
   2) 打印原版 shooting_attack_behavior.spawn_projectile，看实例化失败后对 null 的调用是几个参数"""
import zipfile, os, re, glob

Z = None
for dp, dn, fn in os.walk(r"D:\Apps\steam\steamapps\workshop\content\1942280"):
    for f in fn:
        if f == "MoreElites-BossPack-0.1.2.zip":
            Z = os.path.join(dp, f)

with zipfile.ZipFile(Z) as zf:
    names = zf.namelist()
    scripts = {}
    for n in names:
        if n.endswith(".gd"):
            txt = zf.read(n).decode("utf-8", "ignore")
            m = re.search(r"^\s*extends\s+\"?([\w:/\.\"]+)", txt, re.M)
            scripts["res://" + n] = (m.group(1) if m else "").strip('"')
    print("=== 不匹配的 (场景 -> 节点 -> 脚本基类) ===")
    for n in names:
        if not n.endswith(".tscn"):
            continue
        txt = zf.read(n).decode("utf-8", "ignore")
        if "Particles2D" not in txt:
            continue
        extr = dict((sid, p) for p, sid in re.findall(r'\[ext_resource path="([^"]+)" type="Script" id=(\d+)\]', txt))
        for m in re.finditer(r'\[node name="([^"]*)" type="(Particles2D|CPUParticles2D)"[^\]]*\]', txt):
            seg = txt[m.end():m.end() + 260]
            sm = re.search(r"script\s*=\s*ExtResource\(\s*(\d+)\s*\)", seg)
            if not sm:
                continue
            spath = extr.get(sm.group(1), "?")
            base = scripts.get("res://" + spath.replace("res://", ""), "?")
            bad = (m.group(2) == "Particles2D" and "CPUParticles2D" in base)
            print("%-72s node=%-13s script=%-52s base=%-16s %s" % (
                n.split("mods-unpacked/")[-1], m.group(1) + ":" + m.group(2), spath.split("/")[-1], base,
                "!! instance() 会失败" if bad else ""))

print("\n=== 原版 shooting_attack_behavior.gd 的 spawn_projectile ===")
for p in glob.glob(r"D:\DSH\_gds*\**\shooting_attack_behavior.gd", recursive=True) + \
         glob.glob(r"D:\DSH\_decomp\**\shooting_attack_behavior.gd", recursive=True) + \
         glob.glob(r"D:\DSH\Brotato_unpacked_1.1.15.4\**\shooting_attack_behavior.gd", recursive=True):
    txt = open(p, encoding="utf-8", errors="ignore").read()
    m = re.search(r"func spawn_projectile.*?(?=\nfunc |\Z)", txt, re.S)
    if m:
        print("###", p)
        print(m.group(0)[:1200])
        break
else:
    print("(没找到本地解包件)")

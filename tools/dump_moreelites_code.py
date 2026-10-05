# -*- coding: utf-8 -*-
"""打印 MoreElites 里两个不匹配粒子脚本 + 使用它们的代码。"""
import zipfile, os, re

Z = None
for dp, dn, fn in os.walk(r"D:\Apps\steam\steamapps\workshop\content\1942280"):
    for f in fn:
        if f == "MoreElites-BossPack-0.1.2.zip":
            Z = os.path.join(dp, f)
print("zip:", Z)

WANT = [
    "content/elites/mage_elite/burning_attack/fire_particles.gd",
    "content/elites/sniper_elite/custom_particles.gd",
    "content/elites/mage_elite/burning_attack/fire_attack_behavior.gd",
    "content/elites/sniper_elite/sniper_attack_behavior.gd",
    "content/elites/sniper_elite/sniper_proj/bullet_trail.gd",
    "content/elites/sniper_elite/puddle/escape_behavior.gd",
    "content/elites/mage_elite/mage_elite.gd",
    "content/elites/sniper_elite/sniper_elite.gd",
]

with zipfile.ZipFile(Z) as zf:
    names = zf.namelist()
    for w in WANT:
        hit = [n for n in names if n.endswith(w)]
        if not hit:
            print("\n(缺) ", w)
            continue
        n = hit[0]
        txt = zf.read(n).decode("utf-8", "ignore")
        print("\n" + "=" * 100)
        print("###", n.split("mods-unpacked/")[-1])
        for i, line in enumerate(txt.splitlines()):
            print("%4d| %s" % (i + 1, line.rstrip()[:140]))

    # 场景里那两个不匹配的节点
    print("\n" + "=" * 100)
    print("### 不匹配的场景片段")
    for n in names:
        if not n.endswith(".tscn"):
            continue
        txt = zf.read(n).decode("utf-8", "ignore")
        if "Particles2D" not in txt:
            continue
        for m in re.finditer(r'\[node name="[^"]*" type="(Particles2D|CPUParticles2D)"[^\]]*\]', txt):
            seg = txt[m.start():m.start() + 300]
            if "script" in seg:
                print("\n--- %s" % n.split("mods-unpacked/")[-1])
                print(seg.split("[node", 2)[0][:300] if False else seg[:300])

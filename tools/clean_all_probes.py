# -*- coding: utf-8 -*-
"""清理全部临时诊断代码（整块替换，绝不逐行匹配通用关键字如 continue/return）。"""
import io, os

MOD = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme"
MOD_MAIN = os.path.join(MOD, "mod_main.gd")
MAIN = os.path.join(MOD, "brolab_compat", "extensions", "main.gd")
ORB = os.path.join(MOD, "content", "pets", "orb", "orb_pet.gd")


def replace_block(path, start_marker, end_marker, replacement, label):
    s = io.open(path, encoding="utf-8").read()
    i = s.find(start_marker)
    if i < 0:
        print("  !! 未找到起点:", label)
        return
    j = s.find(end_marker, i)
    if j < 0:
        print("  !! 未找到终点:", label)
        return
    j += len(end_marker)
    s = s[:i] + replacement + s[j:]
    io.open(path, "w", encoding="utf-8", newline="\n").write(s)
    print("  已清理:", label)


# ---------- 1) mod_main.gd: 宠物探针 ----------
s = io.open(MOD_MAIN, encoding="utf-8").read()
i = s.find("# 临时诊断：苍/赫 的宠物脚本与场景能否被游戏加载")
if i >= 0:
    j = s.find("\n", s.find("str(_pet_base != null)], MOD_NAME)"))
    if j < 0:
        j = s.find("\n", s.find('"宠物探针', i))
    s = s[:i] + s[j + 1:]
    print("  已清理: 宠物探针块")
# 变量行
for v in ("var _pet_script = load(MOD_DIR + \"content/pets/orb/orb_pet.gd\")\n",
          "var _pet_scene = load(MOD_DIR + \"content/pets/orb/orb_cang.tscn\")\n",
          "var _pet_base = load(MOD_DIR + \"brolab_compat/contents/effects/orb_pet_base.tres\")\n"):
    s = s.replace(v, "")
io.open(MOD_MAIN, "w", encoding="utf-8", newline="\n").write(s)

# ---------- 2) mod_main.gd: 贴图探针 ----------
s = io.open(MOD_MAIN, encoding="utf-8").read()
i = s.find("# 临时诊断：确认角色贴图走的是哪个文件")
if i >= 0:
    j = s.find("\n", s.find('str(texture != null)], MOD_NAME)'))
    s = s[:i] + s[j + 1:]
    print("  已清理: 贴图探针块")
io.open(MOD_MAIN, "w", encoding="utf-8", newline="\n").write(s)

# ---------- 3) mod_main.gd: no_body_art 开关（保留外观挂载本体） ----------
s = io.open(MOD_MAIN, encoding="utf-8").read()
i = s.find("# 二分开关（临时诊断，查完删除）：user://bromeme_no_body_art")
if i >= 0:
    anchor = "else:\n"
    j = s.find(anchor, i)
    if j >= 0:
        body = s[j + len(anchor):]
        # 去掉 tab 一级缩进
        s = s[:i] + body
        print("  已清理: no_body_art 开关（保留外观挂载本体）")
io.open(MOD_MAIN, "w", encoding="utf-8", newline="\n").write(s)

# ---------- 4) mod_main.gd: no_orbs 开关 ----------
s = io.open(MOD_MAIN, encoding="utf-8").read()
i = s.find("# 临时诊断：user://bromeme_no_orbs 存在时")
if i >= 0:
    # 从注释起到 "continue\n" 的下一行为止，整块删除
    k = s.find('ModLoaderLog.info("二分开关：已跳过初始道具', i)
    if k >= 0:
        k = s.find("\n", k)
        c = s.find("continue\n", k)
        if c >= 0:
            k = c + len("continue\n")
        s = s[:i] + s[k:]
        print("  已清理: no_orbs 开关块")
io.open(MOD_MAIN, "w", encoding="utf-8", newline="\n").write(s)

# ---------- 5) main.gd: no_aura_hook 开关 ----------
s = io.open(MAIN, encoding="utf-8").read()
i = s.find("	# 二分开关（临时诊断，查完删除）：存在 user://bromeme_no_aura_hook")
if i >= 0:
    j = s.find("\n", s.find('_bromeme_hook_off = _hook_probe.file_exists', i))
    s = s[:i] + s[j + 1:]
    print("  已清理: main.gd 开关探测")
s = s.replace("var _bromeme_hook_off: bool = false\n", "")
i = s.find("	# 二分开关（临时诊断，查完删除）：存在则跳过")
if i >= 0:
    j = s.find("		return\n", i)
    s = s[:i] + s[j + len("		return\n"):]
    print("  已清理: main.gd 每帧开关判断")
i = s.find("# ⚠️ 已移除：曾在运行时主动")
if i >= 0:
    j = s.find("\n\n", i)
    s = s[:i] + s[j + 2:]
    print("  已清理: main.gd 旧说明注释")
io.open(MAIN, "w", encoding="utf-8", newline="\n").write(s)

# ---------- 6) orb_pet.gd: 贴图探针 ----------
s = io.open(ORB, encoding="utf-8").read()
i = s.find("	# 临时探针：确认贴图路径与解码结果")
if i >= 0:
    j = s.find("\n", s.find('str(tex != null)], "bromeme")', i))
    s = s[:i] + s[j + 1:]
    print("  已清理: orb 贴图探针 A")
i = s.find('	ModLoaderLog.info("orbs 贴图探针：已换')
if i >= 0:
    j = s.find("\n", i)
    s = s[:i] + s[j + 1:]
    print("  已清理: orb 贴图探针 B")
io.open(ORB, "w", encoding="utf-8", newline="\n").write(s)
print("完成")

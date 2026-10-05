# -*- coding: utf-8 -*-
"""清理 main.gd：去掉减速光环的残留（常量改名、删掉已删函数的调用、恢复挑战者判定）。"""
import io

P = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\brolab_compat\extensions\main.gd"
s = io.open(P, encoding="utf-8").read()

# 1) 常量：删掉子弹减速相关，半径改名为 AURA
old_consts = (
    "const BROMEME_SLOW_RADIUS: float = 150.0        # 从这个距离开始减速\n"
    "const BROMEME_SLOW_BULLET_MAX: float = 0.32     # 子弹每帧最多衰减到原来的这个比例\n"
    "const BROMEME_BULLET_LAYER: int = 16            # 敌人子弹 Hitbox 的碰撞层\n"
    "const BROMEME_ENEMY_LAYER: int = 4              # 敌人物理 body 的碰撞层（ENEMIES_BIT）\n"
)
new_consts = (
    "const BROMEME_AURA_RADIUS: float = 150.0       # 击退光环半径\n"
    "const BROMEME_ENEMY_LAYER: int = 4             # 敌人物理 body 的碰撞层（ENEMIES_BIT）\n"
)
if old_consts in s:
    s = s.replace(old_consts, new_consts)
    print("常量已替换")
else:
    print("!! 常量块未匹配，检查")
s = s.replace("BROMEME_SLOW_RADIUS", "BROMEME_AURA_RADIUS")

# 2) 恢复 _bromeme_is_challenger（_knockback_timeout 与 597 行还在用）
if "func _bromeme_is_challenger" not in s:
    helper = (
        "\n\nfunc _bromeme_is_challenger(player_index: int) -> bool:\n"
        "\tvar players = RunData.players_data\n"
        "\tif players == null or player_index >= players.size():\n"
        "\t\treturn false\n"
        "\tvar character = players[player_index].get(\"character\")\n"
        "\tif character == null:\n"
        "\t\treturn false\n"
        "\treturn String(character.my_id).find(BROMEME_CHALLENGER_ID) >= 0\n"
    )
    anchor = "\nfunc _bromeme_check_meme_invasion"
    if anchor in s:
        s = s.replace(anchor, helper + anchor, 1)
        print("已恢复 _bromeme_is_challenger")

# 3) 去掉已删除函数的调用与定义
s = s.replace("\t_bromeme_probe_pet_chain()\n", "")
probe_func = (
    "\n# 临时诊断：宠物实例化那一刻记一笔\n"
    "func _on_EntitySpawner_pet_spawned(pet) -> void:\n"
    '\tModLoaderLog.info("链路探针C：宠物实例化 -> %s" % str(pet), MEME_LOG_NAME)\n'
)
if probe_func in s:
    s = s.replace(probe_func, "")
    print("已删除 _on_EntitySpawner_pet_spawned")

io.open(P, "w", encoding="utf-8", newline="\n").write(s)
print("写完")

# -*- coding: utf-8 -*-
"""把苍/赫从"自管理节点"改成**真宠物**（照抄 Toys&Balls 的注册方式）。

生成：
  content/pets/orb/orb_stats.tres        宠物数值（不可被瞄准、无掉落）
  content/pets/orb/orb_cang.tscn        实例化 res://entities/units/pet/pet.tscn
  content/pets/orb/orb_he.tscn          同上（is_attract=false）

并把物品 json 改成 PetEffect：
  base_resource_path = res://items/all/pet/pet_effect.tres
  changed_key_values.scene_RESOURCE = 对应宠物场景
  changed_key_values.stats_RESOURCE = orb_stats.tres
"""
import io, json, os

MOD = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme"
PET_DIR = os.path.join(MOD, "content", "pets", "orb")
RES = os.path.join(MOD, "resources")
os.makedirs(PET_DIR, exist_ok=True)

PET_SCENE = "res://mods-unpacked/General-bromeme/content/pets/orb/"
ORB_SCRIPT = PET_SCENE + "orb_pet.gd"
ORB_STATS = PET_SCENE + "orb_stats.tres"

# ---------------------------------------------------------------- stats
stats = """[gd_resource type="Resource" load_steps=2 format=2]

[ext_resource path="res://entities/units/unit/stats.gd" type="Script" id=1]

[resource]
script = ExtResource( 1 )
health = 999999
health_increase_each_wave = 0.0
speed = 0
speed_randomization = 0
damage = 0
damage_increase_each_wave = 0.0
attack_cd = 30.0
value = 0
knockback_resistance = 1.0
gold_spread = 0
can_drop_consumables = false
always_drop_consumables = false
base_drop_chance = 0.0
item_drop_chance = 0.0
armor = 0
armor_increase_each_wave = 0.0
generate_blood = false
"""
with io.open(os.path.join(PET_DIR, "orb_stats.tres"), "w", encoding="utf-8", newline="\n") as f:
    f.write(stats)

# ---------------------------------------------------------------- scenes
def scene(name: str, is_attract: bool) -> str:
    return """[gd_scene load_steps=3 format=2]

[ext_resource path="res://entities/units/pet/pet.tscn" type="PackedScene" id=1]
[ext_resource path="%(script)s" type="Script" id=2]

[node name="%(name)s" instance=ExtResource( 1 )]
script = ExtResource( 2 )
stats = ExtResource( 1 )
is_attract = %(flag)s
orbit_side = %(side)d
orbit_radius = 240.0
""" % {
        "name": name,
        "script": ORB_SCRIPT,
        "flag": "true" if is_attract else "false",
        "side": 1 if is_attract else -1,
    }


for fname, is_attract in (("orb_cang.tscn", True), ("orb_he.tscn", False)):
    with io.open(os.path.join(PET_DIR, fname), "w", encoding="utf-8", newline="\n") as f:
        f.write(scene(fname.replace(".tscn", ""), is_attract))

# ---------------------------------------------------------------- 物品 json
def patch_item(fname: str, pet_scene: str, key: str) -> None:
    p = os.path.join(RES, fname)
    d = json.load(io.open(p, encoding="utf-8"))
    d["datas"] = [{
        "base_resource_path": "res://items/all/pet/pet_effect.tres",
        "changed_key_values": {
            "key": "",
            "text_key": key,
            "custom_key": "",
            "value": 1,
            "storage_method": 0,
            "effect_sign": 0,
            "scene_RESOURCE": {
                "base_resource_path": pet_scene,
                "changed_key_values": {},
            },
            "stats_RESOURCE": {
                "base_resource_path": ORB_STATS,
                "changed_key_values": {},
            },
        },
    }]
    io.open(p, "w", encoding="utf-8", newline="\n").write(
        json.dumps(d, ensure_ascii=False, indent=2) + "\n")
    print("已改为 PetEffect:", fname, "->", pet_scene)


patch_item("1791000301.json", PET_SCENE + "orb_cang.tscn", "BROMEME_EFF_CANG")
patch_item("1791000302.json", PET_SCENE + "orb_he.tscn", "BROMEME_EFF_HE")

print()
for f in sorted(os.listdir(PET_DIR)):
    print("  ", f, os.path.getsize(os.path.join(PET_DIR, f)))

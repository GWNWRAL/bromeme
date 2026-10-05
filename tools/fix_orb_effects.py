# -*- coding: utf-8 -*-
"""物品 json 改用"静态效果资源"（每个状态一个 .tres，脚本写在资源里）。

这样就不再需要 `_build_effect` 里的 set_script —— 而给已实例化 Resource 调
set_script() 正是原生崩溃（0xc0000005 @ 0x1f8d28a）的嫌疑点。
"""
import io, json, os

RES = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\resources"
EFF = "res://mods-unpacked/General-bromeme/brolab_compat/contents/effects/"
PETS = "res://mods-unpacked/General-bromeme/content/pets/orb/"


def patch(fname: str, base_eff: str, pet_scene: str, key: str) -> None:
    p = os.path.join(RES, fname)
    d = json.load(io.open(p, encoding="utf-8"))
    d["datas"] = [{
        "base_resource_path": base_eff,
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
        },
    }]
    io.open(p, "w", encoding="utf-8", newline="\n").write(
        json.dumps(d, ensure_ascii=False, indent=2) + "\n")
    print("已更新", fname)
    print("   ", json.dumps(d["datas"][0], ensure_ascii=False))


patch("1791000301.json", EFF + "orb_cang_effect.tres", PETS + "orb_cang.tscn", "BROMEME_EFF_CANG")
patch("1791000302.json", EFF + "orb_he_effect.tres", PETS + "orb_he.tscn", "BROMEME_EFF_HE")

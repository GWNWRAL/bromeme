# -*- coding: utf-8 -*-
"""写 manifest.json：版本号 2.42.9 + 顶部追加描述。"""
import io, json

P = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\manifest.json"
d = json.load(io.open(P, encoding="utf-8"))

HEAD = (
    "2.42.9: the missing-nin (panren) phase-2 dash chain got a wind-up and a range gate. It now stands still and "
    "flashes for 0.5s (the same wind-up the spike-then-dash action already used) before the chain, and the whole "
    "chain only fires when the boss is further than DASH_CHAIN_MIN_DIST = 300 from the target - if the player is "
    "closer the action is dropped and the boss just finishes it with the normal cooldown instead of dashing. The "
    "distance is checked twice: when the action is picked and again when the wind-up ends, so a player who steps "
    "inside 300 during the wind-up is not charged. The wind-up now carries what it should do afterwards "
    "(dash count / finish with shurikens / minimum distance), so the spike action keeps its old single-dash "
    "wind-up while the phase-2 action reuses the same code. The chain is still two dashes (DASH_CHAIN_COUNT = 2) "
    "- tell me if you want three. some characters and items created by Brolab. ")

d["description"] = HEAD + d["description"]
d["version_number"] = "2.42.9"

io.open(P, "w", encoding="utf-8", newline="\n").write(
    json.dumps(d, ensure_ascii=False, indent=1))

check = json.load(io.open(P, encoding="utf-8"))
print("version_number =", check["version_number"])
print("description 长度 =", len(check["description"]))

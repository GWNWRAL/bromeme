# -*- coding: utf-8 -*-
"""把专属/混沌道具、反抗孙笑川、挑战者的中文 text_key 换成翻译 key（多语言在 mod_main 里注册）。"""
import io, json, glob, os

RES = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\resources"
MAP = {
    "每购买一个道具，meme值 +1": "BROMEME_EFF_MEME_CORE",
    "随机交换你的所有主属性，然后每项 +5": "BROMEME_EFF_CHAOS",
    "随机获得两个 meme 道具（组合 / 改造属性）": "BROMEME_EFF_RANDOM",
    "以 100% 的价格回收你的所有道具": "BROMEME_EFF_SELL",
    "每条主属性独立随机 ×0~3 倍（可能清零，也可能暴涨）": "BROMEME_EFF_ENTROPY",
    "50% 金币翻倍，50% 金币全部打水漂": "BROMEME_EFF_GAMBLER",
    "随机把背包里的一件道具变成全游戏里的另一件道具": "BROMEME_EFF_QUANTUM",
    "随机两条主属性清零，其余每条 +5~+25": "BROMEME_EFF_SACRIFICE",
    "下一波敌袭一开始必定触发孙笑川入侵": "BROMEME_EFF_FKCS",
    "每击杀一个精英或首领：道具价格 -2%、生命值 +5": "BROMEME_EFF_CHALLENGER",
}

changed = 0
for p in sorted(glob.glob(os.path.join(RES, "*.json"))):
    d = json.load(io.open(p, encoding="utf-8"))
    hit = False
    for x in d.get("datas", []):
        c = x.get("changed_key_values", {})
        tk = str(c.get("text_key", ""))
        if tk in MAP:
            c["text_key"] = MAP[tk]
            hit = True
    if hit:
        io.open(p, "w", encoding="utf-8", newline="\n").write(json.dumps(d, ensure_ascii=False, indent=2) + "\n")
        changed += 1
        print("改好:", os.path.basename(p), "|", d.get("name"))
print("共改", changed, "个 JSON")

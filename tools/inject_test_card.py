# -*- coding: utf-8 -*-
"""受控实验：往 run_v3_1.json 注入一件"卡道具"，看读档后是否还在。

- 先备份存档到 D:\\DSH\\_aitato_work\\save_backup_<时间>\\
- 注入的 my_id 用 mod 真实生成的格式：item_bromeme_pick_mix_item_bromeme_yan_56
  （mix 卡 = 组合卡，tag 是 "a.my_id+b.my_id"）
- 只要它在读档后还在，就说明"注册进 ItemService.items"这条路修好了，
  用户遇到的"消失"就是别的原因（例如道具根本没进存档）。
"""
import io, json, os, shutil, time

SAVE_DIR = os.path.join(os.environ["APPDATA"], "Brotato", "76561198978820132")
RUN = os.path.join(SAVE_DIR, "run_v3_1.json")
BAK = os.path.join(r"D:\DSH\_aitato_work", "save_backup_" + time.strftime("%Y%m%d_%H%M%S"))

CARD_ID = "item_bromeme_pick_mix_item_bromeme_yan_56"

os.makedirs(BAK, exist_ok=True)
for f in ["run_v3_1.json", "save_v3_1.json"]:
    src = os.path.join(SAVE_DIR, f)
    if os.path.exists(src):
        shutil.copy2(src, os.path.join(BAK, f))
print("已备份到", BAK)

j = json.load(io.open(RUN, encoding="utf-8"))
st = j["current_run_state"]
items = st["players_data"][0]["items"]

# 已经有就不重复注入
if any(isinstance(x, dict) and x.get("my_id") == CARD_ID for x in items):
    print("存档里已经有", CARD_ID)
else:
    # 用一件现有道具当模板，换成卡道具的字段
    tpl = [x for x in items if isinstance(x, dict) and str(x.get("my_id", "")).startswith("item_bromeme_")][0]
    card = json.loads(json.dumps(tpl))
    card["my_id"] = CARD_ID
    card["name"] = "测试卡(组合)"
    card["tier"] = "2"
    card["max_nb"] = "0"
    card["is_lockable"] = False
    card["tracking_text"] = ""
    # 只留一条简单属性效果，方便辨认
    card["effects"] = [{
        "base_value": 0, "curse_factor": 0, "custom_args": [],
        "custom_key": "", "effect_id": "effect", "effect_sign": 3,
        "key": "stat_armor", "storage_method": 0, "text_key": "", "value": "3",
    }]
    items.append(card)
    io.open(RUN, "w", encoding="utf-8", newline="\n").write(
        json.dumps(j, ensure_ascii=False))
    print("已注入", CARD_ID, "当前道具数 =", len(items))

# 回读校验
chk = json.load(io.open(RUN, encoding="utf-8"))
got = [x.get("my_id") for x in chk["current_run_state"]["players_data"][0]["items"]
       if isinstance(x, dict)]
print("存档现在的道具:", got)

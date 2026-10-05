# -*- coding: utf-8 -*-
"""A/B 实验：注入两件卡道具，其中一件用用户真实丢过的那种 id。

- A: item_bromeme_pick_mix_item_bromeme_yan_56                     （简单 id，之前验证过能存活）
- B: item_bromeme_pick_bromeme_pick_job_stat_armor>stat_fantasy_holy （用户真实丢过的 id）

读档后看谁活下来：
  A 活 B 死 → id 形态（含 >）有问题
  都活     → 说明"读档"没问题，问题在用户那局的**写入时机**
  都死     → 连简单 id 也丢了 → 说明注册表在写入前就被清/重建了
"""
import io, json, os, shutil, time

SAVE_DIR = os.path.join(os.environ["APPDATA"], "Brotato", "76561198978820132")
RUN = os.path.join(SAVE_DIR, "run_v3_1.json")
BAK = os.path.join(r"D:\DSH\_aitato_work", "save_backup_ab_" + time.strftime("%Y%m%d_%H%M%S"))

IDS = [
    "item_bromeme_pick_mix_item_bromeme_yan_56",
    "item_bromeme_pick_bromeme_pick_job_stat_armor>stat_fantasy_holy",
]

os.makedirs(BAK, exist_ok=True)
shutil.copy2(RUN, os.path.join(BAK, "run_v3_1.json"))
print("已备份到", BAK)

j = json.load(io.open(RUN, encoding="utf-8"))
items = j["current_run_state"]["players_data"][0]["items"]
tpl = [x for x in items if isinstance(x, dict) and str(x.get("my_id", "")).startswith("item_")][0]

for cid in IDS:
    if any(isinstance(x, dict) and x.get("my_id") == cid for x in items):
        print("已存在，跳过:", cid)
        continue
    card = json.loads(json.dumps(tpl))
    card["my_id"] = cid
    card["name"] = "AB测试卡"
    card["tier"] = "2"
    card["max_nb"] = "0"
    card["is_lockable"] = False
    card["tracking_text"] = ""
    card["effects"] = [{
        "base_value": 0, "curse_factor": 0, "custom_args": [],
        "custom_key": "", "effect_id": "effect", "effect_sign": 3,
        "key": "stat_armor", "storage_method": 0, "text_key": "", "value": "3",
    }]
    items.append(card)
    print("已注入:", cid)

io.open(RUN, "w", encoding="utf-8", newline="\n").write(json.dumps(j, ensure_ascii=False))
chk = json.load(io.open(RUN, encoding="utf-8"))
print("存档道具:", [x.get("my_id") for x in chk["current_run_state"]["players_data"][0]["items"] if isinstance(x, dict)])

# -*- coding: utf-8 -*-
"""卡道具"退出重进后消失"排查记录 + 实验脚本。

## 已确认（受控实验）
1. 原版读档路径：`player_run_data.gd:177`
     ItemService.get_element_safe(ItemService.items, item.my_id)
   找不到同 my_id 的道具 → **静默丢弃**，不报错。这就是"消失"的机制。
2. 2.42.16 起，卡道具（item_bromeme_pick_*）会：
   - 生成**稳定唯一** id（同一张卡的重复件加 _2/_3 后缀）
   - 通过 ItemService.register_runtime_item() 注册进 ItemService.items
3. 受控实验（2026-09-30）：往 run_v3_1.json 注入
     item_bromeme_pick_mix_item_bromeme_yan_56
   启动游戏 → 读档后**仍然存在**（道具数 7），并且游戏自己重写存档后（23:47:39）
   它依然在 → **读写链路是通的**。

## 待确认
用户报告"退出游戏再重进后那些奖励道具还是会消失"。
当前存档里原本没有 item_bromeme_pick_*（只有 6 件道具，wave=1、还没进商店），
所以无法从存档判断"是没存进去，还是存了读不回来"。

## 下一步实验（第二轮，决定性）
1. 让游戏先加载一次含测试卡的存档（已做）
2. **正常退出游戏**（不是强杀；强杀可能不落盘）
3. 检查退出后的 run_v3_1.json 是否仍含测试卡
   - 含 → 说明"存"没问题；问题在用户那局的**选卡路径**（例如卡道具根本没 add_item）
   - 不含 → 说明"存"就丢了，要查 save_run_state / serialize 环节
4. 再启动一次，检查读档后是否仍在（验证 item_id_lookup 缓存那条路径）
"""
import io, json, os

SAVE = os.path.join(os.environ["APPDATA"], "Brotato", "76561198978820132", "run_v3_1.json")
CARD_ID = "item_bromeme_pick_mix_item_bromeme_yan_56"


def dump() -> None:
    st = json.load(io.open(SAVE, encoding="utf-8"))["current_run_state"]
    items = [x.get("my_id") for x in st["players_data"][0]["items"] if isinstance(x, dict)]
    print("wave=%s 道具数=%d" % (st.get("current_wave"), len(items)))
    for m in items:
        mark = "   <== 测试卡" if m == CARD_ID else ""
        print("   ", m, mark)
    print("测试卡还在吗:", CARD_ID in items)


if __name__ == "__main__":
    dump()

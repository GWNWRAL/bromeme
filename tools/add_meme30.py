# -*- coding: utf-8 -*-
"""给 随机meme / meme核心 各加一条 +30 meme值 效果。

用法与 mod 里其它"+meme值"道具（嘉豪/奶蛙/炮塔）一致：
  base_resource_path = res://items/all/cake/cake_effect_1.tres
  changed_key_values = { key: "stat_meme", value: 30, text_key: "", custom_key: "",
                         storage_method: 0, effect_sign: 0 }
text_key 为空时 effect.gd:117 用 key.to_upper() = "STAT_MEME" 查翻译，
而 mod 的 _register_meme_stat() 里已经注册了 _name_keys["STAT_MEME"]，
Text.keys_needing_operator 也登记过 → 会显示成 "+30 meme值"。
"""
import io, json, os, shutil

RES = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\resources"
BAK = r"D:\DSH\_aitato_work\backup_before_meme30"
TARGETS = {
    "1791000101.json": "item_bromeme_meme_core",
    "1791000103.json": "item_bromeme_meme_random",
}
MEME_EFFECT = {
    "base_resource_path": "res://items/all/cake/cake_effect_1.tres",
    "changed_key_values": {
        "key": "stat_meme",
        "value": 30,
        "text_key": "",
        "custom_key": "",
        "storage_method": 0,
        "effect_sign": 0,
    },
}

os.makedirs(BAK, exist_ok=True)

for fname, want_id in TARGETS.items():
    p = os.path.join(RES, fname)
    shutil.copy2(p, os.path.join(BAK, fname))
    d = json.load(io.open(p, encoding="utf-8"))
    assert d.get("my_id") == want_id, (fname, d.get("my_id"), want_id)

    datas = d.get("datas", [])
    # 幂等：已经有 stat_meme 效果就不再重复加
    already = False
    for ds in datas:
        if ds.get("changed_key_values", {}).get("key") == "stat_meme":
            already = True
            break
    if not already:
        datas.append(json.loads(json.dumps(MEME_EFFECT)))
        d["datas"] = datas

    io.open(p, "w", encoding="utf-8", newline="\n").write(
        json.dumps(d, ensure_ascii=False, indent=2) + "\n")

    # 回读校验
    chk = json.load(io.open(p, encoding="utf-8"))
    keys = [ds.get("changed_key_values", {}).get("key") for ds in chk["datas"]]
    vals = [ds.get("changed_key_values", {}).get("value") for ds in chk["datas"]]
    print("%s (%s): 效果数=%d keys=%s values=%s" % (fname, want_id, len(chk["datas"]), keys, vals))

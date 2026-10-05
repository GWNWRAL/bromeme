# -*- coding: utf-8 -*-
"""
① 牢大：删「元素伤害+8%」(mage_effect_2 value=8) + 加「每5近战伤害→+1远程伤害」
② 挑战者：body 贴图回滚成原版全能者（从 2.34.0 备份的具体路径取）
③ 张雪峰：+15 生命 → +20（靠读基准 .tres 的 key/value 自动定位）
④ 达芬奇：删除护甲相关效果（靠基准 .tres 的 stats_modified / stat_displayed 自动定位）
"""
import io, json, glob, os, re, shutil

MOD = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme"
RES = os.path.join(MOD, "resources")
VANILLA = r"D:\DSH\Brotato_unpacked_1.1.15.4"
CAKE = "res://items/all/cake/cake_effect_1.tres"
POWER = "res://items/all/power_generator/power_generator_effect_1.tres"
report = []


def load(p):
    return json.load(io.open(p, encoding="utf-8"))


def save(p, d):
    io.open(p, "w", encoding="utf-8", newline="\n").write(json.dumps(d, ensure_ascii=False, indent=2) + "\n")


def find(name):
    for p in glob.glob(os.path.join(RES, "*.json")):
        d = load(p)
        if str(d.get("name", "")) == name:
            return p, d
    return None, None


def base_fields(res_path):
    """读基准 .tres（原版解包目录），取出 key / value / stats_modified / stat_displayed。"""
    rel = res_path.replace("res://", "").replace("/", os.sep)
    fp = os.path.join(VANILLA, rel)
    if not os.path.isfile(fp):
        return None
    t = io.open(fp, encoding="utf-8", errors="replace").read()
    out = {}
    for field in ("key", "value", "stat_displayed", "storage_method"):
        m = re.search(r'^%s = "?([^"\n]+)"?$' % field, t, re.M)
        if m:
            out[field] = m.group(1).strip()
    m = re.search(r'^stats_modified = \[([^\]]*)\]', t, re.M)
    if m:
        out["stats_modified"] = [s.strip().strip('"') for s in m.group(1).split(",") if s.strip()]
    return out


# ---------------- ① 牢大 ----------------
p, d = find("牢大")
if d is not None:
    kept, removed = [], []
    for x in d["datas"]:
        c = x.get("changed_key_values", {})
        if "mage_effect_2" in x["base_resource_path"] and c.get("value") == 8:
            bf = base_fields(x["base_resource_path"]) or {}
            removed.append((x["base_resource_path"].split("/")[-1], c.get("value"), bf.get("key")))
            continue
        kept.append(x)
    kept.append({"base_resource_path": POWER,
                 "changed_key_values": {"key": "stat_ranged_damage", "nb_stat_scaled": 5,
                                        "stat_scaled": "stat_melee_damage"}})
    d["datas"] = kept
    save(p, d)
    report.append("牢大: 删 %s；加「每5近战伤害→+1远程伤害」→ %d 条" % (removed, len(kept)))

# ---------------- ② 挑战者 body 回滚 ----------------
src = r"D:\DSH\_mod_backups\Bromeme-2.34.0-preRelease\resources\edited\1790000001.body.png"
dst = os.path.join(RES, "edited", "1790000001.body.png")
if os.path.isfile(src):
    shutil.copyfile(src, dst)
    report.append("挑战者: body 贴图已回滚为原版全能者（%d 字节）" % os.path.getsize(dst))
else:
    report.append("!! 挑战者: 备份贴图不存在 %s" % src)

# ---------------- ③ 张雪峰 ----------------
p, d = find("张雪峰")
if d is not None:
    hit = 0
    for x in d["datas"]:
        c = x.get("changed_key_values", {})
        bf = base_fields(x["base_resource_path"])
        if bf is None:
            continue
        key = c.get("key", bf.get("key"))
        val = c.get("value", bf.get("value"))
        if key == "stat_max_hp" and str(val) == "15":
            c["value"] = 20
            hit += 1
            report.append("张雪峰: 命中 %s（基准 key=%s value=%s）→ 20" % (
                x["base_resource_path"].split("/")[-1], bf.get("key"), bf.get("value")))
    save(p, d)
    if not hit:
        report.append("!! 张雪峰: 自动定位没命中，基准信息 = %s" % [
            (x["base_resource_path"].split("/")[-1], x.get("changed_key_values", {}), base_fields(x["base_resource_path"]))
            for x in d["datas"]])

# ---------------- ④ 达芬奇机器人 ----------------
p, d = find("达芬奇机器人")
if d is not None:
    kept, removed = [], []
    for x in d["datas"]:
        c = x.get("changed_key_values", {})
        bf = base_fields(x["base_resource_path"]) or {}
        blob = json.dumps(c, ensure_ascii=False) + json.dumps(bf, ensure_ascii=False)
        if "stat_armor" in blob or "armor" in str(bf.get("stat_displayed", "")):
            removed.append((x["base_resource_path"].split("/")[-1], c.get("value"), bf.get("stat_displayed")))
            continue
        kept.append(x)
    if removed:
        d["datas"] = kept
        save(p, d)
        report.append("达芬奇: 删除护甲效果 %s → %d 条" % (removed, len(kept)))
    else:
        report.append("!! 达芬奇: 没定位到护甲条目，基准一览 = %s" % [
            (x["base_resource_path"].split("/")[-1], base_fields(x["base_resource_path"])) for x in d["datas"]])

print("\n".join(report))

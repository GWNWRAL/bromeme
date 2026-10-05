# -*- coding: utf-8 -*-
"""
把所有模组的最终压缩包收集到一个交付目录里。

用法: python collect_final.py
产物: D:\\DSH\\FinalMods\\<zip> + README.txt
"""
import os, json, shutil, zipfile, hashlib, datetime

DEST = r"D:\DSH\FinalMods"

# (源压缩包, 交付文件名, 状态, 说明)
ITEMS = [
    (r"D:\DSH\_aitato_work\dist\Toys&Balls-1.0.11.zip", "Toys&Balls-1.0.11.zip",
     "已启用", "玩具和球类武器包。1.0.11 修复图鉴敌人/宠物页与角色面板里名字显示成 key 的问题。"),
    (r"D:\DSH\_aitato_work\dist\Aitato-EnemyScale.zip", "Aitato-EnemyScale.zip",
     "已启用", "敌人 HP/伤害/速度按波数复利增长(默认 5%/5%/0%)，可在游戏内 Mod Options 调节。"),
    (r"D:\DSH\_aitato_work\disabled\Aitato.zip", "Aitato.zip",
     "已停用", "大肥鱼(deepseek)角色本体 0.0.2。按要求暂不加入游戏。"),
    (r"D:\DSH\_aitato_work\dist\BounceNullFix-1.0.2.zip", "BounceNullFix-1.0.2.zip",
     "已启用", "通用崩溃修复（原 Aitato-BounceNullFix，已改中性名）：弹射物撞到没有 spawner 的实体、抛射物未入树时 _hitbox 为 null 等一族 0xC0000005。"),
    (r"D:\DSH\Bromeme\Bromeme.zip", "Bromeme-0.2.5.zip",
     "已启用", "BroLab 里做出来的一批角色与物品（20 角色 + 87 物品）。炮塔：+25 生命/+10 护甲/+10 再生、速度上限 -100%、移动时护甲翻倍且禁止回血、按下移动 0.25s 无敌、+30 击退、每 1 秒击退附近敌人（原版灯笼效果）、100% 立即吸收材料、攻速/伤害的修改 +50%。"),
]


def md5(path):
    h = hashlib.md5()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def manifest_of(zip_path):
    with zipfile.ZipFile(zip_path) as z:
        for n in z.namelist():
            if n.endswith("/manifest.json") and n.count("/") == 2:
                return json.loads(z.read(n).decode("utf-8")), n
    return None, None


def main():
    os.makedirs(DEST, exist_ok=True)
    rows = []

    for src, out_name, status, note in ITEMS:
        if not os.path.exists(src):
            print("!! 缺少源文件:", src)
            continue
        dst = os.path.join(DEST, out_name)
        shutil.copy2(src, dst)

        man, mpath = manifest_of(dst)
        with zipfile.ZipFile(dst) as z:
            entries = len(z.namelist())
            bad = z.testzip()
            backslash = sum(1 for n in z.namelist() if "\\" in n)
            tops = sorted({n.split("/")[0] for n in z.namelist()})

        rows.append({
            "file": out_name,
            "mod": "%s-%s" % (man["namespace"], man["name"]) if man else "?",
            "version": man["version_number"] if man else "?",
            "status": status,
            "note": note,
            "bytes": os.path.getsize(dst),
            "md5": md5(dst),
            "entries": entries,
            "ziptest": "ok" if bad is None else bad,
            "backslash": backslash,
            "tops": ",".join(tops),
        })

    now = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    lines = [
        "Brotato 模组交付包",
        "生成时间 : %s" % now,
        "生成位置 : %s" % DEST,
        "",
        "安装方法 : 把需要的 zip 直接丢进游戏的模组目录(或创意工坊条目目录)后重启游戏, 不要解压。",
        "",
        "=" * 108,
        "%-28s %-26s %-8s %-8s %s" % ("文件", "模组", "版本", "状态", "说明"),
        "-" * 108,
    ]
    for r in rows:
        lines.append("%-28s %-26s %-8s %-8s %s" % (r["file"], r["mod"], r["version"], r["status"], r["note"]))
    lines += ["", "=" * 108, "校验与结构自检", "-" * 108]
    for r in rows:
        lines.append("%s" % r["file"])
        lines.append("    大小 %d 字节 | md5 %s" % (r["bytes"], r["md5"]))
        lines.append("    条目 %d | ziptest %s | 反斜杠路径 %d | 顶层 %s"
                     % (r["entries"], r["ziptest"], r["backslash"], r["tops"]))
    lines.append("")
    open(os.path.join(DEST, "README.txt"), "w", encoding="utf-8").write("\n".join(lines))

    for r in rows:
        print("%-28s %-26s v%-7s %-6s %8.2f MB  %s"
              % (r["file"], r["mod"], r["version"], r["status"], r["bytes"] / 1048576.0, r["md5"]))
    print("\n交付目录 :", DEST)
    print("README   :", os.path.join(DEST, "README.txt"))


if __name__ == "__main__":
    main()

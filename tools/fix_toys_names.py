# -*- coding: utf-8 -*-
"""
Toys&Balls 1.0.6 fix #1: every weapon/item/pet `name` is literal Chinese text.

Vanilla and other mods always store a translation KEY there; the UI renders it
with tr(item.name) / tr(name) (item_parent_data.gd:184, weapon_data.gd:80), so
literal text cannot be translated and shows Chinese in every language.

This script:
  * finds every .tres whose `name` is not key-shaped
  * maps each distinct Chinese name to a key (TOYS_BALLS_*)
  * rewrites the `name` field to the key
  * appends the key + 6-language translations to translations/trans.csv
"""
import csv, io, os, re, glob, sys, collections

MOD = r"D:\DSH\Toys_Balls_build_v4\mods-unpacked\General-Toys_Balls"
CSV = os.path.join(MOD, "translations", "trans.csv")
APPLY = "--apply" in sys.argv

KEY_RE = re.compile(r"^[A-Za-z][A-Za-z0-9_]*$")
NAME_RE = re.compile(r'^name\s*=\s*"([^"]*)"', re.M)

# Chinese name -> (key, en, ja, ko)
MAP = {
    "篮球":       ("TOYS_BALLS_WEAPON_BASKETBALL",    "Basketball",          "バスケットボール", "농구공"),
    "保龄球":     ("TOYS_BALLS_WEAPON_BOWLING",       "Bowling Ball",        "ボウリングの球",   "볼링공"),
    "足球":       ("TOYS_BALLS_WEAPON_FOOTBALL",      "Football",            "サッカーボール",   "축구공"),
    "冰球":       ("TOYS_BALLS_WEAPON_ICE_BALL",      "Ice Ball",            "アイスボール",     "아이스 볼"),
    "玻璃弹珠":   ("TOYS_BALLS_WEAPON_GLASS_MARBLE",  "Glass Marble",        "ビー玉",           "유리 구슬"),
    "回旋镖":     ("TOYS_BALLS_WEAPON_BOOMERANG",     "Boomerang",           "ブーメラン",       "부메랑"),
    "彩蛋":       ("TOYS_BALLS_WEAPON_EASTER_EGG",    "Easter Egg",          "イースターエッグ", "부활절 달걀"),
    "棒球棍":     ("TOYS_BALLS_WEAPON_BASEBALL_BAT",  "Baseball Bat",        "野球バット",       "야구 방망이"),
    "网球拍":     ("TOYS_BALLS_WEAPON_TENNIS_RACKET", "Tennis Racket",       "テニスラケット",   "테니스 라켓"),
    "玩具锤":     ("TOYS_BALLS_WEAPON_TOY_HAMMER",    "Toy Hammer",          "おもちゃのハンマー", "장난감 망치"),
    "水枪":       ("TOYS_BALLS_WEAPON_WATER_GUN",     "Water Gun",           "水鉄砲",           "물총"),
    "乐高盒":     ("TOYS_BALLS_WEAPON_LEGO_BOX",      "Lego Box",            "レゴの箱",         "레고 상자"),
    "光线枪":     ("TOYS_BALLS_WEAPON_RAY_GUN",       "Ray Gun",             "光線銃",           "광선총"),
    "通灵板":     ("TOYS_BALLS_WEAPON_OUIJA_BOARD",   "Ouija Board",         "ウィジャ板",       "위자 보드"),
    "魁地奇球":   ("TOYS_BALLS_WEAPON_QUIDDITCH_BALL","Quidditch Ball",      "クィディッチの球", "퀴디치 공"),
    "玩具总动员": ("TOYS_BALLS_WEAPON_TOY_STORY",     "Toy Story",           "トイ・ストーリー", "토이 스토리"),
    "胡迪":       ("TOYS_BALLS_ITEM_WOODY",           "Woody",               "ウッディ",         "우디"),
    "巴斯光年":   ("TOYS_BALLS_ITEM_BUZZ",            "Buzz Lightyear",      "バズ・ライトイヤー", "버즈 라이트이어"),
}

# ---- 1. collect ------------------------------------------------------------
targets = []          # (abspath, rel, old_name, key)
for p in glob.glob(os.path.join(MOD, "content", "**", "*.tres"), recursive=True):
    rel = os.path.relpath(p, MOD).replace("\\", "/")
    txt = open(p, encoding="utf-8", errors="replace").read()
    m = NAME_RE.search(txt)
    if not m:
        continue
    nm = m.group(1)
    if KEY_RE.match(nm):
        continue
    if nm not in MAP:
        print("!! unmapped name %r in %s" % (nm, rel))
        continue
    targets.append((p, rel, nm, MAP[nm][0]))

print("=" * 74)
print("1) name -> key  (%d files)" % len(targets))
print("=" * 74)
by_key = collections.Counter(k for _, _, _, k in targets)
for k, n in sorted(by_key.items()):
    print("   %-38s %d file(s)" % (k, n))

# ---- 2. csv ---------------------------------------------------------------
raw = open(CSV, encoding="utf-8").read()
rows = list(csv.reader(io.StringIO(raw)))
header = rows[0]
existing = {r[0] for r in rows[1:]}
gi = header.index("zh_Hans_CN")
new_rows = []
for cn, (key, en, ja, ko) in MAP.items():
    if key in existing:
        continue
    row = [key] + [""] * (len(header) - 1)
    row[gi] = cn
    row[header.index("zh_CN")] = cn
    row[header.index("zh_Hant_TW")] = cn
    row[header.index("en")] = en
    row[header.index("ja")] = ja
    row[header.index("ko")] = ko
    new_rows.append(row)

print()
print("=" * 74)
print("2) translation rows to append (%d)" % len(new_rows))
print("=" * 74)
for r in new_rows:
    print("   %s" % r)

# ---- 3. apply -------------------------------------------------------------
if APPLY:
    for p, rel, nm, key in targets:
        txt = open(p, encoding="utf-8", errors="replace").read()
        txt = re.sub(r'^name\s*=\s*"[^"]*"', 'name = "%s"' % key,
                     txt, count=1, flags=re.M)
        open(p, "w", encoding="utf-8", newline="").write(txt)
    rows.extend(new_rows)
    buf = io.StringIO()
    csv.writer(buf, lineterminator="\n").writerows(rows)
    open(CSV, "w", encoding="utf-8", newline="").write(buf.getvalue())
    print()
    print("APPLIED: %d files rewritten, csv rows now %d" % (len(targets), len(rows)))
else:
    print()
    print("DRY RUN - pass --apply")

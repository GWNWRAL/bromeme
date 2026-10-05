# -*- coding: utf-8 -*-
"""Bundle BroLab's custom effect scripts/resources so bromeme is standalone.

BroLab owns 2 effect types used by bromeme content:
  * brolab_effect_midas_hand          (item 天元鼎)
  * brolab_effect_receive_item_at_wave (character 丁真)
plus the runtime hook in extensions/main.gd and the effect-key registration in
extensions/singletons/player_run_data.gd.

We copy them into mods-unpacked/General-bromeme/brolab_compat/ and rewrite the
res:// paths in the .tres files so the mod no longer needs BroLab installed.
"""
import os
import zipfile

Z = r"D:\Apps\steam\steamapps\workshop\content\1942280\3145676266\Brolab.zip"
SRC = "mods-unpacked/QianMo-BroLab/"
DST = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\brolab_compat"

EFFECT_SCRIPTS = [
    "convert_stats_at_wave.gd",
    "effect_midas_hand.gd",
    "receive_items_at_wave.gd",
    "receive_stat_at_wave.gd",
    "stats_end_of_wave_after_wave.gd",
]
VIRTUAL_RESOURCES = [
    "contents/characters/1/brolab_virtual_character_data.tres",
    "contents/characters/1/brolab_virtual_character_effect_1.tres",
    "contents/characters/1/brolab_virtual_character_effect_2.tres",
    "contents/characters/1/brolab_virtual_character_effect_3.tres",
    "contents/characters/1/brolab_virtual_character_effect_4.tres",
    "contents/characters/1/brolab_virtual_character_effect_5.tres",
    "contents/characters/1/brolab_virtual_character_effect_6.tres",
]
EXTENSIONS = [
    "extensions/main.gd",
    "extensions/singletons/player_run_data.gd",
]

OLD_PREFIX = "res://mods-unpacked/QianMo-BroLab/"
NEW_PREFIX = "res://mods-unpacked/General-bromeme/brolab_compat/"


def write(rel, text):
    path = os.path.join(DST, rel.replace("/", os.sep))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(text)
    return path


def main():
    if os.path.isdir(DST):
        import shutil
        shutil.rmtree(DST)

    count = 0
    with zipfile.ZipFile(Z) as z:
        names = set(z.namelist())
        for s in EFFECT_SCRIPTS:
            src = SRC + "contents/effects/" + s
            text = z.read(src).decode("utf-8")
            assert OLD_PREFIX not in text, src
            write("contents/effects/" + s, text)
            count += 1
        for r in VIRTUAL_RESOURCES:
            src = SRC + r
            text = z.read(src).decode("utf-8")
            text = text.replace(OLD_PREFIX, NEW_PREFIX)
            write(r, text)
            count += 1
        for e in EXTENSIONS:
            src = SRC + e
            text = z.read(src).decode("utf-8")
            assert OLD_PREFIX not in text, src
            if e.endswith("main.gd"):
                # BroLab's own main.gd extension may be installed first and become
                # our parent class; GDScript refuses to redeclare a member that
                # already exists in a parent class, so namespace our copy's vars.
                text = text.replace("brolab_midas_timers", "bromeme_midas_timers")
            write(e, text)
            count += 1
        # sanity: everything referenced by our .tres exists in the bundle
        for r in VIRTUAL_RESOURCES:
            for line in z.read(SRC + r).decode("utf-8").splitlines():
                if line.startswith("[ext_resource"):
                    p = line.split('path="')[1].split('"')[0]
                    if p.startswith(OLD_PREFIX):
                        rel = p[len(OLD_PREFIX):]
                        assert SRC + rel in names, (r, rel)

    print("bundled files:", count)
    print("target:", DST)


if __name__ == "__main__":
    main()

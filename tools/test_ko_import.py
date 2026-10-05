# -*- coding: utf-8 -*-
"""
Is the Korean loss caused by the csv_translation IMPORTER, or by my staging?

Minimal case: a tiny csv with an ASCII column and a Korean column, imported by
Godot 3.6.2's csv_translation. If the Korean column comes out empty in the
generated .translation, the importer cannot carry those characters and the
compiled-file route is unusable for Korean.
"""
import os, shutil, subprocess

STAGE = r"D:\DSH\_kotest"
GODOT = r"D:\Apps\Gobot\Godot_v3.6.2-stable_win64.exe\Godot_v3.6.2-stable_win64.exe"

if os.path.exists(STAGE):
    shutil.rmtree(STAGE)
os.makedirs(os.path.join(STAGE, "translations"))

open(os.path.join(STAGE, "project.godot"), "w", encoding="utf-8").write(
    'config_version=4\n\n[application]\n\nconfig/name="kotest"\n')

csv = "key,en,ko\nHELLO,Hello,안녕하세요\nWORLD,World,세계\nMIXED,Value {0}% text,값 {0}% 텍스트\n"
open(os.path.join(STAGE, "translations", "t.csv"), "w", encoding="utf-8", newline="").write(csv)

print("source csv bytes:")
print(open(os.path.join(STAGE, "translations", "t.csv"), "rb").read())

p = subprocess.run([GODOT, "--path", STAGE, "--editor", "--quit"],
                   capture_output=True, text=True, timeout=600)
print("godot exit:", p.returncode)
print("generated:", sorted(os.listdir(os.path.join(STAGE, "translations"))))

with open(os.path.join(STAGE, "probe.gd"), "w", encoding="utf-8") as f:
    f.write('''extends SceneTree

func _init():
	for loc in ["en", "ko"]:
		var t = load("res://translations/t." + loc + ".translation")
		if t == null:
			print(loc, " LOAD FAILED")
			continue
		print(loc, " HELLO=", t.get_message("HELLO"), " WORLD=", t.get_message("WORLD"), " MIXED=", t.get_message("MIXED"))
	quit(0)
''')

p2 = subprocess.run([GODOT, "--path", STAGE, "-s", "probe.gd"],
                    capture_output=True, text=True, timeout=300)
print(p2.stdout)
print(p2.stderr[:400])

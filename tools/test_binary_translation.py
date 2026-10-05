# -*- coding: utf-8 -*-
"""
Can Godot itself produce a proper binary .translation (PHashTranslation) from an
in-memory Translation, and does Korean survive the round-trip?

If yes, this is the correct way to compile the mod's translations: build the
Translation object in GDScript (so no csv_translation character loss), then
generate + save the binary the game actually reads.
"""
import os, shutil, subprocess

STAGE = r"D:\DSH\_bintr"
GODOT = r"D:\Apps\Gobot\Godot_v3.6.2-stable_win64.exe\Godot_v3.6.2-stable_win64.exe"

if os.path.exists(STAGE):
    shutil.rmtree(STAGE)
os.makedirs(STAGE)
open(os.path.join(STAGE, "project.godot"), "w", encoding="utf-8").write(
    'config_version=4\n\n[application]\n\nconfig/name="bintr"\n')

open(os.path.join(STAGE, "gen.gd"), "w", encoding="utf-8").write('''extends SceneTree

func _init():
	var t := Translation.new()
	t.locale = "ko"
	t.add_message("HELLO", "안녕하세요")
	t.add_message("MIXED", "값 {0}% 텍스트")
	t.add_message("PLAIN", "plain ascii")

	var ph := PHashTranslation.new()
	ph.generate(t)
	print("ph class=", ph.get_class(), " locale=", ph.locale)
	print("ph HELLO=", ph.get_message("HELLO"))
	print("ph MIXED=", ph.get_message("MIXED"))

	var err = ResourceSaver.save("res://out.ko.translation", ph)
	print("save err=", err)

	# reload the saved binary and check
	var back = load("res://out.ko.translation")
	print("reloaded=", back)
	if back != null:
		print("  class=", back.get_class())
		print("  HELLO=", back.get_message("HELLO"))
		print("  MIXED=", back.get_message("MIXED"))
		print("  PLAIN=", back.get_message("PLAIN"))
	quit(0)
''')

p = subprocess.run([GODOT, "--path", STAGE, "-s", "gen.gd"],
                   capture_output=True, text=True, timeout=300)
print(p.stdout)
if p.stderr.strip():
    print("--- stderr ---")
    print(p.stderr[:800])

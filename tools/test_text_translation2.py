# -*- coding: utf-8 -*-
"""Verify a plain (no script) text .tres Translation loads and keeps Korean."""
import os, shutil, subprocess

STAGE = r"D:\DSH\_texttr2"
GODOT = r"D:\Apps\Gobot\Godot_v3.6.2-stable_win64.exe\Godot_v3.6.2-stable_win64.exe"

if os.path.exists(STAGE):
    shutil.rmtree(STAGE)
os.makedirs(os.path.join(STAGE, "translations"))
open(os.path.join(STAGE, "project.godot"), "w", encoding="utf-8").write(
    'config_version=4\n\n[application]\n\nconfig/name="texttr2"\n')

body = ('[gd_resource type="Translation" load_steps=1 format=2]\n\n'
        '[resource]\n'
        'resource_name = "ko"\n'
        'locale = "ko"\n'
        'messages = {\n'
        '\t"HELLO": "안녕하세요",\n'
        '\t"MIXED": "값 {0}% 텍스트",\n'
        '\t"PLAIN": "plain ascii"\n'
        '}\n')
open(os.path.join(STAGE, "translations", "t.ko.tres"), "w",
     encoding="utf-8", newline="").write(body)

open(os.path.join(STAGE, "probe.gd"), "w", encoding="utf-8").write('''extends SceneTree

func _init():
	var t = load("res://translations/t.ko.tres")
	print("loaded: ", t)
	if t == null:
		quit(1)
		return
	print("class    : ", t.get_class())
	print("is Translation: ", t is Translation)
	print("locale   : ", t.locale)
	print("HELLO    : ", t.get_message("HELLO"))
	print("MIXED    : ", t.get_message("MIXED"))
	print("PLAIN    : ", t.get_message("PLAIN"))
	TranslationServer.add_translation(t)
	TranslationServer.set_locale("ko")
	print("tr(HELLO): ", tr("HELLO"))
	print("tr(MIXED): ", tr("MIXED"))
	quit(0)
''')

p = subprocess.run([GODOT, "--path", STAGE, "-s", "probe.gd"],
                   capture_output=True, text=True, timeout=300)
print(p.stdout)
if p.stderr.strip():
    print("--- stderr ---")
    print(p.stderr[:500])

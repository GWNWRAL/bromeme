#!/usr/bin/env python3
"""
Does a Godot-4 type name in an ext_resource line (`type="Texture2D"`) break the
scene on Godot 3, or is the type= field ignored?

Builds a clean isolated project with a REAL importable texture (generated PNG)
and compares type="Texture" vs type="Texture2D".
"""
import os, shutil, struct, zlib

D = r"D:\DSH\_typetest"
if os.path.exists(D):
    shutil.rmtree(D)
os.makedirs(D)

open(os.path.join(D, "project.godot"), "w", encoding="utf-8").write(
    'config_version=4\n\n[application]\n\nconfig/name="typetest"\n')
open(os.path.join(D, "good.gd"), "w", encoding="utf-8").write("extends Node\n")


def png_bytes(w=4, h=4):
    def chunk(t, d):
        c = t + d
        return struct.pack(">I", len(d)) + c + struct.pack(">I", zlib.crc32(c) & 0xFFFFFFFF)
    raw = b""
    for y in range(h):
        raw += b"\x00" + bytes([255, 0, 0, 255]) * w
    return (b"\x89PNG\r\n\x1a\n"
            + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(raw))
            + chunk(b"IEND", b""))


open(os.path.join(D, "tex.png"), "wb").write(png_bytes())

# minimal .import so the engine maps tex.png -> a compiled texture
# (generated on first editor import; for the runtime test we let Godot 3 import it)
open(os.path.join(D, "tex.png.import"), "w", encoding="utf-8").write(
    '[remap]\n\nimporter="texture"\ntype="StreamTexture"\n'
    'path="res://.import/tex.png-00000000000000000000000000000000.stex"\n'
    'metadata={\n"vram_texture": false\n}\n\n'
    '[deps]\n\nsource_file="res://tex.png"\n'
    'dest_files=[ "res://.import/tex.png-00000000000000000000000000000000.stex" ]\n\n'
    '[params]\n\ncompress/mode=0\n')

for label, typ in [("scene_good", "Texture"), ("scene_g4", "Texture2D")]:
    open(os.path.join(D, label + ".tscn"), "w", encoding="utf-8").write(
        '[gd_scene load_steps=3 format=2]\n\n'
        '[ext_resource path="res://tex.png" type="%s" id=1]\n'
        '[ext_resource path="res://good.gd" type="Script" id=2]\n\n'
        '[node name="Root" type="Node2D"]\n'
        'script = ExtResource( 2 )\n\n'
        '[node name="S" type="Sprite" parent="."]\n'
        'texture = ExtResource( 1 )\n' % typ)

with open(os.path.join(D, "probe.gd"), "w", encoding="utf-8") as f:
    f.write('''extends SceneTree

func _init():
	for n in ["scene_good.tscn", "scene_g4.tscn"]:
		var ps = load("res://" + n)
		if ps == null:
			print(n, " -> LOAD FAILED")
			continue
		var node = ps.instance()
		if node == null:
			print(n, " -> INSTANCE FAILED")
			continue
		var s = node.get_node_or_null("S")
		print(n, " -> OK  sprite=", s != null, "  texture=", (s != null and s.texture != null))
	quit(0)
''')
print("written")

# -*- coding: utf-8 -*-
"""
Regenerate the compiled .translation files from trans.csv using Godot 3's
csv_translation importer.

Background: trans.csv is an IMPORT SOURCE, not a runtime asset. The mod ships
trans.<locale>.translation files (verified: trans.csv.import declares
importer="csv_translation" and dest_files=[trans.*.translation]). The game only
ever reads the compiled files, which is why editing the csv alone changed
nothing (and why a stale compiled copy kept showing old text / raw keys).

This stages the mod's translations into a throwaway Godot project, lets the
editor import the csv, and copies the produced .translation files back.
"""
import os, shutil, subprocess, sys, zipfile

MOD = r"D:\DSH\Toys_Balls_build_v4\mods-unpacked\General-Toys_Balls"
STAGE = r"D:\DSH\_transcompile"
GODOT = r"D:\Apps\Gobot\Godot_v3.6.2-stable_win64.exe\Godot_v3.6.2-stable_win64.exe"

if os.path.exists(STAGE):
    shutil.rmtree(STAGE)
os.makedirs(os.path.join(STAGE, "translations"))

open(os.path.join(STAGE, "project.godot"), "w", encoding="utf-8").write(
    'config_version=4\n\n[application]\n\nconfig/name="transcompile"\n')

shutil.copy2(os.path.join(MOD, "translations", "trans.csv"),
             os.path.join(STAGE, "translations", "trans.csv"))
shutil.copy2(os.path.join(MOD, "translations", "trans.csv.import"),
             os.path.join(STAGE, "translations", "trans.csv.import"))

before = {}
for f in os.listdir(os.path.join(MOD, "translations")):
    if f.endswith(".translation"):
        before[f] = os.path.getsize(os.path.join(MOD, "translations", f))
print("before:", before)

p = subprocess.run([GODOT, "--path", STAGE, "--editor", "--quit"],
                   capture_output=True, text=True, timeout=600)
print("godot exit:", p.returncode)

made = sorted(f for f in os.listdir(os.path.join(STAGE, "translations"))
              if f.endswith(".translation"))
print("generated:", made)
for f in made:
    print("   %-40s %d bytes" % (f, os.path.getsize(os.path.join(STAGE, "translations", f))))

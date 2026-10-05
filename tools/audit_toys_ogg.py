#!/usr/bin/env python3
"""
Verify the sounds Toys&Balls loads by reading raw bytes (File.open + get_buffer)
rather than through Godot's import system. Those bypass the importer entirely, so
each file must exist AND be a well-formed container, otherwise get_stream()
returns null and the sound is silently dropped.
"""
import os, re

MOD = r"D:\DSH\Toys_Balls_build_v4\mods-unpacked\General-Toys_Balls"
PREFIX = "res://mods-unpacked/General-Toys_Balls/"


def sniff(path):
    with open(path, "rb") as f:
        head = f.read(4)
    if head[:4] == b"OggS":
        return "OGG (valid)"
    if head[:4] == b"RIFF":
        return "WAV (valid)"
    if head[:3] == b"ID3" or head[:2] in (b"\xff\xfb", b"\xff\xf3"):
        return "MP3 (valid)"
    return "UNKNOWN %r" % head


refs = 0
problems = []
for dp, dn, fn in os.walk(MOD):
    for f in fn:
        if not f.endswith(".gd"):
            continue
        p = os.path.join(dp, f)
        txt = open(p, encoding="utf-8", errors="replace").read()
        for m in re.finditer(r'\.open\(\s*"(res://[^"]+)"', txt):
            refs += 1
            ref = m.group(1)
            if not ref.startswith(PREFIX):
                problems.append("%s: non-mod path %s" % (f, ref))
                continue
            rel = ref[len(PREFIX):]
            full = os.path.join(MOD, rel.replace("/", os.sep))
            if not os.path.exists(full):
                problems.append("%s: MISSING %s" % (f, rel))
                continue
            kind = sniff(full)
            size = os.path.getsize(full)
            status = "OK " if "(valid)" in kind else "BAD"
            print("  %s %-38s %-14s %8d bytes   <%s>" % (status, rel, kind, size, f))
            if "(valid)" not in kind:
                problems.append("%s: %s is not a valid container (%s)" % (f, rel, kind))
            if size == 0:
                problems.append("%s: %s is empty" % (f, rel))

print()
print("byte-loaded audio refs:", refs)
print("problems:", len(problems))
for x in problems:
    print("   -", x)
if not problems:
    print("   (none)")

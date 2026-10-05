# -*- coding: utf-8 -*-
"""
打包 Aitato 与 Aitato-BounceNullFix。

Aitato 的源码树现在与参照模组 Dbear-Capybara 严格同构:

    Aitato-ref/
      .import/                          <- 只含 .stex/.md5,放在包根
      mods-unpacked/Aitato-Aitato/      <- 模组本体(manifest/mod_main/content...)

之前 Aitato-final 是"模组内容直接在根、.import 在内容里"的扁平结构,与参照物
不一致(参照物的 .import 也不含 .gdignore)。
"""
import os, zipfile, hashlib, json, sys

AITATO_SRC = r"D:\DSH\_aitato_work\Aitato-ref"
FIX_SRC = r"D:\DSH\_fixmod\mods-unpacked\Aitato-BounceNullFix"
ENEMYSCALE_SRC = r"D:\DSH\_aitato_work\EnemyScale\mods-unpacked\Aitato-EnemyScale"
OUT = r"D:\DSH\_aitato_work\dist"

def add_dir(zf, root, prefix, root_level_dirs=()):
    """root_level_dirs 里的顶层目录按原名放在 zip 根(例如 .import)"""
    for dirpath, dirnames, filenames in os.walk(root):
        for fn in filenames:
            full = os.path.join(dirpath, fn)
            rel = os.path.relpath(full, root).replace("\\", "/")
            top = rel.split("/")[0]
            if top in root_level_dirs:
                arc = rel
            else:
                arc = prefix + rel
            zf.write(full, arc)

def build(src, out_path, prefix, root_level_dirs=()):
    if os.path.exists(out_path):
        os.remove(out_path)
    with zipfile.ZipFile(out_path, "w", zipfile.ZIP_DEFLATED) as zf:
        add_dir(zf, src, prefix, root_level_dirs)
    return out_path

def report(path):
    with zipfile.ZipFile(path) as zf:
        names = zf.namelist()
        bad = zf.testzip()
    md5 = hashlib.md5(open(path, "rb").read()).hexdigest()
    print("=" * 72)
    print(path)
    print("  entries=%d  size=%.1f KB  md5=%s  ziptest=%s"
          % (len(names), os.path.getsize(path) / 1024.0, md5, "ok" if bad is None else bad))
    for n in names:
        print("     ", n)
    for n in names:
        if n.endswith("manifest.json"):
            with zipfile.ZipFile(path) as zf:
                d = json.loads(zf.read(n).decode("utf-8"))
            print("  manifest: name=%s namespace=%s version=%s"
                  % (d.get("name"), d.get("namespace"), d.get("version_number")))

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    # Aitato-ref 已经含 mods-unpacked/ 与 .import/ 两个顶层目录,二者都原样保留
    # 在 zip 根,所以额外前缀为空。
    a = build(AITATO_SRC, os.path.join(OUT, "Aitato.zip"),
              "", root_level_dirs=(".import", "mods-unpacked"))
    b = build(FIX_SRC, os.path.join(OUT, "Aitato-BounceNullFix.zip"),
              "mods-unpacked/Aitato-BounceNullFix/")
    c = build(ENEMYSCALE_SRC, os.path.join(OUT, "Aitato-EnemyScale.zip"),
              "mods-unpacked/Aitato-EnemyScale/")
    report(a)
    report(b)
    report(c)

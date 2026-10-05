# -*- coding: utf-8 -*-
"""
统一备份工具：在对任何模组动手之前，先做一份可完整还原的快照。

用法:
    python backup_mod.py <源目录> <快照名>

会生成:
    D:\\DSH\\_mod_backups\\<快照名>\\files\\...      逐文件副本(可单独还原某个文件)
    D:\\DSH\\_mod_backups\\<快照名>\\snapshot.zip    整树压缩包(可整体还原)
    D:\\DSH\\_mod_backups\\<快照名>\\MANIFEST.txt    清单+校验和+时间
"""
import os, sys, shutil, zipfile, hashlib, datetime

BACKUP_ROOT = r"D:\DSH\_mod_backups"


def md5(path, chunk=1 << 20):
    h = hashlib.md5()
    with open(path, "rb") as f:
        while True:
            b = f.read(chunk)
            if not b:
                break
            h.update(b)
    return h.hexdigest()


def main(src, name):
    dst = os.path.join(BACKUP_ROOT, name)
    files_dir = os.path.join(dst, "files")
    zip_path = os.path.join(dst, "snapshot.zip")

    if os.path.exists(dst):
        print("快照已存在，改为追加时间戳后缀:", dst)
        name = name + "-" + datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
        dst = os.path.join(BACKUP_ROOT, name)
        files_dir = os.path.join(dst, "files")
        zip_path = os.path.join(dst, "snapshot.zip")

    os.makedirs(files_dir, exist_ok=True)

    entries = []
    for dp, dn, fn in os.walk(src):
        for f in fn:
            full = os.path.join(dp, f)
            rel = os.path.relpath(full, src)
            entries.append((full, rel.replace("\\", "/")))

    # 1) 逐文件副本
    for full, rel in entries:
        target = os.path.join(files_dir, rel.replace("/", os.sep))
        os.makedirs(os.path.dirname(target), exist_ok=True)
        shutil.copy2(full, target)

    # 2) 整树 zip
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as z:
        for full, rel in entries:
            z.write(full, rel)

    # 3) 清单
    lines = [
        "snapshot : %s" % name,
        "source   : %s" % src,
        "taken at : %s" % datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "files    : %d" % len(entries),
        "",
        "%-70s %10s  %s" % ("path", "bytes", "md5"),
        "-" * 100,
    ]
    for full, rel in sorted(entries, key=lambda x: x[1]):
        lines.append("%-70s %10d  %s" % (rel, os.path.getsize(full), md5(full)))
    open(os.path.join(dst, "MANIFEST.txt"), "w", encoding="utf-8").write("\n".join(lines))

    print("快照目录 :", dst)
    print("逐文件   :", files_dir)
    print("整树压缩 :", zip_path)
    print("清单     :", os.path.join(dst, "MANIFEST.txt"))
    print("文件数   :", len(entries))
    print("zip 大小 : %.2f MB" % (os.path.getsize(zip_path) / 1048576.0))


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(1)
    main(sys.argv[1], sys.argv[2])

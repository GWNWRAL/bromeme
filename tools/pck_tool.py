# -*- coding: utf-8 -*-
"""极简 .pck 解析器（适配 Brotato 的 Godot 3.7.dev 定制构建）。

该构建的头部在 magic/版本/引擎版本之后还有一段保留区，文件表不是紧跟其后，
所以这里用“第一个 res:// 路径”来定位文件表。

用法:
    python pck_tool.py list <pck> [关键字...]
    python pck_tool.py extract <pck> <输出目录> [包含子串...]
"""
import os, struct, sys


def parse(path):
    with open(path, "rb") as f:
        data = f.read()
    magic, version = struct.unpack_from("<II", data, 0)
    assert magic == 0x43504447, "不是 Godot pck"
    maj, mi, pa = struct.unpack_from("<III", data, 8)

    first = data.find(b"res://")
    if first < 0:
        raise SystemExit("找不到文件表")
    count = struct.unpack_from("<I", data, first - 8)[0]

    entries = []
    cur = first - 4
    for _ in range(count):
        sl = struct.unpack_from("<I", data, cur)[0]
        cur += 4
        name = data[cur:cur + sl].split(b"\x00")[0].decode("utf-8", "replace")
        cur += sl
        ofs, size = struct.unpack_from("<QQ", data, cur)
        cur += 16
        cur += 16  # md5
        entries.append((name, ofs, size))

    return dict(version=version, engine=(maj, mi, pa), count=count, entries=entries, data=data)


def main():
    cmd = sys.argv[1]
    pck = sys.argv[2]
    info = parse(pck)
    print("pck v%d engine=%s files=%d"
          % (info["version"], ".".join(map(str, info["engine"])), len(info["entries"])))

    if cmd == "list":
        keys = sys.argv[3:]
        for name, ofs, size in info["entries"]:
            if not keys or any(k.lower() in name.lower() for k in keys):
                print("%-78s %10d" % (name, size))
        return

    if cmd == "extract":
        outdir = sys.argv[3]
        keys = sys.argv[4:]
        n = 0
        with open(pck, "rb") as f:
            for name, ofs, size in info["entries"]:
                if keys and not any(k.lower() in name.lower() for k in keys):
                    continue
                rel = name.replace("res://", "").replace(":", "_")
                dst = os.path.join(outdir, rel)
                os.makedirs(os.path.dirname(dst) or outdir, exist_ok=True)
                f.seek(ofs)
                with open(dst, "wb") as g:
                    g.write(f.read(size))
                n += 1
        print("提取 %d 个文件 -> %s" % (n, outdir))
        return

    raise SystemExit(__doc__)


if __name__ == "__main__":
    main()

# -*- coding: utf-8 -*-
"""清理临时诊断代码（逐行处理，不用可能回溯的正则）。

van: 删掉
  · ModLoaderLog.info("VAN探针 ...) 开头的行（可能跨 2 行）
  · 我插入的 `elif _dash_index > 0 and _state_timer > 0.5:` 分支
mod_main: 删掉击退探针（注释 + if + ModLoaderLog.info 三行）
"""
import io

VAN = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\meme\content\enemies\van\van.gd"
MOD_MAIN = r"D:\DSH\Bromeme\mods-unpacked\General-bromeme\mod_main.gd"


def clean_van() -> None:
    lines = io.open(VAN, encoding="utf-8").read().split("\n")
    out = []
    i = 0
    dropped = 0
    while i < len(lines):
        l = lines[i]
        if "VAN探针" in l:
            # 如果是 ModLoaderLog.info("VAN探针 ... 多行形式，吃到以 "bromeme") 结尾那行
            if '"bromeme")' not in l and 'bromeme")' not in l:
                j = i
                while j < len(lines) and "bromeme" not in lines[j]:
                    j += 1
                i = j + 1
            else:
                i += 1
            dropped += 1
            continue
        # 删掉我插入的 elif 分支（单独一行）
        if l.strip() == "elif _dash_index > 0 and _state_timer > 0.5:":
            dropped += 1
            i += 1
            continue
        out.append(l)
        i += 1
    s = "\n".join(out)
    io.open(VAN, "w", encoding="utf-8", newline="\n").write(s)
    print("van: 删除 %d 处，行数 %d" % (dropped, len(s.split("\n"))))


def clean_mod_main() -> None:
    lines = io.open(MOD_MAIN, encoding="utf-8").read().split("\n")
    out = []
    i = 0
    dropped = 0
    while i < len(lines):
        l = lines[i]
        if "临时探针（查完删除）：确认效果资源真的加载到了" in l:
            i += 1
            # 跳过紧跟的 if 行与 ModLoaderLog 行
            while i < len(lines) and ('base_path.find("lantern")' in lines[i]
                                      or "击退探针" in lines[i]):
                i += 1
            dropped += 1
            continue
        if "击退探针" in l:
            i += 1
            dropped += 1
            continue
        out.append(l)
        i += 1
    s = "\n".join(out)
    io.open(MOD_MAIN, "w", encoding="utf-8", newline="\n").write(s)
    print("mod_main: 删除 %d 处" % dropped)


clean_van()
clean_mod_main()
print("完成")

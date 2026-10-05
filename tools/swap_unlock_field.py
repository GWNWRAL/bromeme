# -*- coding: utf-8 -*-
"""把 resources/*.json 的 unlocked_by_default 0/1 互换（用户要求）。

依据（原版 + 本 mod 代码）：
  can_be_looted = not (unlocked_by_default == 1)
  init_unlocked_pool() 只收 can_be_looted=true 的
  => json 写 1 = 不进商店；json 写 0 = 进商店

交换之后：
  原本写 1 的 24 件（meme 专属/混沌、李文亚系列、研究方向…）-> 0 ???
等等：写 0 才是进商店。用户要的是这 24 件「不进商店」。
所以这 24 件必须写成 1（= 不进商店），也就是它们**不该被交换**。
"""
import io, json, os, glob, shutil

print("脚本已废弃：见对话说明（这 24 件写 1 = 不进商店，本来就对，不需要交换）。")

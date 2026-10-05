# -*- coding: utf-8 -*-
import sys
sys.stdout.reconfigure(encoding="utf-8")
p = r"D:\DSH\_crash_analysis\narwhal\dlcs\dlc_1\enemies\narwhal\narwhal.tscn"
t = open(p, encoding="utf-8", errors="replace").read()
i = t.find("ChargingShootProjectilesBehavior")
print(t[max(0, i - 200): i + 1200])

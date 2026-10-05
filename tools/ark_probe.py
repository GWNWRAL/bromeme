# -*- coding: utf-8 -*-
"""探测当前 Ark 账号已开通哪些图片生成模型。"""
import json, os, sys, urllib.request, urllib.error

API = "https://ark.cn-beijing.volces.com/api/v3/images/generations"
KEY = os.environ.get("ARK_API_KEY", "")

CANDIDATES = [
    "doubao-seedream-4-0-250828",
    "doubao-seedream-4-0-250828-preview",
    "doubao-seedream-3-0-t2i-250415",
    "doubao-seededit-3-0-i2i-250628",
    "doubao-seededit-3-0-i2i-250715",
    "doubao-seedream-4-5-251028",
    "doubao-seedream-4-5-250928",
    "doubao-seedream-5-0-260828",
    "doubao-seedream-4-1-250928",
    "seedream-4-0-250828",
    "doubao-seedream-4-0",
    "high_aes_general_v30l_zt2i",
]


def probe(model):
    body = json.dumps({"model": model, "prompt": "test", "size": "1024x1024",
                       "response_format": "url", "watermark": False}).encode()
    req = urllib.request.Request(API, data=body,
                                headers={"Content-Type": "application/json",
                                         "Authorization": "Bearer " + KEY}, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=90) as r:
            return "OK", r.read()[:120].decode("utf-8", "replace")
    except urllib.error.HTTPError as e:
        raw = e.read().decode("utf-8", "replace")
        try:
            j = json.loads(raw)
            err = j.get("error", {})
            return err.get("code", "HTTP%d" % e.code), err.get("message", "")[:110]
        except Exception:
            return "HTTP%d" % e.code, raw[:110]
    except Exception as e:
        return type(e).__name__, str(e)[:110]


for m in CANDIDATES:
    code, msg = probe(m)
    print("%-38s %-28s %s" % (m, code, msg))

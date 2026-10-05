# -*- coding: utf-8 -*-
"""检查合成音效：打印峰值/RMS，并画波形+频谱图（人眼确认音色走向）。"""
import os, wave, struct
import numpy as np
from PIL import Image, ImageDraw

OUT = r"D:\DSH\_aitato_work\sfx_out"
IDS = ["whistle", "laugh", "salute", "siren"]


def load(path):
    with wave.open(path, "rb") as w:
        n = w.getnframes()
        rate = w.getframerate()
        raw = w.readframes(n)
    a = np.frombuffer(raw, dtype="<i2").astype(np.float32) / 32768.0
    return a, rate


rows = []
for i in IDS:
    p = os.path.join(OUT, i + ".wav")
    a, rate = load(p)
    peak = float(np.abs(a).max())
    rms = float(np.sqrt((a ** 2).mean()))
    # 有声段占比（包络超过峰值 5% 的采样比例）
    env = np.abs(a)
    k = int(rate * 0.01) or 1
    env = np.convolve(env, np.ones(k) / k, mode="same")
    active = float((env > peak * 0.05).mean())
    print("%-8s %5.2fs peak=%.3f rms=%.4f 有声占比=%.0f%% 削波采样=%d"
          % (i, len(a) / rate, peak, rms, active * 100, int((np.abs(a) > 0.999).sum())))
    rows.append((i, a, rate))

# 画图：每个音效一行，左边波形，右边 0-4kHz 频谱随时间变化
W, HCELL = 900, 190
img = Image.new("RGB", (W * 2 + 30, HCELL * len(rows)), (250, 250, 250))
d = ImageDraw.Draw(img)
for r, (name, a, rate) in enumerate(rows):
    y0 = r * HCELL
    # 波形
    step = max(1, len(a) // W)
    seg = a[: step * W].reshape(-1, step).max(axis=1)
    seg2 = a[: step * W].reshape(-1, step).min(axis=1)
    mid = y0 + HCELL // 2
    scale = (HCELL // 2 - 14)
    for x in range(len(seg)):
        d.line([(x, mid - seg[x] * scale), (x, mid - seg2[x] * scale)], fill=(30, 90, 200))
    d.line([(0, mid), (W, mid)], fill=(200, 200, 200))
    d.text((5, y0 + 4), "%s  waveform" % name, fill=(0, 0, 0))
    # 频谱
    win = 1024
    hop = max(1, len(a) // 300)
    frames = []
    for s in range(0, len(a) - win, hop):
        sp = np.abs(np.fft.rfft(a[s:s + win] * np.hanning(win)))
        frames.append(sp[: int(4000 / (rate / 2) * len(sp))])
    if frames:
        S = np.array(frames).T
        S = 20 * np.log10(S + 1e-6)
        S = np.clip((S - S.max() + 60) / 60.0, 0, 1)
        im = Image.fromarray((S * 255).astype(np.uint8)).resize((W, HCELL - 10), Image.BILINEAR)
        img.paste(im.convert("RGB").transpose(Image.FLIP_TOP_BOTTOM), (W + 30, y0 + 5))
        d.text((W + 35, y0 + 8), "%s  spectrogram 0-4kHz" % name, fill=(255, 255, 0))
img.save(r"D:\DSH\_aitato_work\sfx_check.png")
print("图:", r"D:\DSH\_aitato_work\sfx_check.png", img.size)

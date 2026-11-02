"""Generate the sample chart (120 BPM) -> charts/sample/chart.json
Usage: python tools/gen_chart.py
"""
import json

BEAT = 500
notes = []


def tap(t, lane):
    notes.append({"type": "tap", "time": t, "lane": lane})


def hold(t, end, lane):
    notes.append({"type": "hold", "time": t, "end": end, "lane": lane})


# A: 4분 단타 (2.5s ~ 10s)
pattern = [0, 1, 2, 3, 2, 1, 0, 3]
for i in range(16):
    tap(2500 + i * BEAT, pattern[i % 8])

# B: 홀드 + 사이 단타 (10.5s ~ 18.5s)
for k in range(4):
    base = 10500 + k * 2000
    hold(base, base + 1500, 0 if k % 2 == 0 else 3)
    tap_lane = 1 if k % 2 == 0 else 2
    tap(base + 500, tap_lane)
    tap(base + 1000, tap_lane)

# C: 8분 스트림 + 동시치기 (18.5s ~ 26.5s)
for i in range(32):
    t = 18500 + i * 250
    tap(t, i % 4)
    if i % 8 == 0:
        tap(t, (i + 2) % 4)

# D: 동시 홀드 (26.5s ~ 28s)
hold(26500, 28000, 1)
hold(26500, 28000, 2)

# Field: 바닥 노트와 동시에 진행되는 공중 영역 (B, C 구간 + 마무리)
def field(*keys):
    notes.append({"type": "field", "keys": [{"time": t, "center": c, "width": w} for t, c, w in keys]})


field((11000, 0.30, 0.30), (13000, 0.70, 0.25), (15000, 0.50, 0.20), (17000, 0.30, 0.30))
field((19000, 0.50, 0.40), (21000, 0.20, 0.25), (23000, 0.80, 0.25), (25000, 0.50, 0.30))
field((29500, 0.30, 0.25), (31500, 0.70, 0.15))

# Flick: Field 영역 안에서 가로지르도록 배치 (x는 그 시각의 Field 중심 근처)
def flick(t, x, d):
    notes.append({"type": "flick", "time": t, "x": x, "dir": d})


flick(12000, 0.50, "right")
flick(14000, 0.60, "left")
flick(16000, 0.40, "right")
flick(20000, 0.35, "left")
flick(22000, 0.50, "right")
flick(24000, 0.65, "left")
flick(29000, 0.50, "right")
flick(30500, 0.50, "left")

chart = {
    "meta": {"title": "Metronome Test", "artist": "dummy", "audio": "song.wav", "offset": 0, "level": 8, "difficulty": "NORMAL"},
    "timing": [{"time": 0, "bpm": 120}],
    "notes": notes,
}
with open("charts/sample/chart.json", "w", encoding="utf-8") as f:
    json.dump(chart, f, indent=1)
print("wrote", len(notes), "notes")

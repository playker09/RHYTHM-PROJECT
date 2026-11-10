"""샘플 채보 생성 (120 BPM) -> charts/sample/ez.json, nm.json, hd.json
사용법: python tools/gen_chart.py   (uv 를 쓰면: uv run --no-project python tools/gen_chart.py)
"""
import json
from pathlib import Path

BEAT = 500
OUT = Path(__file__).resolve().parent.parent / "charts" / "sample"


class Chart:
    def __init__(self):
        self.notes = []

    def tap(self, t, lane):
        self.notes.append({"type": "tap", "time": t, "lane": lane})

    def hold(self, t, end, lane):
        self.notes.append({"type": "hold", "time": t, "end": end, "lane": lane})

    def field(self, *keys):
        self.notes.append({"type": "field", "keys": [{"time": t, "center": c, "width": w} for t, c, w in keys]})

    def flick(self, t, x, d):
        self.notes.append({"type": "flick", "time": t, "x": x, "dir": d})

    def save(self, name, level):
        chart = {
            "meta": {"title": "Metronome Test", "artist": "Test Signal", "audio": "song.wav", "offset": 0, "level": level},
            "timing": [{"time": 0, "bpm": 120}],
            "notes": self.notes,
        }
        path = OUT / name
        path.write_text(json.dumps(chart, indent=1), encoding="utf-8")
        print(f"{path.name}: {len(self.notes)} notes (Lv {level})")


def make_ez():
    c = Chart()
    # A: 2분 단타
    for i, lane in enumerate([0, 1, 2, 3, 3, 2, 1, 0]):
        c.tap(2500 + i * BEAT * 2, lane)
    # B: 긴 홀드 + 넓은 Field
    for k in range(4):
        base = 10500 + k * 2000
        c.hold(base, base + 1000, 1 if k % 2 == 0 else 2)
    c.field((11000, 0.35, 0.45), (14000, 0.65, 0.45), (17000, 0.40, 0.45))
    c.flick(13000, 0.50, "right")
    c.flick(16000, 0.50, "left")
    # C: 4분 단타
    for i in range(16):
        c.tap(18500 + i * BEAT, [0, 1, 2, 3, 2, 1][i % 6])
    c.field((19500, 0.50, 0.50), (22500, 0.30, 0.45), (25500, 0.60, 0.45))
    # D: 마무리
    c.hold(26500, 28000, 1)
    c.flick(29000, 0.50, "right")
    c.flick(30500, 0.50, "left")
    return c


def make_nm():
    c = Chart()
    pattern = [0, 1, 2, 3, 2, 1, 0, 3]
    for i in range(16):
        c.tap(2500 + i * BEAT, pattern[i % 8])
    for k in range(4):
        base = 10500 + k * 2000
        c.hold(base, base + 1500, 0 if k % 2 == 0 else 3)
        lane = 1 if k % 2 == 0 else 2
        c.tap(base + 500, lane)
        c.tap(base + 1000, lane)
    for i in range(32):
        t = 18500 + i * 250
        c.tap(t, i % 4)
        if i % 8 == 0:
            c.tap(t, (i + 2) % 4)
    c.hold(26500, 28000, 1)
    c.hold(26500, 28000, 2)
    c.field((11000, 0.30, 0.30), (13000, 0.70, 0.25), (15000, 0.50, 0.20), (17000, 0.30, 0.30))
    c.field((19000, 0.50, 0.40), (21000, 0.20, 0.25), (23000, 0.80, 0.25), (25000, 0.50, 0.30))
    c.field((29500, 0.30, 0.25), (31500, 0.70, 0.15))
    for t, x, d in [(12000, 0.50, "right"), (14000, 0.60, "left"), (16000, 0.40, "right"), (20000, 0.35, "left"),
                    (22000, 0.50, "right"), (24000, 0.65, "left"), (29000, 0.50, "right"), (30500, 0.50, "left")]:
        c.flick(t, x, d)
    return c


def make_hd():
    c = Chart()
    # A: 8분 계단 + 동시치기
    stairs = [0, 1, 2, 3, 2, 1, 0, 1, 2, 3, 1, 2, 0, 3, 1, 2]
    for i in range(32):
        t = 2500 + i * 250
        c.tap(t, stairs[i % 16])
        if i % 8 == 4:
            c.tap(t, 3 - stairs[i % 16])
    # B: 홀드 + 8분 단타 + 좁은 Field
    for k in range(4):
        base = 10500 + k * 2000
        hold_lane = 0 if k % 2 == 0 else 3
        c.hold(base, base + 1750, hold_lane)
        for j in range(1, 7):
            c.tap(base + j * 250, (1 + j % 2) if k % 2 == 0 else (2 - j % 2))
    c.field((11000, 0.25, 0.22), (12000, 0.75, 0.20), (13000, 0.30, 0.20), (14000, 0.70, 0.18),
            (15000, 0.50, 0.16), (16000, 0.25, 0.20), (17000, 0.60, 0.22))
    for t, x, d in [(11500, 0.50, "right"), (12500, 0.52, "left"), (13500, 0.50, "right"), (14500, 0.60, "left"),
                    (15500, 0.38, "left"), (16500, 0.42, "right")]:
        c.flick(t, x, d)
    # C: 16분 트릴 섞인 스트림
    for i in range(32):
        t = 18500 + i * 250
        c.tap(t, [0, 2, 1, 3][i % 4])
        if i % 4 == 0:
            c.tap(t, [3, 1, 2, 0][(i // 4) % 4])
        if i % 8 >= 6:
            c.tap(t + 125, [1, 3, 0, 2][i % 4])
    c.field((19000, 0.50, 0.30), (20000, 0.20, 0.20), (21000, 0.50, 0.18), (22000, 0.80, 0.20),
            (23000, 0.50, 0.18), (24000, 0.25, 0.20), (25000, 0.50, 0.24))
    for t, x, d in [(20500, 0.35, "right"), (21500, 0.65, "right"), (22500, 0.65, "left"), (23500, 0.38, "left"),
                    (24500, 0.38, "right")]:
        c.flick(t, x, d)
    # D: 동시 홀드 + 마무리
    c.hold(26500, 28000, 0)
    c.hold(26500, 28000, 3)
    for j in range(6):
        c.tap(26750 + j * 250, 1 + j % 2)
    c.field((29500, 0.30, 0.22), (30500, 0.70, 0.18), (31500, 0.40, 0.14))
    c.flick(29000, 0.50, "right")
    c.flick(30000, 0.50, "right")
    c.flick(31000, 0.55, "left")
    return c


if __name__ == "__main__":
    make_ez().save("ez.json", 3)
    make_nm().save("nm.json", 8)
    make_hd().save("hd.json", 12)

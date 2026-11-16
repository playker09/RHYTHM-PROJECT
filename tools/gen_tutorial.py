"""튜토리얼 채보 + 가이드 문구 생성 (120 BPM, 약 40초) -> charts/tutorial/ez.json, guide.json
오디오는: python tools/gen_metronome.py 120 45 tutorial
사용법: python tools/gen_tutorial.py   (uv 를 쓰면: uv run --no-project python tools/gen_tutorial.py)

guide.json = {"guides": [{"time", "end", "text", "pad"?}]}  (ms, 곡 시간)
  text = 화면에 띄울 문구([대괄호] 안은 노란색 강조), focus = 그동안 노랗게 강조할 조작 부위("keys" 키 패드 / "air" 공중 판정선·커서), pad = 설정에서 "컨트롤러 사용"을 켰을 때 대신 띄울 문구(없으면 text)
"""
import json
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "charts" / "tutorial"

notes = []
guides = []


def guide(t, end, text, pad=None, focus=None):
    g = {"time": t, "end": end, "text": text}
    if focus:
        g["focus"] = focus
    if pad:
        g["pad"] = pad
    guides.append(g)


# 문구 안의 [대괄호] 부분은 게임에서 노란색으로 강조된다.
# 1) 탭: 한 박 반 간격으로 왼쪽 -> 오른쪽, 그다음 한 박 간격으로 되돌아오기
guide(500, 13800, "노트가 판정선에 닿을 때 [A S D F] 키를 누르세요.", focus="keys")
for i, lane in enumerate([0, 1, 2, 3]):
    notes.append({"type": "tap", "time": 4000 + i * 1500, "lane": lane})
for i, lane in enumerate([3, 2, 1, 0]):
    notes.append({"type": "tap", "time": 10000 + i * 1000, "lane": lane})

# 2) 홀드
guide(14200, 21500, "긴 노트는 [끝날 때까지 키를 누르고] 계세요.", focus="keys")
notes.append({"type": "hold", "time": 17000, "end": 18000, "lane": 1})
notes.append({"type": "hold", "time": 19500, "end": 20500, "lane": 2})

# 3) 공중 Field
guide(21900, 29500,
      "[마우스를 좌우로 움직여] 커서를 [파란 영역 안에] 유지하세요.",
      "[오른쪽 스틱을 좌우로 기울여] 커서를 [파란 영역 안에] 유지하세요.", focus="air")
notes.append({"type": "field", "keys": [
    {"time": 24500, "center": 0.50, "width": 0.45},
    {"time": 26000, "center": 0.30, "width": 0.40},
    {"time": 27500, "center": 0.70, "width": 0.40},
    {"time": 29000, "center": 0.50, "width": 0.40},
]})

# 4) Flick (커서가 가운데에서 시작해 오른쪽 -> 왼쪽으로 번갈아 넘어간다)
guide(29900, 39300,
      "화살표가 판정선에 닿을 때 [화살표 방향으로 마우스를 튕기세요.]",
      "화살표가 판정선에 닿을 때 [화살표 방향으로 오른쪽 스틱을 튕기세요.]", focus="air")
for i, d in enumerate(["right", "left", "right", "left"]):
    notes.append({"type": "flick", "time": 32500 + i * 2000, "x": 0.5, "dir": d})

guide(39600, 41600, "잘하셨습니다! 이제 곡을 골라 플레이해 보세요.")

chart = {
    "meta": {"title": "Tutorial", "artist": "How to Play", "audio": "song.wav", "offset": 0, "level": 1, "difficulty": "EZ"},
    "timing": [{"time": 0, "bpm": 120}],
    "notes": notes,
}
OUT.mkdir(parents=True, exist_ok=True)
(OUT / "ez.json").write_text(json.dumps(chart, indent=1), encoding="utf-8")
(OUT / "guide.json").write_text(json.dumps({"guides": guides}, indent=1, ensure_ascii=False), encoding="utf-8")
print(f"tutorial: {len(notes)} notes, {len(guides)} guides")

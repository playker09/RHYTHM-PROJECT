class_name AirAlert
extends RefCounted
## 스카이 알림: Flick 이 나오기 직전에 튕길 방향의 화면 옆 패널(왼쪽 = LEFT, 오른쪽 = RIGHT)과 공중 판정선을 밝히는 값을 만든다.
## Field 는 알리지 않는다(방향이 없어서 LEFT/RIGHT 가 뜨면 헷갈린다).
## 상태 없이 곡 시간에서 바로 계산한다(판정과 무관, 오토로드 참조 없음).

## 모든 Flick 을 알린다(빈도 제한 없음). 알림이 일찍 뜨면 뒤 노트의 알림이 앞 노트보다 먼저 보여 헷갈리므로 짧게 잡는다.
const LEAD_MS := 1000.0       # 노트 시각보다 이만큼 먼저 알리기 시작
const SIDE_LEFT := -1.0
const SIDE_RIGHT := 1.0

var _entries: Array[Vector2] = []    # (알릴 노트의 시각 ms, 쪽 SIDE_*), 시각 오름차순

## notes = ChartData.notes (time 오름차순)
func setup(notes: Array) -> void:
	_entries.clear()
	for n: NoteData in notes:
		if n.type == NoteData.Type.FLICK:
			_entries.append(Vector2(n.time, SIDE_LEFT if n.dir == "left" else SIDE_RIGHT))

func entry_times() -> Array[float]:
	var out: Array[float] = []
	for e in _entries:
		out.append(e.x)
	return out

## (왼쪽 번쩍임, 왼쪽 떠 있는 정도, 오른쪽 번쩍임, 오른쪽 떠 있는 정도) 전부 0~1. 알릴 것이 없으면 0.
## 한 번만 뜬다: 떠 있는 정도 = 빠르게 나타나 노트 시각에 사라지는 값, 번쩍임 = 나타나는 순간 1 에서 0 으로 가라앉는 값.
func sample(now_ms: float) -> Vector4:
	var out := Vector4.ZERO
	for e in _entries:
		if now_ms < e.x - LEAD_MS:
			break
		if now_ms >= e.x:
			continue
		var u: float = (now_ms - (e.x - LEAD_MS)) / LEAD_MS
		var blink: float = pow(1.0 - u, 2.0)
		var level: float = smoothstep(0.0, 0.12, u) * (1.0 - smoothstep(0.85, 1.0, u))
		if e.y < 0.0 and level >= out.y:
			out.x = blink
			out.y = level
		if e.y > 0.0 and level >= out.w:
			out.z = blink
			out.w = level
	return out

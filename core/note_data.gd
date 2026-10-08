class_name NoteData
extends RefCounted
## 채보의 노트 하나. 하단 '런타임' 필드는 플레이 중에만 쓴다.

enum Type { TAP, HOLD, FLICK, FIELD }

var type: Type = Type.TAP
var time: float = 0.0        # ms (Field는 첫 키프레임)
var end_time: float = 0.0    # ms (Hold 끝, Field 마지막 키프레임, 그 외 = time)
var lane: int = 0            # Tap / Hold
var x: float = 0.5           # Flick 위치 (0~1)
var dir: String = "right"    # Flick 방향
var keys: Array = []         # Field 키프레임 [{time, center, width}]

# 런타임
var judged: bool = false
var head_hit: bool = false
var view: Node3D = null

static func make_tap(t: float, lane_idx: int) -> NoteData:
	var n := NoteData.new()
	n.type = Type.TAP
	n.time = t
	n.end_time = t
	n.lane = lane_idx
	return n

static func make_hold(t: float, end: float, lane_idx: int) -> NoteData:
	var n := NoteData.new()
	n.type = Type.HOLD
	n.time = t
	n.end_time = end
	n.lane = lane_idx
	return n

func reset_runtime() -> void:
	judged = false
	head_hit = false
	view = null

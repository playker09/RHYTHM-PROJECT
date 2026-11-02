class_name FieldController
extends Node
## 가상 마우스 커서(0~1)와 Field 영역 상태.
## 입력 소스(마우스/컨트롤러)에 관계없이 apply_motion / set_cursor 로만 커서를 움직인다.
## Field 노트는 서로 겹치지 않는다고 가정한다.

const PIXELS_FULL_SWEEP := 1000.0   # 감도 1.0에서 커서가 0->1 가려면 필요한 마우스 이동 픽셀

var cursor_x: float = 0.5
var sensitivity: float = 1.0
var grace_ms: float = 150.0
var is_outside: bool = false        # 현재 활성 Field 영역 밖인가 (시각 효과용)

const VELOCITY_WINDOW_MS := 60.0
const FALLBACK_DT_MS := 16.0

var _prev_x: float = 0.5
var _samples: Array[Vector2] = []   # (시각 ms, 커서 x) 최근 기록
var _fields: Array[NoteData] = []
var _first: int = 0
var _outside_since: float = -1.0

func setup(chart: ChartData) -> void:
	_fields.clear()
	for n in chart.notes:
		if n.type == NoteData.Type.FIELD:
			_fields.append(n)
	_first = 0
	_outside_since = -1.0
	is_outside = false
	cursor_x = 0.5
	_prev_x = 0.5
	_samples.clear()

func apply_motion(dx_pixels: float, t: float) -> void:
	set_cursor(cursor_x + dx_pixels / PIXELS_FULL_SWEEP * sensitivity, t)

func set_cursor(x: float, t: float) -> void:
	_prev_x = cursor_x
	cursor_x = clampf(x, 0.0, 1.0)
	_samples.append(Vector2(t, cursor_x))
	while _samples.size() > 1 and t - _samples[0].x > VELOCITY_WINDOW_MS:
		_samples.pop_front()
	_refresh(t)

## 최근 VELOCITY_WINDOW_MS 동안의 부호 있는 커서 속도 (단위/초, + = 오른쪽).
## 직전 샘플이 오래됐으면(정지 후 첫 움직임) 한 프레임 동안 움직였다고 가정한다.
func velocity() -> float:
	if _samples.size() >= 2:
		var a: Vector2 = _samples[0]
		var b: Vector2 = _samples[_samples.size() - 1]
		var dt: float = b.x - a.x
		if dt > 0.0:
			return (b.y - a.y) / dt * 1000.0
	return (cursor_x - _prev_x) / FALLBACK_DT_MS * 1000.0

## 영역이 움직여서 커서가 밖이 되는 경우를 위해 매 프레임 호출
func update(now: float) -> void:
	_refresh(now)

## tick 시각 tick_t 의 판정. JudgeLogic.Grade 또는 GRADE_SKIP.
func evaluate_tick(note: NoteData, tick_t: float) -> int:
	var a: Dictionary = JudgeLogic.field_interp(note.keys, tick_t)
	var inside: bool = JudgeLogic.field_inside(cursor_x, float(a["center"]), float(a["width"]))
	var outside_for: float = 0.0
	if _outside_since >= 0.0:
		outside_for = maxf(tick_t - _outside_since, 0.0)
	return JudgeLogic.field_tick_result(inside, outside_for, grace_ms)

func _active(t: float) -> NoteData:
	while _first < _fields.size() and _fields[_first].end_time < t:
		_first += 1
	if _first < _fields.size() and _fields[_first].time <= t:
		return _fields[_first]
	return null

func _refresh(t: float) -> void:
	var note: NoteData = _active(t)
	if note == null:
		_outside_since = -1.0
		is_outside = false
		return
	var a: Dictionary = JudgeLogic.field_interp(note.keys, t)
	var inside: bool = JudgeLogic.field_inside(cursor_x, float(a["center"]), float(a["width"]))
	is_outside = not inside
	if inside:
		_outside_since = -1.0
	elif _outside_since < 0.0:
		_outside_since = t

class_name JudgeLogic
extends RefCounted
## 판정 순수 함수 모음. 노드/씬 의존 없음 -> 단위 테스트 대상.

enum Grade { PERFECT, GREAT, MISS }

## Field tick이 판정 없이 건너뛰어졌음을 뜻하는 값 (Grade가 아님)
const GRADE_SKIP := -1

## 키프레임 [{time, center, width}] 사이를 선형 보간. 범위 밖은 양 끝 값으로 고정.
static func field_interp(keys: Array, t: float) -> Dictionary:
	var last: int = keys.size() - 1
	if t <= float(keys[0]["time"]):
		return {"center": float(keys[0]["center"]), "width": float(keys[0]["width"])}
	if t >= float(keys[last]["time"]):
		return {"center": float(keys[last]["center"]), "width": float(keys[last]["width"])}
	for i in last:
		var a: Dictionary = keys[i]
		var b: Dictionary = keys[i + 1]
		if t <= float(b["time"]):
			var u: float = (t - float(a["time"])) / (float(b["time"]) - float(a["time"]))
			return {
				"center": lerpf(float(a["center"]), float(b["center"]), u),
				"width": lerpf(float(a["width"]), float(b["width"]), u),
			}
	return {"center": float(keys[last]["center"]), "width": float(keys[last]["width"])}

static func field_inside(cursor_x: float, center: float, width: float) -> bool:
	return absf(cursor_x - center) <= width * 0.5

## 영역 안 = PERFECT. 밖이어도 이탈 후 grace_ms 이내면 판정 없음(SKIP), 넘으면 MISS.
static func field_tick_result(inside: bool, outside_for_ms: float, grace_ms: float) -> int:
	if inside:
		return Grade.PERFECT
	if outside_for_ms <= grace_ms:
		return GRADE_SKIP
	return Grade.MISS

## 커서가 prev_x -> new_x 로 움직이며 note_x 를 dir 방향("left"/"right")으로 가로질렀는가
static func flick_crossed(prev_x: float, new_x: float, note_x: float, dir: String) -> bool:
	var m: float = GameConst.FLICK_X_MARGIN
	if dir == "left":
		return new_x < prev_x and prev_x > note_x - m and new_x <= note_x + m
	return new_x > prev_x and prev_x < note_x + m and new_x >= note_x - m

## velocity: 부호 있는 커서 속도(+ = 오른쪽, 단위/초)
static func flick_speed_ok(velocity: float, dir: String, min_speed: float) -> bool:
	if dir == "left":
		return -velocity >= min_speed
	return velocity >= min_speed

## Flick 등급: PERFECT_MS 이내 PERFECT, FLICK_WINDOW_MS 이내 GREAT, 밖은 MISS
static func flick_grade(delta_ms: float) -> int:
	var a: float = absf(delta_ms)
	if a <= GameConst.PERFECT_MS:
		return Grade.PERFECT
	if a <= GameConst.FLICK_WINDOW_MS:
		return Grade.GREAT
	return Grade.MISS

static func flick_missed(now_ms: float, note_time: float) -> bool:
	return now_ms - note_time > GameConst.FLICK_WINDOW_MS

## delta_ms = 입력 시각 - 노트 시각 (음수 = 빠름)
static func grade_from_delta(delta_ms: float) -> int:
	var a: float = absf(delta_ms)
	if a <= GameConst.PERFECT_MS:
		return Grade.PERFECT
	if a <= GameConst.GREAT_MS:
		return Grade.GREAT
	return Grade.MISS

## 입력이 없어 판정 창을 완전히 지났는가
static func is_missed(now_ms: float, note_time: float) -> bool:
	return now_ms - note_time > GameConst.GREAT_MS

## 점수 가중치 (PERFECT = 1.0)
static func score_weight(grade: int) -> float:
	match grade:
		Grade.PERFECT:
			return 1.0
		Grade.GREAT:
			return GameConst.GREAT_WEIGHT
	return 0.0

static func grade_name(grade: int) -> String:
	match grade:
		Grade.PERFECT:
			return "PERFECT"
		Grade.GREAT:
			return "GREAT"
	return "MISS"

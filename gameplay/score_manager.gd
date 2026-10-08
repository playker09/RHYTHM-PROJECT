class_name ScoreManager
extends Node

signal changed

var score: int = 0
var combo: int = 0
var max_combo: int = 0
var fast: int = 0                     # GREAT 중 빠른 입력
var slow: int = 0
var counts: Array[int] = [0, 0, 0]    # JudgeLogic.Grade 인덱스 (head + tick 합산)

var _total: int = 1
var _earned: float = 0.0

func setup(total_judgements: int) -> void:
	_total = maxi(total_judgements, 1)
	score = 0
	combo = 0
	max_combo = 0
	_earned = 0.0
	counts = [0, 0, 0]
	fast = 0
	slow = 0
	changed.emit()

func on_judged(_note: NoteData, grade: int, delta_ms: float, is_tick: bool) -> void:
	counts[grade] += 1
	if grade == JudgeLogic.Grade.GREAT and not is_tick:
		if delta_ms < 0.0:
			fast += 1
		else:
			slow += 1
	_earned += JudgeLogic.score_weight(grade)
	if grade == JudgeLogic.Grade.MISS:
		combo = 0
	else:
		combo += 1
		max_combo = maxi(max_combo, combo)
	score = roundi(GameConst.MAX_SCORE * _earned / _total)
	changed.emit()

## 결과 등급. 전부 PERFECT면 "AP", 미스가 없으면 최소 "A" 미만이어도 풀콤 표시는 UI에서 따로 한다.
func rank() -> String:
	if counts[1] == 0 and counts[2] == 0 and (counts[0] > 0):
		return "AP"
	if score >= 950000:
		return "S"
	if score >= 900000:
		return "A"
	if score >= 800000:
		return "B"
	if score >= 700000:
		return "C"
	return "D"

func is_full_combo() -> bool:
	return counts[2] == 0 and (counts[0] + counts[1]) > 0
